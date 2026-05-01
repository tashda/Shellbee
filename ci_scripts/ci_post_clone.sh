#!/bin/sh
# Xcode Cloud runs this after cloning the repo, before xcodebuild.
# Generates Config/BuildSettings.local.xcconfig from environment variables
# defined in the Xcode Cloud workflow, since the real local xcconfig is
# gitignored and not available on Apple's runners.
#
# Required env vars (set in Xcode Cloud workflow → Environment Variables):
#   APP_BUNDLE_ID            e.g. com.tashda.shellbee
#   APP_DEVELOPMENT_TEAM     e.g. JQU2HR44D8 (mark as secret)
#   APP_WIDGET_BUNDLE_SUFFIX e.g. widgets
#
# Optional (omit unless you want Sentry symbol upload from CI):
#   SENTRY_DSN, SENTRY_ORG, SENTRY_PROJECT, SENTRY_AUTH_TOKEN

set -eu

if [ -z "${APP_BUNDLE_ID:-}" ] || [ -z "${APP_DEVELOPMENT_TEAM:-}" ] || [ -z "${APP_WIDGET_BUNDLE_SUFFIX:-}" ]; then
  echo "ci_post_clone.sh: required env vars not set (APP_BUNDLE_ID, APP_DEVELOPMENT_TEAM, APP_WIDGET_BUNDLE_SUFFIX)"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$REPO_ROOT/Config/BuildSettings.local.xcconfig"

{
  echo "APP_DEVELOPMENT_TEAM = $APP_DEVELOPMENT_TEAM"
  echo "APP_BUNDLE_ID = $APP_BUNDLE_ID"
  echo "APP_WIDGET_BUNDLE_SUFFIX = $APP_WIDGET_BUNDLE_SUFFIX"
  echo "APP_WIDGET_BUNDLE_ID = \$(APP_BUNDLE_ID).\$(APP_WIDGET_BUNDLE_SUFFIX)"
  echo "APP_TESTS_BUNDLE_ID = \$(APP_BUNDLE_ID).tests"
  echo "APP_UI_TESTS_BUNDLE_ID = \$(APP_BUNDLE_ID).uitests"
  [ -n "${SENTRY_DSN:-}" ]          && echo "SENTRY_DSN = $SENTRY_DSN"
  [ -n "${SENTRY_ORG:-}" ]          && echo "SENTRY_ORG = $SENTRY_ORG"
  [ -n "${SENTRY_PROJECT:-}" ]      && echo "SENTRY_PROJECT = $SENTRY_PROJECT"
  [ -n "${SENTRY_AUTH_TOKEN:-}" ]   && echo "SENTRY_AUTH_TOKEN = $SENTRY_AUTH_TOKEN"
} > "$TARGET"

echo "ci_post_clone.sh: wrote $TARGET"
