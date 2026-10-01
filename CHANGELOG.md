# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `gerrit.py forge <issue> --full`: description, priority and custom fields (e.g. Complexity, TYPO3 Version), relations and comments of a Forge issue, read anonymously from the public JSON API.

## [0.4.0] - 2026-10-01

### Added
- GitHub Actions CI: test suite on Ubuntu and macOS, ShellCheck for `scripts/`, plugin/marketplace manifest validation, and a check that `plugin.json`, the changelog and release tags carry the same version.
- Plugin options `container_runtime` (docker/podman) and `core_dir`, exported to the session by a `SessionStart` hook (`TYPO3_CONTRIB_RUNTIME`, `TYPO3_CORE_DIR`). All scripts honour them.
- `PreToolUse` guard hook (`hooks/guard.py`): Gerrit pushes run `preflight.sh` and need confirmation, posting to Gerrit is denied, `Co-Authored-By` in Core commits is denied.
- `evals/`: five `claude plugin eval` cases with mostly deterministic graders, and an on-demand `Evals` workflow.

### Fixed
- Quickstart tests no longer depend on `docker`/`ssh` being installed on the test machine.
- ShellCheck findings in `qa.sh` and `preflight.sh`.

## [0.3.0] - 2026-10-01

### Added
- `scripts/quickstart-check.sh`: read-only check of the Contribution Guide Quickstart steps 1-5 (prerequisites, Gerrit SSH plus a manual account checklist, Git via `check-setup.sh`, DDEV config/PHP/running, TYPO3 installed with EXT:styleguide and EXT:indexed_search, backend reachable with `--online`).

## [0.2.0] - 2026-10-01

### Added
- Claude Code plugin packaging: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. The repository is its own marketplace (`claude plugin install typo3-contributor@typo3-contributor`).

### Changed
- `SKILL.md` resolves bundled scripts through `${CLAUDE_SKILL_DIR}`, which works both as a plugin and as a symlinked personal skill.

## [0.1.0] - 2026-10-01

### Added
- `SKILL.md` with facts that are often guessed wrong, hard rules, a situation router and the human review gate.
- References: setup, issue, patch, changelog/deprecation, review, docs patch, troubleshooting, git-ai.
- Templates: changelog rst (Feature, Deprecation, Breaking, Important), Forge drafts, Gerrit disclosure comments.
- Scripts: `check-setup.sh`, `qa.sh`, `check-commit-msg.sh`, `preflight.sh`, `fix-trailer-order.sh`, `gerrit.py`.
- Tests: plain-bash and Python tests with anonymized Gerrit/Forge fixtures; documented baselines (`tests/baselines.md`); tests run in a throwaway directory.

[0.4.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.4.0
[0.3.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.3.0
[0.2.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.2.0
[0.1.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.1.0
