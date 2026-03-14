#!/bin/bash
# fetch-pr.sh — Fetches PR data from GitHub and saves markdown + structured AI review sidecar.
#
# Usage:
#   ./fetch-pr.sh <PR_NUMBER> [REPO] [REVIEW_SOURCE]
#   ./fetch-pr.sh <PR_NUMBER> --repo <owner/repo> --review-source <all|coderabbit|copilot|none>
#     [--output-dir <dir>] [--repo-path <abs-path>]
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
    [--output-dir <dir>] [--repo-path <abs-path>]

Examples:
  fetch-pr.sh 161
  fetch-pr.sh 161 demodev-lab/moving-frontend copilot
  fetch-pr.sh 161 --review-source all --repo-path /Users/eddie/Desktop/demodev/moving-frontend
EOF
}

normalize_path() {
  local raw_path="$1"
  if [ -z "$raw_path" ]; then
    return 0
  fi

  if [ "${raw_path#/}" = "$raw_path" ]; then
    raw_path="$(pwd -P)/$raw_path"
  fi

  if [ -d "$raw_path" ]; then
    (
      cd "$raw_path"
      pwd -P
    )
    return 0
  fi

  local parent_dir
  parent_dir="$(dirname "$raw_path")"
  local suffix
  suffix="$(basename "$raw_path")"
  while [ ! -d "$parent_dir" ] && [ "$parent_dir" != "/" ]; do
    suffix="$(basename "$parent_dir")/${suffix}"
    parent_dir="$(dirname "$parent_dir")"
  done
  (
    cd "$parent_dir"
    printf '%s/%s\n' "$(pwd -P)" "$suffix"
  )
}

first_ticket_match() {
  local value="$1"
  printf '%s\n' "$value" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1 || true
}

ticket_match_count() {
  local value="$1"
  local matches
  matches="$(printf '%s\n' "$value" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' || true)"
  printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' '
}

REPO="demodev-lab/moving-frontend"
REVIEW_SOURCE="all"
OUTPUT_DIR="docs/pr-for-review"
TARGET_REPO_PATH=""
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
    --repo-path)
      TARGET_REPO_PATH="${2:?Missing value for --repo-path}"
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

REVIEW_SOURCE="$(printf '%s' "$REVIEW_SOURCE" | tr '[:upper:]' '[:lower:]')"
case "$REVIEW_SOURCE" in
  all|coderabbit|copilot|none) ;;
  *)
    echo "Error: review source must be one of all|coderabbit|copilot|none" >&2
    exit 1
    ;;
esac

if [ -n "$TARGET_REPO_PATH" ]; then
  TARGET_REPO_PATH="$(normalize_path "$TARGET_REPO_PATH")"
fi

RUN_CWD="$(pwd -P)"
FETCHED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

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

BRANCH_TICKET_COUNT="$(ticket_match_count "$PR_BRANCH")"
BRANCH_TICKET_ID=""
if [ "$BRANCH_TICKET_COUNT" -eq 1 ]; then
  BRANCH_TICKET_ID="$(first_ticket_match "$PR_BRANCH")"
elif [ "$BRANCH_TICKET_COUNT" -gt 1 ]; then
  echo "Warning: Multiple ticket IDs found in branch '${PR_BRANCH}'. Falling back to title-derived ticket metadata if available." >&2
fi

TITLE_TICKET_ID="$(first_ticket_match "$PR_TITLE")"

if [ -n "$BRANCH_TICKET_ID" ]; then
  TICKET_ID="$BRANCH_TICKET_ID"
elif [ -n "$TITLE_TICKET_ID" ]; then
  TICKET_ID="$TITLE_TICKET_ID"
else
  TICKET_ID="PR-${PR_NUMBER}"
  echo "Warning: Could not extract ticket ID from branch or title. Using ${TICKET_ID}" >&2
fi

CLEAN_TITLE="$(printf '%s' "$PR_TITLE" | sed 's/^\[.*\] *//' | tr '/:' '-' | tr -s ' ')"
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
  --arg repo_path "${TARGET_REPO_PATH:-}" \
  --arg fetched_at "$FETCHED_AT" \
  --arg run_cwd "$RUN_CWD" \
  --arg ticket_id "$TICKET_ID" \
  --arg output_file "$OUTPUT_FILE" \
  --arg review_data_file "$REVIEW_DATA_FILE" \
  --slurpfile pr "${TMPDIR}/pr.json" \
  --slurpfile coderabbit_walkthrough "${TMPDIR}/coderabbit-walkthrough.json" \
  --slurpfile coderabbit_reviews "${TMPDIR}/coderabbit-reviews.json" \
  --slurpfile coderabbit_comments "${TMPDIR}/coderabbit-comments.json" \
  --slurpfile copilot_reviews "${TMPDIR}/copilot-reviews.json" \
  --slurpfile copilot_comments "${TMPDIR}/copilot-comments.json" '
  def latest_review_id($reviews; $comments):
    if ($reviews | length) > 0 then
      ($reviews | max_by(.submitted_at // "") | .review_id)
    elif ($comments | length) > 0 then
      ($comments | map(.review_id) | map(select(. != null)) | max)
    else
      null
    end;

  def latest_review_submitted_at($reviews; $comments; $latest_id):
    if $latest_id == null then
      null
    elif ($reviews | length) > 0 then
      ($reviews | map(select(.review_id == $latest_id)) | last | .submitted_at)
    else
      ($comments | map(select(.review_id == $latest_id)) | max_by(.updated_at // .created_at // "") | (.updated_at // .created_at))
    end;

  def latest_comments($comments; $latest_id):
    if $latest_id == null then
      []
    else
      ($comments | map(select(.review_id == $latest_id)) | sort_by(.path // "", (.line // .start_line // 0), .comment_id))
    end;

  def selected_latest_comments($review_source; $coderabbit_latest; $copilot_latest):
    if $review_source == "coderabbit" then
      $coderabbit_latest
    elif $review_source == "copilot" then
      $copilot_latest
    elif $review_source == "none" then
      []
    else
      ($coderabbit_latest + $copilot_latest | sort_by(.provider, .path // "", (.line // .start_line // 0), .comment_id))
    end;

  ($coderabbit_reviews[0]) as $coderabbit_reviews_data
  | ($coderabbit_comments[0]) as $coderabbit_comments_data
  | ($copilot_reviews[0]) as $copilot_reviews_data
  | ($copilot_comments[0]) as $copilot_comments_data
  | (latest_review_id($coderabbit_reviews_data; $coderabbit_comments_data)) as $coderabbit_latest_review_id
  | (latest_review_id($copilot_reviews_data; $copilot_comments_data)) as $copilot_latest_review_id
  | (latest_comments($coderabbit_comments_data; $coderabbit_latest_review_id)) as $coderabbit_latest_comments
  | (latest_comments($copilot_comments_data; $copilot_latest_review_id)) as $copilot_latest_comments
  | {
      automation: {
        artifact_version: "0.2.2",
        fetched_at: $fetched_at,
        run_cwd: $run_cwd,
        target_repo_path: (if $repo_path == "" then null else $repo_path end),
        output_markdown_path: $output_file,
        output_review_data_path: $review_data_file
      },
      pr: {
        number: $pr[0].number,
        title: $pr[0].title,
        body: ($pr[0].body // ""),
        author: $pr[0].user.login,
        branch: $pr[0].head.ref,
        branch_basename: ($pr[0].head.ref | split("/") | last),
        head_sha: $pr[0].head.sha,
        state: $pr[0].state,
        draft: $pr[0].draft,
        repo: $repo,
        base_repo: $pr[0].base.repo.full_name,
        base_branch: $pr[0].base.ref,
        base_sha: $pr[0].base.sha,
        head_repo: $pr[0].head.repo.full_name,
        head_branch: $pr[0].head.ref,
        ticket_id: $ticket_id,
        ticket_matches: (($pr[0].head.ref | split("/") | last | scan("[A-Z][A-Z0-9]+-\\d+")) // [])
      },
      review_source: $review_source,
      providers: {
        coderabbit: {
          walkthrough_comments: $coderabbit_walkthrough[0],
          reviews: $coderabbit_reviews_data,
          comments: $coderabbit_comments_data,
          latest_review_id: $coderabbit_latest_review_id,
          latest_review_submitted_at: latest_review_submitted_at($coderabbit_reviews_data; $coderabbit_comments_data; $coderabbit_latest_review_id),
          latest_comment_ids: ($coderabbit_latest_comments | map(.comment_id)),
          latest_comments: $coderabbit_latest_comments
        },
        copilot: {
          reviews: $copilot_reviews_data,
          comments: $copilot_comments_data,
          latest_review_id: $copilot_latest_review_id,
          latest_review_submitted_at: latest_review_submitted_at($copilot_reviews_data; $copilot_comments_data; $copilot_latest_review_id),
          latest_comment_ids: ($copilot_latest_comments | map(.comment_id)),
          latest_comments: $copilot_latest_comments
        }
      },
      normalized_comments: ($coderabbit_comments_data + $copilot_comments_data | sort_by(.provider, .path // "", (.line // .start_line // 0), .comment_id)),
      selected_latest_comments: selected_latest_comments($review_source; $coderabbit_latest_comments; $copilot_latest_comments)
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
