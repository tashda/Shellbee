#!/usr/bin/env bash
# Fail when an app type has a compiler-synthesized isolated deinit.
#
# The app target defaults to @MainActor, which gives every class an
# isolated deinit. Before iOS 26.4, the Swift runtime aborts ("pointer being
# freed was not allocated") when one isolated deinit releases another
# object with one. The app supports iOS 17.5+, so every such class needs
# `nonisolated deinit {}`. This check reads the built binary, so it catches
# classes nobody remembered to annotate.
#
# Usage: check-isolated-deinits.sh <DerivedData path>

set -euo pipefail

DERIVED_DATA="${1:?usage: check-isolated-deinits.sh <DerivedData path>}"
APP=$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name Shellbee.app -type d | head -n1)
[ -n "$APP" ] || { echo "::error::Shellbee.app not found under $DERIVED_DATA" >&2; exit 1; }

BINARY="$APP/Shellbee.debug.dylib"
[ -f "$BINARY" ] || BINARY="$APP/Shellbee"

# ResourceBundleClass is Xcode's generated resource-bundle marker; it is
# never instantiated, so it's never deallocated.
OFFENDERS=$(nm "$BINARY" | awk '{print $NF}' | xcrun swift-demangle \
  | grep "__isolated_deallocating_deinit" | grep -v '^[[:space:]]' \
  | sed -E 's/\.__isolated_deallocating_deinit.*//; s/^.*Shellbee\.//' \
  | grep -v "ResourceBundleClass" | sort -u || true)

if [ -n "$OFFENDERS" ]; then
  echo "These types have an isolated deinit, which crashes on iOS before 26.4 when deinits nest:"
  echo "$OFFENDERS" | sed 's/^/  /'
  while read -r type; do
    echo "::error title=Isolated deinit::$type needs 'nonisolated deinit {}' (the app defaults to @MainActor)"
  done <<<"$OFFENDERS"
  exit 1
fi
echo "No isolated deinits in the app target."
