# PR Review Output Template

Use this exact structure for the review document.

```markdown
# PR Review: [TICKET-ID] Title

**리뷰어**: Eddie | **작성자**: @github-id | **날짜**: YYYY/MM/DD
**브랜치**: branch-name | **소요 시간**: ~N분

---

## 요약 (Summary)

[2-3 sentences. Always start with something positive. Then overall assessment.]

## 스코프 확인 (Scope Note)

[Only include if OUT_OF_SCOPE files exist. Otherwise omit this section entirely.]

> 📌 이 브랜치에는 [TICKET-ID] 외 다른 티켓의 커밋이 포함되어 있습니다.
> 본 리뷰는 [TICKET-ID] 스코프의 파일([N]개)에 집중하고, 스코프 외 파일([M]개)은 skim 수준으로 확인했습니다.

## PR 기술 검증 (Git-Truth Validation)

| PR 문서 주장      | 실제 코드             | 일치 여부 |
| ----------------- | --------------------- | --------- |
| [Feature claim 1] | [Verification result] | ✅/❌/⚠️  |

[Brief note if discrepancies found, otherwise: "PR 문서와 실제 코드가 일치합니다."]

## 코드 리뷰 결과 (Code Review Findings) ← PRIMARY

**총 X건**: 🔴 HIGH A건 / 🟡 MEDIUM B건 / 🟢 LOW C건

### ✅ 내가 직접 수정 (I'll fix) — X건

| #   | 심각도 | 파일        | 내용       | 수정 방법        |
| --- | ------ | ----------- | ---------- | ---------------- |
| 1   | 🔴     | `path:line` | 한 줄 설명 | 구체적 수정 내용 |

### 📚 작성자에게 전달 (Pass to creator) — Y건

#### 🔴 [카테고리: e.g., React Patterns]

**파일**: `path/to/file.tsx:52-54`
**심각도**: 🔴 HIGH — [merge 영향: e.g., "머지 전 수정 필요"]
**문제**: [무엇이 문제인지 — 간결하게]
**이유**: [왜 이것이 중요한지 — 교육적 설명]
**제안**: [어떻게 고치면 좋은지 — 구체적 코드 예시 포함]

---

## AI 리뷰 코멘트 검증 (Triage) ← SECONDARY

[If Quick Review mode or `--review-source none`: OMIT THIS ENTIRE SECTION — do not render it at all.]

[If one or more providers were selected but all of them have 0 comments:]

> AI 리뷰 코멘트가 없습니다.
> 본 리뷰는 코드 직접 분석을 기반으로 작성되었습니다.

[If comments exist:]
**총 N건**: Fix-Self X건 / Pass-to-Creator Y건 / Dismissed Z건

### GitHub Copilot — N건

[If GitHub Copilot has 0 comments:]

> GitHub Copilot 코멘트가 없습니다 (미실행, 자동 리뷰 미설정, 또는 최신 라운드 코멘트 없음).

[If GitHub Copilot comments exist:]
**총 N건**: Fix-Self X건 / Pass-to-Creator Y건 / Dismissed Z건

#### ✅ 내가 직접 수정 (I'll fix) — X건

| #   | 심각도 | 파일        | 내용       | 수정 방법        |
| --- | ------ | ----------- | ---------- | ---------------- |
| 1   | 🟡     | `path:line` | 한 줄 설명 | 구체적 수정 내용 |

#### 📚 작성자에게 전달 (Pass to creator) — Y건

[Same educational format as code review findings, with 심각도 field]

#### ❌ 기각 (Dismissed) — Z건

| #   | 파일   | GitHub Copilot 의견 | 기각 사유 |
| --- | ------ | ------------------- | --------- |
| 1   | `path` | 요약                | 사유      |

### CodeRabbit — N건

[If CodeRabbit has 0 comments:]

> CodeRabbit 코멘트가 없습니다 (Free 플랜 제한 또는 미설정).

[If CodeRabbit comments exist:]
**총 N건**: Fix-Self X건 / Pass-to-Creator Y건 / Dismissed Z건

#### ✅ 내가 직접 수정 (I'll fix) — X건

| #   | 심각도 | 파일        | 내용       | 수정 방법        |
| --- | ------ | ----------- | ---------- | ---------------- |
| 1   | 🟡     | `path:line` | 한 줄 설명 | 구체적 수정 내용 |

#### 📚 작성자에게 전달 (Pass to creator) — Y건

[Same educational format as code review findings, with 심각도 field]

#### ❌ 기각 (Dismissed) — Z건

| #   | 파일   | CodeRabbit 의견 | 기각 사유 |
| --- | ------ | --------------- | --------- |
| 1   | `path` | 요약            | 사유      |

[If 5+ scope dismissals, use consolidated footer format]

## 작성자 피드백 (Feedback for @github-id)

### 잘한 점 (Strengths)

- [구체적인 칭찬 — 무엇을 잘했는지 명시]
- [다른 팀원이 참고할 만한 좋은 패턴이 있다면 언급]

### 학습 포인트 (Learning Points)

[Pass-to-Creator 항목들을 교육적으로 재정리. 패턴별 그룹핑.]

> 💡 **[패턴 이름]**
> [왜 이것이 중요한지 2-3문장 설명]
> [코드 예시가 있으면 포함]

### 다음 PR에서 신경 쓸 점

1. [구체적이고 실행 가능한 조언 — "~를 제출 전에 확인해보세요"]
2. [선택적 두 번째 조언]
```
