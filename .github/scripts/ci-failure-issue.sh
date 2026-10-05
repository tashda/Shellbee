#!/usr/bin/env bash
# Keep one open issue per workflow while it's red on main, so a failure
# lands in the inbox instead of waiting to be found on the Actions tab.
#
#   failing: open "<workflow> is failing on main" (or comment on the open
#            one) with the failing tests, assigned to the repo owner
#   passing: comment and close the open issue, if any
#
# Usage: ci-failure-issue.sh <failure|success> [failures.md]
# Needs GH_TOKEN with issues:write, GITHUB_REPOSITORY, GITHUB_WORKFLOW,
# GITHUB_SERVER_URL, GITHUB_RUN_ID, GITHUB_SHA.

set -euo pipefail

OUTCOME="${1:?usage: ci-failure-issue.sh <failure|success> [failures.md]}"
DETAILS_FILE="${2:-}"
LABEL="ci-failure"
TITLE="$GITHUB_WORKFLOW is failing on main"
RUN_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
SHORT_SHA="${GITHUB_SHA:0:7}"

gh label create "$LABEL" --color B60205 \
  --description "A CI workflow is red on main" 2>/dev/null || true

EXISTING=$(gh issue list --state open --label "$LABEL" --json number,title \
  --jq ".[] | select(.title == \"$TITLE\") | .number" | head -n1)

if [ "$OUTCOME" = "success" ]; then
  if [ -n "$EXISTING" ]; then
    gh issue comment "$EXISTING" --body "Green again on \`$SHORT_SHA\`: $RUN_URL"
    gh issue close "$EXISTING" --reason completed
  fi
  exit 0
fi

DETAILS="The run failed before any test results were recorded (build failure, hang or runner problem). Open the run for the step log."
if [ -n "$DETAILS_FILE" ] && [ -s "$DETAILS_FILE" ]; then
  DETAILS=$(cat "$DETAILS_FILE")
fi

BODY=$(cat <<EOF
**Run:** $RUN_URL
**Commit:** \`$SHORT_SHA\`

$DETAILS

Each failing test is a real failure until shown otherwise: tests that
passed on a retry are reported as warnings on the run, not here. Result
bundles and screenshots are attached to the run as artifacts.
EOF
)

if [ -n "$EXISTING" ]; then
  gh issue comment "$EXISTING" --body "Still failing.

$BODY"
else
  gh issue create --title "$TITLE" --label "$LABEL" --label bug \
    --assignee "$GITHUB_REPOSITORY_OWNER" --body "$BODY"
fi
