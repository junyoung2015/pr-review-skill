# CodeRabbit Comment Triage Guide

How to parse, validate, and classify CodeRabbit comments from PR documents.

---

## Parsing CodeRabbit Sections from PR Documents

PR documents in `docs/pr-for-review/` contain CodeRabbit output embedded as markdown. The key sections are:

### 1. Summary Section

Starts after this HTML comment:

```
<!-- This is an auto-generated comment: release notes by coderabbit.ai -->
## Summary by CodeRabbit
```

Contains bullet-point summary of changes. Use for context, not for triage.

### 2. Walkthrough Section

Starts inside:

```
<!-- walkthrough_start -->
## Walkthrough
```

Contains:

- Prose summary of all changes
- **Changes table** (file paths → description)
- **Sequence diagrams** (if enabled)
- **Estimated review effort** (1-5 scale + time)

### 3. Actionable Comments

After a separator like:

```
# Comment | by CodeRabbit bot | [Date]
**Actionable comments posted: N**
```

Each comment is inside nested `<details>` blocks:

````html
<details>
  <summary>file/path.tsx (N)</summary>
  <blockquote>
    `line-range`: **Title** Description in Korean...

    <details>
      <summary>Suggested fix</summary>
      ```diff - old code + new code
    </details>
  </blockquote>
</details>
````

</details>

<details>
<summary>Prompt for AI Agents</summary>
```
Machine-readable fix instructions...
```
</details>

</blockquote></details>
```

### 4. Nitpick Comments

Inside:

```html
<details>
  <summary>Nitpick comments (N)</summary>
  <blockquote></blockquote>
</details>
```

Same nested structure as actionable comments.

---

## Extraction Process

For each comment, extract:

1. **File path**: From `<summary>` tag (e.g., `apps/web-v2/src/widgets/schedule/ui/place-card/place-card.tsx`)
2. **Line range**: From backtick-wrapped reference (e.g., `` `44-45` `` or `` `142-142` ``)
3. **Title**: Bold text after line range
4. **Description**: Korean text explaining the issue
5. **Suggested fix**: Inside nested `<details>` with diff block (may not exist)
6. **AI Agent Prompt**: Inside "Prompt for AI Agents" details block — machine-readable fix instructions

---

## Validation Process

For each extracted comment:

### Step 1: Check if issue still exists

Read the actual file at the referenced lines. Compare against the description.

**Common reasons an issue may be stale:**

- A later commit on the same branch already fixed it (check `git log --oneline` for the branch)
- CodeRabbit reviewed an earlier commit, not the latest
- The PR doc shows "Files skipped from review as they are similar to previous changes"

### Step 2: Check against project conventions

Cross-reference with CLAUDE.md and `.coderabbit.yaml`:

- CodeRabbit may suggest `YYYY/MM/DD` date format changes — check if the context is an anchor button where space is limited (intentional design choice)
- CodeRabbit may suggest extracting utility functions — check if this aligns with FSD layer rules
- CodeRabbit's `.coderabbit.yaml` profile is `CHILL` — its nitpicks are generally valid but low-priority

### Step 3: Determine if the suggestion is actually correct

CodeRabbit occasionally makes mistakes:

- Suggesting `|| null ||` in a fallback chain (incorrect syntax)
- Flagging code that's already guarded by upstream checks
- Misunderstanding intentional design choices documented in screenshots
- Suggesting changes to code not introduced by this PR (pre-existing debt)

---

## Classification Decision Tree

```
Is the issue still present in the current code?
│
├── NO → DISMISSED
│   Reason: "이후 커밋에서 이미 수정됨" or "이전 리뷰에서 반영됨"
│
└── YES
    │
    ├── Does this contradict a project convention (CLAUDE.md)?
    │   └── YES → DISMISSED
    │       Reason: "프로젝트 컨벤션과 상충" + explain which convention
    │
    ├── Is CodeRabbit's suggestion actually incorrect?
    │   └── YES → DISMISSED
    │       Reason: Explain why the suggestion is wrong
    │
    └── Is the fix mechanical?
        │
        ├── YES (typo, semicolon, formatting, aria-label, conditional render guard)
        │   └── FIX-SELF
        │       Note: Record the one-line fix in the review table
        │
        └── NO
            │
            └── Would the developer learn something important by fixing it?
                │
                ├── YES (architecture, patterns, type system design, error strategy)
                │   └── PASS-TO-CREATOR
                │       Include: Educational Korean explanation (why + how)
                │
                └── NO (simple but multi-line, not educational)
                    └── FIX-SELF
                        Note: Still record in developer profile for pattern tracking
```

---

## Special Cases

### "No actionable comments" message

CodeRabbit sometimes says "No actionable comments were generated" but still includes comments in earlier review rounds. Always check ALL `# Comment | by CodeRabbit bot` sections in the PR doc.

### Incremental reviews

If the PR doc shows multiple CodeRabbit comment rounds (different timestamps), focus on the **latest** round. Earlier rounds may reference code that's already been updated.

### Prompt for AI Agents blocks

These contain machine-readable instructions. They're useful for understanding CodeRabbit's intent but should NOT be blindly executed. Always validate against the actual code first.

---

## Zero CodeRabbit Comments Protocol

When the PR doc contains 0 CodeRabbit comments (no Actionable and no Nitpick sections), follow this protocol.

### Why Zero Comments Happen

- **Free plan limit**: CodeRabbit Free allows limited reviews per month. When exhausted, the bot may still produce a Walkthrough/Summary but no line-level comments.
- **Not configured**: The repo may not have CodeRabbit enabled for this branch or PR.
- **Clean code**: Rarely, CodeRabbit genuinely finds nothing (unlikely for non-trivial PRs).

### Handling Steps

1. **Check for Walkthrough section**: If `## Walkthrough` exists, validate its accuracy:
   - Cross-reference the Changes table with `git diff dev..HEAD --name-only`
   - Build a verification table:
     ```markdown
     | Walkthrough 항목          | 실제 코드 확인          | 정확도 |
     | ------------------------- | ----------------------- | ------ |
     | "PlaceCard 컴포넌트 분리" | ✅ 3개 모드별 파일 확인 | 정확   |
     ```
   - Note inaccuracies as informational (Walkthrough is AI-generated, not code)

2. **State clearly in the review document**:

   ```markdown
   ## CodeRabbit 코멘트 검증

   CodeRabbit 코멘트가 없습니다 (Free 플랜 제한 또는 미설정).
   본 리뷰는 코드 직접 분석을 기반으로 작성되었습니다.
   ```

3. **Do NOT treat this as a blocker**: The review's substance comes from Step 4 (Deep Code Review), not from CodeRabbit triage. Proceed normally with all other steps.

4. **If Walkthrough also absent**: Simply state "CodeRabbit 출력 없음" and move on.

---

## Scope-Aware Dismissal Patterns

When a branch contains commits from multiple tickets (common in long-lived feature branches), apply scope-aware triage.

### Determining Scope from Commit Messages

1. Extract the PR's ticket ID from the branch name or PR title (e.g., `ACME-595`)
2. Run `git log dev..HEAD --oneline` and categorize each commit:
   - `♻️ [ACME-595] 일정 상세 수정` → **IN_SCOPE** (matches PR ticket)
   - `🐛 [ACME-600] 로그인 버그 수정` → **OUT_OF_SCOPE** (different ticket)
   - `chore: update deps` → **IN_SCOPE** (no ticket = assumed part of PR work)
3. Map each commit's changed files to scope:
   ```bash
   git diff-tree --no-commit-id --name-only -r <commit-hash>
   ```

### Scope-Aware Dismissal in Triage Tables

When a CodeRabbit comment targets an OUT_OF_SCOPE file, dismiss it:

```markdown
| #   | 파일                                  | CodeRabbit 의견  | 기각 사유                        |
| --- | ------------------------------------- | ---------------- | -------------------------------- |
| 3   | `views/login/ui/login.tsx`            | 로그인 폼 접근성 | 스코프 외 ([ACME-600] 커밋 소속) |
| 7   | `shared/config/i18n/messages/en.json` | 번역 키 정리     | 스코프 외 (별도 작업)            |
```

### Consolidated Footer for Multiple Scope Dismissals

When 5+ comments are dismissed due to scope, consolidate into a footer instead of listing each:

```markdown
### ❌ 기각 (Dismissed) — 8건

| #   | 파일                | CodeRabbit 의견 | 기각 사유              |
| --- | ------------------- | --------------- | ---------------------- |
| 1   | `place-card.tsx:44` | 조건부 렌더링   | 이후 커밋에서 수정됨   |
| 2   | `place-memo.tsx:12` | null 체크       | 프로젝트 컨벤션과 상충 |

> 📌 **스코프 외 기각 6건**: `login.tsx`, `en.json`, `ko.json` 외 3개 파일은 본 PR의 티켓([ACME-595]) 스코프 밖의 변경으로 기각되었습니다. 해당 파일의 코멘트는 각 파일의 원래 PR에서 다룹니다.
```

### Exception: Obvious Bugs in Out-of-Scope Files

Even for OUT_OF_SCOPE files, flag these if found:

- Null pointer dereference / runtime crash risk
- Security vulnerability (XSS, injection)
- Data loss risk
- Build-breaking change

Mark these as: `⚠️ 스코프 외이지만 심각한 이슈 발견`
