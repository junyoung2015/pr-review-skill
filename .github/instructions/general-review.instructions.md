---
applyTo: "**"
---

When performing a code review in this repository:

- Prioritize runtime correctness, broken user flows, stale types/schemas, missing loading or error states, and weak test coverage.
- Treat architecture and boundary violations as important. Check FSD layer direction, public API usage, and whether a change belongs in the current layer.
- Prefer comments with concrete evidence from the changed code. Avoid vague "could be improved" feedback.
- Avoid style-only comments unless they affect readability, accessibility, or violate an explicit project convention.
- When documentation or env files change, only comment if the docs/env drift can break local setup, deployment, or runtime behavior.
- If the code already follows an intentional project convention, do not suggest a conflicting refactor just because it is a common default elsewhere.
