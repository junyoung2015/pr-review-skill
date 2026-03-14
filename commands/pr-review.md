---
description: Run the PR review pipeline with raw arguments. Supports local PR docs, GitHub PR URLs, --quick, --triage-only, --auto, --history, --review-source, --repo-path, --review-doc, --worktree, --dry-run, and --live.
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
- `--repo-path <abs-path>`
- `--review-doc <path>`
- `--worktree auto|<abs-path>`
- `--dry-run`
- `--live`

Direct code review is primary. AI review triage is secondary.

For `--auto` requests:
- run the scripted fetch/worktree preflight before any review or triage work
- never guess the target repo from sibling directories, previous worktrees, or unrelated clones
- if `--repo-path` is absent and the current working directory is not the PR target repo, stop and tell the user to rerun with `--repo-path <abs-path>`
