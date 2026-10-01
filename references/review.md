# Review and test someone else's change

Anyone with a typo3.org account can review and vote +1 or -1. +2 and -2 are for Core Mergers. **You prepare the review; the human posts comment and vote in the Gerrit web UI.** A conditional request like "+1 it if it's fine" is not a go to post, and neither is time pressure or "do it via ssh".

- A green Core CI is the `core-ci` user's Verified +1. It is no reason for a human Verified +1 (which means "I tested it") or a Code-Review +1 (which means "I read it").
- A vote without your own review adds nothing. If the change already has enough reviews and you have no time, recommend skipping it or leaving a comment-only review.

## 1. Read the state

```bash
python3 <skill>/scripts/gerrit.py status <change>          # owner/uploader, votes, Core CI, reviewer messages
python3 <skill>/scripts/gerrit.py comments <change> --all  # all threads, incl. resolved ones
python3 <skill>/scripts/gerrit.py files <change>           # touched files
python3 <skill>/scripts/gerrit.py diff <change>            # full patch: code review without touching the checkout
python3 <skill>/scripts/gerrit.py forge <resolved issue>   # what the change should fix
```

- **`status` prints "this is YOUR change"** (Gerrit username = ssh user)? Then no vote, only comments.
- **Existing -1s:** read their reasons. They sit in reviewer messages or resolved comments. Try to reproduce them first, because they are the most likely findings.
- **Votes on older patch sets** were dropped by a newer upload ("Outdated Votes"). Check whether the new patch set addresses them.
- **Threads the author answered but did not resolve:** check whether the answer really fixes the point.

## 2. Protect the current work, fetch into a worktree (only for testing)

A code-read-only review can stop after step 1 and `gerrit.py diff`. Testing needs the change locally. The steps below change local repository state, not the server. `gerrit.py fetch` only prints the commands; you run them.

```bash
git status                                    # stash with a name if dirty
git branch --show-current; git log -1 --format='%H %s'   # note branch and HEAD
python3 <skill>/scripts/gerrit.py fetch <change>
git fetch https://review.typo3.org/Packages/TYPO3.CMS refs/changes/NN/<change>/<ps>
git worktree add ../review-<change> FETCH_HEAD    # never cherry-pick onto the human's own HEAD
cd ../review-<change>
git log --oneline origin/main..HEAD           # exactly 1 commit; more = relation chain, review the parents too
```

## 3. Code review checklist (guide: "Common code review checks")

- **Commit message:**
  - `bash <skill>/scripts/check-commit-msg.sh` passes.
  - The text matches the diff and contradicts neither the code nor the rst files.
  - The `Releases:` scope fits `gerrit.py branches`.
- **Does it solve the Forge issue** (read it)? Check edge cases: workspaces, languages, non-admin users, multi-site.
- **Regressions (features and refactorings too):**
  - Do existing configurations still work?
  - Do failsafe and early-boot paths still work (code that runs before the DI container exists)?
  - Does code that extends public, non-final classes still work?
- **Breaking risks in backports:**
  - narrowed types,
  - new PHP features,
  - changed meaning or placeholders of existing labels.
- **Tests:**
  - A bugfix has a regression test that fails without the fix.
  - New functionality has unit or functional tests.
  - UI changes have e2e (Playwright) coverage where useful.
- **PHP:**
  - `final`, `readonly`, `private`/`protected` where possible.
  - DI for services.
  - New files have the license header and `strict_types`.
  - New exception codes are unique timestamps.
- **Frontend:**
  - TypeScript and SCSS sources change together with the compiled files.
  - The feature works for admins and for restricted users.
- **Docs:**
  - Feature, Breaking or Deprecation rst is present and aligned with code and commit message.
  - Extension scanner matcher and scanner tag are plausible.
- **Foreign code:** licence compatible with GPL-2.0-or-later.

## 4. Test

```bash
bash <skill>/scripts/qa.sh            # in the worktree; composerInstall first if vendor/ is missing
```

- Database-related changes: also `-d mariadb` and `-d postgres` (qa.sh prints a note).
- Bugfix: confirm the new test fails without the fix. Revert only the non-test files temporarily, run the test, then restore.

**Manual test in DDEV.** This takes over the human's running instance, so ask first.

1. Baseline: `git checkout --detach origin/main` in the main checkout. Reproduce the issue, or the reviewer's finding.
2. Then `git checkout --detach FETCH_HEAD` (fetch again if needed), followed by:
   `Build/Scripts/runTests.sh -b "$RT" -s composerInstall && ddev typo3 cache:flush && ddev typo3 extension:setup`
3. Run the same steps. Check `var/log/typo3_*.log` and the browser console.
4. Put temporary config (e.g. in `config/system/additional.php`) in one place and remove it afterwards.

## 5. Draft the vote and comment (the human posts it)

- **Code-Review +1:** the code reads correctly. **Verified +1:** you actually tested it. A code-read-only review gets Code-Review only. Drop the "Tested on" block.
- **-1** always needs a concrete reason: a bug, it does not fix the issue, architecture, a missing test.
- **A plausible -1 from someone else that you can reproduce:** a -1 with your own evidence is appropriate. If you cannot reproduce it, say how you tried.

```
Code-Review <±1>, Verified <±1> (patch set <n>)

Tested on main (<php>, <db>):
- reproduced #<issue> / <reviewer>'s finding on origin/main: <result>
- with this patch: <result>
- also checked: <non-admin / workspace / language / early boot>
- runTests: <suites> <green|results>; new test fails without the fix

<blocking points with file:line>
Non-blocking: <remarks>
```

Append the reviewer line from `templates/gerrit-disclosure.md`.

## 6. Clean up

```bash
cd <main checkout>
git checkout <noted branch>            # the branch, not a detached SHA
Build/Scripts/runTests.sh -b "$RT" -s composerInstall && ddev typo3 cache:flush && ddev typo3 extension:setup   # if DDEV was switched
git worktree remove ../review-<change> && git worktree prune
git stash list                         # restore the named stash if you created one
git status; git log -1 --format='%H %s'   # must match the noted state
```
