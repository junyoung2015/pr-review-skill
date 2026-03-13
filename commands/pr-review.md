---
description: Run the PR review pipeline with raw arguments. Supports local PR docs, GitHub PR URLs, --quick, --triage-only, --auto, --history, --review-source, and --dry-run.
---

# pr-review

Treat the text below as the user's exact PR review request and flags:

`$ARGUMENTS`

Read and follow the skill at `skills/pr-review/SKILL.md`.

Interpret `$ARGUMENTS` exactly as provided by the user. Support these common patterns:

- local PR doc path review
- GitHub PR URL review
- `--quick`
- `--triage-only`
- `--auto <PR#>`
- `--history <github-id>`
- `--review-source <all|coderabbit|copilot|none>`
- `--dry-run`

Direct code review is primary. AI review triage is secondary.
