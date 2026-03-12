# Korean Feedback Templates for PR Review

Use these templates as a starting point. Adapt the phrasing to the specific context of each finding. Always sound like a supportive senior developer mentoring a colleague.

---

## 칭찬 (Praise)

Use in the "잘한 점 (Strengths)" section. Be specific — generic praise is unconvincing.

### Component Design
- "컴포넌트 분리 전략이 깔끔합니다. 각 모드별 책임이 명확하게 나뉘어 있어요."
- "공통 요소를 잘 추출해서 재사용성이 높아졌습니다."
- "컴포넌트 간 의존성이 최소화되어 있어 독립적으로 수정하기 쉬운 구조예요."

### Code Quality
- "에러 처리가 꼼꼼합니다. edge case를 잘 고려했어요."
- "타입 안전성이 잘 유지되고 있어요. 런타임 에러 가능성이 낮습니다."
- "네이밍이 직관적이라 코드의 의도가 바로 읽힙니다."

### Architecture
- "FSD 레이어 규칙을 잘 지키고 있어요. import 방향이 깔끔합니다."
- "barrel export 구조가 잘 정리되어 있어 외부에서 사용하기 편리합니다."

### Testing & Documentation
- "테스트 커버리지가 충분합니다. 핵심 시나리오가 모두 포함되어 있어요."
- "커밋 메시지가 변경 의도를 잘 설명하고 있어요."

---

## 교육적 설명 (Educational Explanation)

Use in Pass-to-Creator items and "학습 포인트" section. Explain the "why", not just the "what".

### Pattern: [개념] → [왜 중요한지] → [어떻게]

**React Patterns:**
- "React에서 `useEffect`의 dependency array는 '이 값이 바뀔 때 다시 실행해라'라는 의미입니다. 빈 배열 `[]`은 마운트 시 1번만 실행하라는 뜻이에요. 지금처럼 `[isOpen]`만 넣으면 `placeData`가 바뀌어도 form이 업데이트되지 않습니다."
- "조건부 렌더링에서 falsy 값이 빈 DOM 노드를 만들 수 있어요. `{memo && <p>...</p>}` 패턴으로 memo가 없을 때 아예 렌더링하지 않는 게 좋습니다. 불필요한 DOM 노드는 레이아웃에 영향을 줄 수 있거든요."
- "컴포넌트에서 inline으로 정의한 함수는 매 렌더마다 새 참조가 생깁니다. 이걸 자식 컴포넌트에 props로 넘기면 불필요한 re-render가 발생할 수 있어요. `useCallback`으로 감싸면 참조가 안정됩니다."

**TypeScript:**
- "`.d.ts` 파일에서 `export` 없이 선언하면 전역 ambient 타입이 됩니다. 프로젝트가 커지면 네이밍 충돌이 생길 수 있어요. 명시적으로 `export interface`를 사용하면 모듈 격리가 보장됩니다."
- "같은 역할의 타입이 여러 파일에 흩어져 있으면 어떤 게 정답인지 헷갈립니다. single source of truth를 정하고 다른 곳에서 import하는 패턴을 추천합니다."

**Error Handling:**
- "unknown 값을 조용히 기본값으로 대체하면 (`?? 'bus'`), 백엔드에서 새로운 transport type을 추가했을 때 프론트에서 잘못된 동작을 알아채지 못합니다. 명시적으로 에러를 던지거나 로깅하면 문제를 빨리 발견할 수 있어요."
- "모달을 닫은 후 mutation을 실행하면, 실패 시 사용자에게 피드백을 줄 수가 없어요. mutation이 성공한 후에 닫는 게 UX 관점에서 안전합니다."

**Architecture / FSD:**
- "순수 유틸리티 함수가 UI 컴포넌트 파일 안에 있으면 테스트하기 어렵고, 다른 곳에서 재사용할 때 불필요한 UI 의존성이 생깁니다. `lib/` 또는 `utils/`로 분리하면 테스트도 쉽고 FSD 구조도 깔끔해져요."
- "widgets 레이어 간 import는 FSD에서 금지되어 있어요. 같은 레이어의 다른 slice에서 필요한 코드가 있다면, 아래 레이어(features나 entities)로 내려야 합니다."

**Accessibility:**
- "아이콘만 있는 버튼은 시각적으로는 의미가 명확하지만, 스크린 리더 사용자는 '버튼'이라고만 읽힙니다. `aria-label`을 추가하면 누구나 이 버튼의 용도를 알 수 있어요."
- "`<button>` 요소는 기본적으로 Enter/Space 키 이벤트를 처리합니다. 별도의 `onKeyDown` 핸들러는 중복이에요."

---

## 간결한 수정 (Concise Fix Description)

Use in Fix-Self tables. One-line, action-oriented.

- "세미콜론 누락" / "Missing semicolon"
- "불필요한 빈 줄 제거"
- "`aria-label` 추가 권장"
- "빈 태그 조건부 렌더링 필요"
- "함수 시그니처 멀티라인 포맷팅"
- "하드코딩된 색상 → 시맨틱 토큰"
- "중복 `tabIndex` 및 `onKeyDown` 제거"
- "미사용 상수 제거"

---

## 반복 이슈 (Recurring Issue Escalation)

When a developer has 3+ entries in the same category across PRs.

### Mild (3-4 occurrences)
- "이 패턴이 이전 PR들에서도 나타났습니다 ([TICKET-1], [TICKET-2]). 이 부분을 의식적으로 체크하는 습관을 들이면 좋겠어요."
- "비슷한 피드백이 반복되고 있어요. 이번 기회에 이 개념을 확실히 정리해봅시다."

### Strong (5+ occurrences)
- "같은 카테고리의 피드백이 여러 번 나오고 있습니다. 이 영역에 대한 자기 학습 시간을 갖는 것을 추천드려요."
- "PR 제출 전 체크리스트에 이 항목을 추가하면 도움이 될 거예요."

---

## 다음 PR 조언 (Next PR Advice)

Use in "다음 PR에서 신경 쓸 점" section. Concrete, actionable.

- "다음 PR에서는 `useEffect` 작성 시 dependency array를 먼저 채우고, 불필요한 항목을 빼는 순서로 접근해보세요."
- "새 컴포넌트를 만들 때 접근성 체크리스트를 한 번 돌려보세요: 모든 버튼에 텍스트나 aria-label이 있는지, 키보드로 조작 가능한지."
- "PR 제출 전에 `git diff` 결과를 쭉 읽어보면서 불필요한 빈 줄이나 포맷팅 이슈를 정리하면 리뷰 속도가 빨라집니다."
- "FSD import 방향이 맞는지 확인하는 가장 쉬운 방법: 'import from' 경로가 같은 레이어나 위 레이어를 가리키고 있지 않은지 체크."
- "타입 정의 시 '이 타입이 어디서 import되는가?'를 먼저 생각해보면 ambient vs explicit export 판단이 쉬워집니다."

---

## Git-Truth 검증 피드백 (Git-Truth Validation Feedback)

Use in the "PR 기술 검증" section when PR doc claims don't match the actual diff.

### Claim Not Verified
- "PR 문서에서 언급된 [기능/변경]이 실제 diff에서 확인되지 않습니다. 커밋 이력을 재확인해주세요."
- "문서에는 [파일명]의 변경이 기술되어 있지만, `git diff` 기준으로 해당 파일은 변경되지 않았습니다."

### Undocumented Changes
- "PR 문서에 기술되지 않은 변경사항이 발견되었습니다: [파일 목록]. 의도된 변경인지 확인이 필요합니다."
- "diff 기준으로 [N]개 파일이 변경되었지만, PR 문서의 파일 트리에는 [M]개만 나열되어 있습니다."

### Inaccurate File Tree
- "PR 문서의 변경 파일 목록이 실제 diff와 일치하지 않습니다. 아래 검증 테이블을 참고해주세요."

### Verification Table Templates
```markdown
| PR 문서 주장 | 실제 코드 | 일치 여부 |
|-------------|----------|----------|
| [기능 설명] | ✅ [확인 내용] | ✅ 일치 |
| [기능 설명] | ❌ [불일치 내용] | ❌ 불일치 |
| — (미기술) | ⚠️ [발견된 변경] | ⚠️ 문서 누락 |
```

---

## 스코프 관련 피드백 (Scope-Related Feedback)

Use for multi-ticket branches where some files are outside the PR's ticket scope.

### Scope Notes (top of review)
- "이 브랜치에는 [TICKET-ID] 외 다른 티켓의 커밋이 포함되어 있습니다. 본 리뷰는 [TICKET-ID] 스코프의 파일에 집중하고, 스코프 외 파일은 skim 수준으로 확인했습니다."
- "📌 **스코프 참고**: `git log` 기준, [N]개 커밋 중 [M]개가 [TICKET-ID] 소속이며, [K]개가 다른 티켓 소속입니다."

### Scope Dismissal Footer
- "📌 **스코프 외 기각 [N]건**: [파일 목록 요약]은 본 PR의 티켓([TICKET-ID]) 스코프 밖의 변경으로 기각되었습니다. 해당 파일의 코멘트는 각 파일의 원래 PR에서 다룹니다."

### Scope Overflow Advice
- "다음 PR에서는 하나의 티켓에 해당하는 변경만 포함하면 리뷰 범위가 명확해져서 더 빠른 리뷰가 가능합니다."
- "브랜치에 여러 티켓의 변경이 섞이면 리뷰어가 스코프를 파악하는 데 시간이 더 걸립니다. 가능하면 티켓별로 브랜치를 분리해주세요."

---

## 최소 이슈 재검토 피드백 (Minimum Issue Re-examination Feedback)

Use when the Section K re-examination finds no additional issues.

### Code Quality is Good
- "코드 품질이 양호합니다. Section K 재검토 결과 추가 이슈가 발견되지 않았습니다."
- "edge case, 형제 컴포넌트 일관성, 통합 포인트 등을 추가 검토했으나 특이사항 없습니다."

### When Re-examination Does Find Issues
- "초기 검토에서 놓친 항목이 재검토에서 발견되었습니다:"
- "[카테고리]: [발견 내용] — 이 부분은 [이유]로 인해 확인이 필요합니다."

### Trivial PR (fewer than 3 files, simple logic)
- "이 PR은 변경 범위가 작아 (파일 [N]개, 단순 로직) 최소 이슈 재검토를 생략합니다."
