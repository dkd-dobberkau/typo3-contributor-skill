# Setup

Run `bash scripts/check-setup.sh` first. It reports every gap. `--fix` sets missing repo-local config and copies the hooks. It never overwrites a differing value. `--online` also tests SSH and Docker.

## From scratch (guide Quickstart)

Prerequisites the human must have done (you cannot do these):
- typo3.org account. Gerrit login at https://review.typo3.org with that account.
- SSH public key uploaded in Gerrit settings.
- Commit email registered as a Gerrit identity.
- Forge uses the same account.

```bash
git clone https://github.com/typo3/typo3.git "$HOME/work/TYPO3-Contribute"
cd "$HOME/work/TYPO3-Contribute"
git config user.name "First Last"            # typo3.org identity
git config user.email "registered@example.org"
bash <skill>/scripts/check-setup.sh --fix    # pushurl from ~/.ssh/config, hooks, template, autosetuprebase
```

`~/.ssh/config` entry (the user name is the typo3.org user name):

```
Host review.typo3.org
    Port 29418
    User <username>
    IdentityFile ~/.ssh/<key>
```

`composer gerrit:setup` (Core composer script) installs the hooks too.

## DDEV instance (only needed for manual testing in a browser)

Follow `ddev config` from the guide's Quickstart (project `t3c-main`, docroot `.`, `TYPO3_CONTEXT=Development`). Then:

```bash
ddev start
Build/Scripts/runTests.sh -b docker -s composerInstall
ddev typo3 setup          # interactive; or follow guide Quickstart step "TYPO3"
```

If the user has the `typo3-ddev` / `ddev-mcp` skills, prefer them for DDEV handling.

## Reset to current main (after a merge or before a new change)

Destructive for local changes. First check for unpushed work: `git status`, `git log --oneline origin/main..HEAD`, `git branch --no-merged origin/main`. Commits that are not on Gerrit yet stay on their topic branch; never reset a branch that carries one. Then stash with a name:

```bash
git stash push -u -m "before-reset-$(date +%F)"   # only if there are changes
Build/Scripts/runTests.sh -b docker -s clean
git fetch origin && git checkout main && git reset --hard origin/main
Build/Scripts/runTests.sh -b docker -u            # update test images
Build/Scripts/runTests.sh -b docker -s composerInstall
ddev typo3 cache:flush && ddev typo3 cache:warmup && ddev typo3 extension:setup   # if DDEV is used
```

Afterwards the human can check the Database Analyzer in the backend.
