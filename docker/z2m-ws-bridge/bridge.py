"""
Minimal Zigbee2MQTT WebSocket bridge for integration testing.

Connects to Mosquitto, subscribes to zigbee2mqtt/#, and serves those
messages to WebSocket clients in the same JSON envelope format that
the real Z2M frontend uses: {"topic": "bridge/info", "payload": {...}}

Retained messages are sent immediately when a client connects.
Live messages are broadcast to all connected clients.
"""
import asyncio
import json
import os
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

import paho.mqtt.client as mqtt
import websockets
from websockets.server import WebSocketServerProtocol

HEALTH_PORT = int(os.environ.get("HEALTH_PORT", 8081))

BASE_TOPIC = os.environ.get("Z2M_TOPIC", "zigbee2mqtt")
MQTT_HOST = os.environ.get("MQTT_HOST", "mosquitto")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))
WS_PORT = int(os.environ.get("WS_PORT", 8080))
AUTH_TOKEN = os.environ.get("AUTH_TOKEN", "")

# Retained message store: topic (without base prefix) → payload bytes
retained: dict[str, bytes] = {}
retained_lock = threading.Lock()

# Connected WebSocket clients
clients: set[WebSocketServerProtocol] = set()
clients_lock = asyncio.Lock()

# asyncio event loop (set once the WS server starts)
loop: asyncio.AbstractEventLoop | None = None

# ── MQTT callbacks ────────────────────────────────────────────────────────

def _make_envelope(full_topic: str, payload_bytes: bytes) -> str | None:
    """Return a JSON string ready for the WebSocket, or None to skip."""
    if not full_topic.startswith(BASE_TOPIC + "/"):
        return None
    topic = full_topic[len(BASE_TOPIC) + 1:]
    try:
        payload = json.loads(payload_bytes) if payload_bytes else None
    except (json.JSONDecodeError, UnicodeDecodeError):
        payload = payload_bytes.decode("utf-8", errors="replace")
    return json.dumps({"topic": topic, "payload": payload}, ensure_ascii=False)


def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Connected (rc={rc}), subscribing to {BASE_TOPIC}/#")
    client.subscribe(f"{BASE_TOPIC}/#", qos=1)
    # Announce bridge as online so the seeder knows to start publishing
    client.publish(f"{BASE_TOPIC}/bridge/state", json.dumps({"state": "online"}), retain=True, qos=1)


def on_message(client, userdata, msg):
    topic = msg.topic[len(BASE_TOPIC) + 1:] if msg.topic.startswith(BASE_TOPIC + "/") else msg.topic
    print(f"[MQTT] msg: topic={topic!r} retain={msg.retain} len={len(msg.payload or b'')}", flush=True)

    envelope = _make_envelope(msg.topic, msg.payload)
    if envelope is None:
        return

    # Update cached state. We track last-seen value per topic regardless of
    # the MQTT retain flag, because the seeder publishes retained messages
    # after the bridge has already subscribed — at which point they arrive
    # with retain=False, and would otherwise be skipped.
    with retained_lock:
        if not msg.payload:
            retained.pop(topic, None)
        else:
            retained[topic] = msg.payload

    # Broadcast to all WebSocket clients
    if loop is not None and not loop.is_closed():
        asyncio.run_coroutine_threadsafe(_broadcast(envelope), loop)


async def _broadcast(envelope: str):
    async with clients_lock:
        dead = set()
        for ws in clients:
            try:
                await ws.send(envelope)
            except Exception:
                dead.add(ws)
        clients.difference_update(dead)


# ── WebSocket handler ─────────────────────────────────────────────────────

def _request_path(ws: WebSocketServerProtocol) -> str:
    path = getattr(ws, "path", None)
    if path:
        return path

    request = getattr(ws, "request", None)
    request_path = getattr(request, "path", None)
    if request_path:
        return request_path

    return ""

async def ws_handler(ws: WebSocketServerProtocol):
    if AUTH_TOKEN:
        query = parse_qs(urlparse(_request_path(ws)).query)
        token = query.get("token", [None])[0]
        if token != AUTH_TOKEN:
            await ws.close(code=1008, reason="Invalid token")
            return

    async with clients_lock:
        clients.add(ws)

    # Send all retained messages immediately
    with retained_lock:
        snapshot = dict(retained)

    for topic, payload_bytes in snapshot.items():
        envelope = _make_envelope(f"{BASE_TOPIC}/{topic}", payload_bytes)
        if envelope:
            try:
                await ws.send(envelope)
            except Exception:
                break

    # Keep connection open, handle incoming messages (commands to bridge)
    try:
        async for message in ws:
            # Forward client commands back to MQTT
            try:
                data = json.loads(message)
                t = data.get("topic", "")
                p = data.get("payload", {})
                mqtt_client.publish(
                    f"{BASE_TOPIC}/{t}",
                    json.dumps(p) if not isinstance(p, str) else p,
                    qos=1,
                )
            except Exception as e:
                print(f"[WS] Failed to handle message: {e}")
    except Exception:
        pass
    finally:
        async with clients_lock:
            clients.discard(ws)


# ── Health check HTTP server (separate port, stdlib only) ─────────────────

class _HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(HTTPStatus.OK)
        self.end_headers()
        self.wfile.write(b"OK\n")

    def log_message(self, *args):
        pass  # silence access logs


def _start_health_server():
    server = HTTPServer(("0.0.0.0", HEALTH_PORT), _HealthHandler)
    server.serve_forever()


# ── Main ──────────────────────────────────────────────────────────────────

async def main():
    global loop
    loop = asyncio.get_running_loop()

    health_thread = threading.Thread(target=_start_health_server, daemon=True)
    health_thread.start()
    print(f"[Health] HTTP health endpoint on http://0.0.0.0:{HEALTH_PORT}")

    async with websockets.serve(ws_handler, "0.0.0.0", WS_PORT):
        print(f"[WS] WebSocket bridge listening on ws://0.0.0.0:{WS_PORT}")
        await asyncio.Future()  # run forever


mqtt_client = mqtt.Client()
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message

print(f"[MQTT] Connecting to {MQTT_HOST}:{MQTT_PORT} …")
mqtt_client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
mqtt_client.loop_start()

asyncio.run(main())
