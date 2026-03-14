# Fix-Forward Template

Template for appending reviewer-applied fixes to an existing review document.
Used when the reviewer decides to fix issues directly instead of waiting for the PR creator.

---

## When to Use

Trigger this template when the user indicates they will fix issues themselves. Common triggers:

- "직접 수정", "내가 고칠게", "시간이 없어서 내가 수정"
- "fix it myself", "fix it ourselves", "I'll handle the fixes"
- "Fix-Forward mode", "fix-forward"
- Any prompt indicating the reviewer will apply fixes after completing the review

---

## Canonical Round Shape

Every managed round must use this exact heading format:

```markdown
## 리뷰어 직접 수정 사항 (Reviewer Fixes Applied) - Round {N}
```

Every managed round must include **two fenced JSON blocks** with these exact marker comments so scripts can read them safely:

````markdown
### round_meta

<!-- round_meta:start round={N} -->
```json
{ ... }
```
<!-- round_meta:end round={N} -->

### round_decisions

<!-- round_decisions:start round={N} -->
```json
[
  ...
]
```
<!-- round_decisions:end round={N} -->
````

`round_meta` is the source of truth for PR metadata, provider review ids, worktree metadata, artifact paths, and the current round status.

`round_decisions` is the canonical machine-readable decision list. Scripts must read `verdict` and `reason` from this block only, never from prose.

---

## Required `round_meta` Fields

Use this shape:

```json
{
  "managed_by": "pr-review@0.2.2",
  "round_number": 2,
  "status": "draft",
  "created_at": "2026-03-13T08:24:00Z",
  "updated_at": "2026-03-13T08:24:00Z",
  "pr_number": 161,
  "ticket_id": "MOVE-658",
  "repo": "demodev-lab/moving-frontend",
  "branch": "MOVE-658/social-login-native",
  "head_sha": "abc123...",
  "review_source": "all",
  "provider_review_ids": {
    "coderabbit": 123456789,
    "copilot": 987654321
  },
  "latest_comment_ids": {
    "coderabbit": [111, 112],
    "copilot": [221, 222]
  },
  "artifact_dir": ".pr-review/pr-161/round-2",
  "artifacts": {
    "review_data_json": "/abs/path/to/review-data.json",
    "decisions_json": null,
    "reply_output": null,
    "resolve_output": null
  },
  "worktree": {
    "status": "ready",
    "worktree_mode": "auto",
    "worktree_path": "/abs/path/to/worktree",
    "push_remote": "origin",
    "push_branch": "MOVE-658/social-login-native"
  }
}
```

Allowed round status transitions:

- `draft` -> `dry-run-verified`
- `dry-run-verified` -> `live-posted`
- `dry-run-verified` -> `mutation-partial`
- `dry-run-verified` -> `blocked`
- `mutation-partial` -> `live-posted`
- `blocked` -> `draft`

Any other transition should fail fast.

---

## Required `round_decisions` Shape

A newly created managed round must pre-populate one `pending` row for every latest selected provider comment:

```json
[
  {
    "provider": "copilot",
    "review_id": 987654321,
    "comment_id": 2922644080,
    "path": "apps/web-v2/src/views/login/actions/web-oauth-login-action.ts",
    "line": 18,
    "verdict": "pending",
    "reason": "",
    "owner": ""
  }
]
```

Rules:

- `verdict` must be exactly one of `pending`, `accepted`, `declined`
- `reason` is required for `accepted` and `declined`
- `owner` is optional and may be used for handoff notes
- `comment_id` and `review_id` must map to the latest selected provider round only
- `--live` must fail if any selected entry remains `pending`

---

## Full Markdown Template

Append the following to the **end** of the existing review document (`docs/reviews/[TICKET-ID]-review.md`) after a `---` separator.

````markdown
## 리뷰어 직접 수정 사항 (Reviewer Fixes Applied) - Round {N}

**Date:** {YYYY-MM-DD HH:MM}
> {1-line context: e.g. "Auto-mode round prepared for PR #161 with --review-source all"}
> Update every `round_decisions` verdict from `pending` to `accepted` or `declined` before `--live`.

### round_meta

<!-- round_meta:start round={N} -->
```json
{
  "managed_by": "pr-review@0.2.2",
  "round_number": {N},
  "status": "draft",
  "...": "..."
}
```
<!-- round_meta:end round={N} -->

### round_decisions

<!-- round_decisions:start round={N} -->
```json
[
  {
    "provider": "copilot",
    "review_id": 123,
    "comment_id": 456,
    "path": "src/foo.ts",
    "line": 42,
    "verdict": "pending",
    "reason": "",
    "owner": ""
  }
]
```
<!-- round_decisions:end round={N} -->

### 수정된 항목

| # | 파일 | 수정 내용 | 원래 분류 | 이유 |
|---|------|----------|-----------|------|
| 1 | `file.tsx` | 변경 내용 — 상세 설명 | {Fix-Self|Pass-to-Creator} {🔴|🟡|🟢} | 수정 판단 이유 |

### 미수정 항목

| # | 파일 | 원래 내용 | 미수정 사유 | 검증 방법 |
|---|------|----------|-----------|----------|
| 1 | `file.tsx` | 원래 리뷰 지적 내용 | 미수정 판단 사유 | 검증에 사용한 방법 |

---

## {reviewer_github_id}'s Comment

### 수정사항

- `file-a.tsx`
  - 변경 내용 — 이유
- `file-b.tsx`, `file-c.tsx`
  - 공통 변경 내용 — 이유

### 피드백

- [Educational point 1: 코드 패턴, 아키텍처, 또는 주의사항에 대한 설명]
- [Educational point 2: 다음 PR에서 주의할 점]

### 기타

- [선택사항: 후속 작업 안내, 관련 티켓 링크 등]
````

---

## Field Guidelines

### 수정된 항목 Table

| Column | Format | Description |
|--------|--------|-------------|
| `#` | Sequential number | 1-indexed |
| `파일` | `` `path/to/file.tsx` `` | Backtick-wrapped relative path. Group multiple files with `, ` if same change |
| `수정 내용` | Free text | Concise description of what changed + why |
| `원래 분류` | `{Fix-Self\|Pass-to-Creator} {🔴\|🟡\|🟢}` | Two tokens only: action type + severity emoji |
| `이유` | Free text | Why the reviewer fixed it directly |

### 미수정 항목 Table

| Column | Format | Description |
|--------|--------|-------------|
| `#` | Sequential number | 1-indexed |
| `파일` | `` `path/to/file.tsx` `` | Backtick-wrapped |
| `원래 내용` | Free text | Original review finding that was not fixed |
| `미수정 사유` | Free text | Why it was not fixed |
| `검증 방법` | Free text | How the skip decision was verified |

### Comment Section

| Subsection | Required | Description |
|------------|----------|-------------|
| `수정사항` | ✅ Yes | File-grouped bullet list of all changes |
| `피드백` | ✅ Yes | 1-3 educational points for the PR author |
| `기타` | Optional | Follow-up tickets, related context, or other notes |

---

## Notes

- Legacy review docs without structured metadata remain valid. Start using the managed JSON blocks with the first `v0.2.2`-managed round only.
- Keep previous rounds read-only. New rounds append; they do not rewrite earlier rounds.
- `round_decisions` is the authoritative source for generated decisions artifacts and GitHub mutation previews.
- In worktree mode, treat the worktree copy of the review doc as the editable document for Round N. The source-clone copy is only the seed.
