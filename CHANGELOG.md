# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

[0.2.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.2.0
[0.1.0]: https://github.com/dkd-dobberkau/typo3-contributor-skill/releases/tag/v0.1.0
