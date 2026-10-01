# Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Permission denied (publickey)` on push | Wrong SSH user or key. Test `ssh -p 29418 <user>@review.typo3.org`; expect "Welcome to Gerrit Code Review". Fix the `Host review.typo3.org` block in `~/.ssh/config` (User = typo3.org username, IdentityFile). Usernames with special characters must be escaped. |
| `remote rejected … (invalid committer)` / "You are not a committer" | Commit email is not a registered Gerrit identity. The human registers it at https://review.typo3.org/settings/#EmailAddresses and confirms the mail. Then check `git config user.email` and run `git commit --amend --reset-author --no-edit`. |
| `missing Change-Id in commit message` | Hook was missing when committing. Install it (`check-setup.sh --fix`), then `git commit --amend --no-edit`. |
| A second change was created instead of a patch set | The Change-Id was changed or removed. Abandon the duplicate in Gerrit (the human does it). Amend with the original Change-Id. |
| Change shows a relation chain | More than one commit ahead of `origin/main`. Squash or reset so that exactly one commit remains (`preflight.sh` checks this). |
| `no new changes` on push | Nothing changed since the last patch set. Check `git show HEAD`. |
| Merge conflict when rebasing | `git status`, resolve the files, `git add`, `git rebase --continue`, then re-run `qa.sh`. |
| `runTests.sh` very slow on macOS | Container filesystem overhead. Exclude `typo3temp/` and `.cache` from IDE indexing and from DDEV mutagen sync. |
| `/var/run/docker.sock: permission denied` | Docker is not running, or the user lacks access. Start Docker Desktop. |
| Commit prints `PHP Fatal error … Composer detected issues in your platform` | The optional pre-commit hook runs php-cs-fixer with an older host PHP. Remove `.git/hooks/pre-commit`; `qa.sh` runs cgl in Docker. |
| Test images outdated, odd CI vs. local differences | `Build/Scripts/runTests.sh -b "$RT" -u`, then `-s composerInstall` |
| Core CI red but local green | Base is stale. Run `git fetch origin && git rebase origin/main`, re-run with the CI job's flags (`gerrit.py ci`). |
