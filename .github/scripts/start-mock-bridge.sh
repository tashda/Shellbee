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
#
# Set MULTI_BRIDGE=1 (or pass --dual) to also start a second isolated stack
# on ports 1884/8082 with token `shellbee-integration-token-2` and
# FIXTURE_PREFIX=Lab so it's visibly distinct from the primary bridge.
# Used by MultiBridgeIntegrationTests to exercise BridgeRegistry against
# two real WebSocket peers.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${RUNNER_TEMP:-/tmp}"

DUAL=0
if [[ "${MULTI_BRIDGE:-0}" == "1" ]] || [[ "${1:-}" == "--dual" ]]; then
  DUAL=1
fi

echo "==> Installing mosquitto and Python deps"
brew install mosquitto

# Homebrew Python on macOS GitHub runners is PEP 668 externally-managed,
# so install Python deps into a dedicated venv and use that interpreter.
VENV="$LOG_DIR/z2m-venv"
python3 -m venv "$VENV"
PYTHON="$VENV/bin/python"
"$PYTHON" -m pip install --upgrade --quiet pip
"$PYTHON" -m pip install --quiet paho-mqtt websockets

write_mosq_conf() {
  local port="$1" path="$2"
  cat > "$path" <<EOF
listener $port
allow_anonymous true
persistence false
log_type error
log_type warning
log_type notice
EOF
}

wait_port() {
  local port="$1" timeout="${2:-30}"
  for i in $(seq 1 "$timeout"); do
    if nc -z localhost "$port"; then
      echo "port $port up after ${i}s"
      return 0
    fi
    sleep 1
  done
  return 1
}

# ── Primary bridge ──────────────────────────────────────────────────────────
echo "==> [primary] mosquitto config"
write_mosq_conf 1883 "$LOG_DIR/mosquitto-ci.conf"

echo "==> [primary] Starting mosquitto on 1883"
mosquitto -c "$LOG_DIR/mosquitto-ci.conf" -d
wait_port 1883 20 || { echo "mosquitto did not come up on 1883" >&2; exit 1; }

echo "==> [primary] Starting Z2M WebSocket bridge on 8080"
(
  cd "$REPO_ROOT/docker/z2m-ws-bridge"
  MQTT_HOST=localhost MQTT_PORT=1883 Z2M_TOPIC=zigbee2mqtt \
  WS_PORT=8080 HEALTH_PORT=8081 AUTH_TOKEN=shellbee-integration-token \
  nohup "$PYTHON" -u bridge.py >"$LOG_DIR/z2m-bridge.log" 2>&1 &
  echo $! > "$LOG_DIR/z2m-bridge.pid"
)

echo "==> [primary] Starting seeder"
(
  cd "$REPO_ROOT/docker/seeder"
  MQTT_HOST=localhost MQTT_PORT=1883 Z2M_TOPIC=zigbee2mqtt \
  MODE=continuous SEED_INTERVAL=10 \
  nohup "$PYTHON" -u seeder.py >"$LOG_DIR/z2m-seeder.log" 2>&1 &
  echo $! > "$LOG_DIR/z2m-seeder.pid"
)

echo "==> [primary] Waiting for WebSocket on 8080"
wait_port 8080 30 || {
  echo "primary mock Z2M did not come up on 8080" >&2
  echo "--- bridge log ---" >&2; cat "$LOG_DIR/z2m-bridge.log" >&2 || true
  echo "--- seeder log ---" >&2; cat "$LOG_DIR/z2m-seeder.log" >&2 || true
  exit 1
}

# ── Secondary bridge (optional) ─────────────────────────────────────────────
if [[ "$DUAL" == "1" ]]; then
  echo "==> [secondary] mosquitto config (port 1884)"
  write_mosq_conf 1884 "$LOG_DIR/mosquitto-ci-2.conf"

  echo "==> [secondary] Starting mosquitto on 1884"
  mosquitto -c "$LOG_DIR/mosquitto-ci-2.conf" -d
  wait_port 1884 20 || { echo "mosquitto did not come up on 1884" >&2; exit 1; }

  echo "==> [secondary] Starting Z2M WebSocket bridge on 8082"
  (
    cd "$REPO_ROOT/docker/z2m-ws-bridge"
    MQTT_HOST=localhost MQTT_PORT=1884 Z2M_TOPIC=zigbee2mqtt \
    WS_PORT=8082 HEALTH_PORT=8083 AUTH_TOKEN=shellbee-integration-token-2 \
    nohup "$PYTHON" -u bridge.py >"$LOG_DIR/z2m-bridge-2.log" 2>&1 &
    echo $! > "$LOG_DIR/z2m-bridge-2.pid"
  )

  echo "==> [secondary] Starting seeder (FIXTURE_PREFIX=Lab)"
  (
    cd "$REPO_ROOT/docker/seeder"
    MQTT_HOST=localhost MQTT_PORT=1884 Z2M_TOPIC=zigbee2mqtt \
    MODE=continuous SEED_INTERVAL=10 FIXTURE_PREFIX=Lab \
    nohup "$PYTHON" -u seeder.py >"$LOG_DIR/z2m-seeder-2.log" 2>&1 &
    echo $! > "$LOG_DIR/z2m-seeder-2.pid"
  )

  echo "==> [secondary] Waiting for WebSocket on 8082"
  wait_port 8082 30 || {
    echo "secondary mock Z2M did not come up on 8082" >&2
    echo "--- bridge log ---" >&2; cat "$LOG_DIR/z2m-bridge-2.log" >&2 || true
    echo "--- seeder log ---" >&2; cat "$LOG_DIR/z2m-seeder-2.log" >&2 || true
    exit 1
  }
fi

echo "==> Mock Z2M stack(s) ready."
