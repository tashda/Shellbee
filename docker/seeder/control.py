"""
HTTP control plane for the Shellbee mock z2m engine.

Runs alongside the MQTT seeder in the same container/process. Exposes:
  - GET  /                      → static test-center UI
  - GET  /api/state             → snapshot of devices, groups, bridge info
  - GET  /api/models            → list of selectable models (from models.json)
  - POST /api/scenarios/<name>  → drive a scenario (see SCENARIOS below)

Scenarios mutate the seeder's authoritative state via the helpers it already
uses for normal request handling, so behaviour stays identical to a request
that came in over MQTT.
"""
from __future__ import annotations

import copy
import logging
import os
import random
import threading
import time
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import uvicorn

import fixtures
import seeder

log = logging.getLogger("control")

CONTROL_PORT = int(os.environ.get("CONTROL_PORT", "8765"))
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

app = FastAPI(title="Shellbee Test Center", docs_url="/api/docs", redoc_url=None)


# ── Engine accessors ──────────────────────────────────────────────────────

def _client():
    c = seeder._client
    if c is None:
        raise HTTPException(503, "MQTT client not connected yet")
    return c


def _device_or_404(name: str) -> dict:
    d = seeder._find_device(name)
    if d is None:
        raise HTTPException(404, f"Device {name!r} not found")
    return d


def _ok(**extra: Any) -> dict:
    return {"ok": True, **extra}


# ── Read APIs ─────────────────────────────────────────────────────────────

@app.get("/api/state")
def get_state():
    with seeder._lock:
        devices = [
            {
                "friendly_name": d["friendly_name"],
                "ieee_address": d["ieee_address"],
                "type": d.get("type"),
                "model": (d.get("definition") or {}).get("model"),
                "vendor": (d.get("definition") or {}).get("vendor"),
                "interview_completed": d.get("interview_completed"),
                "interviewing": d.get("interviewing"),
            }
            for d in seeder._devices
            if d.get("type") != "Coordinator"
        ]
        groups = [{"id": g["id"], "friendly_name": g["friendly_name"],
                   "members": len(g.get("members", []))}
                  for g in seeder._groups]
        bridge = {
            "version": seeder._bridge_info.get("version"),
            "permit_join": seeder._bridge_info.get("permit_join"),
        }
    return {"devices": devices, "groups": groups, "bridge": bridge}


@app.get("/api/models")
def list_models():
    return [
        {"model": m["model"], "vendor": m["vendor"], "description": m["description"]}
        for m in fixtures._MODELS.values()
    ]


# ── Scenario request bodies ───────────────────────────────────────────────

class JoinBody(BaseModel):
    name: str | None = None
    model: str | None = None
    ieee: str | None = None
    interview_ms: int = 2500
    fail: bool = False


class NameBody(BaseModel):
    name: str


class SpamBody(BaseModel):
    name: str
    count: int = 50
    interval_ms: int = 50
    field: str | None = None  # if set, drift just this numeric field


class AvailabilityBody(BaseModel):
    name: str
    state: str = "online"  # "online" | "offline"


class FlapBody(BaseModel):
    name: str
    count: int = 6
    interval_ms: int = 500


class PermitJoinBody(BaseModel):
    value: bool = True
    time: int | None = 60


class LogBody(BaseModel):
    level: str = "info"
    message: str = "test log"
    count: int = 1
    interval_ms: int = 0


class ErrorOnceBody(BaseModel):
    subpath: str
    error: str = "Simulated failure from test center"


class GroupFanoutBody(BaseModel):
    group: str
    payload: dict


class BridgeCycleBody(BaseModel):
    offline_ms: int = 3000


# ── Scenarios ─────────────────────────────────────────────────────────────

def _next_ieee() -> str:
    return f"0x{random.randint(0, 0xFFFFFFFFFFFFFFFF):016x}"


def _build_device(model: str, name: str, ieee: str) -> tuple[dict, dict]:
    """Build (device dict, default state) for a model — without mutating fixtures."""
    if model not in fixtures._MODELS:
        raise HTTPException(400, f"Unknown model {model!r}")
    m = fixtures._MODELS[model]
    with seeder._lock:
        addr = max((d.get("network_address") or 0) for d in seeder._devices) + 1
    device = {
        "ieee_address": ieee,
        "type": "Router",
        "network_address": addr,
        "supported": True,
        "friendly_name": name,
        "disabled": False,
        "description": None,
        "definition": {
            "model": m["model"],
            "vendor": m["vendor"],
            "description": m["description"],
            "exposes": copy.deepcopy(m["exposes"]),
            "options": copy.deepcopy(m["options"]),
        },
        "power_source": "Mains (single phase)",
        "model_id": (m["zigbeeModel"] or [m["model"]])[0],
        "manufacturer": m["vendor"],
        "interview_completed": False,
        "interviewing": True,
        "software_build_id": None,
        "date_code": None,
        "endpoints": {"1": {"inputClusters": [], "outputClusters": [],
                            "binds": [], "configuredReportings": []}},
        "options": {},
    }
    state = fixtures._synth_state(m["exposes"])
    state.setdefault("linkquality", 200)
    return device, state


@app.post("/api/scenarios/device/join")
def scenario_join(body: JoinBody):
    """Simulate a brand-new device pairing with the network.

    Sequence:
      device_joined → bridge/devices (interviewing=True) → device_interview started
        → (interview_ms) → bridge/devices (interview_completed=True)
        → device_interview successful → publish state + availability online
    """
    client = _client()
    model = body.model or "ZNCZ02LM"  # mains plug, simple exposes
    if model not in fixtures._MODELS:
        # Fall back to any model so the demo never breaks.
        model = next(iter(fixtures._MODELS))
    name = body.name or f"New {fixtures._MODELS[model]['model']} {random.randint(100, 999)}"
    ieee = body.ieee or _next_ieee()

    if seeder._find_device(name) is not None:
        raise HTTPException(409, f"Device {name!r} already exists")

    device, state = _build_device(model, name, ieee)

    def run():
        with seeder._lock:
            seeder._devices.append(device)
            seeder._states[name] = state
        seeder._emit_event(client, "device_joined",
                           {"friendly_name": name, "ieee_address": ieee})
        seeder._publish_devices(client)
        seeder._emit_event(client, "device_interview", {
            "friendly_name": name, "ieee_address": ieee, "status": "started",
        })
        seeder._emit_log(client, "info", f"Interviewing '{name}'")
        time.sleep(max(0.0, body.interview_ms / 1000.0))
        if body.fail:
            with seeder._lock:
                device["interview_completed"] = False
                device["interviewing"] = False
            seeder._publish_devices(client)
            seeder._emit_event(client, "device_interview", {
                "friendly_name": name, "ieee_address": ieee,
                "status": "failed", "supported": False,
            })
            seeder._emit_log(client, "error", f"Failed to interview '{name}'")
            return
        with seeder._lock:
            device["interview_completed"] = True
            device["interviewing"] = False
        seeder._publish_devices(client)
        seeder._emit_event(client, "device_interview", {
            "friendly_name": name, "ieee_address": ieee,
            "status": "successful", "supported": True,
            "definition": device["definition"],
        })
        seeder._publish_state(client, name)
        seeder._publish_availability(client, name, "online")
        seeder._emit_log(client, "info", f"Successfully interviewed '{name}'")

    threading.Thread(target=run, daemon=True).start()
    return _ok(name=name, ieee_address=ieee, model=model)


@app.post("/api/scenarios/device/leave")
def scenario_leave(body: NameBody):
    client = _client()
    d = _device_or_404(body.name)
    name, ieee = d["friendly_name"], d["ieee_address"]
    with seeder._lock:
        seeder._devices.remove(d)
        seeder._states.pop(name, None)
    seeder._clear_retained(client, name)
    seeder._clear_retained(client, f"{name}/availability")
    seeder._publish_devices(client)
    seeder._emit_event(client, "device_leave",
                       {"ieee_address": ieee, "friendly_name": name})
    seeder._emit_log(client, "warning", f"Device '{name}' left the network")
    return _ok(name=name)


@app.post("/api/scenarios/device/announce")
def scenario_announce(body: NameBody):
    client = _client()
    d = _device_or_404(body.name)
    seeder._emit_event(client, "device_announce", {
        "friendly_name": d["friendly_name"], "ieee_address": d["ieee_address"],
    })
    return _ok()


@app.post("/api/scenarios/ota/run")
def scenario_ota(body: NameBody):
    """Run the full OTA flow: check (mark available) then update (drive progress)."""
    client = _client()
    d = _device_or_404(body.name)
    seeder.handle_request(client, "device/ota_update/check", {"id": d["friendly_name"]})
    # Small delay so the client can render "available" before we start updating.
    threading.Timer(0.4, lambda: seeder.handle_request(
        client, "device/ota_update/update", {"id": d["friendly_name"]})).start()
    return _ok(name=d["friendly_name"])


@app.post("/api/scenarios/ota/check")
def scenario_ota_check(body: NameBody):
    client = _client()
    d = _device_or_404(body.name)
    seeder.handle_request(client, "device/ota_update/check", {"id": d["friendly_name"]})
    return _ok()


@app.post("/api/scenarios/device/spam")
def scenario_spam(body: SpamBody):
    """Burst of state updates from a device — simulates a chatty/buggy device."""
    client = _client()
    d = _device_or_404(body.name)
    name = d["friendly_name"]

    def run():
        for _ in range(max(1, body.count)):
            with seeder._lock:
                if name not in seeder._states:
                    return
                state = seeder._states[name]
                if body.field and body.field in state and isinstance(state[body.field], (int, float)):
                    state[body.field] = round(float(state[body.field]) + random.uniform(-2, 2), 2)
                else:
                    seeder._drift_once(name)
            seeder._publish_state(client, name)
            time.sleep(max(0.0, body.interval_ms / 1000.0))

    threading.Thread(target=run, daemon=True).start()
    return _ok(name=name, count=body.count)


@app.post("/api/scenarios/availability")
def scenario_availability(body: AvailabilityBody):
    client = _client()
    d = _device_or_404(body.name)
    state = "online" if body.state == "online" else "offline"
    seeder._publish_availability(client, d["friendly_name"], state)
    return _ok(name=d["friendly_name"], state=state)


@app.post("/api/scenarios/availability/flap")
def scenario_flap(body: FlapBody):
    client = _client()
    d = _device_or_404(body.name)
    name = d["friendly_name"]

    def run():
        for i in range(max(1, body.count)):
            seeder._publish_availability(client, name, "offline" if i % 2 == 0 else "online")
            time.sleep(max(0.0, body.interval_ms / 1000.0))
        seeder._publish_availability(client, name, "online")

    threading.Thread(target=run, daemon=True).start()
    return _ok(name=name, count=body.count)


@app.post("/api/scenarios/permit_join")
def scenario_permit_join(body: PermitJoinBody):
    client = _client()
    seeder.handle_request(client, "permit_join",
                          {"value": body.value, "time": body.time})
    return _ok(value=body.value, time=body.time)


@app.post("/api/scenarios/bridge/log")
def scenario_log(body: LogBody):
    client = _client()

    def run():
        for i in range(max(1, body.count)):
            msg = body.message if body.count == 1 else f"{body.message} ({i + 1}/{body.count})"
            seeder._emit_log(client, body.level, msg)
            if body.interval_ms:
                time.sleep(body.interval_ms / 1000.0)

    threading.Thread(target=run, daemon=True).start()
    return _ok(level=body.level, count=body.count)


@app.post("/api/scenarios/bridge/cycle")
def scenario_bridge_cycle(body: BridgeCycleBody):
    """Publish bridge/state offline → wait → online. Tests reconnect/banner UX."""
    client = _client()

    def run():
        seeder._pub(client, f"{seeder.Z2M_TOPIC}/bridge/state",
                    {"state": "offline"}, retain=True)
        seeder._emit_log(client, "warning", "Bridge going offline (test)")
        time.sleep(max(0.1, body.offline_ms / 1000.0))
        seeder._pub(client, f"{seeder.Z2M_TOPIC}/bridge/state",
                    {"state": "online"}, retain=True)
        seeder._emit_log(client, "info", "Bridge back online (test)")

    threading.Thread(target=run, daemon=True).start()
    return _ok(offline_ms=body.offline_ms)


@app.post("/api/scenarios/group/fanout")
def scenario_group_fanout(body: GroupFanoutBody):
    """Apply a /set payload to every member of a group (real z2m optimistic mode)."""
    client = _client()
    g = seeder._find_group(body.group)
    if g is None:
        raise HTTPException(404, f"Group {body.group!r} not found")
    affected: list[str] = []
    for member in g.get("members", []):
        d = seeder._find_device(member["ieee_address"])
        if d is None:
            continue
        seeder.handle_set(client, d["friendly_name"], dict(body.payload))
        affected.append(d["friendly_name"])
    return _ok(group=g["friendly_name"], affected=affected)


@app.post("/api/scenarios/reset")
def scenario_reset():
    """Wipe state and re-seed from fixtures. Use to recover from a wild test."""
    client = _client()
    # Clear retained per-device topics for any device that was added at runtime.
    with seeder._lock:
        runtime_names = [d["friendly_name"] for d in seeder._devices
                         if d.get("type") != "Coordinator"]
    seeder._init_state()
    for n in runtime_names:
        seeder._clear_retained(client, n)
        seeder._clear_retained(client, f"{n}/availability")
    seeder.seed_initial(client)
    return _ok()


# ── Static UI ─────────────────────────────────────────────────────────────

if os.path.isdir(STATIC_DIR):
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.get("/")
def index():
    path = os.path.join(STATIC_DIR, "index.html")
    if not os.path.isfile(path):
        return JSONResponse({"error": "UI not built"}, status_code=404)
    return FileResponse(path)


# ── Threaded launcher ─────────────────────────────────────────────────────

def start_in_thread() -> None:
    config = uvicorn.Config(app, host="0.0.0.0", port=CONTROL_PORT,
                            log_level="info", access_log=False)
    server = uvicorn.Server(config)

    def run():
        log.info("Test center listening on http://0.0.0.0:%d", CONTROL_PORT)
        server.run()

    t = threading.Thread(target=run, daemon=True, name="control-http")
    t.start()
