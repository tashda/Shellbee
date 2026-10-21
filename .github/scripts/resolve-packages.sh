#!/usr/bin/env bash
# Resolve Swift packages, retrying when a download fails. Resolution fetches
# binary targets (the Sentry xcframework) from github.com, and a timeout there
# says nothing about the app: it must not turn a nightly red. A package that
# really can't be resolved fails every attempt and still fails the job.
#
# usage: resolve-packages.sh <xcodebuild args...>
set -uo pipefail

for attempt in 1 2 3 4; do
  if xcodebuild -resolvePackageDependencies "$@"; then
    exit 0
  fi
  if [[ "$attempt" == "4" ]]; then
    echo "::error::Swift packages could not be resolved after $attempt attempts."
    exit 1
  fi
  delay=$((attempt * 20))
  echo "::warning::Resolving Swift packages failed (attempt $attempt of 4); retrying in ${delay}s."
  sleep "$delay"
done
