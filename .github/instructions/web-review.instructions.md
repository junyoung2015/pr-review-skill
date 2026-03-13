---
applyTo: "apps/web-v2/**/*.ts,apps/web-v2/**/*.tsx,apps/web-v2/**/*.d.ts"
---

For `apps/web-v2` reviews, focus on issues that matter in production:

- Verify React hooks are safe: dependency arrays, stale closures, `useWatch` vs `watch`, and concurrent actions.
- Check Next.js server actions, auth/session flows, and schema-driven API calls for contract drift. If a request body adds a field, confirm the generated schema/types were updated too.
- Look for missing null guards, loading states, and error handling around async data and mutations.
- Pay attention to FSD boundaries and public API exports. Shared utilities should not be hidden inside feature/view files if reused or cross-cutting.
- Accessibility matters: icon-only controls need labels, semantic structure should remain intact, and keyboard behavior should not regress.
- Test feedback should target real gaps only. Prefer missing assertions, missing error-path coverage, or commented-out test files over minor test style nits.
