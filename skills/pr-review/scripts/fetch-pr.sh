#!/bin/bash
# fetch-pr.sh — Fetches PR data from GitHub and saves markdown + structured AI review sidecar
#
# Usage:
#   ./fetch-pr.sh <PR_NUMBER> [REPO] [REVIEW_SOURCE]
#   ./fetch-pr.sh <PR_NUMBER> --repo <owner/repo> --review-source <all|coderabbit|copilot|none>
#
# Output:
#   - docs/pr-for-review/[TICKET-ID] title.md
#   - docs/pr-for-review/[TICKET-ID] title.review-data.json
#   - Prints the markdown path on stdout (last line)
#
# Requires: gh CLI authenticated with repo access, jq

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  fetch-pr.sh <PR_NUMBER> [REPO] [REVIEW_SOURCE]
  fetch-pr.sh <PR_NUMBER> --repo <owner/repo> --review-source <all|coderabbit|copilot|none>

Examples:
  fetch-pr.sh 161
  fetch-pr.sh 161 demodev-lab/moving-frontend copilot
  fetch-pr.sh 161 --review-source all
EOF
}

REPO="demodev-lab/moving-frontend"
REVIEW_SOURCE="all"
OUTPUT_DIR="docs/pr-for-review"
POSITIONAL=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:?Missing value for --repo}"
      shift 2
      ;;
    --review-source)
      REVIEW_SOURCE="${2:?Missing value for --review-source}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?Missing value for --output-dir}"
      shift 2
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

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  usage >&2
  exit 1
fi

PR_NUMBER="${POSITIONAL[0]}"
if [ "${#POSITIONAL[@]}" -ge 2 ]; then
  REPO="${POSITIONAL[1]}"
fi
if [ "${#POSITIONAL[@]}" -ge 3 ]; then
  REVIEW_SOURCE="${POSITIONAL[2]}"
fi

REVIEW_SOURCE="$(echo "$REVIEW_SOURCE" | tr '[:upper:]' '[:lower:]')"
case "$REVIEW_SOURCE" in
  all|coderabbit|copilot|none) ;;
  *)
    echo "Error: review source must be one of all|coderabbit|copilot|none" >&2
    exit 1
    ;;
esac

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

echo "Fetching PR #${PR_NUMBER} from ${REPO}..." >&2

gh api "repos/${REPO}/pulls/${PR_NUMBER}" > "${TMPDIR}/pr.json"

PR_TITLE="$(jq -r '.title' "${TMPDIR}/pr.json")"
PR_BODY="$(jq -r '.body // ""' "${TMPDIR}/pr.json")"
PR_USER="$(jq -r '.user.login' "${TMPDIR}/pr.json")"
PR_BRANCH="$(jq -r '.head.ref' "${TMPDIR}/pr.json")"
PR_SHA="$(jq -r '.head.sha' "${TMPDIR}/pr.json")"

TICKET_ID="$(echo "$PR_TITLE" | grep -oE '\[?[A-Z]+-[0-9]+\]?' | head -1 | tr -d '[]' || true)"
if [ -z "$TICKET_ID" ]; then
  TICKET_ID="PR-${PR_NUMBER}"
  echo "Warning: Could not extract ticket ID from title. Using ${TICKET_ID}" >&2
fi

CLEAN_TITLE="$(echo "$PR_TITLE" | sed 's/^\[.*\] *//' | tr '/:' '-' | tr -s ' ')"
OUTPUT_FILE="${OUTPUT_DIR}/[${TICKET_ID}] ${CLEAN_TITLE}.md"
REVIEW_DATA_FILE="${OUTPUT_FILE%.md}.review-data.json"

echo "  Title: ${PR_TITLE}" >&2
echo "  Author: ${PR_USER}" >&2
echo "  Branch: ${PR_BRANCH}" >&2
echo "  Ticket: ${TICKET_ID}" >&2
echo "  Review source: ${REVIEW_SOURCE}" >&2

if [ "$REVIEW_SOURCE" = "none" ]; then
  printf '[]\n' > "${TMPDIR}/reviews.json"
  printf '[]\n' > "${TMPDIR}/comments.json"
  printf '[]\n' > "${TMPDIR}/issue-comments.json"
else
  gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews" --paginate | jq -s 'add // []' > "${TMPDIR}/reviews.json"
  gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate | jq -s 'add // []' > "${TMPDIR}/comments.json"
  gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate | jq -s 'add // []' > "${TMPDIR}/issue-comments.json"
fi

jq '
  [
    .[]
    | select(.user.login == "coderabbitai[bot]")
    | {
        comment_id: .id,
        created_at,
        updated_at,
        body: (.body // "")
      }
  ]
' "${TMPDIR}/issue-comments.json" > "${TMPDIR}/coderabbit-walkthrough.json"

jq '
  [
    .[]
    | select(.user.login == "coderabbitai[bot]" and ((.body // "") | length > 0))
    | {
        review_id: .id,
        author: .user.login,
        state,
        submitted_at,
        body: (.body // ""),
        commit_oid: (.commit_id // null)
      }
  ]
' "${TMPDIR}/reviews.json" > "${TMPDIR}/coderabbit-reviews.json"

jq '
  [
    .[]
    | select(.user.login == "coderabbitai[bot]" and .in_reply_to_id == null)
    | {
        provider: "coderabbit",
        review_id: .pull_request_review_id,
        comment_id: .id,
        author: .user.login,
        path,
        line,
        start_line,
        original_line,
        original_start_line,
        side,
        commit_id,
        body: (.body // ""),
        created_at,
        updated_at,
        in_reply_to_id
      }
  ]
' "${TMPDIR}/comments.json" > "${TMPDIR}/coderabbit-comments.json"

jq '
  [
    .[]
    | select((.user.login // "") | test("^copilot-pull-request-reviewer(\\[bot\\])?$"))
    | {
        review_id: .id,
        author: .user.login,
        state,
        submitted_at,
        body: (.body // ""),
        commit_oid: (.commit_id // null)
      }
  ]
' "${TMPDIR}/reviews.json" > "${TMPDIR}/copilot-reviews.json"

COPILOT_REVIEW_IDS="$(jq '[.[].review_id]' "${TMPDIR}/copilot-reviews.json")"
jq --argjson review_ids "$COPILOT_REVIEW_IDS" '
  [
    .[]
    | select(
        .in_reply_to_id == null
        and (
          ((.pull_request_review_id // -1) as $rid | ($review_ids | index($rid)) != null)
          or ((.user.login // "") | ascii_downcase) == "copilot"
        )
      )
    | {
        provider: "copilot",
        review_id: .pull_request_review_id,
        comment_id: .id,
        author: .user.login,
        path,
        line,
        start_line,
        original_line,
        original_start_line,
        side,
        commit_id,
        body: (.body // ""),
        created_at,
        updated_at,
        in_reply_to_id
      }
  ]
' "${TMPDIR}/comments.json" > "${TMPDIR}/copilot-comments.json"

jq -n \
  --arg repo "$REPO" \
  --arg review_source "$REVIEW_SOURCE" \
  --slurpfile pr "${TMPDIR}/pr.json" \
  --slurpfile coderabbit_walkthrough "${TMPDIR}/coderabbit-walkthrough.json" \
  --slurpfile coderabbit_reviews "${TMPDIR}/coderabbit-reviews.json" \
  --slurpfile coderabbit_comments "${TMPDIR}/coderabbit-comments.json" \
  --slurpfile copilot_reviews "${TMPDIR}/copilot-reviews.json" \
  --slurpfile copilot_comments "${TMPDIR}/copilot-comments.json" '
  {
    pr: {
      number: $pr[0].number,
      title: $pr[0].title,
      body: ($pr[0].body // ""),
      author: $pr[0].user.login,
      branch: $pr[0].head.ref,
      head_sha: $pr[0].head.sha,
      state: $pr[0].state,
      draft: $pr[0].draft,
      repo: $repo
    },
    review_source: $review_source,
    providers: {
      coderabbit: {
        walkthrough_comments: $coderabbit_walkthrough[0],
        reviews: $coderabbit_reviews[0],
        comments: $coderabbit_comments[0],
        latest_review_id: (
          if ($coderabbit_reviews[0] | length) == 0
          then null
          else ($coderabbit_reviews[0] | max_by(.submitted_at) | .review_id)
          end
        )
      },
      copilot: {
        reviews: $copilot_reviews[0],
        comments: $copilot_comments[0],
        latest_review_id: (
          if ($copilot_reviews[0] | length) == 0
          then null
          else ($copilot_reviews[0] | max_by(.submitted_at) | .review_id)
          end
        )
      }
    },
    normalized_comments: ($coderabbit_comments[0] + $copilot_comments[0])
  }
' > "$REVIEW_DATA_FILE"

CODE_RABBIT_WALKTHROUGH_COUNT="$(jq 'length' "${TMPDIR}/coderabbit-walkthrough.json")"
CODE_RABBIT_REVIEW_COUNT="$(jq 'length' "${TMPDIR}/coderabbit-reviews.json")"
CODE_RABBIT_INLINE_COUNT="$(jq 'length' "${TMPDIR}/coderabbit-comments.json")"
COPILOT_REVIEW_COUNT="$(jq 'length' "${TMPDIR}/copilot-reviews.json")"
COPILOT_INLINE_COUNT="$(jq 'length' "${TMPDIR}/copilot-comments.json")"

{
  echo ""
  echo "# ${PR_TITLE}"
  echo ""

  if [ -n "$PR_BODY" ]; then
    echo "$PR_BODY"
  fi

  if [ "$REVIEW_SOURCE" != "copilot" ] && { [ "$CODE_RABBIT_WALKTHROUGH_COUNT" -gt 0 ] || [ "$CODE_RABBIT_REVIEW_COUNT" -gt 0 ]; }; then
    WALKTHROUGH_BODY="$(jq -r 'if length == 0 then "" else .[0].body end' "${TMPDIR}/coderabbit-walkthrough.json")"
    if [ -n "$WALKTHROUGH_BODY" ] && ! printf '%s' "$PR_BODY" | grep -q "Summary by CodeRabbit"; then
      echo ""
      echo "---"
      echo ""
      echo "$WALKTHROUGH_BODY"
    fi

    jq -r '.[] | "---\n\n# Comment | by CodeRabbit bot | \(.submitted_at)\n\n\(.body)"' "${TMPDIR}/coderabbit-reviews.json"
  fi

  if [ "$REVIEW_SOURCE" != "coderabbit" ] && [ "$COPILOT_REVIEW_COUNT" -gt 0 ]; then
    echo ""
    echo "---"
    echo ""
    jq -r 'max_by(.submitted_at) | "## Summary by GitHub Copilot\n\n<!-- review_id: \(.review_id) -->\n\n\(.body)"' "${TMPDIR}/copilot-reviews.json"

    LATEST_COPILOT_REVIEW_ID="$(jq -r 'max_by(.submitted_at) | .review_id' "${TMPDIR}/copilot-reviews.json")"
    LATEST_COPILOT_SUBMITTED_AT="$(jq -r 'max_by(.submitted_at) | .submitted_at' "${TMPDIR}/copilot-reviews.json")"
    LATEST_COPILOT_COMMENT_COUNT="$(jq --argjson review_id "$LATEST_COPILOT_REVIEW_ID" '[.[] | select(.review_id == $review_id)] | length' "${TMPDIR}/copilot-comments.json")"

    if [ "$LATEST_COPILOT_COMMENT_COUNT" -gt 0 ]; then
      echo ""
      echo "---"
      echo ""
      echo "# Comment | by GitHub Copilot | ${LATEST_COPILOT_SUBMITTED_AT}"
      echo ""
      jq -r --argjson review_id "$LATEST_COPILOT_REVIEW_ID" '
        .[]
        | select(.review_id == $review_id)
        | "### `\(.path):\(.line // .start_line // 0)`\n\n\(.body)\n"
      ' "${TMPDIR}/copilot-comments.json"
    fi
  fi
} > "$OUTPUT_FILE"

echo "" >&2
echo "Saved markdown to: ${OUTPUT_FILE}" >&2
echo "Saved review data to: ${REVIEW_DATA_FILE}" >&2
echo "  PR Author: @${PR_USER}" >&2
echo "  Branch: ${PR_BRANCH}" >&2
echo "  Head SHA: ${PR_SHA}" >&2
echo "  CodeRabbit walkthrough comments: ${CODE_RABBIT_WALKTHROUGH_COUNT}" >&2
echo "  CodeRabbit reviews: ${CODE_RABBIT_REVIEW_COUNT}" >&2
echo "  CodeRabbit inline comments: ${CODE_RABBIT_INLINE_COUNT}" >&2
echo "  GitHub Copilot reviews: ${COPILOT_REVIEW_COUNT}" >&2
echo "  GitHub Copilot inline comments: ${COPILOT_INLINE_COUNT}" >&2

echo "${OUTPUT_FILE}"
