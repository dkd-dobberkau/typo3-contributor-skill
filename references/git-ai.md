# git-ai: line-level AI attribution for human review (optional)

Check with `command -v git-ai`. If it is missing, skip this file.

[git-ai](https://usegitai.com) records which lines an agent wrote, as git notes (`refs/notes/ai`). It does not change commit messages, so TYPO3 commit rules are unaffected. Use it to focus the human's review on AI-written lines and to quantify the disclosure. Without it, the human reviews the plain diff and the disclosure has no numbers.

## Setup (once, with the human's consent)

```bash
git-ai config --add allow_repositories '*typo3/typo3*'   # track only the Core checkout
git-ai install-hooks                                      # agent hooks (checkpoints for Claude Code)
git-ai config                                             # review prompt_storage / telemetry settings with the human
```

## Use

| Moment | Command |
|---|---|
| Before the human review gate | `git-ai diff HEAD`: diff with AI/human annotations. Show the AI-authored hunks first |
| Per file | `git-ai blame <file>` |
| Disclosure numbers | `git-ai stats HEAD --json`: the AI share of added lines goes into `templates/gerrit-disclosure.md` |
| After amend/rebase | Attribution follows the commit; re-run `stats` for the new patch set |

## Guardrails

- **Notes never go to Gerrit.** Push only with the explicit refspec `git push origin HEAD:refs/for/main`. `preflight.sh` fails if `remote.origin.push` contains `refs/notes`. If a push prints anything about `refs/notes`, stop and tell the human.
- Prompts can contain private context. Never run `git-ai share` for Core work without the human's decision.
- Attribution supports the human review; it does not replace it. Every line gets reviewed.
- git-ai only sees code written through tracked agent sessions. Code pasted in from elsewhere shows up as human-authored. Say so in the disclosure instead of quoting a misleading percentage.
