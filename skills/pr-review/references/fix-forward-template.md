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

## Template

Append the following to the **end** of the existing review document (`docs/reviews/[TICKET-ID]-review.md`), after the last `---` separator.

### Round Numbering

- First time fixing: `Round 1`
- If new CodeRabbit comments or issues arise after Round 1 fixes: `Round 2`
- Continue incrementing for subsequent rounds

### Markdown Template

````markdown
## 리뷰어 직접 수정 사항 (Reviewer Fixes Applied) - Round {N}

**Date:** {YYYY-MM-DD HH:MM}
> {1-line context: e.g., "시간 부족으로 Fix-Self + Pass-to-Creator 전체를 직접 수정"}
> Typecheck: {✅/❌} `pnpm typecheck`

### 수정된 항목

| # | 파일 | 수정 내용 | 원래 분류 | 이유 |
|---|------|----------|-----------|------|
| 1 | `file.tsx` | 변경 내용 — 상세 설명 | {Fix-Self|Pass-to-Creator} {🔴|🟡|🟢} | 수정 판단 이유 |

### 미수정 항목

| # | 파일 | 원래 내용 | 미수정 사유 | 검증 방법 |
|---|------|----------|-----------|----------|
| 1 | `file.tsx` | 원래 리뷰 지적 내용 | 미수정 판단 사유 | 검증에 사용한 방법 |

(미수정 항목이 없으면: "없음")

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
| `수정 내용` | Free text | Concise description of what was changed + why (use `—` dash separator) |
| `원래 분류` | `{Fix-Self\|Pass-to-Creator} {🔴\|🟡\|🟢}` | Two tokens only: action type + severity emoji. No free-text variations |
| `이유` | Free text | Why the reviewer fixed it directly (e.g., "1줄 방어 코드, 즉시 수정 가능", "시간 부족으로 직접 수정") |

### 미수정 항목 Table

| Column | Format | Description |
|--------|--------|-------------|
| `#` | Sequential number | 1-indexed |
| `파일` | `` `path/to/file.tsx` `` | Backtick-wrapped |
| `원래 내용` | Free text | Original review finding that was not fixed |
| `미수정 사유` | Free text | Why it was not fixed (e.g., "CodeRabbit 오판", "별도 티켓으로 분리 권장", "API 미연결 상태로 수정 불가") |
| `검증 방법` | Free text | How the skip-decision was verified (e.g., "`pnpm typecheck` 제거 시 실패 확인", "`grep -rn TravelMode` 사용처 확인") |

### Comment Section

| Subsection | Required | Description |
|------------|----------|-------------|
| `수정사항` | ✅ Yes | File-grouped bullet list of all changes. Group related files on one line. Each sub-bullet: `변경 내용 — 이유` |
| `피드백` | ✅ Yes | 1-3 educational points for the PR author. Focus on patterns, not individual fixes. This is the learning opportunity — even when the reviewer fixes things, the author should understand *why* |
| `기타` | Optional | Follow-up tickets, related context, or anything that doesn't fit above |

---

## Examples

### Minimal (small PR, few fixes)

```markdown
## 리뷰어 직접 수정 사항 (Reviewer Fixes Applied) - Round 1

**Date:** 2026-03-03 14:30
> 시간 부족으로 전체 이슈를 직접 수정
> Typecheck: ✅ `pnpm typecheck`

### 수정된 항목

| # | 파일 | 수정 내용 | 원래 분류 | 이유 |
|---|------|----------|-----------|------|
| 1 | `lounge-card.tsx` | 날짜 포맷 `MM-dd-yyyy` → `dd-MM-yyyy` | Fix-Self 🟡 | 기계적 포맷 변경 |
| 2 | `mocks.ts` | dead export `MOCK_LOUNGE_INFO`, `MOCK_CITIES` 제거 | Fix-Self 🟢 | 미사용 코드 정리 |

### 미수정 항목

없음

---

## junyoung2015's Comment

### 수정사항

- `lounge-card.tsx`
  - 날짜 포맷 `MM-dd-yyyy` → `dd-MM-yyyy` (프로젝트 표준)
- `mocks.ts`
  - dead export 2개 제거 (`MOCK_LOUNGE_INFO`, `MOCK_CITIES`)

### 피드백

- 날짜 포맷은 프로젝트 표준 `dd-MM-yyyy`를 기본으로 사용해주세요. 형제 컴포넌트와 일관성을 유지하는 것이 중요합니다.
```

### With 미수정 항목 (false positive case)

```markdown
### 미수정 항목

| # | 파일 | 원래 내용 | 미수정 사유 | 검증 방법 |
|---|------|----------|-----------|----------|
| 1 | `completed-trip-transportation-route.tsx` | `type TravelMode` import 제거 | CodeRabbit 오판: 내부 `TransportationStop` prop에서 실사용 중 | `pnpm typecheck` — import 제거 시 타입 에러 발생 확인 |
```
