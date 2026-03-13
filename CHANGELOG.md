# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning while the plugin remains in the `0.x` phase.

## [Unreleased]

### Added
- Release workflow validation for plugin metadata, changelog presence, and review scripts.
- Dry-run support for AI review reply and thread resolution scripts.
- GitHub Copilot-specific review instructions and triage guidance.
- Team usage note for safe rollout and provider-aware review usage.

### Changed
- PR review skill now supports provider-aware AI review triage for GitHub Copilot and CodeRabbit.
- Fetch pipeline now saves structured `*.review-data.json` sidecars for AI review metadata.
- README now documents provider-aware review modes, dry-run usage, and safer auto-review guidance.

## [0.2.0] - 2026-03-13

### Added
- GitHub Copilot review support alongside existing CodeRabbit handling.
- Provider-neutral scripts for replying to AI review comments and resolving AI review threads.
- Copilot-specific triage guide and repo-level Copilot review instructions.
- Benchmark coverage for Copilot-only, mixed-provider, and quick-review scenarios.

### Changed
- Review output now treats direct code review as primary and AI review triage as provider-aware secondary output.
- Auto review flow now supports `--review-source` selection and `--dry-run` mutation previews.
- Plugin metadata and marketplace metadata now describe Copilot-aware review behavior.

## [0.1.0] - 2026-03-12

### Added
- Initial plugin release for PR review, CodeRabbit triage, fix-forward workflow, and developer feedback tracking.
