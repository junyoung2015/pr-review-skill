#!/bin/bash
# resolve-ai-review-threads.sh — Resolves accepted PR review threads via GraphQL.
#
# Usage:
#   ./resolve-ai-review-threads.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
#   ./resolve-ai-review-threads.sh <PR_NUMBER> <DECISIONS_JSON> --repo <owner/repo> [--dry-run] [--output <path>]
#
# Canonical decisions artifact:
# {
#   "entries": [
#     {
#       "provider": "copilot|coderabbit",
#       "review_id": 123,
#       "comment_id": 456,
#       "verdict": "accepted|declined|pending",
#       "reason": "...",
#       "round_status": "draft"
#     }
#   ]
# }
#
# Only threads corresponding to "accepted" verdicts are resolved.
# Uses GitHub GraphQL because thread resolution has no REST endpoint.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  resolve-ai-review-threads.sh <PR_NUMBER> <DECISIONS_JSON> [REPO]
  resolve-ai-review-threads.sh <PR_NUMBER> <DECISIONS_JSON> --repo <owner/repo> [--dry-run] [--output <path>]
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

latest_provider_review_id() {
  local provider="$1"
  local reviews_file="$2"
  local comments_file="$3"

  jq -nr \
    --arg provider "$provider" \
    --slurpfile reviews "$reviews_file" \
    --slurpfile comments "$comments_file" '
      def provider_reviews:
        if $provider == "coderabbit" then
          [
            $reviews[0][]
            | select(.user.login == "coderabbitai[bot]" and ((.body // "") | length > 0))
            | {review_id: .id, submitted_at}
          ]
        else
          [
            $reviews[0][]
            | select((.user.login // "") | test("^copilot-pull-request-reviewer(\\[bot\\])?$"))
            | {review_id: .id, submitted_at}
          ]
        end;

      def provider_comments:
        if $provider == "coderabbit" then
          [
            $comments[0][]
            | select(.user.login == "coderabbitai[bot]" and .in_reply_to_id == null and .pull_request_review_id != null)
            | {review_id: .pull_request_review_id, updated_at: (.updated_at // .created_at // "")}
          ]
        else
          ([provider_reviews[].review_id]) as $review_ids
          | [
              $comments[0][]
              | select(
                  .in_reply_to_id == null
                  and .pull_request_review_id != null
                  and (
                    ((.pull_request_review_id) as $comment_review_id | ($review_ids | index($comment_review_id)) != null)
                    or ((.user.login // "") | ascii_downcase) == "copilot"
                  )
                )
              | {review_id: .pull_request_review_id, updated_at: (.updated_at // .created_at // "")}
            ]
        end;

      (provider_reviews) as $reviews_filtered
      | (provider_comments) as $comments_filtered
      | if ($reviews_filtered | length) > 0 then
          ($reviews_filtered | max_by(.submitted_at // "") | .review_id | tostring)
        elif ($comments_filtered | length) > 0 then
          ($comments_filtered | max_by(.updated_at // "") | .review_id | tostring)
        else
          ""
        end
    '
}

REPO="demodev-lab/moving-frontend"
DRY_RUN=false
OUTPUT_PATH=""
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
    --output)
      OUTPUT_PATH="${2:?Missing value for --output}"
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

if [ -n "$OUTPUT_PATH" ]; then
  OUTPUT_PATH="$(normalize_path "$OUTPUT_PATH")"
  mkdir -p "$(dirname "$OUTPUT_PATH")"
fi

NORMALIZED_ENTRIES="$(jq '
  (if type == "array" then . else (.entries // []) end)
  | map(
      . + {
        verdict:
          (if .verdict == "accept" then "accepted"
           elif .verdict == "decline" then "declined"
           else .verdict
           end)
      }
    )
' "$DECISIONS_FILE")"

DECISION_COUNT="$(printf '%s' "$NORMALIZED_ENTRIES" | jq 'length')"
if [ "$DECISION_COUNT" -eq 0 ]; then
  echo "No decisions to resolve." >&2
  SUMMARY="$(jq -n --arg mode "$(if [ "$DRY_RUN" = true ]; then echo dry-run; else echo live; fi)" '{mode: $mode, processed: 0, results: []}')"
  if [ -n "$OUTPUT_PATH" ]; then
    printf '%s\n' "$SUMMARY" | jq '.' > "$OUTPUT_PATH"
  fi
  printf '%s\n' "$SUMMARY"
  exit 0
fi

PENDING_COUNT="$(printf '%s' "$NORMALIZED_ENTRIES" | jq '[.[] | select(.verdict == "pending")] | length')"
if [ "$DRY_RUN" != true ] && [ "$PENDING_COUNT" -gt 0 ]; then
  echo "Error: Live thread resolution cannot continue while ${PENDING_COUNT} decision(s) remain pending." >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

OWNER="$(printf '%s' "$REPO" | cut -d'/' -f1)"
REPO_NAME="$(printf '%s' "$REPO" | cut -d'/' -f2)"

gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews" --paginate | jq -s 'add // []' > "${TMPDIR}/reviews.json"
gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate | jq -s 'add // []' > "${TMPDIR}/comments.json"

LATEST_CODERABBIT_REVIEW_ID="$(latest_provider_review_id "coderabbit" "${TMPDIR}/reviews.json" "${TMPDIR}/comments.json")"
LATEST_COPILOT_REVIEW_ID="$(latest_provider_review_id "copilot" "${TMPDIR}/reviews.json" "${TMPDIR}/comments.json")"

printf '%s' "$NORMALIZED_ENTRIES" | jq \
  --slurpfile comments "${TMPDIR}/comments.json" \
  --arg coderabbit_latest "$LATEST_CODERABBIT_REVIEW_ID" \
  --arg copilot_latest "$LATEST_COPILOT_REVIEW_ID" '
    map(
      (.provider) as $provider
      | if (["coderabbit", "copilot"] | index($provider)) == null then
        error("provider must be coderabbit or copilot")
      else .
      end
      | (.verdict) as $verdict
      | if (["accepted", "declined", "pending"] | index($verdict)) == null then
          error("verdict must be accepted|declined|pending")
        else .
        end
      | if (.review_id | type) != "number" or (.comment_id | type) != "number" then
          error("review_id and comment_id must be numeric")
        else .
        end
      | (.provider == "coderabbit" and ($coderabbit_latest == "" or (.review_id | tostring) != $coderabbit_latest)) as $bad_coderabbit
      | (.provider == "copilot" and ($copilot_latest == "" or (.review_id | tostring) != $copilot_latest)) as $bad_copilot
      | if $bad_coderabbit or $bad_copilot then
          error("decision targets a stale provider review round")
        else .
        end
      | (.comment_id) as $decision_comment_id
      | (.review_id) as $decision_review_id
      | ($comments[0] | map(select(.id == $decision_comment_id and .pull_request_review_id == $decision_review_id))) as $matches
      | if ($matches | length) != 1 then
          error("comment_id not found on the current PR")
        else .
        end
    )
  ' >/dev/null

ALL_THREADS='[]'
HAS_NEXT=true
CURSOR=""

while [ "$HAS_NEXT" = true ]; do
  if [ -z "$CURSOR" ]; then
    PAGE_JSON="$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100) {
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
                  }
                }
              }
            }
          }
        }
      }
    ' -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER")"
  else
    PAGE_JSON="$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!, $cursor: String!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100, after: $cursor) {
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
                  }
                }
              }
            }
          }
        }
      }
    ' -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER" -f cursor="$CURSOR")"
  fi

  PAGE_NODES="$(printf '%s' "$PAGE_JSON" | jq '.data.repository.pullRequest.reviewThreads.nodes')"
  ALL_THREADS="$(printf '%s' "$ALL_THREADS" "$PAGE_NODES" | jq -s '.[0] + .[1]')"
  HAS_NEXT="$(printf '%s' "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')"
  CURSOR="$(printf '%s' "$PAGE_JSON" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // ""')"
done

echo "Resolving accepted AI review threads for PR #${PR_NUMBER}..." >&2
if [ "$DRY_RUN" = true ]; then
  echo "Dry run enabled. No GitHub threads will be resolved." >&2
fi

RESULTS='[]'
RESOLVED=0
ALREADY_RESOLVED=0
SKIPPED_DECLINED=0
SKIPPED_PENDING=0
NOT_FOUND=0
ERRORS=0

while read -r decision; do
  COMMENT_ID="$(printf '%s' "$decision" | jq -r '.comment_id')"
  PROVIDER="$(printf '%s' "$decision" | jq -r '.provider')"
  REVIEW_ID="$(printf '%s' "$decision" | jq -r '.review_id')"
  VERDICT="$(printf '%s' "$decision" | jq -r '.verdict')"

  if [ "$VERDICT" = "pending" ]; then
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, status: "pending-skip"}]
      ')"
    SKIPPED_PENDING=$((SKIPPED_PENDING + 1))
    continue
  fi

  if [ "$VERDICT" = "declined" ]; then
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, status: "declined-no-resolve"}]
      ')"
    SKIPPED_DECLINED=$((SKIPPED_DECLINED + 1))
    continue
  fi

  THREAD_ID="$(printf '%s' "$ALL_THREADS" | jq -r --argjson cid "$COMMENT_ID" '
    .[]
    | select(.comments.nodes[0].databaseId == $cid)
    | .id
  ')"

  if [ -z "$THREAD_ID" ] || [ "$THREAD_ID" = "null" ]; then
    echo "  WARNING: No thread found for comment ${COMMENT_ID}" >&2
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, status: "thread-not-found"}]
      ')"
    NOT_FOUND=$((NOT_FOUND + 1))
    continue
  fi

  IS_RESOLVED="$(printf '%s' "$ALL_THREADS" | jq -r --argjson cid "$COMMENT_ID" '
    .[]
    | select(.comments.nodes[0].databaseId == $cid)
    | .isResolved
  ')"

  if [ "$IS_RESOLVED" = true ]; then
    echo "  Thread for comment ${COMMENT_ID} already resolved, skipping." >&2
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" \
      --arg thread_id "$THREAD_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, thread_id: $thread_id, status: "already-resolved"}]
      ')"
    ALREADY_RESOLVED=$((ALREADY_RESOLVED + 1))
    continue
  fi

  echo "  Resolving thread for ${PROVIDER} comment ${COMMENT_ID} (${THREAD_ID})..." >&2

  if [ "$DRY_RUN" = true ]; then
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" \
      --arg thread_id "$THREAD_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, thread_id: $thread_id, status: "preview"}]
      ')"
    continue
  fi

  if gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread {
          id
          isResolved
        }
      }
    }
  ' -f threadId="$THREAD_ID" >/dev/null; then
    echo "    Done." >&2
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" \
      --arg thread_id "$THREAD_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, thread_id: $thread_id, status: "resolved"}]
      ')"
    RESOLVED=$((RESOLVED + 1))
  else
    echo "    ERROR: Failed to resolve thread ${THREAD_ID}" >&2
    RESULTS="$(printf '%s' "$RESULTS" | jq \
      --arg provider "$PROVIDER" \
      --argjson review_id "$REVIEW_ID" \
      --argjson comment_id "$COMMENT_ID" \
      --arg thread_id "$THREAD_ID" '
        . + [{provider: $provider, review_id: $review_id, comment_id: $comment_id, thread_id: $thread_id, status: "error"}]
      ')"
    ERRORS=$((ERRORS + 1))
  fi
done < <(printf '%s' "$NORMALIZED_ENTRIES" | jq -c '.[]')

SUMMARY="$(jq -n \
  --arg mode "$(if [ "$DRY_RUN" = true ]; then echo dry-run; else echo live; fi)" \
  --arg repo "$REPO" \
  --argjson pr_number "$PR_NUMBER" \
  --argjson resolved "$RESOLVED" \
  --argjson already_resolved "$ALREADY_RESOLVED" \
  --argjson skipped_declined "$SKIPPED_DECLINED" \
  --argjson skipped_pending "$SKIPPED_PENDING" \
  --argjson not_found "$NOT_FOUND" \
  --argjson errors "$ERRORS" \
  --argjson results "$RESULTS" \
  '
    {
      action: "resolve-threads",
      mode: $mode,
      repo: $repo,
      pr_number: $pr_number,
      resolved: $resolved,
      already_resolved: $already_resolved,
      skipped_declined: $skipped_declined,
      skipped_pending: $skipped_pending,
      not_found: $not_found,
      errors: $errors,
      results: $results
    }
  ')"

if [ -n "$OUTPUT_PATH" ]; then
  printf '%s\n' "$SUMMARY" | jq '.' > "$OUTPUT_PATH"
fi

printf '%s\n' "$SUMMARY"

if [ $((NOT_FOUND + ERRORS)) -gt 0 ]; then
  exit 1
fi
