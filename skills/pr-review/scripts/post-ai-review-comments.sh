#!/bin/bash
# post-ai-review-comments.sh — Posts accept/decline replies to PR review comments
#
# Usage:
#   ./post-ai-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
#   ./post-ai-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> --repo <owner/repo> [--dry-run]
#
# DECISIONS_JSON:
# [
#   { "provider": "copilot", "comment_id": 12345, "verdict": "accept", "reason": "Applied in latest commit." },
#   { "provider": "coderabbit", "comment_id": 67890, "verdict": "decline", "reason": "Project convention conflict." }
# ]
#
# Requires: gh CLI authenticated with repo access + pull-requests:write

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  post-ai-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
  post-ai-review-comments.sh <PR_NUMBER> <DECISIONS_JSON> --repo <owner/repo> [--dry-run]
EOF
}

REPO="demodev-lab/moving-frontend"
DRY_RUN=false
POSITIONAL=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:?Missing value for --repo}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 2 ]; then
  usage >&2
  exit 1
fi

PR_NUMBER="${POSITIONAL[0]}"
DECISIONS_FILE="${POSITIONAL[1]}"
if [ "${#POSITIONAL[@]}" -ge 3 ]; then
  REPO="${POSITIONAL[2]}"
fi

if [ ! -f "$DECISIONS_FILE" ]; then
  echo "Error: Decisions file not found: ${DECISIONS_FILE}" >&2
  exit 1
fi

DECISION_COUNT="$(jq 'length' "$DECISIONS_FILE")"
if [ "$DECISION_COUNT" -eq 0 ]; then
  echo "No decisions to post." >&2
  exit 0
fi

echo "Processing ${DECISION_COUNT} AI review decision(s) for PR #${PR_NUMBER}..." >&2
if [ "$DRY_RUN" = true ]; then
  echo "Dry run enabled. No GitHub replies will be posted." >&2
fi

ACCEPTED=0
DECLINED=0
ERRORS=0

while read -r decision; do
  COMMENT_ID="$(echo "$decision" | jq -r '.comment_id')"
  VERDICT="$(echo "$decision" | jq -r '.verdict')"
  REASON="$(echo "$decision" | jq -r '.reason')"
  PROVIDER="$(echo "$decision" | jq -r '.provider // "unknown"')"

  if [ "$VERDICT" = "accept" ]; then
    BODY="## Accept
${REASON}"
    ACCEPTED=$((ACCEPTED + 1))
  else
    BODY="## Decline
${REASON}"
    DECLINED=$((DECLINED + 1))
  fi

  echo "  Replying to ${PROVIDER} comment ${COMMENT_ID}: ${VERDICT}..." >&2

  if [ "$DRY_RUN" = true ]; then
    echo "    DRY-RUN: would POST reply to /repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" >&2
    echo "    Body preview:" >&2
    printf '%s\n' "$BODY" >&2
  else
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
  fi

  sleep 1
done < <(jq -c '.[]' "$DECISIONS_FILE")

echo "" >&2
if [ "$DRY_RUN" = true ]; then
  echo "AI review comment reply preview complete." >&2
else
  echo "AI review comment replies complete." >&2
fi
echo "  Accepted: ${ACCEPTED}" >&2
echo "  Declined: ${DECLINED}" >&2
if [ "$ERRORS" -gt 0 ]; then
  echo "  Errors: ${ERRORS}" >&2
fi
