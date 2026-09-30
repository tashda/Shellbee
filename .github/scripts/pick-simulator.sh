#!/usr/bin/env bash
# Pick an available iOS simulator whose name matches a regex, newest name
# last-sorted, and write device_id / device_name to $GITHUB_OUTPUT.
#
# Usage: pick-simulator.sh <name-regex> [fallback-regex]
# e.g.   pick-simulator.sh 'iPhone.*Pro Max' '^iPhone'
#
# Tests should run on a consistent, current-size screen. Sorting names
# alone picks "iPhone SE", the smallest screen, which hides rows below the
# fold and made list-counting tests fail for the wrong reason.

set -euo pipefail

REGEX="${1:?usage: pick-simulator.sh <name-regex> [fallback-regex]}"
FALLBACK="${2:-}"
JSON=$(xcrun simctl list devices available --json)

pick() {
  jq -r --arg regex "$1" \
    '[.devices | to_entries[]
      | select(.key | test("iOS"))
      | .value[]
      | select(.isAvailable and (.name | test($regex; "i")))]
     | sort_by(.name) | last | .udid // empty' <<<"$JSON"
}

DEVICE_ID=$(pick "$REGEX")
if [ -z "$DEVICE_ID" ] && [ -n "$FALLBACK" ]; then
  echo "::warning::No simulator matched '$REGEX'; falling back to '$FALLBACK'"
  DEVICE_ID=$(pick "$FALLBACK")
fi
if [ -z "$DEVICE_ID" ]; then
  echo "::error::No simulator matched '$REGEX'" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

NAME=$(jq -r --arg id "$DEVICE_ID" \
  '[.devices | to_entries[].value[] | select(.udid == $id)][0].name' <<<"$JSON")
echo "Using: $NAME ($DEVICE_ID)"
echo "device_id=$DEVICE_ID" >> "${GITHUB_OUTPUT:-/dev/stdout}"
echo "device_name=$NAME" >> "${GITHUB_OUTPUT:-/dev/stdout}"
