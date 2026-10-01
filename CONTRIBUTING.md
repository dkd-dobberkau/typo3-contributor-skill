# Contributing

Issues and pull requests are welcome.

- Run `bash tests/run.sh` before submitting; all tests must pass.
- Changes to scripts need a test first (`tests/test_*.sh`, `tests/test_gerrit.py`).
- Facts about TYPO3 Core (suite names, hook behaviour, paths) must be verified against a current
  `typo3/typo3` checkout, not taken from memory or older docs. Note the source in `tests/baselines.md`.
- Behaviour changes to `SKILL.md` or `references/` should be checked with a subagent scenario
  (with and without the change), as described in `tests/baselines.md`.
- Test fixtures from real Gerrit/Forge responses must be anonymized (no names, emails or comment texts).
