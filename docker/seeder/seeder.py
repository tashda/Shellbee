"""
Shellbee dev-environment seeder.

Waits for Zigbee2MQTT to come online, then publishes retained MQTT messages
that override the bridge/devices list and inject realistic device states for
all nine device categories the app supports. In continuous mode, device states
drift slowly over time to simulate a live network.
"""

import json
import os
import random
import time
import logging
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from fixtures import (
    ALL_DEVICES, DEVICE_STATES, BRIDGE_INFO, BRIDGE_HEALTH, GROUPS
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [seeder] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S"
)
log = logging.getLogger(__name__)

MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
Z2M_TOPIC = os.environ.get("Z2M_TOPIC", "zigbee2mqtt")
MODE = os.environ.get("MODE", "continuous")           # "once" or "continuous"
SEED_INTERVAL = int(os.environ.get("SEED_INTERVAL", "60"))

_z2m_online = False


def on_connect(client, userdata, flags, reason_code, properties):
    log.info("Connected to MQTT broker (rc=%s)", reason_code)
    client.subscribe(f"{Z2M_TOPIC}/bridge/state")


def on_message(client, userdata, msg):
    global _z2m_online
    payload = msg.payload.decode(errors="replace")
    try:
        data = json.loads(payload)
        state = data.get("state", payload)
    except Exception:
        state = payload
    if state == "online":
        log.info("Zigbee2MQTT is online")
        _z2m_online = True


def pub(client, topic, payload, retain=True):
    data = json.dumps(payload, separators=(",", ":"), default=str)
    client.publish(topic, data, retain=retain, qos=1)


def seed(client):
    log.info("Seeding %d devices …", len(ALL_DEVICES) - 1)  # exclude coordinator

    # bridge/info
    pub(client, f"{Z2M_TOPIC}/bridge/info", BRIDGE_INFO)

    # bridge/devices (full list including coordinator)
    pub(client, f"{Z2M_TOPIC}/bridge/devices", ALL_DEVICES)

    # bridge/groups
    pub(client, f"{Z2M_TOPIC}/bridge/groups", GROUPS)

    # bridge/health
    pub(client, f"{Z2M_TOPIC}/bridge/health", BRIDGE_HEALTH)

    # Per-device: state + availability
    for device in ALL_DEVICES:
        name = device["friendly_name"]
        if device["type"] == "Coordinator":
            continue

        state = dict(DEVICE_STATES.get(name, {}))
        now = datetime.now().isoformat(timespec="seconds")
        state["last_seen"] = now
        pub(client, f"{Z2M_TOPIC}/{name}", state)
        pub(client, f"{Z2M_TOPIC}/{name}/availability", {"state": "online"})

    # A few log messages so the Logs tab isn't empty
    for level, msg in [
        ("info",    "Seeder: network ready with all device categories"),
        ("warning", "Seeder: this is a simulated network — no real devices"),
        ("debug",   "Seeder: stub coordinator at channel 11, PAN 6754"),
    ]:
        pub(client, f"{Z2M_TOPIC}/bridge/logging",
            {"level": level, "message": msg, "namespace": "seeder", "message_id": None},
            retain=False)

    log.info("Seed complete")


def drift_state(name: str, base_state: dict) -> dict:
    """Return a slightly drifted copy of a device's state."""
    s = dict(base_state)
    now = datetime.now().isoformat(timespec="seconds")
    s["last_seen"] = now

    if "temperature" in s:
        s["temperature"] = round(s["temperature"] + random.uniform(-0.3, 0.3), 1)
    if "humidity" in s:
        s["humidity"] = round(max(0, min(100, s["humidity"] + random.uniform(-1, 1))), 1)
    if "power" in s:
        s["power"] = round(max(0, s["power"] + random.uniform(-2, 2)), 1)
    if "linkquality" in s:
        s["linkquality"] = max(0, min(255, s["linkquality"] + random.randint(-5, 5)))
    if "battery" in s:
        s["battery"] = max(0, min(100, s["battery"] - random.randint(0, 1)))

    return s


def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message

    log.info("Connecting to %s:%d …", MQTT_HOST, MQTT_PORT)
    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
            break
        except Exception as exc:
            log.warning("Broker not ready (%s), retrying in 3s …", exc)
            time.sleep(3)

    client.loop_start()

    # Wait for Z2M to announce itself
    log.info("Waiting for Zigbee2MQTT …")
    deadline = time.time() + 120
    while not _z2m_online and time.time() < deadline:
        time.sleep(1)

    if not _z2m_online:
        log.error("Zigbee2MQTT did not come online within 120 s — seeding anyway")

    # Give Z2M a moment to finish publishing its own retained messages
    time.sleep(3)

    seed(client)

    if MODE == "once":
        client.loop_stop()
        return

    # Continuous mode: re-seed periodically + drift device states
    log.info("Continuous mode: drifting state every %ds", SEED_INTERVAL)
    while True:
        time.sleep(SEED_INTERVAL)
        log.debug("Drift tick")
        for device in ALL_DEVICES:
            name = device["friendly_name"]
            if device["type"] == "Coordinator":
                continue
            base = DEVICE_STATES.get(name, {})
            if base:
                drifted = drift_state(name, base)
                pub(client, f"{Z2M_TOPIC}/{name}", drifted)


if __name__ == "__main__":
    main()
