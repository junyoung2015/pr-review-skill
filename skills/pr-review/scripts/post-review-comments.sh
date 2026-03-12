#!/bin/bash
# post-review-comments.sh — Posts accept/decline replies to CodeRabbit review comments
#
# Usage: ./post-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
#
# DECISIONS_JSON is a path to a JSON file with this structure:
# [
#   { "comment_id": 12345, "verdict": "accept", "reason": "Applied in latest commit." },
#   { "comment_id": 67890, "verdict": "decline", "reason": "Project convention conflict." }
# ]
#
# After posting replies, optionally resolves accepted threads via GraphQL.
#
# Requires: gh CLI authenticated with repo access + pull-requests:write

set -euo pipefail

PR_NUMBER="${1:?Usage: post-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]}"
DECISIONS_FILE="${2:?Usage: post-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]}"
REPO="${3:-demodev-lab/moving-frontend}"

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

if [ ! -f "$DECISIONS_FILE" ]; then
  echo "Error: Decisions file not found: ${DECISIONS_FILE}" >&2
  exit 1
fi

DECISION_COUNT=$(jq 'length' "$DECISIONS_FILE")
echo "Processing ${DECISION_COUNT} comment decisions for PR #${PR_NUMBER}..." >&2

ACCEPTED=0
DECLINED=0
ERRORS=0

# Use process substitution instead of pipe to avoid subshell counter loss
while read -r decision; do
  COMMENT_ID=$(echo "$decision" | jq -r '.comment_id')
  VERDICT=$(echo "$decision" | jq -r '.verdict')
  REASON=$(echo "$decision" | jq -r '.reason')

  # Format the reply body
  if [ "$VERDICT" = "accept" ]; then
    BODY="## Accept
${REASON}"
    ACCEPTED=$((ACCEPTED + 1))
  else
    BODY="## Decline
${REASON}"
    DECLINED=$((DECLINED + 1))
  fi

  echo "  Replying to comment ${COMMENT_ID}: ${VERDICT}..." >&2

  # Post the reply
  if gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
    -f body="$BODY" > /dev/null 2>&1; then
    echo "    Done." >&2
  else
    echo "    ERROR: Failed to reply to comment ${COMMENT_ID}" >&2
    ERRORS=$((ERRORS + 1))
  fi

  # Rate limit protection
  sleep 1
done < <(jq -c '.[]' "$DECISIONS_FILE")

echo "" >&2
echo "Comment replies complete." >&2
echo "  Accepted: ${ACCEPTED}" >&2
echo "  Declined: ${DECLINED}" >&2
if [ "$ERRORS" -gt 0 ]; then
  echo "  Errors: ${ERRORS}" >&2
fi
