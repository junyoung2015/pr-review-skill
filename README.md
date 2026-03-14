# pr-review-skill

AI-powered PR review pipeline for [Claude Code](https://claude.ai/claude-code). It turns 30-45 minute PR reviews into structured reviews with deep code analysis, provider-aware AI review triage, worktree-aware auto execution, fix-forward support, and educational developer feedback.

## Killer Feature

The killer feature is **automated PR review that combines direct code review with GitHub Copilot and CodeRabbit comment handling in one flow**.

Use one command:

```bash
# --auto: receives a PR number, fetches the PR, and runs the full pipeline
# --review-source all: triages both GitHub Copilot and CodeRabbit comments if present
/pr-review --auto 161 --review-source all
```

What that pipeline gives you:
- fetch the PR directly from GitHub
- run independent deep code review on the actual diff
- triage **GitHub Copilot** and **CodeRabbit** comments together
- separate provider-specific feedback cleanly
- support fix-forward workflow with managed Round N records
- stop safely on dirty repos unless a clean worktree is prepared
- preview reply/resolve actions safely before any `--live` mutation

Direct code review remains the primary output. AI review triage is secondary.

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
/pr-review path/to/saved-pr.md --quick
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

## Update an existing install

### If installed as a local plugin

Pull the latest repo changes, then reload plugins or restart Claude Code:

```bash
git pull
/reload-plugins
```

### If installed via marketplace

Update the marketplace metadata first, then refresh the installed plugin in Claude Code:

```text
/plugin marketplace update <marketplace-name>
```

Version changes in [`.claude-plugin/plugin.json`](/Users/eddie/Desktop/eddiesohn/pr/.claude-plugin/plugin.json) and [`.claude-plugin/marketplace.json`](/Users/eddie/Desktop/eddiesohn/pr/.claude-plugin/marketplace.json) are what allow Claude Code to detect a new release.

## Usage

Once installed, use `/pr-review` directly:

```
# Full review from a PR document
/pr-review docs/pr-for-review/[TICKET-ID] description.md

# Full review from GitHub with provider selection
/pr-review https://github.com/owner/repo/pull/161 --review-source copilot

# Quick review (skip AI triage entirely)
/pr-review docs/pr-for-review/[TICKET-ID] description.md --quick

# Mixed-provider review
/pr-review https://github.com/owner/repo/pull/161 --review-source all

# Auto mode: fetch, review, fix-forward, prepare artifacts, then stop unless --live is present
/pr-review --auto 123 --review-source all --repo-path /abs/path/to/repo --worktree auto
```

If Claude Code auto-triggers the skill from natural language, that also works. `/pr-review` is just the most reliable explicit entrypoint.

Do not rely on `/pr-review:pr-review` for flag-heavy usage. The supported command entrypoint is `/pr-review`.

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
| `--repo-path <abs-path>` | Explicitly resolve the target product repo for auto mode |
| `--review-doc <path>` | Override the canonical review doc path for managed rounds |
| `--worktree auto` | Create or reuse the deterministic clean worktree for the current PR round |
| `--worktree <abs-path>` | Reuse or create a clean worktree at an explicit path |
| `--live` | Required before auto mode commits, pushes, replies, or resolves threads |

### Full Auto Mixed-Provider

Use this when the PR has both GitHub Copilot and CodeRabbit comments and you want the hardened supervised flow:

```bash
/pr-review --auto 161 \
  --review-source all \
  --repo-path /Users/eddie/Desktop/demodev/moving-frontend \
  --review-doc /Users/eddie/Desktop/demodev/moving-frontend/docs/reviews/MOVE-658-review.md \
  --worktree auto
```

What this does:
- validates the local repo against the PR head repo and branch
- fails fast with `needs-repo-path` if `--repo-path` is missing and the current directory is not the target repo
- stops safely if the repo is dirty and no worktree policy is supplied
- resolves the review doc explicitly or via `docs/reviews/<TICKET>-review.md`
- creates the first review doc at the resolved path during Phase B if the file does not already exist
- mirrors the authoritative review doc into the prepared worktree before managed Round N edits
- appends or resumes a managed Round N section in the review doc
- stores artifacts under `.pr-review/pr-161/round-N/`
- generates the provider-neutral decisions artifact and dry-run preview outputs
- stops before live mutation unless `--live` is present

If the branch basename has zero or multiple ticket matches, pass `--review-doc <path>` explicitly.

### Team-Safe Auto Workflow

Use this when you want the full pipeline but do **not** want to post anything yet:

```bash
# 1. Run auto review and stop after artifact + preview generation
/pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md --worktree auto

# 2. Inspect the generated round artifacts
cat /abs/path/to/repo/.pr-review/pr-161/round-N/decisions.json
cat /abs/path/to/repo/.pr-review/pr-161/round-N/reply-output.json
cat /abs/path/to/repo/.pr-review/pr-161/round-N/resolve-output.json

# 3. After every pending decision is updated in round_decisions, re-run with --live
/pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md --worktree auto --live
```

`--dry-run` previews GitHub replies / thread resolutions only. It does not push by itself. `--live` is the explicit confirmation switch for code + GitHub mutation.
On the `--live` path, the workflow must rerun `generate-decisions-json.sh --require-live-ready` before any commit or push. If any latest-round row is still `pending`, live mutation fails at that preflight boundary.
For branch shapes like `MOVE-658/social-login-native`, the basename is `social-login-native`, so pass `--review-doc` explicitly.

### Current Release Boundary

`v0.2.2` is a supervised auto-mode hardening release. It is considered done for explicit repo resolution, worktree-safe execution, managed Round N review-doc updates, decisions artifact generation, and dry-run preview flow.

It is not presented as autonomous review or as exhaustive live-mutation proof for every branch-drift, rerun, or legacy-doc edge case. Human review of `round_decisions` remains required before `--live`.

If follow-up work is needed, the likely `v0.2.3` candidates are stricter repo or branch mismatch proof, deeper legacy review-doc migration coverage, branch-drift or blocked-state validation before live mutation, and broader live mixed-provider acceptance coverage. If those do not become recurring rollout pain, leave `v0.2.2` as-is and keep the automation lean.

### Output

Review documents are saved to `docs/reviews/[TICKET-ID]-review.md` with:
- Git-truth validation (PR doc claims vs actual code)
- Code review findings (9 dimensions, severity-classified)
- GitHub Copilot / CodeRabbit triage (if applicable)
- Educational feedback for the PR author
- Developer profile updates at `docs/reviews/developers/<github-id>.md`

Managed auto-mode artifacts are stored in the target repo under:

```text
.pr-review/pr-<PR_NUMBER>/round-<N>/
```

That directory is local operational state. The workflow keeps it out of tracked product content via the active worktree exclude file instead of editing the repo’s `.gitignore`.

Review-doc contract:
- the authoritative review doc must live inside the resolved target repo
- when `--worktree auto` or `--worktree <path>` is used, the workflow copies that review doc into the prepared worktree at the same repo-relative path before mutating Round N state
- managed review-doc edits happen in the worktree copy, not the dirty source clone

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

## Release management

This plugin is currently versioned in the `0.x` range.

- Current plugin version lives in [`.claude-plugin/plugin.json`](/Users/eddie/Desktop/eddiesohn/pr/.claude-plugin/plugin.json)
- Marketplace version lives in [`.claude-plugin/marketplace.json`](/Users/eddie/Desktop/eddiesohn/pr/.claude-plugin/marketplace.json)
- Human-readable release notes live in [CHANGELOG.md](/Users/eddie/Desktop/eddiesohn/pr/CHANGELOG.md)
- Release automation lives in [.github/workflows/release.yml](/Users/eddie/Desktop/eddiesohn/pr/.github/workflows/release.yml)

Recommended release flow:

1. Update the plugin version in `plugin.json`
2. Sync the same version in `marketplace.json`
3. Add a matching section to `CHANGELOG.md`
   Include an optional line like `> Release title: Copilot-aware PR review workflow` directly under the version header if you want a custom GitHub Release title. Otherwise the workflow falls back to the raw tag name.
4. Merge to `main`
5. Create and push a git tag like `v0.2.0`
6. Let GitHub Actions validate and publish the GitHub Release

For `v0.2.2`, the release story should match the current boundary above: supervised automation hardened and documented, with deeper live-proof and edge-case expansion deferred unless rollout evidence justifies `v0.2.3`.

## License

[MIT](LICENSE)
