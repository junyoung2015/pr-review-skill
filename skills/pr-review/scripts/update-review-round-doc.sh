#!/bin/bash
# update-review-round-doc.sh — Appends/resumes managed review rounds and updates round status/artifact metadata.
#
# Usage:
#   ./update-review-round-doc.sh init <REVIEW_DATA_JSON> --repo-path <repo> [--review-doc <path>]
#     [--review-source <all|coderabbit|copilot|none>] [--worktree-json <path>] [--artifact-dir <path>]
#   ./update-review-round-doc.sh status <REVIEW_DOC> --round <N> --status <draft|dry-run-verified|live-posted|mutation-partial|blocked>
#     [--artifact-dir <path>] [--artifact <key>=<value>]... [--worktree-json <path>]
#
# Output:
#   - Machine-readable JSON on stdout
#   - Human guidance on stderr
#
# Requires: jq

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  update-review-round-doc.sh init <REVIEW_DATA_JSON> --repo-path <repo> [--review-doc <path>]
    [--review-source <all|coderabbit|copilot|none>] [--worktree-json <path>] [--artifact-dir <path>]

  update-review-round-doc.sh status <REVIEW_DOC> --round <N> --status <draft|dry-run-verified|live-posted|mutation-partial|blocked>
    [--artifact-dir <path>] [--artifact <key>=<value>]... [--worktree-json <path>]
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

path_within() {
  local base_path="$1"
  local candidate_path="$2"
  case "$candidate_path" in
    "$base_path" | "$base_path"/*) return 0 ;;
    *) return 1 ;;
  esac
}

extract_ticket_id_from_branch() {
  local branch_name="$1"
  local branch_basename
  branch_basename="$(basename "$branch_name")"

  local matches
  matches="$(printf '%s\n' "$branch_basename" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' || true)"
  local match_count
  match_count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [ "$match_count" -eq 1 ]; then
    printf '%s\n' "$matches" | sed '/^$/d' | head -1
    return 0
  fi

  if [ "$match_count" -eq 0 ]; then
    echo "ambiguous: no ticket found in branch basename '${branch_basename}'" >&2
  else
    echo "ambiguous: multiple ticket ids found in branch basename '${branch_basename}'" >&2
  fi
  return 1
}

extract_ticket_id_from_review_doc() {
  local review_doc_path="$1"
  local review_doc_name
  review_doc_name="$(basename "$review_doc_path")"

  local matches
  matches="$(printf '%s\n' "$review_doc_name" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' || true)"
  local match_count
  match_count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [ "$match_count" -eq 1 ]; then
    printf '%s\n' "$matches" | sed '/^$/d' | head -1
    return 0
  fi

  return 1
}

is_placeholder_ticket_id() {
  local ticket_id="$1"
  [[ "$ticket_id" =~ ^PR-[0-9]+$ ]]
}

resolve_review_doc_path() {
  local repo_path="$1"
  local explicit_path="$2"
  local branch_name="$3"

  if [ -n "$explicit_path" ]; then
    local normalized_explicit_path
    normalized_explicit_path="$(normalize_path "$explicit_path")"
    if ! path_within "$repo_path" "$normalized_explicit_path"; then
      echo "Error: Explicit review doc must live inside the resolved target repo: ${normalized_explicit_path}" >&2
      return 1
    fi
    printf '%s\n' "$normalized_explicit_path"
    return 0
  fi

  local ticket_id
  ticket_id="$(extract_ticket_id_from_branch "$branch_name")" || return 1
  printf '%s/docs/reviews/%s-review.md\n' "$repo_path" "$ticket_id"
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

extract_last_round_meta() {
  local file_path="$1"
  perl -0ne '
    while (/<!--\s*round_meta:start\s+round=(\d+)\s*-->\s*```json\s*(.*?)\s*```\s*<!--\s*round_meta:end\s+round=\1\s*-->/sg) {
      $last = $2;
    }
    END {
      print $last if defined $last;
    }
  ' "$file_path"
}

replace_round_meta() {
  local file_path="$1"
  local round_number="$2"
  local meta_json="$3"
  local replacement
  replacement="$(cat <<EOF
<!-- round_meta:start round=${round_number} -->
\`\`\`json
$(printf '%s' "$meta_json" | jq '.')
\`\`\`
<!-- round_meta:end round=${round_number} -->
EOF
)"

  local tmp_file
  tmp_file="$(mktemp)"
  ROUND="$round_number" REPLACEMENT="$replacement" perl -0pe '
    my $round = $ENV{ROUND};
    my $replacement = $ENV{REPLACEMENT};
    my $pattern = qr{<!--\s*round_meta:start\s+round=\Q$round\E\s*-->\s*```json\s*.*?\s*```\s*<!--\s*round_meta:end\s+round=\Q$round\E\s*-->}s;
    die "round_meta block for round $round not found\n" unless s/$pattern/$replacement/;
  ' "$file_path" > "$tmp_file"
  mv "$tmp_file" "$file_path"
}

highest_round_heading() {
  local file_path="$1"
  local highest
  highest="$(grep -E '^## .*Round [0-9]+' "$file_path" | sed -E 's/^## .*Round ([0-9]+).*$/\1/' | sort -n | tail -1 || true)"
  if [ -z "$highest" ]; then
    highest=0
  fi
  printf '%s\n' "$highest"
}

validate_status_transition() {
  local from_status="$1"
  local to_status="$2"

  if [ "$from_status" = "$to_status" ]; then
    return 0
  fi

  case "${from_status}:${to_status}" in
    draft:dry-run-verified|dry-run-verified:live-posted|dry-run-verified:mutation-partial|dry-run-verified:blocked|mutation-partial:live-posted|blocked:draft)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

selected_review_source() {
  local override="$1"
  local review_data_file="$2"
  if [ -n "$override" ]; then
    printf '%s\n' "$override"
  else
    jq -r '.review_source // "all"' "$review_data_file"
  fi
}

provider_latest_review_ids_json() {
  local review_data_file="$1"
  jq '
    {
      coderabbit: (.providers.coderabbit.latest_review_id // null),
      copilot: (.providers.copilot.latest_review_id // null)
    }
  ' "$review_data_file"
}

selected_provider_review_ids_match() {
  local existing_json="$1"
  local current_json="$2"
  local review_source="$3"

  case "$review_source" in
    coderabbit)
      [ "$(printf '%s' "$existing_json" | jq -c '{coderabbit}')" = "$(printf '%s' "$current_json" | jq -c '{coderabbit}')" ]
      ;;
    copilot)
      [ "$(printf '%s' "$existing_json" | jq -c '{copilot}')" = "$(printf '%s' "$current_json" | jq -c '{copilot}')" ]
      ;;
    none)
      return 0
      ;;
    *)
      [ "$(printf '%s' "$existing_json" | jq -c .)" = "$(printf '%s' "$current_json" | jq -c .)" ]
      ;;
  esac
}

provider_latest_comment_ids_json() {
  local review_data_file="$1"
  jq '
    {
      coderabbit: (.providers.coderabbit.latest_comment_ids // []),
      copilot: (.providers.copilot.latest_comment_ids // [])
    }
  ' "$review_data_file"
}

pending_decisions_json() {
  local review_data_file="$1"
  local review_source="$2"

  jq --arg review_source "$review_source" '
    def selected_comments:
      if $review_source == "coderabbit" then
        (.providers.coderabbit.latest_comments // [])
      elif $review_source == "copilot" then
        (.providers.copilot.latest_comments // [])
      elif $review_source == "none" then
        []
      else
        ((.providers.coderabbit.latest_comments // []) + (.providers.copilot.latest_comments // []))
      end;

    selected_comments
    | sort_by(.provider, .path // "", (.line // .start_line // 0), .comment_id)
    | map({
        provider,
        review_id,
        comment_id,
        path,
        line: (.line // .start_line // null),
        verdict: "pending",
        reason: "",
        owner: ""
      })
  ' "$review_data_file"
}

MODE=""
REPO_PATH=""
REVIEW_DOC_PATH=""
REVIEW_SOURCE_OVERRIDE=""
WORKTREE_JSON_PATH=""
ARTIFACT_DIR_OVERRIDE=""
ROUND_NUMBER=""
STATUS_VALUE=""
POSITIONAL=()
ARTIFACT_UPDATES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-path)
      REPO_PATH="${2:?Missing value for --repo-path}"
      shift 2
      ;;
    --review-doc)
      REVIEW_DOC_PATH="${2:?Missing value for --review-doc}"
      shift 2
      ;;
    --review-source)
      REVIEW_SOURCE_OVERRIDE="${2:?Missing value for --review-source}"
      shift 2
      ;;
    --worktree-json)
      WORKTREE_JSON_PATH="${2:?Missing value for --worktree-json}"
      shift 2
      ;;
    --artifact-dir)
      ARTIFACT_DIR_OVERRIDE="${2:?Missing value for --artifact-dir}"
      shift 2
      ;;
    --round)
      ROUND_NUMBER="${2:?Missing value for --round}"
      shift 2
      ;;
    --status)
      STATUS_VALUE="${2:?Missing value for --status}"
      shift 2
      ;;
    --artifact)
      ARTIFACT_UPDATES+=("${2:?Missing value for --artifact}")
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

MODE="${POSITIONAL[0]}"
TARGET_INPUT="${POSITIONAL[1]}"

case "$MODE" in
  init|status) ;;
  *)
    echo "Error: Mode must be one of: init, status" >&2
    exit 1
    ;;
esac

if [ -n "$WORKTREE_JSON_PATH" ] && [ ! -f "$WORKTREE_JSON_PATH" ]; then
  echo "Error: Worktree JSON file not found: ${WORKTREE_JSON_PATH}" >&2
  exit 1
fi

NOW_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
NOW_HUMAN="$(date +"%Y-%m-%d %H:%M")"

if [ "$MODE" = "init" ]; then
  REVIEW_DATA_FILE="$TARGET_INPUT"
  if [ ! -f "$REVIEW_DATA_FILE" ]; then
    echo "Error: Review data file not found: ${REVIEW_DATA_FILE}" >&2
    exit 1
  fi

  if [ -z "$REPO_PATH" ]; then
    echo "Error: init mode requires --repo-path <repo>." >&2
    exit 1
  fi
  REPO_PATH="$(normalize_path "$REPO_PATH")"

  BRANCH_NAME="$(jq -r '.pr.branch' "$REVIEW_DATA_FILE")"
  REVIEW_DOC_PATH="$(resolve_review_doc_path "$REPO_PATH" "$REVIEW_DOC_PATH" "$BRANCH_NAME")" || {
    echo "Error: Could not resolve the review doc. Pass --review-doc <path>." >&2
    exit 1
  }

  if [ ! -f "$REVIEW_DOC_PATH" ]; then
    echo "Error: Review doc not found at ${REVIEW_DOC_PATH}. Auto mode requires an existing review doc before round append." >&2
    exit 1
  fi

  PR_NUMBER="$(jq -r '.pr.number' "$REVIEW_DATA_FILE")"
  BRANCH_HEAD_SHA="$(jq -r '.pr.head_sha' "$REVIEW_DATA_FILE")"

  TITLE_TICKET_ID="$(jq -r '.pr.ticket_id // empty' "$REVIEW_DATA_FILE")"
  REVIEW_DOC_TICKET_ID="$(extract_ticket_id_from_review_doc "$REVIEW_DOC_PATH" || true)"
  BRANCH_TICKET_ID="$(extract_ticket_id_from_branch "$BRANCH_NAME" || true)"

  if [ -n "$REVIEW_DOC_TICKET_ID" ] && [ -n "$BRANCH_TICKET_ID" ] && [ "$REVIEW_DOC_TICKET_ID" != "$BRANCH_TICKET_ID" ]; then
    echo "Error: Review doc ticket ${REVIEW_DOC_TICKET_ID} does not match branch ticket ${BRANCH_TICKET_ID}." >&2
    exit 1
  fi

  if [ -n "$REVIEW_DOC_TICKET_ID" ]; then
    TICKET_ID="$REVIEW_DOC_TICKET_ID"
  elif [ -n "$BRANCH_TICKET_ID" ]; then
    TICKET_ID="$BRANCH_TICKET_ID"
  elif [ -n "$TITLE_TICKET_ID" ] && ! is_placeholder_ticket_id "$TITLE_TICKET_ID"; then
    TICKET_ID="$TITLE_TICKET_ID"
  else
    echo "Error: Could not derive the ticket id from the review doc or branch metadata. Pass --review-doc explicitly." >&2
    exit 1
  fi

  REVIEW_SOURCE="$(selected_review_source "$REVIEW_SOURCE_OVERRIDE" "$REVIEW_DATA_FILE")"
  case "$REVIEW_SOURCE" in
    all|coderabbit|copilot|none) ;;
    *)
      echo "Error: review source must be one of all|coderabbit|copilot|none" >&2
      exit 1
      ;;
  esac

  HIGHEST_ROUND="$(highest_round_heading "$REVIEW_DOC_PATH")"
  LAST_META="$(extract_last_round_meta "$REVIEW_DOC_PATH")"

  if [ -n "$LAST_META" ] && [ "$(printf '%s' "$LAST_META" | jq -r '.status // ""')" = "mutation-partial" ]; then
    ROUND_NUMBER="$(printf '%s' "$LAST_META" | jq -r '.round_number')"
    EXISTING_REVIEW_IDS="$(printf '%s' "$LAST_META" | jq '.provider_review_ids')"
    CURRENT_REVIEW_IDS="$(provider_latest_review_ids_json "$REVIEW_DATA_FILE")"
    if ! selected_provider_review_ids_match "$EXISTING_REVIEW_IDS" "$CURRENT_REVIEW_IDS" "$REVIEW_SOURCE"; then
      echo "Error: The latest provider review ids changed since the mutation-partial round was created. Start a new round after operator review." >&2
      exit 1
    fi
    if [ "$(printf '%s' "$LAST_META" | jq -r '.head_sha')" != "$BRANCH_HEAD_SHA" ]; then
      echo "Error: The PR head SHA changed since the mutation-partial round was created. Start a new round after operator review." >&2
      exit 1
    fi

    UPDATED_META="$(printf '%s' "$LAST_META" | jq \
      --arg updated_at "$NOW_ISO" \
      --arg review_data_path "$REVIEW_DATA_FILE" \
      --arg review_source "$REVIEW_SOURCE" \
      --argjson worktree "$(if [ -n "$WORKTREE_JSON_PATH" ]; then cat "$WORKTREE_JSON_PATH"; else printf 'null'; fi)" \
      '
        .updated_at = $updated_at
        | .review_source = $review_source
        | .artifacts.review_data_json = $review_data_path
        | if $worktree == null then . else .worktree = $worktree end
      ')"
    ROUND_NUMBER="$(printf '%s' "$UPDATED_META" | jq -r '.round_number')"
    replace_round_meta "$REVIEW_DOC_PATH" "$ROUND_NUMBER" "$UPDATED_META"
    jq -n \
      --arg review_doc_path "$REVIEW_DOC_PATH" \
      --arg action "resumed" \
      --argjson meta "$UPDATED_META" \
      '{action: $action, review_doc_path: $review_doc_path, meta: $meta}'
    exit 0
  fi

  ROUND_NUMBER=$((HIGHEST_ROUND + 1))
  if [ -n "$ARTIFACT_DIR_OVERRIDE" ]; then
    ARTIFACT_DIR="$ARTIFACT_DIR_OVERRIDE"
  else
    ARTIFACT_DIR=".pr-review/pr-${PR_NUMBER}/round-${ROUND_NUMBER}"
  fi

  WORKTREE_JSON='null'
  if [ -n "$WORKTREE_JSON_PATH" ]; then
    WORKTREE_JSON="$(cat "$WORKTREE_JSON_PATH")"
  fi

  META_JSON="$(jq -n \
    --arg managed_by "pr-review@0.2.2" \
    --argjson round_number "$ROUND_NUMBER" \
    --arg status "draft" \
    --arg created_at "$NOW_ISO" \
    --arg updated_at "$NOW_ISO" \
    --argjson pr_number "$(jq -r '.pr.number' "$REVIEW_DATA_FILE")" \
    --arg ticket_id "$TICKET_ID" \
    --arg repo "$(jq -r '.pr.head_repo // .pr.repo' "$REVIEW_DATA_FILE")" \
    --arg branch "$BRANCH_NAME" \
    --arg head_sha "$BRANCH_HEAD_SHA" \
    --arg review_source "$REVIEW_SOURCE" \
    --arg artifact_dir "$ARTIFACT_DIR" \
    --arg review_data_path "$REVIEW_DATA_FILE" \
    --argjson provider_review_ids "$(provider_latest_review_ids_json "$REVIEW_DATA_FILE")" \
    --argjson latest_comment_ids "$(provider_latest_comment_ids_json "$REVIEW_DATA_FILE")" \
    --argjson worktree "$WORKTREE_JSON" \
    '
      {
        managed_by: $managed_by,
        round_number: $round_number,
        status: $status,
        created_at: $created_at,
        updated_at: $updated_at,
        pr_number: $pr_number,
        ticket_id: $ticket_id,
        repo: $repo,
        branch: $branch,
        head_sha: $head_sha,
        review_source: $review_source,
        provider_review_ids: $provider_review_ids,
        latest_comment_ids: $latest_comment_ids,
        artifact_dir: $artifact_dir,
        artifacts: {
          review_data_json: $review_data_path,
          decisions_json: null,
          reply_output: null,
          resolve_output: null
        },
        worktree: (if $worktree == null then null else $worktree end)
      }
    ')"

  DECISIONS_JSON="$(pending_decisions_json "$REVIEW_DATA_FILE" "$REVIEW_SOURCE")"

  ROUND_SECTION="$(cat <<EOF
---

## 리뷰어 직접 수정 사항 (Reviewer Fixes Applied) - Round ${ROUND_NUMBER}

**Date:** ${NOW_HUMAN}
> Auto-mode round prepared for PR #${PR_NUMBER} with \`--review-source ${REVIEW_SOURCE}\`
> Update every \`round_decisions\` verdict from \`pending\` to \`accepted\` or \`declined\` before \`--live\`.

### round_meta

<!-- round_meta:start round=${ROUND_NUMBER} -->
\`\`\`json
$(printf '%s' "$META_JSON" | jq '.')
\`\`\`
<!-- round_meta:end round=${ROUND_NUMBER} -->

### round_decisions

<!-- round_decisions:start round=${ROUND_NUMBER} -->
\`\`\`json
$(printf '%s' "$DECISIONS_JSON" | jq '.')
\`\`\`
<!-- round_decisions:end round=${ROUND_NUMBER} -->

### 수정된 항목

_없음. fix-forward 후에 채우세요._

### 미수정 항목

_없음. triage 후 필요한 경우에만 채우세요._
EOF
)"

  printf '\n%s\n' "$ROUND_SECTION" >> "$REVIEW_DOC_PATH"

  jq -n \
    --arg action "appended" \
    --arg review_doc_path "$REVIEW_DOC_PATH" \
    --argjson meta "$META_JSON" \
    --argjson decisions "$DECISIONS_JSON" \
    '{action: $action, review_doc_path: $review_doc_path, meta: $meta, round_decisions: $decisions}'
  exit 0
fi

REVIEW_DOC_PATH="$TARGET_INPUT"
if [ ! -f "$REVIEW_DOC_PATH" ]; then
  echo "Error: Review doc not found: ${REVIEW_DOC_PATH}" >&2
  exit 1
fi

if [ -z "$ROUND_NUMBER" ] || [ -z "$STATUS_VALUE" ]; then
  echo "Error: status mode requires both --round <N> and --status <value>." >&2
  exit 1
fi

CURRENT_META="$(extract_round_meta "$REVIEW_DOC_PATH" "$ROUND_NUMBER")"
if [ -z "$CURRENT_META" ]; then
  echo "Error: Could not find round_meta for round ${ROUND_NUMBER} in ${REVIEW_DOC_PATH}." >&2
  exit 1
fi

CURRENT_STATUS="$(printf '%s' "$CURRENT_META" | jq -r '.status')"
if ! validate_status_transition "$CURRENT_STATUS" "$STATUS_VALUE"; then
  echo "Error: Invalid round status transition ${CURRENT_STATUS} -> ${STATUS_VALUE}." >&2
  exit 1
fi

UPDATED_META="$CURRENT_META"
if [ -n "$ARTIFACT_DIR_OVERRIDE" ]; then
  UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg artifact_dir "$ARTIFACT_DIR_OVERRIDE" '.artifact_dir = $artifact_dir')"
fi
UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg status "$STATUS_VALUE" --arg updated_at "$NOW_ISO" '.status = $status | .updated_at = $updated_at')"

if [ -n "$WORKTREE_JSON_PATH" ]; then
  UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --argjson worktree "$(cat "$WORKTREE_JSON_PATH")" '.worktree = $worktree')"
fi

if [ "${#ARTIFACT_UPDATES[@]}" -gt 0 ]; then
  for artifact_update in "${ARTIFACT_UPDATES[@]}"; do
    artifact_key="${artifact_update%%=*}"
    artifact_value="${artifact_update#*=}"
    if [ "$artifact_key" = "$artifact_update" ]; then
      echo "Error: --artifact expects key=value pairs. Received: ${artifact_update}" >&2
      exit 1
    fi
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg key "$artifact_key" --arg value "$artifact_value" '
      .artifacts[$key] = (if $value == "" then null else $value end)
    ')"
  done
fi

case "$STATUS_VALUE" in
  dry-run-verified)
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg timestamp "$NOW_ISO" '.dry_run_verified_at = $timestamp')"
    ;;
  live-posted)
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg timestamp "$NOW_ISO" '.live_posted_at = $timestamp')"
    ;;
  mutation-partial)
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg timestamp "$NOW_ISO" '.mutation_partial_at = $timestamp')"
    ;;
  blocked)
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg timestamp "$NOW_ISO" '.blocked_at = $timestamp')"
    ;;
  draft)
    UPDATED_META="$(printf '%s' "$UPDATED_META" | jq --arg timestamp "$NOW_ISO" '.reopened_at = $timestamp')"
    ;;
esac

replace_round_meta "$REVIEW_DOC_PATH" "$ROUND_NUMBER" "$UPDATED_META"

jq -n \
  --arg action "updated" \
  --arg review_doc_path "$REVIEW_DOC_PATH" \
  --argjson meta "$UPDATED_META" \
  '{action: $action, review_doc_path: $review_doc_path, meta: $meta}'
