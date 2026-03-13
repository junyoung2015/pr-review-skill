# pr-review-skill

AI-powered PR review pipeline for [Claude Code](https://claude.ai/claude-code). It turns 30-45 minute PR reviews into structured reviews with deep code analysis, provider-aware AI review triage, fix-forward support, and educational developer feedback.

The skill now supports both **GitHub Copilot review** and **CodeRabbit**. Direct code review remains the primary output; AI review triage is secondary.

- Team rollout note: [TEAM-USAGE.md](/Users/eddie/Desktop/eddiesohn/pr/TEAM-USAGE.md)

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Claude Code](https://claude.ai/claude-code) | 1.0.33+ | Runtime |
| Git | 2.x+ | Diff analysis |

### GitHub CLI (required for auto mode, strongly recommended)

Install and authenticate [`gh`](https://cli.github.com/) to unlock the full pipeline: auto-fetch PRs, inspect Copilot / CodeRabbit review data, post review replies, and resolve threads:

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

# Full review from GitHub with provider selection
/pr-review:pr-review https://github.com/owner/repo/pull/161 --review-source copilot

# Quick review (skip AI triage entirely)
/pr-review:pr-review docs/pr-for-review/[TICKET-ID] description.md --quick

# Mixed-provider review
/pr-review:pr-review https://github.com/owner/repo/pull/161 --review-source all

# Auto mode: fetch, review, fix-forward, then pause before commit/push/reply
/pr-review:pr-review --auto 123 --review-source all
```

### Modes

| Mode | Flag | What it does |
|------|------|-------------|
| Full Review | _(default)_ | Git-truth validation, deep code review, AI review triage, developer tracking |
| Quick Review | `--quick` | Skip AI review triage — just git-truth + deep code review |
| Triage Only | `--triage-only` | Only process GitHub Copilot and/or CodeRabbit comments |
| Auto Review | `--auto <PR#>` | End-to-end: fetch PR, review, fix-forward, then optionally commit/push/reply |
| Developer History | `--history <github-id>` | Show accumulated review patterns for a developer |

### Key Flags

| Flag | Meaning |
|------|---------|
| `--review-source all` | Review every supported provider found on the PR |
| `--review-source copilot` | Only triage GitHub Copilot review comments |
| `--review-source coderabbit` | Only triage CodeRabbit review comments |
| `--review-source none` | Skip AI review triage (quick review semantics) |
| `--dry-run` | Preview reply / resolve actions without mutating GitHub |

### Team-safe auto workflow

Use this when you want the full pipeline but do **not** want to post anything yet:

```bash
# 1. Run auto review and stop before live GitHub mutations
/pr-review:pr-review --auto 161 --review-source all

# 2. Preview planned replies / resolutions from the generated decisions file
skills/pr-review/scripts/post-ai-review-comments.sh 161 /tmp/pr-161-decisions.json --dry-run
skills/pr-review/scripts/resolve-ai-review-threads.sh 161 /tmp/pr-161-decisions.json --dry-run
```

`--dry-run` only previews GitHub replies / thread resolutions. It does not push by itself.

### Output

Review documents are saved to `docs/reviews/[TICKET-ID]-review.md` with:
- Git-truth validation (PR doc claims vs actual code)
- Code review findings (9 dimensions, severity-classified)
- GitHub Copilot / CodeRabbit triage (if applicable)
- Educational feedback for the PR author
- Developer profile updates at `docs/reviews/developers/<github-id>.md`

## How it works

1. **Parse** the PR document and extract claims
2. **Validate** claims against the actual git diff (git-truth)
3. **Deep review** every in-scope file across 9 dimensions (bugs, architecture, React/TS patterns, consistency, DRY, UI, error handling, a11y, performance)
4. **Triage** GitHub Copilot and/or CodeRabbit comments with provider-aware classification
5. **Classify** findings: Fix-Self vs Pass-to-Creator, severity HIGH/MEDIUM/LOW
6. **Generate** structured review document with educational feedback
7. **Track** developer growth patterns over time

## Repository custom instructions for Copilot

If you use GitHub Copilot review on GitHub.com, this repo includes:

- `.github/copilot-instructions.md`
- `.github/instructions/general-review.instructions.md`
- `.github/instructions/web-review.instructions.md`
- `.github/instructions/mobile-review.instructions.md`

These guide Copilot toward architecture, runtime correctness, test quality, and meaningful review comments instead of generic style nits.

## License

[MIT](LICENSE)
