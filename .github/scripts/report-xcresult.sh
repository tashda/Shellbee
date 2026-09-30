#!/usr/bin/env bash
# Turn an .xcresult bundle into something a person notices:
#   - a job summary with totals, every failing test and its message,
#     and tests that only passed on retry (flaky)
#   - `::error` / `::warning` annotations, which show on the run page and
#     in the PR's checks tab
#   - an optional Markdown fragment ($FAILURES_OUT) that the notify job
#     folds into the "CI is failing" issue
#
# Usage: report-xcresult.sh <path.xcresult> <title>
#
# Never fails the step itself: the xcodebuild step already decides
# pass/fail. This only reports.

set -uo pipefail

XCRESULT="${1:?usage: report-xcresult.sh <path.xcresult> <title>}"
TITLE="${2:?usage: report-xcresult.sh <path.xcresult> <title>}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
FAILURES_OUT="${FAILURES_OUT:-}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Annotation text can't contain raw newlines or '%'.
escape() { local s="${1//'%'/%25}"; s="${s//$'\r'/%0D}"; s="${s//$'\n'/%0A}"; printf '%s' "$s"; }

# xcresult stores paths relative to the source root with a leading slash
# ("/ShellbeeUITests/Foo.swift") and sometimes without the subfolder, so
# resolve by filename against the checkout.
resolve_file() {
  local path="${1#/}"
  if [ -f "$REPO_ROOT/$path" ]; then echo "$path"; return; fi
  (cd "$REPO_ROOT" && git ls-files | grep -m1 "/$(basename "$path")$") || echo "$path"
}

emit_fragment() { [ -n "$FAILURES_OUT" ] && printf '%s\n' "$1" >> "$FAILURES_OUT"; }

if [ ! -d "$XCRESULT" ]; then
  {
    echo "## ❌ $TITLE"
    echo
    echo "No result bundle was produced. The build failed or xcodebuild hung before tests ran; see the step log."
  } >> "$SUMMARY_FILE"
  echo "::error title=$(escape "$TITLE")::No result bundle produced; tests did not run"
  emit_fragment "- **$TITLE**: no result bundle; tests did not run"
  exit 0
fi

SUMMARY_JSON=$(xcrun xcresulttool get test-results summary --path "$XCRESULT" --compact 2>&1) || {
  echo "## ⚠️ $TITLE" >> "$SUMMARY_FILE"
  echo "Could not read the result bundle: \`$SUMMARY_JSON\`" >> "$SUMMARY_FILE"
  echo "::warning title=$(escape "$TITLE")::Could not read result bundle"
  exit 0
}
TESTS_JSON=$(xcrun xcresulttool get test-results tests --path "$XCRESULT" --compact 2>/dev/null || echo '{}')

RESULT=$(jq -r '.result' <<<"$SUMMARY_JSON")
PASSED=$(jq -r '.passedTests' <<<"$SUMMARY_JSON")
FAILED=$(jq -r '.failedTests' <<<"$SUMMARY_JSON")
SKIPPED=$(jq -r '.skippedTests' <<<"$SUMMARY_JSON")
DEVICE=$(jq -r '[.devicesAndConfigurations[]?.device | "\(.deviceName) (iOS \(.osVersion))"] | unique | join(", ")' <<<"$SUMMARY_JSON")

# One line per failing test: identifier \t message \t file \t line
FAILURES=$(jq -r '
  [.. | objects | select(.nodeType == "Test Case" and .result == "Failed")]
  | .[]
  | . as $case
  | ([$case | .. | objects | select(.nodeType == "Failure Message")] | first) as $msg
  | [$case.nodeIdentifier,
     ($msg.name // "Failed without a message (crash or timeout?)"),
     ($msg.sourceLocation.filePath // ""),
     ($msg.sourceLocation.lineNumber // "" | tostring)]
  | @tsv' <<<"$TESTS_JSON")

# Tests that failed at least one repetition but passed overall.
FLAKY=$(jq -r '
  [.. | objects
     | select(.nodeType == "Test Case" and .result != "Failed")
     | select([.. | objects | select(.nodeType == "Repetition" and .result == "Failed")] | length > 0)]
  | .[].nodeIdentifier' <<<"$TESTS_JSON")

ICON="✅"; [ "$RESULT" != "Passed" ] && ICON="❌"
{
  echo "## $ICON $TITLE"
  echo
  echo "**$RESULT** · $PASSED passed · $FAILED failed · $SKIPPED skipped · $DEVICE"
  echo
  if [ -n "$FAILURES" ]; then
    echo "### Failing tests"
    echo
    echo "| Test | Failure | Where |"
    echo "| --- | --- | --- |"
  fi
} >> "$SUMMARY_FILE"

if [ -n "$FAILURES" ]; then
  emit_fragment "**$TITLE** ($DEVICE)"
  while IFS=$'\t' read -r ident msg file line; do
    where=""; annot_loc=""
    if [ -n "$file" ]; then
      rel=$(resolve_file "$file")
      where="\`$rel:$line\`"
      annot_loc="file=$rel,line=$line,"
    fi
    cell_msg=${msg//|/\\|}
    echo "| \`$ident\` | $cell_msg | $where |" >> "$SUMMARY_FILE"
    echo "::error ${annot_loc}title=$(escape "$ident")::$(escape "$msg")"
    emit_fragment "- \`$ident\`: $msg ${where}"
  done <<<"$FAILURES"
  emit_fragment ""
fi

if [ -n "$FLAKY" ]; then
  {
    echo
    echo "### ⚠️ Passed only on retry"
    echo
    echo "These failed once, then passed. They didn't fail the run, but a test that needs a retry is hiding either a race in the app or a weak wait in the test."
    echo
    while read -r ident; do echo "- \`$ident\`"; done <<<"$FLAKY"
  } >> "$SUMMARY_FILE"
  while read -r ident; do
    echo "::warning title=Flaky test::$(escape "$ident") failed once and passed on retry"
  done <<<"$FLAKY"
fi

exit 0
