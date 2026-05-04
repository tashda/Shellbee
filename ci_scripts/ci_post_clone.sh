#!/bin/sh
# Xcode Cloud runs this after cloning the repo, before xcodebuild.
# Generates Config/BuildSettings.local.xcconfig from environment variables
# defined in the Xcode Cloud workflow, since the real local xcconfig is
# gitignored and not available on Apple's runners.
#
# Required env vars (set in Xcode Cloud workflow → Environment Variables):
#   SHELLBEE_BUNDLE_ID       e.g. com.tashda.shellbee
#   SHELLBEE_TEAM_ID         e.g. JQU2HR44D8 (plain text; do not mark secret)
#   SHELLBEE_WIDGET_SUFFIX   e.g. widgets
#
# These are intentionally renamed (vs. APP_BUNDLE_ID / APP_DEVELOPMENT_TEAM) to
# avoid Xcode Cloud rejecting names that collide with reserved Xcode build
# settings like DEVELOPMENT_TEAM.
#
# Optional (omit unless you want Sentry symbol upload from CI):
#   SENTRY_DSN, SENTRY_ORG, SENTRY_PROJECT, SENTRY_AUTH_TOKEN

set -eu

if [ -z "${SHELLBEE_BUNDLE_ID:-}" ] || [ -z "${SHELLBEE_TEAM_ID:-}" ] || [ -z "${SHELLBEE_WIDGET_SUFFIX:-}" ]; then
  echo "ci_post_clone.sh: required env vars not set (SHELLBEE_BUNDLE_ID, SHELLBEE_TEAM_ID, SHELLBEE_WIDGET_SUFFIX)"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$REPO_ROOT/Config/BuildSettings.local.xcconfig"

{
  echo "APP_DEVELOPMENT_TEAM = $SHELLBEE_TEAM_ID"
  echo "APP_IPHONEOS_CODE_SIGN_IDENTITY = Apple Distribution"
  echo "APP_BUNDLE_ID = $SHELLBEE_BUNDLE_ID"
  echo "APP_WIDGET_BUNDLE_SUFFIX = $SHELLBEE_WIDGET_SUFFIX"
  echo "APP_WIDGET_BUNDLE_ID = \$(APP_BUNDLE_ID).\$(APP_WIDGET_BUNDLE_SUFFIX)"
  echo "APP_TESTS_BUNDLE_ID = \$(APP_BUNDLE_ID).tests"
  echo "APP_UI_TESTS_BUNDLE_ID = \$(APP_BUNDLE_ID).uitests"
  [ -n "${SENTRY_DSN:-}" ]          && echo "SENTRY_DSN = $SENTRY_DSN"
  [ -n "${SENTRY_ORG:-}" ]          && echo "SENTRY_ORG = $SENTRY_ORG"
  [ -n "${SENTRY_PROJECT:-}" ]      && echo "SENTRY_PROJECT = $SENTRY_PROJECT"
  [ -n "${SENTRY_AUTH_TOKEN:-}" ]   && echo "SENTRY_AUTH_TOKEN = $SENTRY_AUTH_TOKEN"
} > "$TARGET"

echo "ci_post_clone.sh: wrote $TARGET"
