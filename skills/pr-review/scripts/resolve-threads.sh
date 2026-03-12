#!/bin/bash
# resolve-threads.sh — Resolves accepted CodeRabbit review threads via GraphQL
#
# Usage: ./resolve-threads.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
#
# DECISIONS_JSON is a path to a JSON file with this structure:
# [
#   { "comment_id": 12345, "verdict": "accept", "reason": "Applied in latest commit." },
#   { "comment_id": 67890, "verdict": "decline", "reason": "Project convention conflict." }
# ]
#
# Only threads corresponding to "accept" verdicts are resolved.
# Uses GraphQL API (thread resolution has no REST endpoint).
#
# Requires: gh CLI authenticated with contents:write permission

set -euo pipefail

PR_NUMBER="${1:?Usage: resolve-threads.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]}"
DECISIONS_FILE="${2:?Usage: resolve-threads.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]}"
REPO="${3:-demodev-lab/moving-frontend}"

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

if [ ! -f "$DECISIONS_FILE" ]; then
  echo "Error: Decisions file not found: ${DECISIONS_FILE}" >&2
  exit 1
fi

# Count accepted decisions
ACCEPTED_IDS=$(jq -r '[.[] | select(.verdict == "accept") | .comment_id] | .[]' "$DECISIONS_FILE")
ACCEPTED_COUNT=$(echo "$ACCEPTED_IDS" | grep -c . || true)

if [ "$ACCEPTED_COUNT" -eq 0 ]; then
  echo "No accepted comments to resolve." >&2
  exit 0
fi

echo "Resolving threads for ${ACCEPTED_COUNT} accepted comment(s) on PR #${PR_NUMBER}..." >&2

# Step 1: Fetch all review threads with their comment IDs via GraphQL
# Uses cursor-based pagination to handle PRs with >100 threads
echo "  Fetching review threads..." >&2
ALL_THREADS="[]"
HAS_NEXT="true"
CURSOR=""

while [ "$HAS_NEXT" = "true" ]; do
  if [ -z "$CURSOR" ]; then
    CURSOR_ARG=""
    CURSOR_PARAM=""
  else
    CURSOR_ARG="-f cursor=$CURSOR"
    CURSOR_PARAM=', after: $cursor'
  fi

  PAGE_JSON=$(gh api graphql -f query="
    query(\$owner: String!, \$repo: String!, \$pr: Int!$([ -n "$CURSOR" ] && echo ', $cursor: String')) {
      repository(owner: \$owner, name: \$repo) {
        pullRequest(number: \$pr) {
          reviewThreads(first: 100${CURSOR_PARAM}) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              id
              isResolved
              comments(first: 1) {
                nodes {
                  databaseId
                  author {
                    login
                  }
                }
              }
            }
          }
        }
      }
    }
  " -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER" $CURSOR_ARG)

  # Extract nodes and merge into ALL_THREADS
  PAGE_NODES=$(echo "$PAGE_JSON" | jq '.data.repository.pullRequest.reviewThreads.nodes')
  ALL_THREADS=$(echo "$ALL_THREADS" "$PAGE_NODES" | jq -s '.[0] + .[1]')

  HAS_NEXT=$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

THREAD_COUNT=$(echo "$ALL_THREADS" | jq 'length')
echo "  Found ${THREAD_COUNT} review thread(s)" >&2

# Wrap in the same structure the rest of the script expects
THREADS_JSON=$(echo "$ALL_THREADS" | jq '{data: {repository: {pullRequest: {reviewThreads: {nodes: .}}}}}')

# Step 2: For each accepted comment_id, find the matching thread and resolve it
RESOLVED=0
SKIPPED=0
NOT_FOUND=0
ERRORS=0

for COMMENT_ID in $ACCEPTED_IDS; do
  # Find the thread whose first comment matches this comment_id
  # CodeRabbit inline comments are the first comment in their thread
  THREAD_ID=$(echo "$THREADS_JSON" | jq -r --argjson cid "$COMMENT_ID" '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.comments.nodes[0].databaseId == $cid)
    | .id
  ')

  if [ -z "$THREAD_ID" ] || [ "$THREAD_ID" = "null" ]; then
    echo "  WARNING: No thread found for comment ${COMMENT_ID}" >&2
    NOT_FOUND=$((NOT_FOUND + 1))
    continue
  fi

  # Check if already resolved
  IS_RESOLVED=$(echo "$THREADS_JSON" | jq -r --argjson cid "$COMMENT_ID" '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.comments.nodes[0].databaseId == $cid)
    | .isResolved
  ')

  if [ "$IS_RESOLVED" = "true" ]; then
    echo "  Thread for comment ${COMMENT_ID} already resolved, skipping." >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "  Resolving thread for comment ${COMMENT_ID} (${THREAD_ID})..." >&2

  if gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread {
          id
          isResolved
        }
      }
    }
  ' -f threadId="$THREAD_ID" > /dev/null 2>&1; then
    echo "    Done." >&2
    RESOLVED=$((RESOLVED + 1))
  else
    echo "    ERROR: Failed to resolve thread ${THREAD_ID}" >&2
    ERRORS=$((ERRORS + 1))
  fi

  # Rate limit protection
  sleep 0.5
done

echo "" >&2
echo "Thread resolution complete." >&2
echo "  Resolved: ${RESOLVED}" >&2
echo "  Already resolved: ${SKIPPED}" >&2
if [ "$NOT_FOUND" -gt 0 ]; then
  echo "  Not found: ${NOT_FOUND}" >&2
fi
if [ "$ERRORS" -gt 0 ]; then
  echo "  Errors: ${ERRORS}" >&2
fi
