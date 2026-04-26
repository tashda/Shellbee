#!/usr/bin/env bash
# Start the mock Z2M stack natively on the macOS GitHub runner.
#
# We can't run docker-compose on macos-15 ARM runners — Docker isn't
# preinstalled and nested virtualization is unavailable, so colima/Lima
# can't boot a Linux VM. The stack is just mosquitto + two Python
# scripts, so we run them directly on the host instead. The simulator
# still reaches them on localhost:1883 / localhost:8080 the same way it
# would with docker port forwarding.
#
# Logs are tee'd into $RUNNER_TEMP so failure artifacts can scoop them up.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${RUNNER_TEMP:-/tmp}"

echo "==> Installing mosquitto and Python deps"
brew install mosquitto
python3 -m pip install --upgrade --quiet pip
python3 -m pip install --quiet paho-mqtt websockets

echo "==> Writing mosquitto config (anonymous, no persistence)"
MOSQ_CONF="$LOG_DIR/mosquitto-ci.conf"
cat > "$MOSQ_CONF" <<EOF
listener 1883
allow_anonymous true
persistence false
log_type error
log_type warning
log_type notice
EOF

echo "==> Starting mosquitto"
mosquitto -c "$MOSQ_CONF" -d
for i in $(seq 1 20); do
  if nc -z localhost 1883; then
    echo "mosquitto up after ${i}s"
    break
  fi
  sleep 1
done
if ! nc -z localhost 1883; then
  echo "mosquitto did not come up on 1883" >&2
  exit 1
fi

echo "==> Starting Z2M WebSocket bridge"
(
  cd "$REPO_ROOT/docker/z2m-ws-bridge"
  MQTT_HOST=localhost MQTT_PORT=1883 Z2M_TOPIC=zigbee2mqtt \
  WS_PORT=8080 HEALTH_PORT=8081 AUTH_TOKEN=shellbee-integration-token \
  nohup python3 -u bridge.py >"$LOG_DIR/z2m-bridge.log" 2>&1 &
  echo $! > "$LOG_DIR/z2m-bridge.pid"
)

echo "==> Starting seeder"
(
  cd "$REPO_ROOT/docker/seeder"
  MQTT_HOST=localhost MQTT_PORT=1883 Z2M_TOPIC=zigbee2mqtt \
  MODE=continuous SEED_INTERVAL=10 \
  nohup python3 -u seeder.py >"$LOG_DIR/z2m-seeder.log" 2>&1 &
  echo $! > "$LOG_DIR/z2m-seeder.pid"
)

echo "==> Waiting for WebSocket bridge on localhost:8080"
for i in $(seq 1 30); do
  if nc -z localhost 8080; then
    echo "Mock Z2M bridge is up after ${i}s"
    exit 0
  fi
  sleep 1
done

echo "Mock Z2M bridge did not come up on localhost:8080" >&2
echo "--- bridge log ---" >&2
cat "$LOG_DIR/z2m-bridge.log" >&2 || true
echo "--- seeder log ---" >&2
cat "$LOG_DIR/z2m-seeder.log" >&2 || true
exit 1
