#!/bin/bash
# generate-decisions-json.sh — Generates a normalized provider-neutral decisions artifact from a managed review round.
#
# Usage:
#   ./generate-decisions-json.sh <REVIEW_DOC> <REVIEW_DATA_JSON> [--repo-path <repo>] [--round <N>] [--output <path>]
#
# Output:
#   - Writes the normalized artifact to disk
#   - Prints a JSON summary to stdout
#
# Requires: jq

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate-decisions-json.sh <REVIEW_DOC> <REVIEW_DATA_JSON> [--repo-path <repo>] [--round <N>] [--output <path>] [--require-live-ready]
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

extract_round_meta() {
  local file_path="$1"
  local round_number="$2"
  ROUND="$round_number" perl -0ne '
    my $round = $ENV{ROUND};
    if (/<!--\s*round_meta:start\s+round=\Q$round\E\s*-->\s*```json\s*(.*?)\s*```\s*<!--\s*round_meta:end\s+round=\Q$round\E\s*-->/s) {
      print $1;
    }
  ' "$file_path"
}

extract_round_decisions() {
  local file_path="$1"
  local round_number="$2"
  ROUND="$round_number" perl -0ne '
    my $round = $ENV{ROUND};
    if (/<!--\s*round_decisions:start\s+round=\Q$round\E\s*-->\s*```json\s*(.*?)\s*```\s*<!--\s*round_decisions:end\s+round=\Q$round\E\s*-->/s) {
      print $1;
    }
  ' "$file_path"
}

last_managed_round() {
  local file_path="$1"
  perl -0ne '
    while (/<!--\s*round_meta:start\s+round=(\d+)\s*-->\s*```json\s*(.*?)\s*```\s*<!--\s*round_meta:end\s+round=\1\s*-->/sg) {
      $last = $1;
    }
    END {
      print $last if defined $last;
    }
  ' "$file_path"
}

select_latest_comments_json() {
  local review_data_file="$1"
  local review_source="$2"
  jq --arg review_source "$review_source" '
    if $review_source == "coderabbit" then
      (.providers.coderabbit.latest_comments // [])
    elif $review_source == "copilot" then
      (.providers.copilot.latest_comments // [])
    elif $review_source == "none" then
      []
    else
      ((.providers.coderabbit.latest_comments // []) + (.providers.copilot.latest_comments // []))
    end
    | sort_by(.provider, .path // "", (.line // .start_line // 0), .comment_id)
  ' "$review_data_file"
}

compare_provider_review_ids() {
  local meta_json="$1"
  local review_data_file="$2"
  local review_source="$3"

  local meta_ids
  meta_ids="$(printf '%s' "$meta_json" | jq '.provider_review_ids')"
  local current_ids
  current_ids="$(jq '
    {
      coderabbit: (.providers.coderabbit.latest_review_id // null),
      copilot: (.providers.copilot.latest_review_id // null)
    }
  ' "$review_data_file")"

  case "$review_source" in
    coderabbit)
      [ "$(printf '%s' "$meta_ids" | jq -c '{coderabbit}')" = "$(printf '%s' "$current_ids" | jq -c '{coderabbit}')" ]
      ;;
    copilot)
      [ "$(printf '%s' "$meta_ids" | jq -c '{copilot}')" = "$(printf '%s' "$current_ids" | jq -c '{copilot}')" ]
      ;;
    none)
      return 0
      ;;
    *)
      [ "$(printf '%s' "$meta_ids" | jq -c .)" = "$(printf '%s' "$current_ids" | jq -c .)" ]
      ;;
  esac
}

compare_latest_comment_ids() {
  local meta_json="$1"
  local review_data_file="$2"
  local review_source="$3"

  local meta_ids
  meta_ids="$(printf '%s' "$meta_json" | jq '.latest_comment_ids // {coderabbit: [], copilot: []}')"
  local current_ids
  current_ids="$(jq '
    {
      coderabbit: (.providers.coderabbit.latest_comment_ids // []),
      copilot: (.providers.copilot.latest_comment_ids // [])
    }
  ' "$review_data_file")"

  case "$review_source" in
    coderabbit)
      [ "$(printf '%s' "$meta_ids" | jq -c '{coderabbit}')" = "$(printf '%s' "$current_ids" | jq -c '{coderabbit}')" ]
      ;;
    copilot)
      [ "$(printf '%s' "$meta_ids" | jq -c '{copilot}')" = "$(printf '%s' "$current_ids" | jq -c '{copilot}')" ]
      ;;
    none)
      return 0
      ;;
    *)
      [ "$(printf '%s' "$meta_ids" | jq -c .)" = "$(printf '%s' "$current_ids" | jq -c .)" ]
      ;;
  esac
}

REPO_PATH=""
ROUND_NUMBER=""
OUTPUT_PATH=""
REQUIRE_LIVE_READY=false
POSITIONAL=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-path)
      REPO_PATH="${2:?Missing value for --repo-path}"
      shift 2
      ;;
    --round)
      ROUND_NUMBER="${2:?Missing value for --round}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:?Missing value for --output}"
      shift 2
      ;;
    --require-live-ready)
      REQUIRE_LIVE_READY=true
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

REVIEW_DOC_PATH="${POSITIONAL[0]}"
REVIEW_DATA_FILE="${POSITIONAL[1]}"

if [ ! -f "$REVIEW_DOC_PATH" ]; then
  echo "Error: Review doc not found: ${REVIEW_DOC_PATH}" >&2
  exit 1
fi
if [ ! -f "$REVIEW_DATA_FILE" ]; then
  echo "Error: Review data file not found: ${REVIEW_DATA_FILE}" >&2
  exit 1
fi

if [ -z "$ROUND_NUMBER" ]; then
  ROUND_NUMBER="$(last_managed_round "$REVIEW_DOC_PATH")"
  if [ -z "$ROUND_NUMBER" ]; then
    echo "Error: No managed review round was found in ${REVIEW_DOC_PATH}." >&2
    exit 1
  fi
fi

ROUND_META="$(extract_round_meta "$REVIEW_DOC_PATH" "$ROUND_NUMBER")"
ROUND_DECISIONS="$(extract_round_decisions "$REVIEW_DOC_PATH" "$ROUND_NUMBER")"

if [ -z "$ROUND_META" ] || [ -z "$ROUND_DECISIONS" ]; then
  echo "Error: Missing structured round data for round ${ROUND_NUMBER} in ${REVIEW_DOC_PATH}." >&2
  exit 1
fi

REVIEW_SOURCE="$(printf '%s' "$ROUND_META" | jq -r '.review_source // "all"')"
if ! compare_provider_review_ids "$ROUND_META" "$REVIEW_DATA_FILE" "$REVIEW_SOURCE"; then
  echo "Error: Latest provider review ids no longer match the current round metadata. Rebuild the round before generating decisions." >&2
  exit 1
fi
if ! compare_latest_comment_ids "$ROUND_META" "$REVIEW_DATA_FILE" "$REVIEW_SOURCE"; then
  echo "Error: Latest provider comment ids no longer match the current round metadata. Rebuild the round before generating decisions." >&2
  exit 1
fi

LATEST_COMMENTS_JSON="$(select_latest_comments_json "$REVIEW_DATA_FILE" "$REVIEW_SOURCE")"

NORMALIZED_ENTRIES="$(jq -n \
  --argjson decisions "$ROUND_DECISIONS" \
  --argjson latest_comments "$LATEST_COMMENTS_JSON" \
  --argjson meta "$ROUND_META" '
    def latest_comment($provider; $comment_id):
      ($latest_comments | map(select(.provider == $provider and .comment_id == $comment_id)) | .[0]);

    if ($decisions | type) != "array" then
      error("round_decisions must be a JSON array")
    else
      $decisions
      | (map(.provider + ":" + (.comment_id | tostring)) | group_by(.) | map(select(length > 1)) | length) as $duplicate_count
      | if $duplicate_count > 0 then
          error("duplicate decision rows found in round_decisions")
        else
          .
        end
      | (map(.provider + ":" + (.comment_id | tostring)) | sort) as $decision_keys
      | ($latest_comments | map(.provider + ":" + (.comment_id | tostring)) | sort) as $latest_keys
      | ($latest_keys - $decision_keys) as $missing_keys
      | if ($missing_keys | length) > 0 then
          error("round_decisions is missing latest-round comment rows: " + ($missing_keys | join(", ")))
        else
          .
        end
      | map(
          if (.provider | type) != "string" or (.comment_id | type) != "number" or (.review_id | type) != "number" then
            error("every decision row must include provider, review_id, and numeric comment_id")
          else .
          end
          | (.verdict // "") as $verdict
          | if (["pending", "accepted", "declined"] | index($verdict)) == null then
              error("decision verdict must be one of pending|accepted|declined")
            else .
            end
          | if (.verdict != "pending" and ((.reason // "") | length) == 0) then
              error("accepted/declined decisions must include a non-empty reason")
            else .
            end
          | (latest_comment(.provider; .comment_id)) as $latest
          | if $latest == null then
              error("decision row references a stale or missing latest-round comment")
            else .
            end
          | if $latest.review_id != .review_id then
              error("decision row review_id does not match the latest provider review")
            else .
            end
          | {
              provider: .provider,
              review_id: .review_id,
              comment_id: .comment_id,
              path: $latest.path,
              line: ($latest.line // $latest.start_line // null),
              verdict: .verdict,
              reason: (.reason // ""),
              owner: (.owner // ""),
              round_status: ($meta.status // "draft")
            }
        )
    end
  ')"

if [ "$REQUIRE_LIVE_READY" = true ]; then
  ROUND_STATUS="$(printf '%s' "$ROUND_META" | jq -r '.status // "draft"')"
  case "$ROUND_STATUS" in
    dry-run-verified|mutation-partial) ;;
    *)
      echo "Error: Live preflight requires round status dry-run-verified or mutation-partial. Current status: ${ROUND_STATUS}." >&2
      exit 1
      ;;
  esac

  PENDING_COUNT="$(printf '%s' "$NORMALIZED_ENTRIES" | jq '[.[] | select(.verdict == "pending")] | length')"
  if [ "$PENDING_COUNT" -gt 0 ]; then
    echo "Error: Live preflight failed. ${PENDING_COUNT} latest-round decision(s) remain pending in round_decisions." >&2
    exit 1
  fi
fi

if [ -z "$REPO_PATH" ]; then
  REPO_PATH="$(jq -r '.automation.target_repo_path // empty' "$REVIEW_DATA_FILE")"
fi
if [ -n "$REPO_PATH" ]; then
  REPO_PATH="$(normalize_path "$REPO_PATH")"
fi

if [ -z "$OUTPUT_PATH" ]; then
  ARTIFACT_DIR="$(printf '%s' "$ROUND_META" | jq -r '.artifact_dir // empty')"
  if [ -z "$ARTIFACT_DIR" ]; then
    echo "Error: round_meta.artifact_dir is missing; pass --output explicitly." >&2
    exit 1
  fi
  if [ -z "$REPO_PATH" ]; then
    echo "Error: Could not resolve repo path for artifact output. Pass --repo-path <repo> or include target_repo_path in the review data." >&2
    exit 1
  fi
  OUTPUT_PATH="${REPO_PATH}/${ARTIFACT_DIR}/decisions.json"
fi

OUTPUT_PATH="$(normalize_path "$OUTPUT_PATH")"
mkdir -p "$(dirname "$OUTPUT_PATH")"

ARTIFACT_JSON="$(jq -n \
  --arg version "0.2.2" \
  --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg review_doc_path "$REVIEW_DOC_PATH" \
  --arg review_data_path "$REVIEW_DATA_FILE" \
  --argjson meta "$ROUND_META" \
  --argjson entries "$NORMALIZED_ENTRIES" \
  '
    {
      version: $version,
      generated_at: $generated_at,
      review_doc_path: $review_doc_path,
      review_data_path: $review_data_path,
      pr_number: $meta.pr_number,
      repo: $meta.repo,
      round_number: $meta.round_number,
      round_status: $meta.status,
      review_source: $meta.review_source,
      entries: $entries
    }
  ')"

printf '%s\n' "$ARTIFACT_JSON" | jq '.' > "$OUTPUT_PATH"

jq -n \
  --arg output_path "$OUTPUT_PATH" \
  --argjson artifact "$ARTIFACT_JSON" \
  '{output_path: $output_path, artifact: $artifact, entry_count: ($artifact.entries | length)}'
