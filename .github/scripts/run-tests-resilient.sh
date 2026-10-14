#!/usr/bin/env bash
# Run `xcodebuild test-without-building`, and run it once more only when the
# test runner itself never got going: the runner process was killed before it
# connected, so no test executed and nothing about the app was learned. A
# real test failure never matches these signatures and is never retried
# here (per-test retries are -retry-tests-on-failure's job).
#
# usage: run-tests-resilient.sh <result-bundle.xcresult> <log-file> <xcodebuild args...>
set -uo pipefail

BUNDLE="$1"; LOG="$2"; shift 2

INFRA='Early unexpected exit, operation never finished bootstrapping|Test crashed with signal kill before establishing connection|The test runner failed to initialize for UI testing|Failed to establish communication with the test runner|Lost connection to the testmanagerd|Unable to boot the Simulator'

for attempt in 1 2; do
  rm -rf "$BUNDLE"
  xcodebuild test-without-building -resultBundlePath "$BUNDLE" "$@" 2>&1 | tee "$LOG"
  status=${PIPESTATUS[0]}
  [[ "$status" == "0" ]] && exit 0
  if [[ "$attempt" == "1" ]] && grep -qE "$INFRA" "$LOG"; then
    echo "::warning::The test runner died before running any test (infrastructure, not the app). Running the suite once more."
    cp "$LOG" "$LOG.attempt1"
    xcrun simctl shutdown all >/dev/null 2>&1 || true
    sleep 5
    continue
  fi
  exit "$status"
done
