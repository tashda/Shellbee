"""
Shellbee mock Zigbee2MQTT engine.

Much more than a passive seeder: this process owns authoritative device and
bridge state on the mock network. It subscribes to the same MQTT topics the
real Zigbee2MQTT would react to (``<device>/set``, ``<device>/get``,
``bridge/request/#``) and mirrors the real z2m request/response/event
protocol so the iOS client can be exercised end-to-end without a real radio.

What is faithfully simulated
----------------------------
- ``<device>/set``: payload merged into device state; full state republished
  retained on ``zigbee2mqtt/<device>`` (identical to z2m's read-after-write).
- ``<device>/get``: republishes the current retained state.
- ``bridge/request/<path>``: every request receives a matching
  ``bridge/response/<path>`` envelope ``{data, status, [error], [transaction]}``.
  Covered: device rename/remove/options/interview/configure/bind/unbind,
  OTA check/update (with progress ticks), group add/remove/rename/options +
  group members add/remove, permit_join, info, restart, backup, options,
  health_check, install_code/add, devices, groups, touchlink scan/identify/
  factory_reset, action, configure_reporting.
- ``bridge/event``: emitted for device_joined, device_leave, device_renamed,
  device_interview, device_announce, and permit_join state changes.
- OTA state machine: ``update`` is attached to the device state as
  ``{installed_version, latest_version, state}``. ``check`` flips state to
  ``available``; ``update`` drives progress → ``updating`` with ``progress``
  and ``remaining``, finishing as ``idle`` with ``installed_version`` caught up.
- Continuous drift: temp/humidity/power/linkquality/battery drift on the
  LIVE state so user-set values are preserved across ticks.

What is intentionally NOT simulated (stubs)
-------------------------------------------
- No real Zigbee interview or OTA image transfer — only the public protocol
  (events and response envelopes) is produced.
- No binding enforcement or scene recall side-effects.
- No group fan-out: setting a group does NOT automatically change its
  members' states (z2m does when optimistic=true; we can add if a test
  needs it).
- No availability-timeout logic. Devices stay ``online`` until a test
  explicitly flips them.
- No retained ``bridge/logging`` — z2m does not retain these either; they
  are streamed live, which we match.
- No TouchLink radio behavior — responses are empty ``found`` arrays etc.
- ``bridge/request/backup`` returns an empty payload (no real zip).

All request handlers raise :class:`RequestError` on bad input; the outer
dispatcher converts that into the standard z2m
``{data, status: "error", error}`` envelope.
"""

from __future__ import annotations

import copy
import json
import logging
import os
import random
import threading
import time
from datetime import datetime
from typing import Any, Callable

import paho.mqtt.client as mqtt

from fixtures import (
    ALL_DEVICES, DEVICE_STATES, BRIDGE_INFO, BRIDGE_HEALTH, GROUPS
)

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s [engine] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger(__name__)

MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
Z2M_TOPIC = os.environ.get("Z2M_TOPIC", "zigbee2mqtt")
MODE = os.environ.get("MODE", "continuous")            # "once" | "continuous"
SEED_INTERVAL = int(os.environ.get("SEED_INTERVAL", "60"))
OTA_TICK_MS = int(os.environ.get("OTA_TICK_MS", "400"))
OTA_STEP = int(os.environ.get("OTA_STEP", "10"))

# ── Mutable engine state ──────────────────────────────────────────────────

_lock = threading.RLock()
_devices: list[dict] = []          # mirror of ALL_DEVICES, mutable
_groups: list[dict] = []           # mirror of GROUPS, mutable
_states: dict[str, dict] = {}      # live state per friendly_name
_bridge_info: dict = {}            # mirror of BRIDGE_INFO, mutable
_bridge_health: dict = {}          # mirror of BRIDGE_HEALTH, mutable
_permit_join_timer: threading.Timer | None = None

# Topics from previous fixture revisions — cleared on startup so stale
# retained messages don't leak into a fresh client connect.
STALE_TOPICS = [
    "Living Room Air Purifier",
    "Living Room Air Purifier/availability",
]


class RequestError(Exception):
    """Raised by a request handler to produce a ``status: "error"`` response."""


# ── Publish helpers ───────────────────────────────────────────────────────

def _now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _pub(client, topic: str, payload: Any, *, retain: bool = True) -> None:
    if isinstance(payload, (bytes, bytearray)):
        data: Any = payload
    else:
        data = json.dumps(payload, separators=(",", ":"), default=str)
    client.publish(topic, data, retain=retain, qos=1)


def _publish_state(client, name: str) -> None:
    with _lock:
        if name not in _states:
            return
        state = dict(_states[name])
    state["last_seen"] = _now_iso()
    _pub(client, f"{Z2M_TOPIC}/{name}", state, retain=True)


def _publish_availability(client, name: str, state: str = "online") -> None:
    _pub(client, f"{Z2M_TOPIC}/{name}/availability", {"state": state}, retain=True)


def _publish_devices(client) -> None:
    with _lock:
        snapshot = copy.deepcopy(_devices)
    _pub(client, f"{Z2M_TOPIC}/bridge/devices", snapshot, retain=True)


def _publish_groups(client) -> None:
    with _lock:
        snapshot = copy.deepcopy(_groups)
    _pub(client, f"{Z2M_TOPIC}/bridge/groups", snapshot, retain=True)


def _publish_info(client) -> None:
    with _lock:
        snapshot = copy.deepcopy(_bridge_info)
    _pub(client, f"{Z2M_TOPIC}/bridge/info", snapshot, retain=True)


def _publish_health(client) -> None:
    with _lock:
        snapshot = copy.deepcopy(_bridge_health)
    _pub(client, f"{Z2M_TOPIC}/bridge/health", snapshot, retain=True)


def _emit_event(client, type_: str, data: dict) -> None:
    envelope = {"type": type_, "data": data}
    _pub(client, f"{Z2M_TOPIC}/bridge/event", envelope, retain=False)


def _emit_log(client, level: str, message: str) -> None:
    _pub(
        client,
        f"{Z2M_TOPIC}/bridge/logging",
        {"level": level, "message": message, "namespace": "engine", "message_id": None},
        retain=False,
    )


def _clear_retained(client, topic_suffix: str) -> None:
    client.publish(f"{Z2M_TOPIC}/{topic_suffix}", payload=b"", retain=True, qos=1)


# ── Device lookup ─────────────────────────────────────────────────────────

def _find_device(identifier: str) -> dict | None:
    """Look up by friendly_name first, then ieee_address."""
    with _lock:
        for d in _devices:
            if d["friendly_name"] == identifier:
                return d
        for d in _devices:
            if d["ieee_address"] == identifier:
                return d
    return None


def _find_group(identifier: str | int) -> dict | None:
    with _lock:
        for g in _groups:
            if g["friendly_name"] == identifier or g["id"] == identifier:
                return g
        # Allow numeric string IDs
        try:
            gid = int(identifier)
            for g in _groups:
                if g["id"] == gid:
                    return g
        except (TypeError, ValueError):
            pass
    return None


def _next_group_id() -> int:
    with _lock:
        return (max((g["id"] for g in _groups), default=0) + 1)


# ── /set and /get handlers ────────────────────────────────────────────────

def _hex_to_xy(hex_str: str) -> dict:
    """Convert a `#rrggbb` colour to CIE 1931 xy coords. Mirrors what real
    z2m does when the frontend posts ``{"color": {"hex": "..."}}``."""
    if not isinstance(hex_str, str):
        return {"x": 0.3, "y": 0.3}
    h = hex_str.lstrip("#")
    if len(h) != 6:
        return {"x": 0.3, "y": 0.3}
    try:
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    except ValueError:
        return {"x": 0.3, "y": 0.3}
    def gc(c: float) -> float:
        return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
    r, g, b = gc(r), gc(g), gc(b)
    X = r * 0.4124 + g * 0.3576 + b * 0.1805
    Y = r * 0.2126 + g * 0.7152 + b * 0.0722
    Z = r * 0.0193 + g * 0.1192 + b * 0.9505
    s = X + Y + Z
    if s <= 0:
        return {"x": 0.3, "y": 0.3}
    return {"x": round(X / s, 4), "y": round(Y / s, 4)}


def _is_light(device: dict) -> bool:
    defn = device.get("definition") or {}
    for ex in defn.get("exposes", []) or []:
        if ex.get("type") == "light":
            return True
    return False


def handle_set(client, name: str, payload: Any) -> None:
    if not isinstance(payload, dict):
        log.warning("set for %r: non-dict payload %r", name, payload)
        return
    device = _find_device(name)
    if device is None:
        log.warning("set for unknown device %r", name)
        return
    payload = dict(payload)
    with _lock:
        state = _states.setdefault(name, {})
        # "state" requests with value "TOGGLE" flip the current binary state.
        if payload.get("state") == "TOGGLE":
            current = state.get("state", "OFF")
            payload["state"] = "OFF" if str(current).upper() == "ON" else "ON"

        # Light semantics: real z2m turns the bulb ON when brightness/color/
        # color_temp is set on an OFF light, and updates color_mode to match
        # the chosen colour representation. The app reads color_mode to pick
        # which slider to render. Real z2m also normalises a `hex` color
        # input into xy coords; the app's colour reader only understands
        # x/y, hue/sat, or r/g/b — never hex — so we must convert.
        if _is_light(device):
            if (
                "brightness" in payload
                or "color" in payload
                or "color_temp" in payload
            ) and "state" not in payload:
                payload["state"] = "ON"
            if "color_temp" in payload:
                payload["color_mode"] = "color_temp"
            elif "color" in payload and isinstance(payload["color"], dict):
                c = dict(payload["color"])
                if "hex" in c and "x" not in c and "hue" not in c:
                    c = _hex_to_xy(c["hex"])
                    payload["color"] = c
                if "hue" in c or "saturation" in c:
                    payload["color_mode"] = "hs"
                elif "x" in c or "y" in c:
                    payload["color_mode"] = "xy"

        for k, v in payload.items():
            state[k] = v
        state["last_seen"] = _now_iso()
    _publish_state(client, name)


def handle_get(client, name: str, payload: Any) -> None:
    if _find_device(name) is None:
        return
    _publish_state(client, name)


# ── bridge/request handlers ───────────────────────────────────────────────

_handlers: dict[str, Callable[[Any, Any], Any]] = {}


def _register(path: str):
    def deco(fn):
        _handlers[path] = fn
        return fn
    return deco


@_register("device/rename")
def _req_device_rename(client, payload):
    old = payload.get("from")
    new = payload.get("to")
    if not old or not new:
        raise RequestError("Parameters 'from' and 'to' are required")
    device = _find_device(old)
    if device is None:
        raise RequestError(f"Device '{old}' does not exist")
    if _find_device(new) is not None:
        raise RequestError(f"Device '{new}' already exists")
    with _lock:
        device["friendly_name"] = new
        if old in _states:
            _states[new] = _states.pop(old)
    _clear_retained(client, old)
    _clear_retained(client, f"{old}/availability")
    _publish_state(client, new)
    _publish_availability(client, new)
    _publish_devices(client)
    _emit_event(client, "device_renamed", {"from": old, "to": new})
    return {"from": old, "to": new, "homeassistant_rename": bool(payload.get("homeassistant_rename", False))}


@_register("device/remove")
def _req_device_remove(client, payload):
    ident = payload.get("id") or payload.get("friendly_name")
    if not ident:
        raise RequestError("Parameter 'id' is required")
    device = _find_device(ident)
    if device is None:
        raise RequestError(f"Device '{ident}' does not exist")
    name = device["friendly_name"]
    ieee = device["ieee_address"]
    with _lock:
        _devices.remove(device)
        _states.pop(name, None)
    _clear_retained(client, name)
    _clear_retained(client, f"{name}/availability")
    _publish_devices(client)
    _emit_event(client, "device_leave", {"ieee_address": ieee, "friendly_name": name})
    return {"id": ident, "block": bool(payload.get("block", False)),
            "force": bool(payload.get("force", False))}


@_register("device/options")
def _req_device_options(client, payload):
    ident = payload.get("id") or payload.get("friendly_name")
    options = payload.get("options")
    if not ident or options is None:
        raise RequestError("Parameters 'id' and 'options' are required")
    device = _find_device(ident)
    if device is None:
        raise RequestError(f"Device '{ident}' does not exist")
    with _lock:
        # Real Z2M stores per-device options in `bridge/info.config.devices[ieee]`,
        # not on the per-device entry of `bridge/devices`. Mirror that here so the
        # mock matches production behavior — and keep the on-device copy so any
        # legacy reader still works.
        device.setdefault("options", {}).update(options)
        merged = dict(device["options"])
        config = _bridge_info.setdefault("config", {})
        cfg_devices = config.setdefault("devices", {})
        ieee = device.get("ieee_address") or ident
        entry = cfg_devices.setdefault(ieee, {"friendly_name": device.get("friendly_name", ident)})
        entry.update(options)
    _publish_devices(client)
    _publish_info(client)
    return {"id": ident, "from": options, "to": merged, "restart_required": False}


@_register("device/interview")
def _req_device_interview(client, payload):
    ident = payload.get("id")
    if not ident:
        raise RequestError("Parameter 'id' is required")
    device = _find_device(ident)
    if device is None:
        raise RequestError(f"Device '{ident}' does not exist")

    def run():
        name = device["friendly_name"]
        ieee = device["ieee_address"]
        _emit_event(client, "device_interview", {
            "friendly_name": name, "status": "started", "ieee_address": ieee,
        })
        time.sleep(1)
        with _lock:
            device["interview_completed"] = True
            device["interviewing"] = False
            device["interview_state"] = "SUCCESSFUL"
        _emit_event(client, "device_interview", {
            "friendly_name": name, "status": "successful", "ieee_address": ieee,
            "supported": True,
            "definition": device.get("definition"),
        })
        _publish_devices(client)
    threading.Thread(target=run, daemon=True).start()
    return {"id": ident}


@_register("device/configure")
def _req_device_configure(client, payload):
    ident = payload.get("id")
    if not ident:
        raise RequestError("Parameter 'id' is required")
    if _find_device(ident) is None:
        raise RequestError(f"Device '{ident}' does not exist")
    return {"id": ident}


@_register("device/bind")
def _req_device_bind(client, payload):
    return payload


@_register("device/unbind")
def _req_device_unbind(client, payload):
    return payload


@_register("device/configure_reporting")
def _req_device_configure_reporting(client, payload):
    return payload


# ── OTA ────────────────────────────────────────────────────────────────────

def _version_bump(v: Any) -> Any:
    """Return a plausible 'newer' version for a build string or int."""
    if isinstance(v, int):
        return v + 1
    if isinstance(v, str) and v:
        parts = v.split(".")
        try:
            parts[-1] = str(int(parts[-1]) + 1)
            return ".".join(parts)
        except ValueError:
            return v + "+1"
    return 1


def _device_version_map(device: dict) -> dict:
    installed = device.get("software_build_id") or 0
    return {
        "installed_version": installed if isinstance(installed, int) else 1,
        "latest_version": _version_bump(installed) if isinstance(installed, int) else 2,
    }


@_register("device/ota_update/check")
def _req_ota_check(client, payload):
    ident = payload.get("id")
    if not ident:
        raise RequestError("Parameter 'id' is required")
    device = _find_device(ident)
    if device is None:
        raise RequestError(f"Device '{ident}' does not exist")
    name = device["friendly_name"]
    versions = _device_version_map(device)
    with _lock:
        state = _states.setdefault(name, {})
        state["update"] = {
            "installed_version": versions["installed_version"],
            "latest_version": versions["latest_version"],
            "state": "available",
        }
    _publish_state(client, name)
    return {
        "id": ident,
        "updateAvailable": True,
        "from": {"software_build_id": str(versions["installed_version"])},
        "to":   {"software_build_id": str(versions["latest_version"])},
    }


@_register("device/ota_update/update")
def _req_ota_update(client, payload):
    ident = payload.get("id")
    if not ident:
        raise RequestError("Parameter 'id' is required")
    device = _find_device(ident)
    if device is None:
        raise RequestError(f"Device '{ident}' does not exist")
    name = device["friendly_name"]
    transaction = payload.get("transaction")
    versions = _device_version_map(device)

    def run():
        _emit_log(client, "info", f"Updating '{name}' to latest firmware")
        progress = 0
        while progress < 100:
            progress = min(100, progress + OTA_STEP)
            remaining_s = max(0, (100 - progress) * OTA_TICK_MS // 1000)
            with _lock:
                _states.setdefault(name, {})["update"] = {
                    "installed_version": versions["installed_version"],
                    "latest_version": versions["latest_version"],
                    "state": "updating",
                    "progress": progress,
                    "remaining": remaining_s,
                }
            _publish_state(client, name)
            time.sleep(OTA_TICK_MS / 1000.0)
        with _lock:
            _states.setdefault(name, {})["update"] = {
                "installed_version": versions["latest_version"],
                "latest_version": versions["latest_version"],
                "state": "idle",
            }
        _publish_state(client, name)
        # Post-update response (z2m publishes the success envelope when done).
        response = {
            "data": {
                "id": ident,
                "from": {"software_build_id": str(versions["installed_version"])},
                "to":   {"software_build_id": str(versions["latest_version"])},
            },
            "status": "ok",
        }
        if transaction is not None:
            response["transaction"] = transaction
        _pub(client, f"{Z2M_TOPIC}/bridge/response/device/ota_update/update",
             response, retain=False)
        _emit_log(client, "info", f"Finished update of '{name}'")

    threading.Thread(target=run, daemon=True).start()
    # Suppress the auto-response; we publish our own when the async update finishes.
    raise _DeferResponse()


class _DeferResponse(Exception):
    """Handler will publish its own response asynchronously — skip auto-reply."""


# ── Groups ─────────────────────────────────────────────────────────────────

@_register("group/add")
def _req_group_add(client, payload):
    fname = payload.get("friendly_name")
    if not fname:
        raise RequestError("Parameter 'friendly_name' is required")
    if _find_group(fname) is not None:
        raise RequestError(f"Group '{fname}' already exists")
    gid = payload.get("id") or _next_group_id()
    group = {
        "id": int(gid),
        "friendly_name": fname,
        "description": None,
        "members": [],
        "scenes": [],
    }
    with _lock:
        _groups.append(group)
    _publish_groups(client)
    return {"friendly_name": fname, "id": int(gid)}


@_register("group/remove")
def _req_group_remove(client, payload):
    ident = payload.get("id") or payload.get("friendly_name")
    if ident is None:
        raise RequestError("Parameter 'id' is required")
    group = _find_group(ident)
    if group is None:
        raise RequestError(f"Group '{ident}' does not exist")
    with _lock:
        _groups.remove(group)
    _publish_groups(client)
    return {"id": ident, "force": bool(payload.get("force", False))}


@_register("group/rename")
def _req_group_rename(client, payload):
    old = payload.get("from")
    new = payload.get("to")
    if not old or not new:
        raise RequestError("Parameters 'from' and 'to' are required")
    group = _find_group(old)
    if group is None:
        raise RequestError(f"Group '{old}' does not exist")
    if _find_group(new) is not None:
        raise RequestError(f"Group '{new}' already exists")
    with _lock:
        group["friendly_name"] = new
    _publish_groups(client)
    return {"from": old, "to": new}


@_register("group/options")
def _req_group_options(client, payload):
    ident = payload.get("id") or payload.get("friendly_name")
    options = payload.get("options", {})
    group = _find_group(ident)
    if group is None:
        raise RequestError(f"Group '{ident}' does not exist")
    with _lock:
        group.setdefault("description", None)
        if "description" in options:
            group["description"] = options["description"]
    _publish_groups(client)
    return {"id": ident, "from": {}, "to": options, "restart_required": False}


@_register("group/members/add")
def _req_group_member_add(client, payload):
    g = _find_group(payload.get("group"))
    if g is None:
        raise RequestError(f"Group '{payload.get('group')}' does not exist")
    dev = _find_device(payload.get("device", ""))
    if dev is None:
        raise RequestError(f"Device '{payload.get('device')}' does not exist")
    endpoint = payload.get("endpoint") or int(next(iter(dev.get("endpoints", {"1": {}}).keys())))
    member = {"ieee_address": dev["ieee_address"], "endpoint": int(endpoint)}
    with _lock:
        if member not in g["members"]:
            g["members"].append(member)
    _publish_groups(client)
    return {"group": g["friendly_name"], "device": dev["friendly_name"], "endpoint": int(endpoint)}


@_register("group/members/remove")
def _req_group_member_remove(client, payload):
    g = _find_group(payload.get("group"))
    if g is None:
        raise RequestError(f"Group '{payload.get('group')}' does not exist")
    dev = _find_device(payload.get("device", ""))
    ieee = dev["ieee_address"] if dev else payload.get("device")
    with _lock:
        g["members"] = [m for m in g["members"] if m["ieee_address"] != ieee]
    _publish_groups(client)
    return {"group": g["friendly_name"], "device": payload.get("device")}


# ── Bridge-level requests ──────────────────────────────────────────────────

def _clear_permit_join_timer():
    global _permit_join_timer
    if _permit_join_timer is not None:
        _permit_join_timer.cancel()
        _permit_join_timer = None


@_register("permit_join")
def _req_permit_join(client, payload):
    global _permit_join_timer
    value = bool(payload.get("value", False))
    time_s = payload.get("time")
    with _lock:
        _bridge_info["permit_join"] = value
        _bridge_info["permit_join_timeout"] = int(time_s) if (value and time_s) else None
        _bridge_info["config"]["permit_join"] = value
    _publish_info(client)
    _emit_event(client, "permit_join", {"permitted": value, "time": time_s, "device": payload.get("device")})
    _clear_permit_join_timer()
    if value and time_s:
        def expire():
            with _lock:
                _bridge_info["permit_join"] = False
                _bridge_info["permit_join_timeout"] = None
                _bridge_info["config"]["permit_join"] = False
            _publish_info(client)
            _emit_event(client, "permit_join", {"permitted": False})
        _permit_join_timer = threading.Timer(float(time_s), expire)
        _permit_join_timer.daemon = True
        _permit_join_timer.start()
    return {"value": value, "time": time_s, "device": payload.get("device")}


@_register("info")
def _req_info(client, payload):
    _publish_info(client)
    with _lock:
        return copy.deepcopy(_bridge_info)


@_register("restart")
def _req_restart(client, payload):
    _emit_log(client, "info", "Restart requested (mock engine — no-op)")
    return {}


@_register("backup")
def _req_backup(client, payload):
    return {"zip": ""}


@_register("options")
def _req_options(client, payload):
    """Merge the options payload into bridge/info.config (deep merge)."""
    if not isinstance(payload, dict):
        raise RequestError("Payload must be an object")

    def deep_merge(dst: dict, src: dict) -> None:
        for k, v in src.items():
            if isinstance(v, dict) and isinstance(dst.get(k), dict):
                deep_merge(dst[k], v)
            else:
                dst[k] = v

    with _lock:
        options = payload.get("options", payload)
        deep_merge(_bridge_info["config"], options)
        snapshot = copy.deepcopy(_bridge_info)
    _publish_info(client)
    return {"restart_required": False, "config": snapshot["config"]}


@_register("health_check")
def _req_health_check(client, payload):
    _publish_health(client)
    with _lock:
        return copy.deepcopy(_bridge_health)


@_register("install_code/add")
def _req_install_code(client, payload):
    return {"value": payload.get("value", "")}


@_register("devices")
def _req_devices(client, payload):
    _publish_devices(client)
    return []


@_register("groups")
def _req_groups(client, payload):
    _publish_groups(client)
    return []


@_register("touchlink/scan")
def _req_touchlink_scan(client, payload):
    return {"found": []}


@_register("touchlink/identify")
def _req_touchlink_identify(client, payload):
    return payload


@_register("touchlink/factory_reset")
def _req_touchlink_factory_reset(client, payload):
    return payload


@_register("action")
def _req_action(client, payload):
    return payload


# ── Dispatch ───────────────────────────────────────────────────────────────

def handle_request(client, subpath: str, payload: Any) -> None:
    handler = _handlers.get(subpath)
    transaction = payload.get("transaction") if isinstance(payload, dict) else None
    response_topic = f"{Z2M_TOPIC}/bridge/response/{subpath}"

    if handler is None:
        log.warning("No handler for bridge/request/%s", subpath)
        envelope = {"data": {}, "status": "error", "error": f"Unknown request: {subpath}"}
        if transaction is not None:
            envelope["transaction"] = transaction
        _pub(client, response_topic, envelope, retain=False)
        return

    try:
        data = handler(client, payload if isinstance(payload, dict) else {})
        envelope: dict[str, Any] = {"data": data or {}, "status": "ok"}
    except _DeferResponse:
        return
    except RequestError as exc:
        envelope = {"data": payload if isinstance(payload, dict) else {},
                    "status": "error", "error": str(exc)}
    except Exception as exc:  # noqa: BLE001
        log.exception("Handler for %s raised", subpath)
        envelope = {"data": payload if isinstance(payload, dict) else {},
                    "status": "error", "error": f"Internal error: {exc}"}

    if transaction is not None:
        envelope["transaction"] = transaction
    _pub(client, response_topic, envelope, retain=False)


# ── MQTT wiring ────────────────────────────────────────────────────────────

_z2m_online = False
_client: mqtt.Client | None = None  # set in main() once instantiated; used by control.py
_mqtt_connected = False              # True between on_connect and on_disconnect
_mqtt_last_error: str | None = None  # last broker connect/disconnect failure reason
_seed_complete = False               # True after seed_initial() finishes


def on_connect(client, userdata, flags, reason_code, properties):
    global _mqtt_connected, _mqtt_last_error
    log.info("Connected to MQTT broker (rc=%s)", reason_code)
    _mqtt_connected = True
    _mqtt_last_error = None
    client.subscribe(f"{Z2M_TOPIC}/bridge/state")
    client.subscribe(f"{Z2M_TOPIC}/+/set")
    client.subscribe(f"{Z2M_TOPIC}/+/get")
    client.subscribe(f"{Z2M_TOPIC}/bridge/request/#")
    client.subscribe(f"{Z2M_TOPIC}/_engine/client_connected")


def on_disconnect(client, userdata, *args):
    global _mqtt_connected
    _mqtt_connected = False
    log.warning("Disconnected from MQTT broker (args=%s)", args)


def on_message(client, userdata, msg):
    global _z2m_online
    topic = msg.topic
    if not topic.startswith(Z2M_TOPIC + "/"):
        return
    sub = topic[len(Z2M_TOPIC) + 1:]

    try:
        payload = json.loads(msg.payload) if msg.payload else {}
    except Exception:
        payload = msg.payload.decode(errors="replace") if msg.payload else ""

    if sub == "bridge/state":
        state = payload.get("state") if isinstance(payload, dict) else payload
        if state == "online":
            _z2m_online = True
            log.info("Zigbee2MQTT bridge online")
        return

    if sub == "_engine/client_connected":
        # Fire a drift tick shortly after a new WS client connects so the
        # app's Activity log has at least one state-diff entry ready by
        # the time it reaches the Logs view. Delay long enough for the
        # retained-message replay to finish ingesting in the client.
        threading.Timer(1.0, lambda: drift_tick(client)).start()
        return

    if sub.endswith("/set"):
        name = sub[:-len("/set")]
        handle_set(client, name, payload)
        return

    if sub.endswith("/get"):
        name = sub[:-len("/get")]
        handle_get(client, name, payload)
        return

    if sub.startswith("bridge/request/"):
        handle_request(client, sub[len("bridge/request/"):], payload)
        return


# ── Initial seed + drift ───────────────────────────────────────────────────

def _init_state() -> None:
    global _devices, _groups, _bridge_info, _bridge_health
    with _lock:
        _devices = copy.deepcopy(ALL_DEVICES)
        _groups = copy.deepcopy(GROUPS)
        _bridge_info = copy.deepcopy(BRIDGE_INFO)
        _bridge_health = copy.deepcopy(BRIDGE_HEALTH)
        # Mirror per-device options into bridge/info.config.devices to match real Z2M.
        cfg_devices = _bridge_info.setdefault("config", {}).setdefault("devices", {})
        for d in _devices:
            ieee = d.get("ieee_address")
            if not ieee:
                continue
            entry = {"friendly_name": d.get("friendly_name", "")}
            entry.update(d.get("options") or {})
            cfg_devices[ieee] = entry
        _states.clear()
        for name, state in DEVICE_STATES.items():
            _states[name] = copy.deepcopy(state)


def _clear_stale(client) -> None:
    for t in STALE_TOPICS:
        _clear_retained(client, t)


def seed_initial(client) -> None:
    count = sum(1 for d in _devices if d.get("type") != "Coordinator")
    log.info("Seeding %d devices …", count)
    _clear_stale(client)
    _publish_info(client)
    _publish_devices(client)
    _publish_groups(client)
    _publish_health(client)
    for device in _devices:
        if device.get("type") == "Coordinator":
            continue
        name = device["friendly_name"]
        _publish_state(client, name)
        _publish_availability(client, name)
    for level, message in [
        ("info",    f"Engine ready: {count} devices"),
        ("warning", "Mock network — no real Zigbee radio"),
        ("debug",   "Coordinator stubbed at channel 11, PAN 6754"),
    ]:
        _emit_log(client, level, message)
    log.info("Seed complete")


def _drift_once(name: str) -> dict:
    s = _states[name]
    if "temperature" in s and isinstance(s["temperature"], (int, float)):
        s["temperature"] = round(float(s["temperature"]) + random.uniform(-0.3, 0.3), 1)
    if "humidity" in s and isinstance(s["humidity"], (int, float)):
        s["humidity"] = round(max(0, min(100, float(s["humidity"]) + random.uniform(-1, 1))), 1)
    if "power" in s and isinstance(s["power"], (int, float)):
        s["power"] = round(max(0, float(s["power"]) + random.uniform(-2, 2)), 1)
    if "linkquality" in s and isinstance(s["linkquality"], int):
        s["linkquality"] = max(0, min(255, s["linkquality"] + random.randint(-5, 5)))
    if "battery" in s and isinstance(s["battery"], int):
        s["battery"] = max(0, min(100, s["battery"] - random.randint(0, 1)))
    return s


def drift_tick(client) -> None:
    with _lock:
        names = [d["friendly_name"] for d in _devices if d.get("type") != "Coordinator"]
    for name in names:
        with _lock:
            if name not in _states:
                continue
            _drift_once(name)
        _publish_state(client, name)
    # Emit a live bridge log on every tick so the app's Bridge Log view is
    # populated the moment a test arrives. Real z2m emits debug log lines
    # for message activity; matching that shape keeps the engine faithful.
    _emit_log(client, "debug", f"drift tick: published {len(names)} device states")


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> None:
    global _client, _mqtt_last_error, _seed_complete
    _init_state()

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    _client = client

    # Start the test-center HTTP server before we touch the broker. If MQTT is
    # unreachable, scenarios will still 503 — but /api/state and /api/health
    # come up immediately so the operator can see what's wrong.
    try:
        import control
        control.start_in_thread()
    except Exception as exc:  # noqa: BLE001
        log.warning("Control plane not started: %s", exc)

    log.info("Connecting to %s:%d …", MQTT_HOST, MQTT_PORT)
    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
            _mqtt_last_error = None
            break
        except Exception as exc:
            _mqtt_last_error = f"{type(exc).__name__}: {exc}"
            log.warning("Broker not ready (%s), retrying in 3s …", exc)
            time.sleep(3)

    client.loop_start()

    log.info("Waiting for Zigbee2MQTT bridge …")
    deadline = time.time() + 120
    while not _z2m_online and time.time() < deadline:
        time.sleep(0.5)

    if not _z2m_online:
        log.error("Bridge never announced online — seeding anyway")

    time.sleep(2)
    seed_initial(client)
    _seed_complete = True

    if MODE == "once":
        client.loop_stop()
        return

    log.info("Continuous mode: drift every %ds", SEED_INTERVAL)
    while True:
        time.sleep(SEED_INTERVAL)
        drift_tick(client)


if __name__ == "__main__":
    main()
