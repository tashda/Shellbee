#!/bin/sh
# Uploads dSYMs to Sentry so crash reports are symbolicated.
# Runs as an Xcode Run Script build phase on the Shellbee target.
#
# Inputs (build settings / env from xcconfig):
#   SENTRY_AUTH_TOKEN  — personal auth token with "project:write" scope
#   SENTRY_ORG         — Sentry organisation slug
#   SENTRY_PROJECT     — Sentry project slug
#
# This script is non-fatal: if any prerequisite is missing it prints a
# warning and exits 0, so developer / OSS builds never break on it.

set -u

# Skip non-Release builds. dSYMs from Debug builds are noisy and not useful.
if [ "${CONFIGURATION:-}" = "Debug" ]; then
  echo "note: skipping Sentry dSYM upload (Debug build)"
  exit 0
fi

if [ -z "${SENTRY_AUTH_TOKEN:-}" ] || [ -z "${SENTRY_ORG:-}" ] || [ -z "${SENTRY_PROJECT:-}" ]; then
  echo "warning: Sentry dSYM upload skipped — set SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT in Config/BuildSettings.local.xcconfig to enable."
  exit 0
fi

# Locate sentry-cli. Preference: user-installed on PATH > homebrew > sentry-cocoa SPM bundle.
SENTRY_CLI=""
if command -v sentry-cli >/dev/null 2>&1; then
  SENTRY_CLI="$(command -v sentry-cli)"
elif [ -x "/opt/homebrew/bin/sentry-cli" ]; then
  SENTRY_CLI="/opt/homebrew/bin/sentry-cli"
elif [ -x "/usr/local/bin/sentry-cli" ]; then
  SENTRY_CLI="/usr/local/bin/sentry-cli"
else
  # sentry-cocoa (SPM) ships a sentry-cli binary — path varies by Xcode version.
  SPM_ROOT="${BUILD_DIR%/Build/*}/SourcePackages"
  for candidate in \
    "$SPM_ROOT/artifacts/sentry-cocoa/Sentry/sentry-cli" \
    "$SPM_ROOT/artifacts/sentry-cocoa/sentry-cli/sentry-cli" \
    "$SPM_ROOT/checkouts/sentry-cocoa/Sources/Sentry/sentry-cli"; do
    if [ -x "$candidate" ]; then
      SENTRY_CLI="$candidate"
      break
    fi
  done
fi

if [ -z "$SENTRY_CLI" ]; then
  echo "warning: sentry-cli not found. Install with 'brew install getsentry/tools/sentry-cli' to enable dSYM upload."
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ] || [ ! -d "$DWARF_DSYM_FOLDER_PATH" ]; then
  echo "warning: no dSYM folder at '${DWARF_DSYM_FOLDER_PATH:-<unset>}' — skipping upload"
  exit 0
fi

echo "Uploading dSYMs to Sentry ($SENTRY_ORG/$SENTRY_PROJECT) using $SENTRY_CLI"

"$SENTRY_CLI" debug-files upload \
  --org "$SENTRY_ORG" \
  --project "$SENTRY_PROJECT" \
  --auth-token "$SENTRY_AUTH_TOKEN" \
  --include-sources \
  "$DWARF_DSYM_FOLDER_PATH" \
  || echo "warning: sentry-cli dSYM upload failed (non-fatal)"
