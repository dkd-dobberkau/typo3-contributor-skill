# Create and iterate a patch

## 1. Issue

Every commit needs its own Forge issue (`Resolves: #<id>`). If none exists, draft one with `references/issue.md`; the human creates it. Never invent a number. For a number the human gives you, run `python3 scripts/gerrit.py forge <id>`: does it exist and describe this change?

Possibly exploitable? Stop and go to the Security Team (SKILL.md hard rules). Typical cases: unescaped output of values editors can set, missing access checks, token or hash bypass.

## 2. Diagnose (bugfix) / agree the design (feature, refactoring)

**Bugfix.** Before editing, state:
1. the affected system extension and code path,
2. one piece of evidence (stack trace line, reproduced behaviour, failing test),
3. the smallest test that shows the bug.

Trace the value from input to output. The bug may not exist: Fluid and `GeneralUtility::implodeAttributes($attributes, true)` already escape, and older branches may differ from `main`. Get the human's confirmation, then write the test and watch it fail.

**Feature or new public API.** Agree these with the human before writing code:
- namespace and class name (look for a neighbouring precedent),
- public API vs. `@internal`,
- method signature,
- DI vs. `makeInstance`. Static and `makeInstance`'d contexts cannot use constructor injection.

Find a merged precedent with `git log --oneline --grep='Deprecate' -- <path>` and mirror its structure.

## 3. Implement

- **Clean, current base on a topic branch:** `git status` clean, then `git fetch origin && git checkout -b change-<topic> origin/main`.
- **The change the human describes is not there** (clean tree, other branch or checkout): say so and ask. Do not recreate it from the description.
- **Fix already in the working tree** (pasted by the human):
  - `git stash push -m "<topic>"`, `git fetch origin && git rebase origin/main`, `git stash pop`.
  - Then write the test and prove it: revert only the fix (`git stash push -- <file>`), see the test fail, `git stash pop`.
- **New PHP files:** license header + `declare(strict_types=1);` (copy from a neighbouring file).
- **New exception codes:** `date +%s`, then `grep -rn <code> typo3/` to confirm it is unique.
- **`Build/Sources` changes (TypeScript/SCSS):** `-s build` and commit the compiled `Resources/Public` files.
- **Feature, breaking change, deprecation:** `references/changelog-deprecation.md`.
- **XLIFF:**
  - New files: no `locallang_` prefix, snake_case ids.
  - On LTS branches, never change the meaning or the placeholders of existing labels.

## 4. Commit

Commit only if the human asked for a commit. Stage only related files (`git add <paths>`, check `git status`), then `git commit -s` with the template:

```
[BUGFIX] Keep record language when copying content elements

Describe what is changed now (imperative), not the old broken
behaviour - the Forge issue holds the problem description.

Resolves: #110864
Releases: main, 14.3
```

- **Keyword:** `[BUGFIX]` `[FEATURE]` `[TASK]` `[DOCS]` `[SECURITY]`, optionally with `[!!!]` in front.
- **Length:** subject ≤ 52 characters if possible. No line may reach 72 characters (AGENTS.md); only URLs may be longer.
- **Footer:** one `Resolves:` / `Related:` per line, space after the colon.
- **`Releases:`:** candidates from `python3 scripts/gerrit.py branches`.
  - Bugfixes start on `main`. Include an LTS branch only if the bug exists there (`git show origin/14.3:<file>`).
  - The backport targets are the human's call.
- **Footer order:** `Resolves:`/`Related:`, `Releases:`, `Signed-off-by:` (from `-s`), `Change-Id:` (added by the hook, kept byte-identical on amend).
- **Never add:**
  - a hand-written `Change-Id`,
  - a `Co-Authored-By` line.
  Keep `Signed-off-by` lines that others already added.

Then: `bash scripts/check-commit-msg.sh`.

## 5. QA

```bash
bash scripts/qa.sh            # runs the matching suites with -b docker
bash scripts/qa.sh --fix      # lets cglGit/normalizeXliff fix files; then: git commit -a --amend --no-edit
```

The first run pulls container images, which takes a while. Do not skip suites to save time. CI runs them anyway, and a red CI costs a full round trip.

phpstan errors: fix the code. Never add new entries to `Build/phpstan/phpstan-baseline.neon` for your own change. Mergers regenerate the baseline (`-s phpstanGenerateBaseline`) only after tool updates.

## 6. Human review gate + push

`bash scripts/preflight.sh` must print `PREFLIGHT OK`. Read its WARN lines too; `security-heuristic` needs an explicit answer from the human. Then present the gate from SKILL.md and push only after the yes given there:

```bash
git push origin HEAD:refs/for/main
```

The output contains `https://review.typo3.org/c/Packages/TYPO3.CMS/+/<number>`. Offer a Slack announcement text for `#typo3-cms-coredev` (the human posts it).

## Iterate (reviewer feedback or Core CI failed)

```bash
python3 scripts/gerrit.py status <change>          # owner, uploader, votes, CI verdict, reviewer messages
python3 scripts/gerrit.py comments <change> --all  # threads incl. resolved ones (vote reasons hide there)
python3 scripts/gerrit.py ci <change>              # failed jobs + exact local reproduction command
```

Check the premise against the output:
- Does the feedback the human quoted exist?
- Is it the human's change?
- Did someone else upload the latest patch set? If yes, ask before amending over their work.

Get the latest patch set. Your local commit may be stale after a reset or a rebase in Gerrit:

```bash
git status                                    # stash unrelated work first (named stash)
python3 scripts/gerrit.py fetch <change>      # prints the commands below for the latest patch set
git fetch https://review.typo3.org/Packages/TYPO3.CMS refs/changes/NN/<change>/<ps>
git checkout -B change-<change> FETCH_HEAD
git log -1 --format=%B | grep Change-Id       # must be the change's Change-Id
git rebase origin/main                        # after git fetch origin, if main moved on; resolve conflicts, rerun qa
```

1. Reproduce the failed CI job with the exact command `gerrit.py ci` prints (PHP version, DBMS). Fix it.
2. Address each review thread.
3. Run `qa.sh`, then `git commit -a --amend` (Change-Id untouched).
4. Keep the commit message. Change it only when the scope changed, e.g. the reviewer asked for a different approach.
5. Run `check-commit-msg.sh`, `preflight.sh`, then the human review gate again.
6. Draft one reply per thread ("Done: renamed $foo to $isHidden", "Done: added functional test FooTest"). The human posts them and resolves the threads.

New functional test for a feature: put it in the extension's `Tests/Functional/<same path as the class>/<Class>Test.php`, with CSV fixtures under `Fixtures/`. Mirror a neighbouring test.

## Handover (human unavailable)

Never push without the gate. Leave everything local and write a handover for the human (with the `handoff` skill if available):
- branch name, base commit, named stashes, and the warning "do not run Reset before pushing",
- `git show --stat HEAD`, the `preflight.sh` output with its WARN lines, the green `qa.sh` suites, and the test that fails without the fix,
- open questions: diagnosis, security assessment, `Releases:` scope, sign-off,
- the disclosure draft and the exact push command.

## Afterwards

Clean up so the next change does not stack on this one: `references/setup.md` → "Reset".
