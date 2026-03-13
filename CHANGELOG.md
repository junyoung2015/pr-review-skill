# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning while the plugin remains in the `0.x` phase.

## [Unreleased]

## [0.2.1] - 2026-03-13

> Release title: command wrapper and manifest validation fix

### Added
- Explicit `/pr-review` command wrapper for passing raw review arguments safely.

### Changed
- README and rollout docs now position automated provider-aware review as the primary feature and use `/pr-review` as the supported command entrypoint.
- Plugin and marketplace descriptions now highlight automated review as the primary feature.
- Plugin manifest `repository` field now uses the format expected by Claude's plugin validator.

### Fixed
- Fixed marketplace installation failure caused by an invalid `plugin.json` repository field.

## [0.2.0] - 2026-03-13

> Release title: Copilot-aware PR review workflow

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

> Release title: Initial PR review skill release

### Added
- Initial plugin release for PR review, CodeRabbit triage, fix-forward workflow, and developer feedback tracking.
