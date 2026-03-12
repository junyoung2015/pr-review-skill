# PR Review Criteria Checklist

This checklist is derived from CLAUDE.md project conventions and .coderabbit.yaml path-specific rules. Walk through each section for every changed file.

---

## A. FSD Layer Compliance

### Import Direction Rules (Strict)

```
app/ → views/ → widgets/ → features/ → entities/ → shared/
Each layer imports ONLY from layers below it.
Cross-slice imports at the same layer are FORBIDDEN.
```

**Check for each file:**

- [ ] No upward imports (e.g., widget importing from views)
- [ ] No cross-slice imports (e.g., `views/schedule` importing from `views/login`)
- [ ] Barrel exports used for public API of each module

### API Location Rules

| Layer                      | What belongs here                                                                      |
| -------------------------- | -------------------------------------------------------------------------------------- |
| `shared/api/`              | HTTP clients (`client.ts`, `server.ts`, `base.ts`), `safeResponseJson`, response types |
| `shared/config/auth/`      | NextAuth.js configuration, JWT callbacks, session management                           |
| `entities/<domain>/api.ts` | Domain CRUD operations (getTerms, getProfile)                                          |
| `widgets/<widget>/api/`    | Widget-scoped data fetching                                                            |
| `views/<view>/api/`        | Page-specific form mutations                                                           |
| `views/<view>/actions/`    | Next.js server actions                                                                 |

**Check:** Are API calls placed in the correct layer?

### Export Patterns

- In `_source` folders: `export const ComponentName = () => {}` (named exports only)
- `export default` ONLY in: `page.tsx`, `layout.tsx`, `not-found.tsx`, `error.tsx`

---

## B. React & TypeScript Conventions

### React Hook Form

- [ ] Uses `useWatch()` instead of `watch()` — prevents unnecessary re-renders
- [ ] `useWatch({ control, name: 'fieldName' })` for specific field watching

### useEffect Dependencies

- [ ] All values used inside useEffect are listed in the dependency array
- [ ] Or explicitly disabled with ESLint comment + explanation
- [ ] No stale closures from empty `[]` dependency arrays that should have dependencies

### Conditional Rendering

- [ ] No empty DOM elements rendered when data is falsy (e.g., `{memo && <p>...</p>}`)
- [ ] Early returns for missing required data (e.g., `if (!data) return null`)

### Type Safety

- [ ] No `any` types — use proper generics or `unknown` with type guards
- [ ] Props interfaces defined for components with 3+ props
- [ ] Optional props marked with `?`, not defaulted to `undefined`
- [ ] Explicit `export` on type declarations in `.d.ts` files (avoid ambient globals)

---

## C. UI / Design System

### Semantic Tokens

- [ ] No hardcoded color values (e.g., `#2375D9`, `rgb(...)`)
- [ ] Use semantic tokens: `color="grey.10"`, `bg="background.basic.1"`
- [ ] SVG fills use CSS variables: `fill="var(--color-primary-4)"`

### Layout Patterns

- [ ] `gap` for spacing between sibling sections, not `padding`
- [ ] Parent container controls spacing with `gap`; children don't add external margin
- [ ] Clear distinction between container spacing (`gap`) and internal padding (`padding`)

### Interactive Elements

- [ ] `_hover` states on all interactive list items
- [ ] No conditional background colors by index (`bg={index === 0 ? ... : ...}`)
- [ ] Prefer `<button>` over `<div role="button">` for clickable elements

---

## D. Error Handling

### API Error Handling

- [ ] Uses `safeResponseJson` from `@/shared/api` in catch blocks
- [ ] Never uses raw `error.response.json()` (can throw on empty body)
- [ ] No nested try-catch for JSON parsing

### Mutation Error Handling

- [ ] User sees feedback on mutation failure (toast, error state, etc.)
- [ ] Modal/sheet stays open on mutation error (don't close before confirming success)
- [ ] No silent swallowing of errors

---

## E. Data Formatting

### Date Handling

- [ ] Storage format: ISO8601 with timezone (`2025-08-18T00:00:00+00:00`)
- [ ] Display format: `YYYY/MM/DD` for user-facing dates
- [ ] Never use `new Date(dateString)` with date-only strings (timezone shift risk)
- [ ] Use date-fns `format()` or project utility for date formatting

### Number Formatting

- [ ] Currency/costs formatted with locale-appropriate separators
- [ ] Duration displayed in user-friendly format (not raw minutes/seconds)

---

## F. Accessibility

### Interactive Elements

- [ ] All icon-only buttons have `aria-label` describing their purpose
- [ ] Decorative icons have `aria-hidden="true"`
- [ ] No redundant `onKeyDown` handlers on `<button>` elements (native behavior suffices)
- [ ] No redundant `tabIndex={0}` on natively focusable elements

### Semantic HTML

- [ ] Clickable elements use `<button>` or `<a>`, not `<div>` with click handlers
- [ ] Form inputs have associated labels
- [ ] Headings follow hierarchy (no skipping h1 → h3)

---

## G. Security

### Data Protection

- [ ] No secrets, tokens, or API keys in source code
- [ ] No `console.log` of sensitive data without `__DEV__` guard
- [ ] Input validation at system boundaries (user input, external APIs)

### Safe Operations

- [ ] Retry disabled for destructive operations (DELETE, etc.)
- [ ] No `dangerouslySetInnerHTML` without sanitization
- [ ] URL construction uses proper encoding

---

## H. Performance

### React Optimization

- [ ] `useCallback` for functions passed as props to child components
- [ ] `useMemo` for expensive computations in render
- [ ] No inline object/array creation in JSX props (causes unnecessary re-renders)
- [ ] Large lists use virtualization or pagination

### Network

- [ ] No N+1 query patterns (fetching in loops)
- [ ] Timeout protection on network/bridge calls
- [ ] Proper loading states during data fetching

---

## I. DRY / Code Organization

### Duplication

- [ ] No identical class strings repeated across 3+ files (extract to constant or utility)
- [ ] No identical logic blocks across sibling components (extract to shared hook or utility)
- [ ] Shared utilities in correct FSD layer (not inline in component files)

### File Organization

- [ ] Pure utility functions not embedded in UI component files
- [ ] Type definitions in dedicated `.types.ts` or `.d.ts` files when shared
- [ ] Barrel exports (`index.ts`) properly maintained when adding/removing exports

---

## J. Git-Truth Validation

Verify PR document claims against the actual git diff. The diff is the single source of truth — the PR doc is just a description.

### PR Claims vs Actual Diff

- [ ] Run `git diff dev..HEAD --name-only` to get the authoritative changed file list
- [ ] Cross-reference with PR doc's file tree / Changes table — flag any discrepancies:
  - **Undocumented changes**: Files in diff but missing from PR doc
  - **Phantom files**: Files listed in PR doc but NOT in the actual diff
  - **Inaccurate descriptions**: File listed but the described change doesn't match actual diff
- [ ] Check PR doc's feature claims against what the code actually does (claim verification)

### Scope Determination

Determine which files are IN_SCOPE vs OUT_OF_SCOPE for this PR's ticket:

1. Extract ticket ID from PR title or branch name (e.g., `ACME-595` from `ACME-595/split-place-card`)
2. Run `git log dev..HEAD --oneline` to see commit messages
3. Commits prefixed with the ticket ID (e.g., `[ACME-595]`) → their changed files are **IN_SCOPE**
4. Commits with a different ticket prefix (e.g., `[ACME-600]`) → their changed files are **OUT_OF_SCOPE**
5. Commits with no ticket prefix → treat as IN_SCOPE (assumed part of the work)

### Out-of-Scope File Handling

- [ ] OUT_OF_SCOPE files get a **skim review** only (check for obvious bugs, no deep critique)
- [ ] Do NOT produce Pass-to-Creator findings for OUT_OF_SCOPE files (they're someone else's work or incidental changes)
- [ ] Exception: obvious bugs (null dereference, security issue) in OUT_OF_SCOPE files still get flagged
- [ ] Scope note appears at the top of the review document when OUT_OF_SCOPE files exist

### Validation Output Format

Produce a verification table:

```markdown
| PR 문서 주장              | 실제 코드                          | 일치 여부 |
| ------------------------- | ---------------------------------- | --------- |
| PlaceCard를 모드별로 분리 | ✅ 3개 모드별 컴포넌트 생성 확인   | ✅ 일치   |
| 공통 함수 분리            | ✅ openEditBottomSheet 공통화 확인 | ✅ 일치   |
| 파일 8개 변경             | ⚠️ 실제 diff 기준 10개 변경        | ⚠️ 불일치 |
```

---

## K. Minimum Issue Re-examination Checklist

When a non-trivial PR (3+ files changed, meaningful logic) yields fewer than 3 substantive findings after Steps 3-4, run this second-pass checklist. **Never invent fake issues** — but look harder at commonly-missed dimensions.

### Edge Cases & Null Handling

- [ ] What happens when API returns empty array/null/undefined for the main data?
- [ ] Are optional chaining operators (`?.`) used where data can be undefined?
- [ ] What happens on first render before data loads? (loading/skeleton states)
- [ ] What if the user navigates away during an async operation?

### Sibling Component Consistency

- [ ] Do sibling components (same parent directory) follow the same prop interface patterns?
- [ ] Are shared types actually shared, or are there parallel type definitions?
- [ ] Do similar components handle the same edge cases the same way?
- [ ] Are naming conventions consistent across siblings? (e.g., `onClose` vs `handleClose`)

### Integration Points

- [ ] Barrel exports (`index.ts`) updated when new files are added?
- [ ] Type boundaries between layers correct? (entity types used in widget props, etc.)
- [ ] Are new hooks/utilities properly exported and importable?
- [ ] Do new components get registered in parent routing/layout if needed?

### Test Coverage

- [ ] Are new utility functions tested?
- [ ] Are edge cases from the PR's logic represented in tests?
- [ ] Do existing tests still pass with these changes? (no broken imports/mocks)

### Missing Error States

- [ ] Mutations show user feedback on failure?
- [ ] Network errors handled gracefully? (not just console.error)
- [ ] Form validation covers all required fields?
- [ ] Bridge calls have timeout/fallback handling?
