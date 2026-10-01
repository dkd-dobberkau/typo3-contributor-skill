# Contributing

Issues and pull requests are welcome.

- Run `bash tests/run.sh` and `shellcheck -x scripts/*.sh` before submitting. CI runs both (Ubuntu and macOS) and validates the plugin manifests.
- On release, bump `.claude-plugin/plugin.json` and the CHANGELOG to the same version; CI checks that they match each other and the tag.
- Changes to scripts need a test first (`tests/test_*.sh`, `tests/test_gerrit.py`).
- Facts about TYPO3 Core (suite names, hook behaviour, paths) must be verified against a current
  `typo3/typo3` checkout, not taken from memory or older docs. Note the source in `tests/baselines.md`.
- Behaviour changes to `SKILL.md` or `references/` need a passing `claude plugin eval .` run; add a case
  under `evals/` for new rules. Prefer regex/tool_used graders; check every failing grader by reading the answer.
- Test fixtures from real Gerrit/Forge responses must be anonymized (no names, emails or comment texts).
