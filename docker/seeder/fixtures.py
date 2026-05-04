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

# Visually distinguish two simultaneous seeders during multi-bridge testing.
# When set, every fixture device's friendly name (and the matching key in
# DEVICE_STATES) is prefixed; IEEEs are also salted by appending the prefix
# code so the two bridges' device lists look completely different to the app.
_FIXTURE_PREFIX = os.environ.get("FIXTURE_PREFIX", "")
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

    if _FIXTURE_PREFIX:
        name = f"{_FIXTURE_PREFIX}{name}"
        # Salt the last 6 hex chars of the IEEE so the prefixed bridge has
        # genuinely distinct device IDs — otherwise the same IEEE under two
        # bridges would race the firstSeen migration logic.
        if ieee.startswith("0x") and len(ieee) == 18:
            salt = format(abs(hash(_FIXTURE_PREFIX)) & 0xFFFFFF, "06x")
            ieee = ieee[:12] + salt

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
        "interview_state": "SUCCESSFUL",
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


# ── Test Lights (variety for action-card coverage) ──
device("Test Light 01"         , model="GL-SPI-206P", ieee="0xbee1010000000000")
device("Test Light 02"         , model="BMCT-DZ", ieee="0xbee1020000000000")
device("Test Light 03"         , model="GL-C-006", ieee="0xbee1030000000000")
device("Test Light 04"         , model="GL-C-003P", ieee="0xbee1040000000000")
device("Test Light 05"         , model="GL-H-001", ieee="0xbee1050000000000")
device("Test Light 06"         , model="GL-C-006S", ieee="0xbee1060000000000")
device("Test Light 07"         , model="3420-G", ieee="0xbee1070000000000")
device("Test Light 08"         , model="LED2109G6", ieee="0xbee1080000000000")
device("Test Light 09"         , model="GL-G-003P", ieee="0xbee1090000000000")
device("Test Light 10"         , model="GL-C-006P", ieee="0xbee10a0000000000")
device("Test Light 11"         , model="LED1546G12", ieee="0xbee10b0000000000")
device("Test Light 12"         , model="QS-Zigbee-D02-TRIAC-LN", ieee="0xbee10c0000000000")
device("Test Light 13"         , model="QS-Zigbee-D02-TRIAC-2C-LN", ieee="0xbee10d0000000000")
device("Test Light 14"         , model="GL-C-007-1ID", ieee="0xbee10e0000000000")
device("Test Light 15"         , model="4256050-ZHAC", ieee="0xbee10f0000000000")
device("Test Light 16"         , model="4257050-ZHAC", ieee="0xbee1100000000000")

# ── Test Switches (variety for action-card coverage) ──
device("Test Switch 01"        , model="BSP-FZ2", ieee="0xbee2010000000000")
device("Test Switch 02"        , model="BSP-FD", ieee="0xbee2020000000000")
device("Test Switch 03"        , model="BTH-RM230Z", ieee="0xbee2030000000000")
device("Test Switch 04"        , model="4256251-RZHAC", ieee="0xbee2040000000000")
device("Test Switch 05"        , model="PSM-29ZBSR", ieee="0xbee2050000000000")
device("Test Switch 06"        , model="4256050-RZHAC", ieee="0xbee2060000000000")
device("Test Switch 07"        , model="LLKZMK12LM", ieee="0xbee2070000000000")
device("Test Switch 08"        , model="X701A", ieee="0xbee2080000000000")
device("Test Switch 09"        , model="WS-USC01", ieee="0xbee2090000000000")
device("Test Switch 10"        , model="W564100", ieee="0xbee20a0000000000")
device("Test Switch 11"        , model="AUT000069", ieee="0xbee20b0000000000")
device("Test Switch 12"        , model="QBKG27LM", ieee="0xbee20c0000000000")
device("Test Switch 13"        , model="BMCT-RZ", ieee="0xbee20d0000000000")
device("Test Switch 14"        , model="4257050-RZHAC", ieee="0xbee20e0000000000")
device("Test Switch 15"        , model="4200-C", ieee="0xbee20f0000000000")
device("Test Switch 16"        , model="3200-fr", ieee="0xbee2100000000000")

# ── Test Covers (variety for action-card coverage) ──
device("Test Cover 01"         , model="SCM-5ZBS", ieee="0xbee3010000000000")
device("Test Cover 02"         , model="S520567", ieee="0xbee3020000000000")
device("Test Cover 03"         , model="CP180335E-01", ieee="0xbee3030000000000")
device("Test Cover 04"         , model="CK-MG22-JLDJ-01(7015)", ieee="0xbee3040000000000")
device("Test Cover 05"         , model="ZNJLBL01LM", ieee="0xbee3050000000000")
device("Test Cover 06"         , model="QS-Zigbee-C01", ieee="0xbee3060000000000")
device("Test Cover 07"         , model="MB60L-ZG-ZT-TY", ieee="0xbee3070000000000")
device("Test Cover 08"         , model="E2102", ieee="0xbee3080000000000")
device("Test Cover 09"         , model="EPJ-ZB", ieee="0xbee3090000000000")
device("Test Cover 10"         , model="ZNCLDJ14LM", ieee="0xbee30a0000000000")
device("Test Cover 11"         , model="HS2CM-N-DC", ieee="0xbee30b0000000000")
device("Test Cover 12"         , model="E2103", ieee="0xbee30c0000000000")
device("Test Cover 13"         , model="5128.10", ieee="0xbee30d0000000000")
device("Test Cover 14"         , model="11830304", ieee="0xbee30e0000000000")
device("Test Cover 15"         , model="TS130F_dual", ieee="0xbee30f0000000000")
device("Test Cover 16"         , model="QS-Zigbee-C03", ieee="0xbee3100000000000")

# ── Test Locks (variety for action-card coverage) ──
device("Test Lock 01"          , model="66492-001", ieee="0xbee4010000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 02"          , model="YRD426NRSC", ieee="0xbee4020000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 03"          , model="YRL256 TS", ieee="0xbee4030000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 04"          , model="99140-002", ieee="0xbee4040000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 05"          , model="99140-139", ieee="0xbee4050000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 06"          , model="YRD256HA20BP", ieee="0xbee4060000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 07"          , model="99140-031", ieee="0xbee4070000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 08"          , model="99100-045", ieee="0xbee4080000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 09"          , model="99100-006", ieee="0xbee4090000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 10"          , model="99120-021", ieee="0xbee40a0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 11"          , model="YAYRD256HA2619", ieee="0xbee40b0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 12"          , model="YRD652HA20BP", ieee="0xbee40c0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 13"          , model="YMF30", ieee="0xbee40d0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 14"          , model="YMF40/YDM4109+/YDF40", ieee="0xbee40e0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 15"          , model="YRD210-HA-605", ieee="0xbee40f0000000000",
       type="EndDevice", power_source="Battery")
device("Test Lock 16"          , model="YRL-220L", ieee="0xbee4100000000000",
       type="EndDevice", power_source="Battery")

# ── Test Climate devices (variety for action-card coverage) ──
device("Test Climate 01"       , model="CoZB_dha", ieee="0xbee5010000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 02"       , model="BTH-RM", ieee="0xbee5020000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 03"       , model="ZBHTR20WT", ieee="0xbee5030000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 04"       , model="BTH-RA", ieee="0xbee5040000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 05"       , model="SRTS-A01", ieee="0xbee5050000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 06"       , model="WT-A03E", ieee="0xbee5060000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 07"       , model="COZB0001", ieee="0xbee5070000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 08"       , model="TS0601_thermostat_thermosphere", ieee="0xbee5080000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 09"       , model="ME168_AVATTO", ieee="0xbee5090000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 10"       , model="3157100", ieee="0xbee50a0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 11"       , model="WV704R0A0902", ieee="0xbee50b0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 12"       , model="Icon2", ieee="0xbee50c0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 13"       , model="3156105", ieee="0xbee50d0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 14"       , model="Icon", ieee="0xbee50e0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 15"       , model="SLR1", ieee="0xbee50f0000000000",
       type="EndDevice", power_source="Battery")
device("Test Climate 16"       , model="SLR1b", ieee="0xbee5100000000000",
       type="EndDevice", power_source="Battery")

# ── Test Fans (variety for action-card coverage) ──
device("Test Fan 01"           , model="AC201", ieee="0xbee6010000000000")

# ── Test Sensors (variety for action-card coverage) ──
device("Test Sensor 01"        , model="8750001213", ieee="0xbee7010000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 02"        , model="WSDCGQ12LM", ieee="0xbee7020000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 03"        , model="ISW-ZPR1-WP13", ieee="0xbee7030000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 04"        , model="RADION TriTech ZB", ieee="0xbee7040000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 05"        , model="3323-G", ieee="0xbee7050000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 06"        , model="BSEN-W", ieee="0xbee7060000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 07"        , model="BSD-2", ieee="0xbee7070000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 08"        , model="WISZB-137", ieee="0xbee7080000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 09"        , model="HS3AQ", ieee="0xbee7090000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 10"        , model="AQSZB-110", ieee="0xbee70a0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 11"        , model="HS2AQ-EM", ieee="0xbee70b0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 12"        , model="FP1E", ieee="0xbee70c0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 13"        , model="KK-ES-J01W", ieee="0xbee70d0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 14"        , model="HS3CG", ieee="0xbee70e0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 15"        , model="BSIR-EZ", ieee="0xbee70f0000000000",
       type="EndDevice", power_source="Battery")
device("Test Sensor 16"        , model="BSEN-M", ieee="0xbee7100000000000",
       type="EndDevice", power_source="Battery")

# ── Test Remotes (variety for action-card coverage) ──
device("Test Remote 01"        , model="BSEN-C2", ieee="0xbee8010000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 02"        , model="8719514440937/8719514440999", ieee="0xbee8020000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 03"        , model="511.324", ieee="0xbee8030000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 04"        , model="SBRC-005B-B", ieee="0xbee8040000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 05"        , model="3400-D", ieee="0xbee8050000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 06"        , model="mTouch_Bryter", ieee="0xbee8060000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 07"        , model="SR-ZG9030F-PS", ieee="0xbee8070000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 08"        , model="BSEN-CV", ieee="0xbee8080000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 09"        , model="BSEN-C2D", ieee="0xbee8090000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 10"        , model="BHI-US", ieee="0xbee80a0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 11"        , model="KP-23EL-ZBS-ACE", ieee="0xbee80b0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 12"        , model="KEYZB-110", ieee="0xbee80c0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 13"        , model="SBTZB-110", ieee="0xbee80d0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 14"        , model="HS1RC-N", ieee="0xbee80e0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 15"        , model="HM1RC-2-E", ieee="0xbee80f0000000000",
       type="EndDevice", power_source="Battery")
device("Test Remote 16"        , model="HS1RC-EM", ieee="0xbee8100000000000",
       type="EndDevice", power_source="Battery")

# ── Test Generic devices (variety for action-card coverage) ──
device("Test Generic 01"       , model="SA100", ieee="0xbee9010000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 02"       , model="SRAC-23B-ZBSR", ieee="0xbee9020000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 03"       , model="QT-05M", ieee="0xbee9030000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 04"       , model="BMCT-SLZ", ieee="0xbee9040000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 05"       , model="Flower_Sensor_v2", ieee="0xbee9050000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 06"       , model="SLACKY_DIY_CO2_SENSOR_R02", ieee="0xbee9060000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 07"       , model="WS01", ieee="0xbee9070000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 08"       , model="WS90", ieee="0xbee9080000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 09"       , model="ZF24", ieee="0xbee9090000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 10"       , model="HM-722ESY-E Plus", ieee="0xbee90a0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 11"       , model="3328-G", ieee="0xbee90b0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 12"       , model="3310-G", ieee="0xbee90c0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 13"       , model="3315-Geu", ieee="0xbee90d0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 14"       , model="SS300", ieee="0xbee90e0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 15"       , model="SD-8SCZBS", ieee="0xbee90f0000000000",
       type="EndDevice", power_source="Battery")
device("Test Generic 16"       , model="WLS-15ZBS", ieee="0xbee9100000000000",
       type="EndDevice", power_source="Battery")



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
