"""
Fixture device definitions for Shellbee dev environment.
One representative device per category the app supports.
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

# ── Air purifier / fan (IKEA STARKVIND) ───────────────────────────────────
FAN = {
    "ieee_address": "0x0c4314fffeb1c2d3",
    "type": "Router",
    "network_address": 10008,
    "supported": True,
    "friendly_name": "Living Room Air Purifier",
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
    REMOTE
]

DEVICE_STATES = {
    LIGHT_CT["friendly_name"]:    LIGHT_CT_STATE,
    LIGHT_COLOR["friendly_name"]: LIGHT_COLOR_STATE,
    SWITCH_PLUG["friendly_name"]: SWITCH_PLUG_STATE,
    SENSOR["friendly_name"]:      SENSOR_STATE,
    CLIMATE["friendly_name"]:     CLIMATE_STATE,
    COVER["friendly_name"]:       COVER_STATE,
    LOCK["friendly_name"]:        LOCK_STATE,
    FAN["friendly_name"]:         FAN_STATE,
    REMOTE["friendly_name"]:      REMOTE_STATE,
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
    }
]
