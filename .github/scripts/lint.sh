#!/usr/bin/env bash
# Mechanical enforcement of the rules in CLAUDE.md that have an obvious
# regex form. Cheap, fast, runs in seconds. Fails the build if anything
# matches.
#
# What's checked:
#   1. SwiftUI Stepper(  — never used; we have InlineIntField/Slider/TextField.
#   2. Trailing ellipsis  — `…` or three literal dots before a closing quote
#      in user-facing string literals. Catches "Loading…" / "Loading...".
#
# Scope: Shellbee/ (app sources) only. Tests, docker scripts, docs, and
# the windfront reference project are excluded.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FAIL=0

# Filter that drops grep -Rn output lines whose source content is a comment.
# Format: <path>:<lineno>:<source>. Match comment-only lines (//, ///, /*) at
# the start of <source> after optional whitespace.
not_a_comment() {
  grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|/\*)'
}

# 1. Stepper
echo "==> Checking for SwiftUI Stepper(…)"
STEPPER_HITS=$(grep -RnE '\bStepper[[:space:]]*\(' Shellbee/ --include='*.swift' \
  | not_a_comment || true)
if [[ -n "$STEPPER_HITS" ]]; then
  echo "::error::Forbidden SwiftUI Stepper found. Use Slider, InlineIntField, or TextField (numberPad). See CLAUDE.md."
  echo "$STEPPER_HITS"
  FAIL=1
fi

# 2. Trailing ellipsis in string literals — both forms.
# Heuristic: `..."` or `…"` inside a Swift file, in non-comment lines, is
# almost always user-facing copy. Annotate `// lint-allow-ellipsis` to opt out.
echo "==> Checking for trailing ellipsis in UI strings"
ELLIPSIS_HITS=$(grep -RnE '\.{3}"|…"' Shellbee/ --include='*.swift' \
  | not_a_comment \
  | grep -v 'lint-allow-ellipsis' || true)
if [[ -n "$ELLIPSIS_HITS" ]]; then
  echo "::error::Trailing ellipsis (… or ...) found in UI strings. CLAUDE.md forbids this. Annotate '// lint-allow-ellipsis' on the line if a literal ellipsis is genuinely required (e.g. a regex)."
  echo "$ELLIPSIS_HITS"
  FAIL=1
fi

if [[ "$FAIL" == "0" ]]; then
  echo "==> Lint passed."
fi
exit "$FAIL"
