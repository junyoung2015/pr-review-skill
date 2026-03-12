# pr-review-skill

AI-powered PR review pipeline for [Claude Code](https://claude.ai/claude-code). Turns 30-45 min code reviews into ~8 min structured reviews with deep code analysis, CodeRabbit triage, fix-forward, and educational developer feedback.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Claude Code](https://claude.ai/claude-code) | 1.0.33+ | Runtime |
| Git | 2.x+ | Diff analysis |

### GitHub CLI (required for auto mode, strongly recommended)

Install and authenticate [`gh`](https://cli.github.com/) to unlock the full pipeline — auto-fetch PRs, post review replies, and resolve threads:

```bash
brew install gh   # or see https://cli.github.com/
gh auth login
```

Scripts also use [`jq`](https://jqlang.github.io/jq/) for JSON parsing:

```bash
brew install jq
```

Without `gh`, auto mode (`--auto`) and script-based features won't work. You can still run reviews manually by saving the PR content to a local markdown file and providing the path:

```
/pr-review:pr-review path/to/saved-pr.md --quick
```

```bash
# Verify all prerequisites
claude --version
gh auth status
jq --version
```

## Install

### Option A: Plugin marketplace (recommended)

```bash
# In Claude Code:
/plugin marketplace add junyoung2015/pr-review-skill
/plugin install pr-review@pr-review-skill
```

### Option B: Local plugin

```bash
git clone git@github.com:junyoung2015/pr-review-skill.git
claude --plugin-dir ./pr-review-skill
```

## Usage

Once installed, the skill triggers when you mention reviewing a PR, or you can invoke it directly:

```
# Full review from a PR document
/pr-review:pr-review docs/pr-for-review/[TICKET-ID] description.md

# Quick review (skip CodeRabbit triage)
/pr-review:pr-review docs/pr-for-review/[TICKET-ID] description.md --quick

# Auto mode: fetch, review, fix-forward, reply — all in one
/pr-review:pr-review --auto 123
```

### Modes

| Mode | Flag | What it does |
|------|------|-------------|
| Full Review | _(default)_ | Git-truth validation, deep code review, CodeRabbit triage, developer tracking |
| Quick Review | `--quick` | Skip CodeRabbit triage — just git-truth + deep code review |
| Triage Only | `--triage-only` | Only process CodeRabbit comments |
| Auto Review | `--auto <PR#>` | End-to-end: fetch PR, review, fix-forward, commit, push, reply to CodeRabbit |
| Developer History | `--history <github-id>` | Show accumulated review patterns for a developer |

### Output

Review documents are saved to `docs/reviews/[TICKET-ID]-review.md` with:
- Git-truth validation (PR doc claims vs actual code)
- Code review findings (9 dimensions, severity-classified)
- CodeRabbit comment triage (if applicable)
- Educational feedback for the PR author
- Developer profile updates at `docs/reviews/developers/<github-id>.md`

## How it works

1. **Parse** the PR document and extract claims
2. **Validate** claims against the actual git diff (git-truth)
3. **Deep review** every in-scope file across 9 dimensions (bugs, architecture, React/TS patterns, consistency, DRY, UI, error handling, a11y, performance)
4. **Triage** CodeRabbit comments with scope-aware classification
5. **Classify** findings: Fix-Self vs Pass-to-Creator, severity HIGH/MEDIUM/LOW
6. **Generate** structured review document with educational feedback
7. **Track** developer growth patterns over time

## License

[MIT](LICENSE)
