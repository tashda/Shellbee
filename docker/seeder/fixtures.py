"""
Fixture devices for the Shellbee mock z2m engine.

Each entry binds a friendly name to a real Zigbee2MQTT model. Definitions
(exposes, options, meta) are pulled from ``models.json`` — generated from
the official zigbee-herdsman-converters library so the app sees the same
schema it would in production.

Adding a device:
  1. Pick a model from https://www.zigbee2mqtt.io/supported-devices/
     (or any other zhc-supported model).
  2. Add the model to ``MODELS`` in ``tools/dump_models.cjs``.
  3. From ``docker/seeder/tools/`` run ``node dump_models.cjs > ../models.json``.
  4. Append a ``device(...)`` line below.

Sensible default state is synthesised from the model's exposes (binaries
default OFF, numerics to their min, batteries to 80, linkquality to 200).
Override anything you want with ``state={...}``.
"""

from __future__ import annotations

import copy
import json
import os
from typing import Any

# ── Model catalogue ───────────────────────────────────────────────────────

_MODELS_PATH = os.path.join(os.path.dirname(__file__), "models.json")
with open(_MODELS_PATH) as f:
    _MODELS: dict[str, dict] = json.load(f)


# ── State synthesis ───────────────────────────────────────────────────────

def _default_for(feature: dict) -> Any:
    """Pick a sensible starting value for a single expose feature."""
    name = feature.get("name") or feature.get("property") or ""
    typ = feature.get("type")
    if typ == "binary":
        return feature.get("value_off", False)
    if typ == "numeric":
        if name == "battery":
            return 80
        if name == "linkquality":
            return 200
        if name in ("voltage", "power", "current", "energy"):
            return 0
        if "value_min" in feature:
            return feature["value_min"]
        return 0
    if typ == "enum":
        vals = feature.get("values") or []
        return vals[0] if vals else None
    if typ == "text":
        return ""
    if typ == "composite":
        out: dict[str, Any] = {}
        for sub in feature.get("features", []) or []:
            v = _default_for(sub)
            if v is not None:
                out[sub.get("property") or sub.get("name")] = v
        return out
    return None


def _is_published(feature: dict) -> bool:
    # z2m access bits: 1=published, 2=set, 4=get. Skip set-only commands.
    return bool(feature.get("access", 1) & 1)


def _synth_state(exposes: list[dict]) -> dict[str, Any]:
    """Walk a model's resolved exposes and produce a default state dict."""
    state: dict[str, Any] = {}
    for ex in exposes:
        # Generic types (light/switch/cover/lock/climate/fan) wrap features.
        features = ex.get("features")
        if features:
            for f in features:
                if not _is_published(f):
                    continue
                prop = f.get("property") or f.get("name")
                if prop and prop not in state:
                    val = _default_for(f)
                    if val is not None:
                        state[prop] = val
            continue
        if not _is_published(ex):
            continue
        prop = ex.get("property") or ex.get("name")
        if prop and prop not in state:
            val = _default_for(ex)
            if val is not None:
                state[prop] = val
    return state


# ── Registry ──────────────────────────────────────────────────────────────

ALL_DEVICES: list[dict] = []
DEVICE_STATES: dict[str, dict] = {}

_NETWORK_ADDR = 10000


def device(
    name: str,
    *,
    model: str,
    ieee: str,
    type: str = "Router",
    power_source: str = "Mains (single phase)",
    state: dict | None = None,
) -> None:
    """Register a fixture device by zhc model name."""
    global _NETWORK_ADDR
    if model not in _MODELS:
        raise KeyError(
            f"Model {model!r} not in models.json. Add it to "
            "tools/dump_models.cjs and regenerate."
        )
    m = _MODELS[model]
    _NETWORK_ADDR += 1

    ALL_DEVICES.append({
        "ieee_address": ieee,
        "type": type,
        "network_address": _NETWORK_ADDR,
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
        "power_source": power_source,
        "model_id": (m["zigbeeModel"] or [m["model"]])[0],
        "manufacturer": m["vendor"],
        "interview_completed": True,
        "interviewing": False,
        "software_build_id": None,
        "date_code": None,
        "endpoints": {"1": {"inputClusters": [], "outputClusters": [],
                            "binds": [], "configuredReportings": []}},
        "options": {},
    })

    synth = _synth_state(m["exposes"])
    if state:
        synth.update(state)
    synth.setdefault("linkquality", 200)
    DEVICE_STATES[name] = synth


# ── Coordinator ───────────────────────────────────────────────────────────

COORDINATOR = {
    "ieee_address": "0x00124b0000000000",
    "type": "Coordinator",
    "network_address": 0,
    "supported": True,
    "friendly_name": "Coordinator",
    "disabled": False,
    "description": None,
    "definition": None,
    "power_source": "Mains (single phase)",
    "model_id": None,
    "manufacturer": None,
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [], "outputClusters": [],
                        "binds": [], "configuredReportings": []}},
    "options": {},
}
ALL_DEVICES.append(COORDINATOR)


# ── Devices ───────────────────────────────────────────────────────────────
# (model, friendly_name, IEEE) — IEEEs preserved so existing GROUPS still work.

device("Living Room Light",          model="LED1545G12",        ieee="0x000b57fffec6a5b3")
device("Bedroom Hue",                model="9290012573A",       ieee="0x0017880103f72892")
device("Kitchen Plug",               model="TS011F_plug_1",     ieee="0x000b57fffec51378")
device("Office Sensor",              model="WSDCGQ11LM",        ieee="0x00158d0001234567",
       type="EndDevice", power_source="Battery")
device("Bedroom Thermostat",         model="SPZB0001",          ieee="0x0015bc001e000fe0",
       type="EndDevice", power_source="Battery")
device("Living Room Blinds",         model="E1926",             ieee="0x0c4314fffed23456")
device("Front Door Lock",            model="BE468",             ieee="0x54ef441000130bed",
       type="EndDevice", power_source="Battery")
device("Bathroom Fan",               model="E2007",             ieee="0x0c4314fffeb1c2d3")
device("TRADFRI Remote",             model="E1524/E1810",       ieee="0x000b57fffe9a0b01",
       type="EndDevice", power_source="Battery")
device("Kitchen RGB Bulb",           model="9290024896",        ieee="0x0017880108a4b2c1")
device("Hallway Dimmer Bulb",        model="LED1836G9",         ieee="0x000b57fffec0a111")
device("Desk LED Strip",             model="GL-C-008-1ID",      ieee="0x00124b0022334455")
device("Dining Candle Bulb",         model="LED1949C5",         ieee="0x000b57fffec0a222")
device("Hallway Motion",             model="RTCGQ11LM",         ieee="0x00158d00011aa001",
       type="EndDevice", power_source="Battery")
device("Garage Motion",              model="E1525/E1745",       ieee="0x000b57fffec0b333",
       type="EndDevice", power_source="Battery")
device("Back Door Contact",          model="MCCGQ11LM",         ieee="0x00158d00022bb002",
       type="EndDevice", power_source="Battery")
device("Washing Machine Vibration",  model="DJT11LM",           ieee="0x00158d00033cc003",
       type="EndDevice", power_source="Battery")
device("Basement Leak Sensor",       model="LDSENK09",          ieee="0x00158d00044dd004",
       type="EndDevice", power_source="Battery")
device("Kitchen Smoke Alarm",        model="SMSZB-120",         ieee="0x0015bc002a000a01",
       type="EndDevice", power_source="Battery")
device("Office Air Quality",         model="VOCKQJK11LM",       ieee="0x00158d00055ee005",
       type="EndDevice", power_source="Battery")
device("Living Room Presence",       model="RTCZCGQ11LM",       ieee="0x00158d00066ff006")
device("Patio Light Sensor",         model="GZCGQ01LM",         ieee="0x00158d00077ff007",
       type="EndDevice", power_source="Battery")
device("Lamp Plug",                  model="E160x/E170x/E190x", ieee="0x000b57fffec0c444")
device("Living Room Wall Switch",    model="QBKG11LM",          ieee="0x00158d00088aa008")
device("Kitchen Dual Switch",        model="QBKG12LM",          ieee="0x00158d00099bb009")
device("Bedroom Dimmer",             model="Z3-1BRL",           ieee="0xa4c13800aaaabbbb",
       type="EndDevice", power_source="Battery")
device("Bedside Button",             model="E1743",             ieee="0x000b57fffec0d555",
       type="EndDevice", power_source="Battery")
device("Hue Dimmer Remote",          model="324131092621",      ieee="0x0017880104abcd11",
       type="EndDevice", power_source="Battery")
device("Bedroom Curtain",            model="E1757",             ieee="0x000b57fffec0e666",
       type="EndDevice", power_source="Battery")
device("Garage Siren",               model="HS2WD-E",           ieee="0x0015bc002b000b02")
device("Study Smart Knob",           model="ZNXNKG02LM",        ieee="0x00158d000aacc00a",
       type="EndDevice", power_source="Battery")
device("Guest Room Radiator",        model="014G2461",          ieee="0x0015bc002c000c03",
       type="EndDevice", power_source="Battery")
device("Back Door Lock",             model="YRD226HA2619",      ieee="0x54ef441000131cfe",
       type="EndDevice", power_source="Battery")
device("Backyard Outdoor Sensor",    model="9290019758",        ieee="0x001788010bcd0f12",
       type="EndDevice", power_source="Battery")

# ── Fans (UI variety: minimal → exposes-rich) ─────────────────────────────
device("Closet FanBee",              model="FanBee",            ieee="0xa0b0c0d000000001")
device("Patio Hampton Fan",          model="99432",             ieee="0xa0b0c0d000000002")
device("Office Inovelli Fan Switch", model="VZM35-SN",          ieee="0xa0b0c0d000000003")
device("Living Inovelli FanLight",   model="VZM36",             ieee="0xa0b0c0d000000004")
device("Garage Mercator Fan",        model="SSWF01G",           ieee="0xa0b0c0d000000005")
device("Workshop MultiTerm Fan",     model="ZC0101",            ieee="0xa0b0c0d000000006")
device("Bedroom OWON HVAC",          model="AC221",             ieee="0xa0b0c0d000000007")
device("Hallway OWON Thermostat",    model="PCT504",            ieee="0xa0b0c0d000000008")
device("Sunroom Schneider Fan",      model="41ECSFWMZ-VW",      ieee="0xa0b0c0d000000009")
device("Attic Tuya Fan",             model="_TZE284_z5jz7wpo",  ieee="0xa0b0c0d00000000a")


# ── Bridge / groups (unchanged) ───────────────────────────────────────────

BRIDGE_INFO = {
    "version": "2.1.0",
    "commit": "abc123def456abc123def456abc123def456abc1",
    "coordinator": {
        "ieee_address": "0x00124b0000000000",
        "meta": {"revision": 20230507, "transportrev": 2, "product": 2,
                 "majorrel": 2, "minorrel": 7, "hwrev": 11},
    },
    "network": {"channel": 11, "pan_id": 6754, "extended_pan_id": "0xdddddddddddddddd"},
    "log_level": "info",
    "permit_join": False,
    "permit_join_timeout": None,
    "restart_required": False,
    "config": {
        "homeassistant": {"enabled": False},
        "permit_join": False,
        "mqtt": {
            "base_topic": "zigbee2mqtt",
            "server": "mqtt://mosquitto:1883",
            "include_device_information": False,
            "force_disable_retain": False,
            "version": 4,
            "keepalive": 60,
            "reject_unauthorized": True,
            "qos": 0,
        },
        "serial": {"adapter": "stub", "disable_led": False, "rtscts": False},
        "frontend": {"enabled": True, "port": 8080, "host": "0.0.0.0"},
        "advanced": {
            "log_level": "info",
            "log_rotation": True,
            "log_directories_kept": 10,
            "pan_id": 6754,
            "ext_pan_id": [221, 221, 221, 221, 221, 221, 221, 221],
            "channel": 11,
            "last_seen": "ISO_8601_local",
            "elapsed": False,
            "timestamp_format": "YYYY-MM-DD HH:mm:ss",
            "cache_state": True,
            "cache_state_persistent": True,
            "cache_state_send_on_connect": True,
            "output": "json",
            "transmit_power": None,
            "adapter_concurrent": None,
            "adapter_delay": None,
        },
        "availability": {"enabled": False},
        "ota": {
            "update_check_interval": 1440,
            "disable_automatic_update_check": False,
            "zigbee_ota_override_index_location": None,
            "image_block_response_time": 250,
            "default_maximum_data_size": 50,
        },
        "health": {"enabled": False, "check_interval": 0},
        "passlist": [],
        "blocklist": [],
    },
}

BRIDGE_HEALTH = {
    "healthy": True,
    "response_time": 32,
    "process": {"uptime": 3600, "memory_usage": 42.5, "memory_usage_mb": 85.2},
    "os": {"load_average_5m": 1.2, "memory_usage": 55.3, "memory_usage_gb": 3.7},
    "mqtt": {"connected": True, "queued": 0, "published": 1234, "received": 5678},
}

GROUPS = [
    {
        "id": 1,
        "friendly_name": "All Lights",
        "description": None,
        "members": [
            {"ieee_address": "0x000b57fffec6a5b3", "endpoint": 1},
            {"ieee_address": "0x0017880103f72892", "endpoint": 11},
        ],
        "scenes": [
            {"id": 1, "name": "Evening"},
            {"id": 2, "name": "Movie"},
        ],
    },
    {
        "id": 2,
        "friendly_name": "Bedroom",
        "description": None,
        "members": [
            {"ieee_address": "0x0017880103f72892", "endpoint": 11},
            {"ieee_address": "0xa4c13800aaaabbbb", "endpoint": 1},
            {"ieee_address": "0x000b57fffec0e666", "endpoint": 1},
        ],
        "scenes": [{"id": 3, "name": "Night"}],
    },
    {
        "id": 3,
        "friendly_name": "Kitchen",
        "description": None,
        "members": [
            {"ieee_address": "0x000b57fffec51378", "endpoint": 1},
            {"ieee_address": "0x0017880108a4b2c1", "endpoint": 11},
            {"ieee_address": "0x00158d00099bb009", "endpoint": 1},
        ],
        "scenes": [],
    },
]
