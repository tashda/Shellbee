"""
Fixture device definitions for Shellbee dev environment.
A realistic mix of ~30 devices covering the major categories the app supports.
"""

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
    "endpoints": {"1": {"inputClusters": [], "outputClusters": [], "binds": [], "configuredReportings": []}},
    "options": {}
}

# ── Light: CT + brightness (IKEA TRADFRI) ─────────────────────────────────
LIGHT_CT = {
    "ieee_address": "0x000b57fffec6a5b3",
    "type": "Router",
    "network_address": 10001,
    "supported": True,
    "friendly_name": "Living Room Light",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "LED1545G12",
        "vendor": "IKEA",
        "description": "TRADFRI LED bulb E26/E27 980 lm, dimmable, white spectrum",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254},
                    {"type": "numeric", "name": "color_temp", "label": "Color temperature",
                     "property": "color_temp", "access": 7, "value_min": 250, "value_max": 454,
                     "unit": "mired",
                     "presets": [
                         {"name": "coolest", "value": 250, "description": "Coolest temperature"},
                         {"name": "cool", "value": 290, "description": "Cool temperature"},
                         {"name": "neutral", "value": 370, "description": "Neutral temperature"},
                         {"name": "warm", "value": 454, "description": "Warm temperature"},
                         {"name": "warmest", "value": 454, "description": "Warmest temperature"}
                     ]}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "TRADFRI bulb E26 WS opal 980lm",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.2.217",
    "date_code": "20210901",
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 6, 8, 768], "outputClusters": [5], "binds": [], "configuredReportings": []}},
    "options": {"color_temp_startup": 370}
}

LIGHT_CT_STATE = {
    "state": "ON",
    "brightness": 200,
    "color_temp": 370,
    "color_mode": "color_temp",
    "linkquality": 142
}

# ── Light: Full color + CT (Philips Hue) ──────────────────────────────────
LIGHT_COLOR = {
    "ieee_address": "0x0017880103f72892",
    "type": "Router",
    "network_address": 10002,
    "supported": True,
    "friendly_name": "Bedroom Hue",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "9290012573A",
        "vendor": "Philips",
        "description": "Hue white and color ambiance A19 bulb E26",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254},
                    {"type": "numeric", "name": "color_temp", "label": "Color temperature",
                     "property": "color_temp", "access": 7, "value_min": 153, "value_max": 500,
                     "unit": "mired",
                     "presets": [
                         {"name": "coolest", "value": 153}, {"name": "cool", "value": 200},
                         {"name": "neutral", "value": 370}, {"name": "warm", "value": 454},
                         {"name": "warmest", "value": 500}
                     ]},
                    {"type": "composite", "name": "color_xy", "label": "Color (X/Y)",
                     "property": "color", "access": 7,
                     "features": [
                         {"type": "numeric", "name": "x", "property": "x", "access": 7},
                         {"type": "numeric", "name": "y", "property": "y", "access": 7}
                     ]},
                    {"type": "enum", "name": "color_mode", "label": "Color mode",
                     "property": "color_mode", "access": 1, "values": ["color_temp", "xy", "hs"]}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "LCA001",
    "manufacturer": "Signify Netherlands B.V.",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.104.2",
    "date_code": None,
    "endpoints": {"11": {"inputClusters": [0, 3, 4, 5, 6, 8, 768], "outputClusters": [], "binds": [], "configuredReportings": []}},
    "options": {}
}

LIGHT_COLOR_STATE = {
    "state": "ON",
    "brightness": 180,
    "color_temp": 300,
    "color": {"x": 0.3151, "y": 0.3251},
    "color_mode": "xy",
    "linkquality": 200
}

# ── Switch / Plug with power metering (Tuya TS011F) ───────────────────────
SWITCH_PLUG = {
    "ieee_address": "0x000b57fffec51378",
    "type": "Router",
    "network_address": 10003,
    "supported": True,
    "friendly_name": "Kitchen Plug",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "TS011F_plug_1",
        "vendor": "Tuya",
        "description": "Smart plug (with power monitoring)",
        "exposes": [
            {
                "type": "switch",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"}
                ]
            },
            {"type": "numeric", "name": "power", "label": "Power", "property": "power",
             "access": 1, "unit": "W"},
            {"type": "numeric", "name": "energy", "label": "Energy", "property": "energy",
             "access": 1, "unit": "kWh"},
            {"type": "numeric", "name": "voltage", "label": "Voltage", "property": "voltage",
             "access": 1, "unit": "V"},
            {"type": "numeric", "name": "current", "label": "Current", "property": "current",
             "access": 1, "unit": "A"},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "TS011F",
    "manufacturer": "_TZ3000_g5xawfcq",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.5",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 6, 1794, 2820, 57344, 57345], "outputClusters": [10, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}

SWITCH_PLUG_STATE = {
    "state": "ON",
    "power": 45.2,
    "energy": 1234.56,
    "voltage": 230.1,
    "current": 0.196,
    "linkquality": 187
}

# ── Sensor: temperature + humidity (Aqara) ────────────────────────────────
SENSOR = {
    "ieee_address": "0x00158d0001234567",
    "type": "EndDevice",
    "network_address": 10004,
    "supported": True,
    "friendly_name": "Office Sensor",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "WSDCGQ11LM",
        "vendor": "Aqara",
        "description": "Temperature and humidity sensor",
        "exposes": [
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "humidity", "label": "Humidity", "property": "humidity",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "pressure", "label": "Pressure", "property": "pressure",
             "access": 1, "unit": "hPa"},
            {"type": "numeric", "name": "temperature", "label": "Temperature",
             "property": "temperature", "access": 1, "unit": "°C"},
            {"type": "binary", "name": "battery_low", "label": "Battery low",
             "property": "battery_low", "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.weather",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20161129",
    "endpoints": {"1": {"inputClusters": [0, 3, 65535], "outputClusters": [0, 4, 65535], "binds": [], "configuredReportings": []}},
    "options": {}
}

SENSOR_STATE = {
    "battery": 75,
    "battery_low": False,
    "humidity": 65.2,
    "pressure": 1013.1,
    "temperature": 21.5,
    "linkquality": 98
}

# ── Climate: TRV (Eurotronic Spirit) ─────────────────────────────────────
CLIMATE = {
    "ieee_address": "0x0015bc001e000fe0",
    "type": "Router",
    "network_address": 10005,
    "supported": True,
    "friendly_name": "Bedroom Thermostat",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "SPZB0001",
        "vendor": "Eurotronic",
        "description": "Spirit Zigbee wireless heater thermostat",
        "exposes": [
            {
                "type": "climate",
                "features": [
                    {"type": "numeric", "name": "local_temperature", "label": "Local temperature",
                     "property": "local_temperature", "access": 1, "unit": "°C",
                     "value_min": 0, "value_max": 40},
                    {"type": "numeric", "name": "occupied_heating_setpoint",
                     "label": "Occupied heating setpoint", "property": "occupied_heating_setpoint",
                     "access": 7, "unit": "°C", "value_min": 5, "value_max": 30, "value_step": 0.5},
                    {"type": "enum", "name": "system_mode", "label": "System mode",
                     "property": "system_mode", "access": 7,
                     "values": ["off", "auto", "heat"]},
                    {"type": "enum", "name": "running_state", "label": "Running state",
                     "property": "running_state", "access": 1,
                     "values": ["idle", "heat"]}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "SPZB0001",
    "manufacturer": "Eurotronic",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "39",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 513, 516], "outputClusters": [0, 10], "binds": [], "configuredReportings": []}},
    "options": {}
}

CLIMATE_STATE = {
    "battery": 80,
    "local_temperature": 20.5,
    "occupied_heating_setpoint": 22.0,
    "running_state": "heat",
    "system_mode": "heat",
    "linkquality": 45
}

# ── Cover (IKEA KADRILJ roller blind) ─────────────────────────────────────
COVER = {
    "ieee_address": "0x0c4314fffed23456",
    "type": "EndDevice",
    "network_address": 10006,
    "supported": True,
    "friendly_name": "Living Room Blinds",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1926",
        "vendor": "IKEA",
        "description": "KADRILJ roller blind",
        "exposes": [
            {
                "type": "cover",
                "features": [
                    {"type": "enum", "name": "state", "label": "State", "property": "state",
                     "access": 7, "values": ["OPEN", "CLOSE", "STOP"]},
                    {"type": "numeric", "name": "position", "label": "Position",
                     "property": "position", "access": 7, "value_min": 0, "value_max": 100,
                     "unit": "%"}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "TRADFRI roller blind",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.2.009",
    "date_code": "20190128",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 4, 5, 32, 258, 4096, 64636], "outputClusters": [3, 4, 6, 8, 25, 258, 4096], "binds": [], "configuredReportings": []}},
    "options": {}
}

COVER_STATE = {
    "state": "CLOSE",
    "position": 0,
    "battery": 65,
    "linkquality": 155
}

# ── Lock (Schlage BE468 Connect smart deadbolt) ──────────────────────────
LOCK = {
    "ieee_address": "0x54ef441000130bed",
    "type": "EndDevice",
    "network_address": 10007,
    "supported": True,
    "friendly_name": "Front Door Lock",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "BE468",
        "vendor": "Schlage",
        "description": "Connect smart deadbolt",
        "exposes": [
            {
                "type": "lock",
                "features": [
                    {"type": "enum", "name": "state", "label": "State", "property": "state",
                     "access": 7, "values": ["LOCK", "UNLOCK"]},
                    {"type": "enum", "name": "lock_state", "label": "Lock state",
                     "property": "lock_state", "access": 1,
                     "values": ["not_fully_locked", "locked", "unlocked"]}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "BE468",
    "manufacturer": "Schlage",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.23.1",
    "date_code": None,
    "endpoints": {"11": {"inputClusters": [0, 1, 3, 10, 257], "outputClusters": [10, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}

LOCK_STATE = {
    "battery": 62,
    "state": "LOCK",
    "lock_state": "locked",
    "linkquality": 90
}

# ── Air purifier / fan (IKEA STARKVIND) — renamed "Bathroom Fan" ─────────
FAN = {
    "ieee_address": "0x0c4314fffeb1c2d3",
    "type": "Router",
    "network_address": 10008,
    "supported": True,
    "friendly_name": "Bathroom Fan",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E2006",
        "vendor": "IKEA",
        "description": "STARKVIND air purifier",
        "exposes": [
            {
                "type": "fan",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "fan_state",
                     "access": 7, "value_on": "ON", "value_off": "OFF"},
                    {"type": "enum", "name": "mode", "label": "Mode", "property": "fan_mode",
                     "access": 7, "values": ["off", "auto", "1", "2", "3", "4", "5", "6", "7", "8", "9"]}
                ]
            },
            {"type": "numeric", "name": "fan_speed", "label": "Fan speed",
             "property": "fan_speed", "access": 1, "value_min": 0, "value_max": 9},
            {"type": "numeric", "name": "pm25", "label": "PM2.5", "property": "pm25",
             "access": 1, "unit": "µg/m³"},
            {"type": "enum", "name": "air_quality", "label": "Air quality",
             "property": "air_quality", "access": 1,
             "values": ["excellent", "good", "moderate", "poor", "unhealthy", "hazardous", "out_of_range", "unknown"]},
            {"type": "binary", "name": "replace_filter", "label": "Replace filter",
             "property": "replace_filter", "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "filter_age", "label": "Filter age",
             "property": "filter_age", "access": 1, "unit": "minutes"},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "STARKVIND Air purifier",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.033",
    "date_code": "20211125",
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 514, 64599], "outputClusters": [25, 32], "binds": [], "configuredReportings": []}},
    "options": {}
}

FAN_STATE = {
    "fan_state": "ON",
    "fan_mode": "auto",
    "fan_speed": 4,
    "pm25": 12,
    "air_quality": "good",
    "replace_filter": False,
    "filter_age": 72000,
    "linkquality": 120
}

# ── Remote (IKEA TRADFRI) ─────────────────────────────────────────────────
REMOTE = {
    "ieee_address": "0x000b57fffe9a0b01",
    "type": "EndDevice",
    "network_address": 10009,
    "supported": True,
    "friendly_name": "TRADFRI Remote",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1524/E1810",
        "vendor": "IKEA",
        "description": "TRADFRI remote control",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1,
             "values": ["arrow_left_click", "arrow_left_hold", "arrow_left_release",
                        "arrow_right_click", "arrow_right_hold", "arrow_right_release",
                        "brightness_down_click", "brightness_down_hold", "brightness_down_release",
                        "brightness_up_click", "brightness_up_hold", "brightness_up_release",
                        "toggle"]},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "TRADFRI remote control",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.2.010",
    "date_code": "20190329",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 32, 4096], "outputClusters": [3, 4, 5, 6, 8, 4096], "binds": [], "configuredReportings": []}},
    "options": {}
}

REMOTE_STATE = {
    "battery": 90,
    "linkquality": 200,
    "action": "toggle"
}

# ═══════════════════════════════════════════════════════════════════════════
# Additional devices — bring the network up to a realistic ~30-device mix
# ═══════════════════════════════════════════════════════════════════════════

# ── Light: RGB bulb (Hue Color) ───────────────────────────────────────────
LIGHT_RGB = {
    "ieee_address": "0x0017880108a4b2c1",
    "type": "Router",
    "network_address": 10010,
    "supported": True,
    "friendly_name": "Kitchen RGB Bulb",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "LCT015",
        "vendor": "Philips",
        "description": "Hue white and color ambiance E26",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254},
                    {"type": "composite", "name": "color_xy", "label": "Color (X/Y)",
                     "property": "color", "access": 7,
                     "features": [
                         {"type": "numeric", "name": "x", "property": "x", "access": 7},
                         {"type": "numeric", "name": "y", "property": "y", "access": 7}
                     ]},
                    {"type": "enum", "name": "color_mode", "label": "Color mode",
                     "property": "color_mode", "access": 1, "values": ["color_temp", "xy", "hs"]}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "LCT015",
    "manufacturer": "Signify Netherlands B.V.",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.88.1",
    "date_code": None,
    "endpoints": {"11": {"inputClusters": [0, 3, 4, 5, 6, 8, 768], "outputClusters": [], "binds": [], "configuredReportings": []}},
    "options": {}
}
LIGHT_RGB_STATE = {"state": "OFF", "brightness": 128, "color": {"x": 0.4, "y": 0.35}, "color_mode": "xy", "linkquality": 180}

# ── Light: White dimmer bulb (IKEA) ───────────────────────────────────────
LIGHT_DIMMER = {
    "ieee_address": "0x000b57fffec0a111",
    "type": "Router",
    "network_address": 10011,
    "supported": True,
    "friendly_name": "Hallway Dimmer Bulb",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "LED1836G9",
        "vendor": "IKEA",
        "description": "TRADFRI LED bulb E27 806 lumen, dimmable, warm white",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "TRADFRI bulb E27 WW 806lm",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.012",
    "date_code": "20200928",
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 6, 8], "outputClusters": [5], "binds": [], "configuredReportings": []}},
    "options": {}
}
LIGHT_DIMMER_STATE = {"state": "ON", "brightness": 80, "linkquality": 150}

# ── Light: LED strip (Gledopto) ───────────────────────────────────────────
LIGHT_STRIP = {
    "ieee_address": "0x00124b0022334455",
    "type": "Router",
    "network_address": 10012,
    "supported": True,
    "friendly_name": "Desk LED Strip",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "GL-C-008",
        "vendor": "Gledopto",
        "description": "Zigbee LED controller RGBW",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254},
                    {"type": "composite", "name": "color_xy", "label": "Color (X/Y)",
                     "property": "color", "access": 7,
                     "features": [
                         {"type": "numeric", "name": "x", "property": "x", "access": 7},
                         {"type": "numeric", "name": "y", "property": "y", "access": 7}
                     ]}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "GL-C-008",
    "manufacturer": "GLEDOPTO",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.9",
    "date_code": None,
    "endpoints": {"11": {"inputClusters": [0, 3, 4, 5, 6, 8, 768], "outputClusters": [], "binds": [], "configuredReportings": []}},
    "options": {}
}
LIGHT_STRIP_STATE = {"state": "ON", "brightness": 255, "color": {"x": 0.2, "y": 0.6}, "linkquality": 165}

# ── Light: Candle bulb (IKEA) ─────────────────────────────────────────────
LIGHT_CANDLE = {
    "ieee_address": "0x000b57fffec0a222",
    "type": "Router",
    "network_address": 10013,
    "supported": True,
    "friendly_name": "Dining Candle Bulb",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "LED1949C5",
        "vendor": "IKEA",
        "description": "TRADFRI LED bulb E12 candle",
        "exposes": [
            {
                "type": "light",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"},
                    {"type": "numeric", "name": "brightness", "label": "Brightness",
                     "property": "brightness", "access": 7, "value_min": 0, "value_max": 254},
                    {"type": "numeric", "name": "color_temp", "label": "Color temperature",
                     "property": "color_temp", "access": 7, "value_min": 250, "value_max": 454, "unit": "mired"}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "TRADFRI bulb E12 WS candle 450lm",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.011",
    "date_code": "20210618",
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 6, 8, 768], "outputClusters": [5], "binds": [], "configuredReportings": []}},
    "options": {}
}
LIGHT_CANDLE_STATE = {"state": "OFF", "brightness": 110, "color_temp": 370, "color_mode": "color_temp", "linkquality": 130}

# ── Motion sensor (Aqara RTCGQ11LM) ───────────────────────────────────────
MOTION_AQARA = {
    "ieee_address": "0x00158d00011aa001",
    "type": "EndDevice",
    "network_address": 10014,
    "supported": True,
    "friendly_name": "Hallway Motion",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "RTCGQ11LM",
        "vendor": "Aqara",
        "description": "Human body movement and illuminance sensor",
        "exposes": [
            {"type": "binary", "name": "occupancy", "label": "Occupancy", "property": "occupancy",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "illuminance", "label": "Illuminance",
             "property": "illuminance", "access": 1, "unit": "lx"},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.sensor_motion.aq2",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20200315",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 1024, 1030, 65535], "outputClusters": [0, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
MOTION_AQARA_STATE = {"occupancy": False, "illuminance": 12, "battery": 85, "linkquality": 110}

# ── Motion sensor (IKEA TRADFRI E1525) ────────────────────────────────────
MOTION_IKEA = {
    "ieee_address": "0x000b57fffec0b333",
    "type": "EndDevice",
    "network_address": 10015,
    "supported": True,
    "friendly_name": "Garage Motion",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1525/E1745",
        "vendor": "IKEA",
        "description": "TRADFRI motion sensor",
        "exposes": [
            {"type": "binary", "name": "occupancy", "label": "Occupancy", "property": "occupancy",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "TRADFRI motion sensor",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "24.4.6",
    "date_code": "20190303",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 32, 4096], "outputClusters": [3, 4, 6, 25, 4096], "binds": [], "configuredReportings": []}},
    "options": {}
}
MOTION_IKEA_STATE = {"occupancy": True, "battery": 70, "linkquality": 140}

# ── Door/window contact (Aqara MCCGQ11LM) ─────────────────────────────────
CONTACT = {
    "ieee_address": "0x00158d00022bb002",
    "type": "EndDevice",
    "network_address": 10016,
    "supported": True,
    "friendly_name": "Back Door Contact",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "MCCGQ11LM",
        "vendor": "Aqara",
        "description": "Door and window contact sensor",
        "exposes": [
            {"type": "binary", "name": "contact", "label": "Contact", "property": "contact",
             "access": 1, "value_on": False, "value_off": True},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.sensor_magnet.aq2",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20200512",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 65535], "outputClusters": [0, 4, 65535], "binds": [], "configuredReportings": []}},
    "options": {}
}
CONTACT_STATE = {"contact": True, "battery": 92, "linkquality": 170}

# ── Vibration sensor (Aqara DJT11LM) ──────────────────────────────────────
VIBRATION = {
    "ieee_address": "0x00158d00033cc003",
    "type": "EndDevice",
    "network_address": 10017,
    "supported": True,
    "friendly_name": "Washing Machine Vibration",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "DJT11LM",
        "vendor": "Aqara",
        "description": "Vibration sensor",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1, "values": ["vibration", "tilt", "drop"]},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.vibration.aq1",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20181130",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 257, 1280, 65535], "outputClusters": [0, 4, 65535], "binds": [], "configuredReportings": []}},
    "options": {}
}
VIBRATION_STATE = {"action": "vibration", "battery": 55, "linkquality": 120}

# ── Water leak sensor (Heiman LDSENK09 / Aqara-style) ─────────────────────
LEAK = {
    "ieee_address": "0x00158d00044dd004",
    "type": "EndDevice",
    "network_address": 10018,
    "supported": True,
    "friendly_name": "Basement Leak Sensor",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "LDSENK09",
        "vendor": "Heiman",
        "description": "Water leak sensor",
        "exposes": [
            {"type": "binary", "name": "water_leak", "label": "Water leak",
             "property": "water_leak", "access": 1, "value_on": True, "value_off": False},
            {"type": "binary", "name": "battery_low", "label": "Battery low",
             "property": "battery_low", "access": 1, "value_on": True, "value_off": False},
            {"type": "binary", "name": "tamper", "label": "Tamper", "property": "tamper",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "LDSENK09",
    "manufacturer": "HEIMAN",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20211201",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 1280], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
LEAK_STATE = {"water_leak": False, "battery_low": False, "tamper": False, "battery": 88, "linkquality": 100}

# ── Smoke detector (Develco SMSZB-120) ────────────────────────────────────
SMOKE = {
    "ieee_address": "0x0015bc002a000a01",
    "type": "EndDevice",
    "network_address": 10019,
    "supported": True,
    "friendly_name": "Kitchen Smoke Alarm",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "SMSZB-120",
        "vendor": "Develco",
        "description": "Smoke detector with siren",
        "exposes": [
            {"type": "binary", "name": "smoke", "label": "Smoke", "property": "smoke",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "binary", "name": "battery_low", "label": "Battery low",
             "property": "battery_low", "access": 1, "value_on": True, "value_off": False},
            {"type": "binary", "name": "test", "label": "Test", "property": "test",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "SMSZB-120",
    "manufacturer": "Develco Products A/S",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "4.0.4",
    "date_code": "20210104",
    "endpoints": {"35": {"inputClusters": [0, 1, 3, 1280, 1282], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
SMOKE_STATE = {"smoke": False, "battery_low": False, "test": False, "battery": 96, "linkquality": 115}

# ── Air quality sensor (PM2.5 + VOC) ──────────────────────────────────────
AIR_QUALITY = {
    "ieee_address": "0x00158d00055ee005",
    "type": "Router",
    "network_address": 10020,
    "supported": True,
    "friendly_name": "Office Air Quality",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "VOCKQJK11LM",
        "vendor": "Aqara",
        "description": "TVOC air quality monitor",
        "exposes": [
            {"type": "numeric", "name": "pm25", "label": "PM2.5", "property": "pm25",
             "access": 1, "unit": "µg/m³"},
            {"type": "numeric", "name": "voc", "label": "VOC", "property": "voc",
             "access": 1, "unit": "ppb"},
            {"type": "numeric", "name": "temperature", "label": "Temperature",
             "property": "temperature", "access": 1, "unit": "°C"},
            {"type": "numeric", "name": "humidity", "label": "Humidity", "property": "humidity",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.airmonitor.acn01",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "0.0.0_0025",
    "date_code": "20211115",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 1026, 1029, 1066, 1070], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
AIR_QUALITY_STATE = {"pm25": 8, "voc": 120, "temperature": 22.1, "humidity": 45.0, "battery": 78, "linkquality": 160}

# ── Presence sensor (Aqara FP1) ───────────────────────────────────────────
PRESENCE = {
    "ieee_address": "0x00158d00066ff006",
    "type": "EndDevice",
    "network_address": 10021,
    "supported": True,
    "friendly_name": "Living Room Presence",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "RTCZCGQ11LM",
        "vendor": "Aqara",
        "description": "Presence sensor FP1",
        "exposes": [
            {"type": "binary", "name": "presence", "label": "Presence", "property": "presence",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "enum", "name": "presence_event", "label": "Presence event",
             "property": "presence_event", "access": 1,
             "values": ["enter", "leave", "left_enter", "right_leave", "right_enter", "left_leave", "approach", "away"]},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "lumi.motion.ac01",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.0_0008",
    "date_code": "20220301",
    "endpoints": {"1": {"inputClusters": [0, 3, 1030], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
PRESENCE_STATE = {"presence": True, "presence_event": "enter", "linkquality": 175}

# ── Illuminance sensor (Aqara GZCGQ01LM) ──────────────────────────────────
ILLUMINANCE = {
    "ieee_address": "0x00158d00077ff007",
    "type": "EndDevice",
    "network_address": 10022,
    "supported": True,
    "friendly_name": "Patio Light Sensor",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "GZCGQ01LM",
        "vendor": "Aqara",
        "description": "Light intensity sensor",
        "exposes": [
            {"type": "numeric", "name": "illuminance", "label": "Illuminance",
             "property": "illuminance", "access": 1, "unit": "lx"},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.sen_ill.mgl01",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": None,
    "date_code": "20190826",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 1024], "outputClusters": [3], "binds": [], "configuredReportings": []}},
    "options": {}
}
ILLUMINANCE_STATE = {"illuminance": 450, "battery": 82, "linkquality": 125}

# ── Smart plug without power monitoring (IKEA TRADFRI) ────────────────────
PLUG_SIMPLE = {
    "ieee_address": "0x000b57fffec0c444",
    "type": "Router",
    "network_address": 10023,
    "supported": True,
    "friendly_name": "Lamp Plug",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1603/E1702/E1708",
        "vendor": "IKEA",
        "description": "TRADFRI control outlet",
        "exposes": [
            {
                "type": "switch",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"}
                ]
            },
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "TRADFRI control outlet",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.3.089",
    "date_code": "20210202",
    "endpoints": {"1": {"inputClusters": [0, 3, 4, 5, 6, 8, 64636], "outputClusters": [5, 25, 32], "binds": [], "configuredReportings": []}},
    "options": {}
}
PLUG_SIMPLE_STATE = {"state": "OFF", "linkquality": 178}

# ── Wall switch, single-gang (Aqara QBKG11LM) ─────────────────────────────
WALL_SWITCH_1 = {
    "ieee_address": "0x00158d00088aa008",
    "type": "Router",
    "network_address": 10024,
    "supported": True,
    "friendly_name": "Living Room Wall Switch",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "QBKG11LM",
        "vendor": "Aqara",
        "description": "Smart wall switch (with neutral, single rocker)",
        "exposes": [
            {
                "type": "switch",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE"}
                ]
            },
            {"type": "numeric", "name": "power", "label": "Power", "property": "power",
             "access": 1, "unit": "W"},
            {"type": "numeric", "name": "temperature", "label": "Temperature",
             "property": "temperature", "access": 1, "unit": "°C"},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "lumi.ctrl_ln1.aq1",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.0",
    "date_code": "20190314",
    "endpoints": {"1": {"inputClusters": [0, 1, 2, 3, 4, 5, 6, 10, 12, 2820], "outputClusters": [10, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
WALL_SWITCH_1_STATE = {"state": "ON", "power": 0.0, "temperature": 28, "linkquality": 190}

# ── Dual-gang wall switch (Aqara QBKG12LM) ────────────────────────────────
WALL_SWITCH_2 = {
    "ieee_address": "0x00158d00099bb009",
    "type": "Router",
    "network_address": 10025,
    "supported": True,
    "friendly_name": "Kitchen Dual Switch",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "QBKG12LM",
        "vendor": "Aqara",
        "description": "Smart wall switch (with neutral, double rocker)",
        "exposes": [
            {
                "type": "switch",
                "endpoint": "left",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state_left",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE",
                     "endpoint": "left"}
                ]
            },
            {
                "type": "switch",
                "endpoint": "right",
                "features": [
                    {"type": "binary", "name": "state", "label": "State", "property": "state_right",
                     "access": 7, "value_on": "ON", "value_off": "OFF", "value_toggle": "TOGGLE",
                     "endpoint": "right"}
                ]
            },
            {"type": "numeric", "name": "power", "label": "Power", "property": "power",
             "access": 1, "unit": "W"},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "lumi.ctrl_ln2.aq1",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.0",
    "date_code": "20190411",
    "endpoints": {
        "1": {"inputClusters": [0, 1, 2, 3, 4, 5, 6, 10], "outputClusters": [10, 25], "binds": [], "configuredReportings": []},
        "2": {"inputClusters": [0, 3, 4, 5, 6], "outputClusters": [], "binds": [], "configuredReportings": []}
    },
    "options": {}
}
WALL_SWITCH_2_STATE = {"state_left": "ON", "state_right": "OFF", "power": 12.3, "linkquality": 155}

# ── Dimmer switch (Lutron Aurora) ─────────────────────────────────────────
DIMMER_SWITCH = {
    "ieee_address": "0xa4c13800aaaabbbb",
    "type": "EndDevice",
    "network_address": 10026,
    "supported": True,
    "friendly_name": "Bedroom Dimmer",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "Z3-1BRL",
        "vendor": "Lutron",
        "description": "Aurora smart bulb dimmer",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1, "values": ["brightness_step_up", "brightness_step_down"]},
            {"type": "numeric", "name": "brightness", "label": "Brightness",
             "property": "brightness", "access": 1, "value_min": 0, "value_max": 254},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "Z3-1BRL",
    "manufacturer": "Lutron",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "3.3",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 4096], "outputClusters": [3, 6, 8], "binds": [], "configuredReportings": []}},
    "options": {}
}
DIMMER_SWITCH_STATE = {"action": "brightness_step_up", "brightness": 180, "battery": 77, "linkquality": 145}

# ── Smart button 1-button (IKEA E1743) ────────────────────────────────────
BUTTON_1 = {
    "ieee_address": "0x000b57fffec0d555",
    "type": "EndDevice",
    "network_address": 10027,
    "supported": True,
    "friendly_name": "Bedside Button",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1743",
        "vendor": "IKEA",
        "description": "TRADFRI on/off switch",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1, "values": ["on", "off", "brightness_move_up", "brightness_move_down", "brightness_stop"]},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "TRADFRI on/off switch",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.3.014",
    "date_code": "20200312",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 32, 4096], "outputClusters": [3, 6, 8, 25, 4096], "binds": [], "configuredReportings": []}},
    "options": {}
}
BUTTON_1_STATE = {"action": "on", "battery": 84, "linkquality": 160}

# ── Multi-button remote (Hue Dimmer RWL021) ───────────────────────────────
BUTTON_MULTI = {
    "ieee_address": "0x0017880104abcd11",
    "type": "EndDevice",
    "network_address": 10028,
    "supported": True,
    "friendly_name": "Hue Dimmer Remote",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "324131092621",
        "vendor": "Philips",
        "description": "Hue dimmer switch",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1,
             "values": ["on_press", "on_hold", "on_release",
                        "up_press", "up_hold", "up_release",
                        "down_press", "down_hold", "down_release",
                        "off_press", "off_hold", "off_release"]},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "RWL021",
    "manufacturer": "Signify Netherlands B.V.",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "5.45.1.17846",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 64512], "outputClusters": [3, 4, 6, 8, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
BUTTON_MULTI_STATE = {"action": "on_press", "battery": 65, "linkquality": 150}

# ── Smart curtain motor (IKEA FYRTUR) ─────────────────────────────────────
CURTAIN = {
    "ieee_address": "0x000b57fffec0e666",
    "type": "EndDevice",
    "network_address": 10029,
    "supported": True,
    "friendly_name": "Bedroom Curtain",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "E1757",
        "vendor": "IKEA",
        "description": "FYRTUR roller blind",
        "exposes": [
            {
                "type": "cover",
                "features": [
                    {"type": "enum", "name": "state", "label": "State", "property": "state",
                     "access": 7, "values": ["OPEN", "CLOSE", "STOP"]},
                    {"type": "numeric", "name": "position", "label": "Position",
                     "property": "position", "access": 7, "value_min": 0, "value_max": 100, "unit": "%"}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "FYRTUR block-out roller blind",
    "manufacturer": "IKEA of Sweden",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "2.2.009",
    "date_code": "20200813",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 4, 5, 32, 258, 4096, 64636], "outputClusters": [3, 4, 6, 8, 25, 258, 4096], "binds": [], "configuredReportings": []}},
    "options": {}
}
CURTAIN_STATE = {"state": "OPEN", "position": 100, "battery": 58, "linkquality": 130}

# ── Siren (Heiman warningDevice) ──────────────────────────────────────────
SIREN = {
    "ieee_address": "0x0015bc002b000b02",
    "type": "Router",
    "network_address": 10030,
    "supported": True,
    "friendly_name": "Garage Siren",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "HS2WD-E",
        "vendor": "Heiman",
        "description": "Smart siren",
        "exposes": [
            {"type": "enum", "name": "warning_mode", "label": "Warning mode",
             "property": "warning_mode", "access": 2,
             "values": ["stop", "burglar", "fire", "emergency", "police_panic", "fire_panic", "emergency_panic"]},
            {"type": "numeric", "name": "duration", "label": "Duration",
             "property": "duration", "access": 2, "value_min": 0, "value_max": 1800, "unit": "s"},
            {"type": "binary", "name": "battery_low", "label": "Battery low",
             "property": "battery_low", "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Mains (single phase)",
    "model_id": "WarningDevice",
    "manufacturer": "HEIMAN",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.0.5",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 1282], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
SIREN_STATE = {"warning_mode": "stop", "duration": 0, "battery_low": False, "battery": 100, "linkquality": 175}

# ── Smart knob (Aqara ZNXNKG02LM) ─────────────────────────────────────────
KNOB = {
    "ieee_address": "0x00158d000aacc00a",
    "type": "EndDevice",
    "network_address": 10031,
    "supported": True,
    "friendly_name": "Study Smart Knob",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "ZNXNKG02LM",
        "vendor": "Aqara",
        "description": "Smart rotary knob H1 (wireless)",
        "exposes": [
            {"type": "enum", "name": "action", "label": "Action", "property": "action",
             "access": 1,
             "values": ["single", "double", "hold", "release", "start_rotating", "rotation", "stop_rotating"]},
            {"type": "numeric", "name": "action_rotation_angle", "label": "Rotation angle",
             "property": "action_rotation_angle", "access": 1, "unit": "°"},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "lumi.remote.rkba01",
    "manufacturer": "LUMI",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "0.0.0_0027",
    "date_code": "20220518",
    "endpoints": {"1": {"inputClusters": [0, 1, 3], "outputClusters": [3, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
KNOB_STATE = {"action": "single", "action_rotation_angle": 0, "battery": 95, "linkquality": 165}

# ── Thermostat (Danfoss Ally) ─────────────────────────────────────────────
THERMOSTAT_ALT = {
    "ieee_address": "0x0015bc002c000c03",
    "type": "Router",
    "network_address": 10032,
    "supported": True,
    "friendly_name": "Guest Room Radiator",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "014G2461",
        "vendor": "Danfoss",
        "description": "Ally thermostatic radiator valve",
        "exposes": [
            {
                "type": "climate",
                "features": [
                    {"type": "numeric", "name": "local_temperature", "label": "Local temperature",
                     "property": "local_temperature", "access": 1, "unit": "°C",
                     "value_min": 0, "value_max": 40},
                    {"type": "numeric", "name": "occupied_heating_setpoint",
                     "label": "Occupied heating setpoint", "property": "occupied_heating_setpoint",
                     "access": 7, "unit": "°C", "value_min": 4, "value_max": 35, "value_step": 0.5},
                    {"type": "enum", "name": "system_mode", "label": "System mode",
                     "property": "system_mode", "access": 7, "values": ["off", "heat"]}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "eTRV0100",
    "manufacturer": "Danfoss",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.13",
    "date_code": "20210103",
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 10, 513, 516], "outputClusters": [0, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
THERMOSTAT_ALT_STATE = {"local_temperature": 19.0, "occupied_heating_setpoint": 20.5, "system_mode": "heat", "battery": 72, "linkquality": 95}

# ── Second lock (Yale YRD226) ─────────────────────────────────────────────
LOCK_ALT = {
    "ieee_address": "0x54ef441000131cfe",
    "type": "EndDevice",
    "network_address": 10033,
    "supported": True,
    "friendly_name": "Back Door Lock",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "YRD226HA2619",
        "vendor": "Yale",
        "description": "Assure lock",
        "exposes": [
            {
                "type": "lock",
                "features": [
                    {"type": "enum", "name": "state", "label": "State", "property": "state",
                     "access": 7, "values": ["LOCK", "UNLOCK"]},
                    {"type": "enum", "name": "lock_state", "label": "Lock state",
                     "property": "lock_state", "access": 1,
                     "values": ["not_fully_locked", "locked", "unlocked"]}
                ]
            },
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "YRD226/246 TSDB",
    "manufacturer": "Yale",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "3.1",
    "date_code": None,
    "endpoints": {"1": {"inputClusters": [0, 1, 3, 10, 257], "outputClusters": [10, 25], "binds": [], "configuredReportings": []}},
    "options": {}
}
LOCK_ALT_STATE = {"state": "UNLOCK", "lock_state": "unlocked", "battery": 48, "linkquality": 85}

# ── Outdoor motion + temperature sensor (Philips Hue Outdoor) ─────────────
OUTDOOR_MOTION = {
    "ieee_address": "0x001788010bcd0f12",
    "type": "EndDevice",
    "network_address": 10034,
    "supported": True,
    "friendly_name": "Backyard Outdoor Sensor",
    "disabled": False,
    "description": None,
    "definition": {
        "model": "9290019758",
        "vendor": "Philips",
        "description": "Hue outdoor motion sensor",
        "exposes": [
            {"type": "binary", "name": "occupancy", "label": "Occupancy", "property": "occupancy",
             "access": 1, "value_on": True, "value_off": False},
            {"type": "numeric", "name": "temperature", "label": "Temperature",
             "property": "temperature", "access": 1, "unit": "°C"},
            {"type": "numeric", "name": "illuminance", "label": "Illuminance",
             "property": "illuminance", "access": 1, "unit": "lx"},
            {"type": "numeric", "name": "battery", "label": "Battery", "property": "battery",
             "access": 1, "unit": "%", "value_min": 0, "value_max": 100},
            {"type": "numeric", "name": "linkquality", "label": "Link quality",
             "property": "linkquality", "access": 1, "unit": "lqi", "value_min": 0, "value_max": 255}
        ],
        "options": []
    },
    "power_source": "Battery",
    "model_id": "SML002",
    "manufacturer": "Signify Netherlands B.V.",
    "interview_completed": True,
    "interviewing": False,
    "software_build_id": "1.1.28573",
    "date_code": None,
    "endpoints": {"2": {"inputClusters": [0, 1, 3, 1024, 1026, 1030, 64515], "outputClusters": [25], "binds": [], "configuredReportings": []}},
    "options": {}
}
OUTDOOR_MOTION_STATE = {"occupancy": False, "temperature": 14.2, "illuminance": 3200, "battery": 68, "linkquality": 80}

# ═══════════════════════════════════════════════════════════════════════════

ALL_DEVICES = [
    COORDINATOR,
    LIGHT_CT,
    LIGHT_COLOR,
    SWITCH_PLUG,
    SENSOR,
    CLIMATE,
    COVER,
    LOCK,
    FAN,
    REMOTE,
    LIGHT_RGB,
    LIGHT_DIMMER,
    LIGHT_STRIP,
    LIGHT_CANDLE,
    MOTION_AQARA,
    MOTION_IKEA,
    CONTACT,
    VIBRATION,
    LEAK,
    SMOKE,
    AIR_QUALITY,
    PRESENCE,
    ILLUMINANCE,
    PLUG_SIMPLE,
    WALL_SWITCH_1,
    WALL_SWITCH_2,
    DIMMER_SWITCH,
    BUTTON_1,
    BUTTON_MULTI,
    CURTAIN,
    SIREN,
    KNOB,
    THERMOSTAT_ALT,
    LOCK_ALT,
    OUTDOOR_MOTION,
]

DEVICE_STATES = {
    LIGHT_CT["friendly_name"]:       LIGHT_CT_STATE,
    LIGHT_COLOR["friendly_name"]:    LIGHT_COLOR_STATE,
    SWITCH_PLUG["friendly_name"]:    SWITCH_PLUG_STATE,
    SENSOR["friendly_name"]:         SENSOR_STATE,
    CLIMATE["friendly_name"]:        CLIMATE_STATE,
    COVER["friendly_name"]:          COVER_STATE,
    LOCK["friendly_name"]:           LOCK_STATE,
    FAN["friendly_name"]:            FAN_STATE,
    REMOTE["friendly_name"]:         REMOTE_STATE,
    LIGHT_RGB["friendly_name"]:      LIGHT_RGB_STATE,
    LIGHT_DIMMER["friendly_name"]:   LIGHT_DIMMER_STATE,
    LIGHT_STRIP["friendly_name"]:    LIGHT_STRIP_STATE,
    LIGHT_CANDLE["friendly_name"]:   LIGHT_CANDLE_STATE,
    MOTION_AQARA["friendly_name"]:   MOTION_AQARA_STATE,
    MOTION_IKEA["friendly_name"]:    MOTION_IKEA_STATE,
    CONTACT["friendly_name"]:        CONTACT_STATE,
    VIBRATION["friendly_name"]:      VIBRATION_STATE,
    LEAK["friendly_name"]:           LEAK_STATE,
    SMOKE["friendly_name"]:          SMOKE_STATE,
    AIR_QUALITY["friendly_name"]:    AIR_QUALITY_STATE,
    PRESENCE["friendly_name"]:       PRESENCE_STATE,
    ILLUMINANCE["friendly_name"]:    ILLUMINANCE_STATE,
    PLUG_SIMPLE["friendly_name"]:    PLUG_SIMPLE_STATE,
    WALL_SWITCH_1["friendly_name"]:  WALL_SWITCH_1_STATE,
    WALL_SWITCH_2["friendly_name"]:  WALL_SWITCH_2_STATE,
    DIMMER_SWITCH["friendly_name"]:  DIMMER_SWITCH_STATE,
    BUTTON_1["friendly_name"]:       BUTTON_1_STATE,
    BUTTON_MULTI["friendly_name"]:   BUTTON_MULTI_STATE,
    CURTAIN["friendly_name"]:        CURTAIN_STATE,
    SIREN["friendly_name"]:          SIREN_STATE,
    KNOB["friendly_name"]:           KNOB_STATE,
    THERMOSTAT_ALT["friendly_name"]: THERMOSTAT_ALT_STATE,
    LOCK_ALT["friendly_name"]:       LOCK_ALT_STATE,
    OUTDOOR_MOTION["friendly_name"]: OUTDOOR_MOTION_STATE,
}

BRIDGE_INFO = {
    "version": "2.1.0",
    "commit": "abc123def456abc123def456abc123def456abc1",
    "coordinator": {
        "ieee_address": "0x00124b0000000000",
        "meta": {"revision": 20230507, "transportrev": 2, "product": 2, "majorrel": 2, "minorrel": 7, "hwrev": 11}
    },
    "network": {
        "channel": 11,
        "pan_id": 6754,
        "extended_pan_id": "0xdddddddddddddddd"
    },
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
            "qos": 0
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
            "adapter_delay": None
        },
        "availability": {"enabled": False},
        "ota": {
            "update_check_interval": 1440,
            "disable_automatic_update_check": False,
            "zigbee_ota_override_index_location": None,
            "image_block_response_time": 250,
            "default_maximum_data_size": 50
        },
        "health": {"enabled": False, "check_interval": 0},
        "passlist": [],
        "blocklist": []
    }
}

BRIDGE_HEALTH = {
    "healthy": True,
    "response_time": 32,
    "process": {
        "uptime": 3600,
        "memory_usage": 42.5,
        "memory_usage_mb": 85.2
    },
    "os": {
        "load_average_5m": 1.2,
        "memory_usage": 55.3,
        "memory_usage_gb": 3.7
    },
    "mqtt": {
        "connected": True,
        "queued": 0,
        "published": 1234,
        "received": 5678
    }
}

GROUPS = [
    {
        "id": 1,
        "friendly_name": "All Lights",
        "description": None,
        "members": [
            {"ieee_address": "0x000b57fffec6a5b3", "endpoint": 1},
            {"ieee_address": "0x0017880103f72892", "endpoint": 11}
        ],
        "scenes": [
            {"id": 1, "name": "Evening"},
            {"id": 2, "name": "Movie"}
        ]
    },
    {
        "id": 2,
        "friendly_name": "Bedroom",
        "description": None,
        "members": [
            {"ieee_address": "0x0017880103f72892", "endpoint": 11},       # Bedroom Hue
            {"ieee_address": "0xa4c13800aaaabbbb", "endpoint": 1},        # Bedroom Dimmer
            {"ieee_address": "0x000b57fffec0e666", "endpoint": 1}         # Bedroom Curtain
        ],
        "scenes": [
            {"id": 3, "name": "Night"}
        ]
    },
    {
        "id": 3,
        "friendly_name": "Kitchen",
        "description": None,
        "members": [
            {"ieee_address": "0x000b57fffec51378", "endpoint": 1},        # Kitchen Plug
            {"ieee_address": "0x0017880108a4b2c1", "endpoint": 11},       # Kitchen RGB Bulb
            {"ieee_address": "0x00158d00099bb009", "endpoint": 1}         # Kitchen Dual Switch
        ],
        "scenes": []
    }
]

# ══════════════════════════════════════════════════════════════════════════
# Intentionally omitted / stubbed zigbee2mqtt behaviours
# --------------------------------------------------------------------------
# These fixtures simulate device *presence and state* but deliberately do not
# model the full zigbee2mqtt runtime. Keep this list in mind when writing
# tests against the mock bridge — features below will not respond as a real
# network does.
#
# - No scene recall simulation: GROUPS advertise `scenes` for UI, but
#   `scene_recall` / `scene_store` MQTT commands are not acted on by the
#   seeder and will not change any device state.
# - No energy_history / daily energy rollups: only the live `energy` counter
#   is published; there is no per-day/-week aggregation topic.
# - No real interview state machine: every device is published with
#   `interview_completed=true`, `interviewing=false`. Pairing, re-interview,
#   and interview progress events are not emitted.
# - No binding enforcement: `binds` arrays are empty stubs. `bridge/request/
#   device/bind` and `device/unbind` requests are not honoured.
# - No group membership enforcement: sending to a group topic does not fan
#   out state changes to member devices in this mock.
# - No OTA firmware flow: `software_build_id` / `date_code` are static;
#   `bridge/request/device/ota_update/*` is not implemented.
# - No permit_join lifecycle: `permit_join` in BRIDGE_INFO is static False
#   and the seeder does not toggle it or emit `device_joined` events.
# - No availability timeout simulation: every device is published as
#   `online` once and never transitions to `offline` on its own.
# - No action→event replay: remote/button `action` values are static in the
#   fixture and do not rotate through the full enum on a schedule.
# - No device removal / rename round-trip: the seeder never deletes a device
#   it has published, and does not handle `bridge/request/device/rename`.
# - No network map: `bridge/response/networkmap` is not served.
# ══════════════════════════════════════════════════════════════════════════
