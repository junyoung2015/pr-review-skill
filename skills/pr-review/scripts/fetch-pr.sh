#!/bin/bash
# fetch-pr.sh — Fetches PR data from GitHub and saves it locally for pr-review skill
#
# Usage: ./fetch-pr.sh <PR_NUMBER> [REPO]
# Output: Saves PR doc to docs/pr-for-review/[TICKET-ID] title.md
#         Prints the saved file path to stdout (last line)
#
# Requires: gh CLI authenticated with repo access

set -euo pipefail

PR_NUMBER="${1:?Usage: fetch-pr.sh <PR_NUMBER> [REPO]}"
REPO="${2:-demodev-lab/moving-frontend}"
OUTPUT_DIR="docs/pr-for-review"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "Fetching PR #${PR_NUMBER} from ${REPO}..." >&2

# 1. Fetch PR metadata
PR_JSON=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" \
  --jq '{
    title: .title,
    body: .body,
    head_sha: .head.sha,
    head_ref: .head.ref,
    user: .user.login,
    state: .state,
    draft: .draft,
    number: .number
  }')

PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body')
PR_USER=$(echo "$PR_JSON" | jq -r '.user')
PR_BRANCH=$(echo "$PR_JSON" | jq -r '.head_ref')
PR_SHA=$(echo "$PR_JSON" | jq -r '.head_sha')

# Extract ticket ID from title (e.g., [ACME-598] -> ACME-598)
TICKET_ID=$(echo "$PR_TITLE" | grep -oE '\[?[A-Z]+-[0-9]+\]?' | head -1 | tr -d '[]')
if [ -z "$TICKET_ID" ]; then
  TICKET_ID="PR-${PR_NUMBER}"
  echo "Warning: Could not extract ticket ID from title. Using ${TICKET_ID}" >&2
fi

# Clean title for filename (remove ticket prefix brackets, trim)
CLEAN_TITLE=$(echo "$PR_TITLE" | sed 's/^\[.*\] *//')

echo "  Title: ${PR_TITLE}" >&2
echo "  Author: ${PR_USER}" >&2
echo "  Branch: ${PR_BRANCH}" >&2
echo "  Ticket: ${TICKET_ID}" >&2

# 2. Fetch CodeRabbit walkthrough comment (issue comment)
# Note: --paginate applies --jq per page, so use per-element filter and post-process
echo "Fetching CodeRabbit walkthrough comment..." >&2
CR_WALKTHROUGH=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body' | head -1)

# 3. Fetch CodeRabbit review(s) — only main reviews with "Actionable comments posted"
# Use per-element jq filter + jq -s to avoid per-page array aggregation bug
echo "Fetching CodeRabbit reviews..." >&2
CR_REVIEWS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews" --paginate \
  --jq '.[] | select(.user.login == "coderabbitai[bot]" and (.body | length > 0) and (.body | contains("Actionable comments posted")))' \
  | jq -s '.')

CR_REVIEW_COUNT=$(echo "$CR_REVIEWS" | jq 'length')
echo "  Found ${CR_REVIEW_COUNT} CodeRabbit review(s)" >&2

# 4. Fetch CodeRabbit inline review comments (for reference)
# Use per-element jq filter to avoid per-page aggregation bug with --paginate
echo "Fetching CodeRabbit inline comments..." >&2
CR_INLINE_COUNT=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.user.login == "coderabbitai[bot]" and .in_reply_to_id == null)' \
  | jq -s 'length')
echo "  Found ${CR_INLINE_COUNT} CodeRabbit inline comment(s)" >&2

# 5. Compose the output document
OUTPUT_FILE="${OUTPUT_DIR}/[${TICKET_ID}] ${CLEAN_TITLE}.md"

{
  # PR body (contains the template-based content)
  echo ""
  echo "# ${PR_TITLE}"
  echo ""

  # If PR body has content, include it (skip the title line if it duplicates)
  if [ -n "$PR_BODY" ]; then
    echo "$PR_BODY"
  fi

  # Separator before CodeRabbit content
  if [ -n "$CR_WALKTHROUGH" ] && [ "$CR_WALKTHROUGH" != '""' ] && [ "$CR_WALKTHROUGH" != "" ]; then
    # The walkthrough comment typically already contains the "Summary by CodeRabbit" marker
    # Check if the PR body already includes it (some templates embed it)
    if ! echo "$PR_BODY" | grep -q "Summary by CodeRabbit"; then
      echo ""
      echo "---"
      echo ""
      echo "$CR_WALKTHROUGH"
    fi
  fi

  # CodeRabbit review comments (actionable + nitpick)
  if [ "$CR_REVIEW_COUNT" -gt 0 ]; then
    echo "$CR_REVIEWS" | jq -r '.[] | "---\n\n# Comment | by CodeRabbit bot | \(.submitted_at)\n\n\(.body)"'
  fi

} > "$OUTPUT_FILE"

echo "" >&2
echo "Saved to: ${OUTPUT_FILE}" >&2
echo "  PR Author: @${PR_USER}" >&2
echo "  Branch: ${PR_BRANCH}" >&2
echo "  Head SHA: ${PR_SHA}" >&2
echo "  CodeRabbit reviews: ${CR_REVIEW_COUNT}" >&2
echo "  CodeRabbit inline comments: ${CR_INLINE_COUNT}" >&2

# Output the file path (for consumption by other scripts/Claude)
echo "${OUTPUT_FILE}"
