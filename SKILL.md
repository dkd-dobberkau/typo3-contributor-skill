---
name: typo3-contributor
description: Use when contributing to TYPO3 Core (typo3/typo3, review.typo3.org Gerrit, forge.typo3.org) - fixing a Core bug, preparing or updating a patch set, addressing reviewer or Core CI feedback, reviewing or testing someone else's change, writing changelog or deprecation rst files, Core documentation patches, or reporting a Core issue.
---

# TYPO3 Core Contribution

Skill directory: `${CLAUDE_SKILL_DIR}`. All `scripts/`, `references/` and `templates/` paths here and in the references (also written as `<skill>/…`) are relative to it. Commands run inside the Core checkout, so call scripts with that absolute prefix, e.g. `bash ${CLAUDE_SKILL_DIR}/scripts/qa.sh`.

## Overview

Guides Core contributions along the official
[Contribution Workflow Guide](https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/),
corrected where the guide is outdated. Inside the checkout, the Core team's `AGENTS.md` (loaded via the
Core's `CLAUDE.md`) is authoritative and wins on conflicts. This skill adds the supervision, tooling
and review flow it lacks. **AI may contribute; a human supervises.** You prepare
everything locally. The human reviews the full diff and decides about every push. The human posts
all comments and votes and creates Forge tickets; you draft them.

## Facts that differ from what you expect

| Topic | Fact |
|---|---|
| Checkout | `${TYPO3_CORE_DIR:-$HOME/work/TYPO3-Contribute}` (plugin option `core_dir`), DDEV project `t3c-main`, CLI `ddev typo3 …` |
| `origin` | Fetches from **GitHub** (no `refs/changes`). Patch sets come from `https://review.typo3.org/Packages/TYPO3.CMS`; use `gerrit.py fetch <change>` |
| Push | Always `git push origin HEAD:refs/for/main` (pushurl = Gerrit ssh, user from `~/.ssh/config`) |
| runTests | Always `Build/Scripts/runTests.sh -b "$RT" …` with `RT=${TYPO3_CONTRIB_RUNTIME:-docker}` (plugin option `container_runtime`; the scripts do this themselves) (with `CI=true` for test/build suites, as in AGENTS.md). No `-s lint` and no `-s acceptance`: use `lintPhp`/`lintTypescript`/`lintScss`, and `e2e` (Playwright, `Build/tests/playwright/e2e/*.spec.ts`). Check `-h` before inventing a suite |
| CI | GitLab pipeline; Gerrit user `core-ci` votes Verified ±1 ("Core CI is (not) happy: <pipeline>"). Not Bamboo |
| commit-msg hook | **Never blocks** (exit 0 even without `Resolves:`) and still adds a Change-Id. It only flags lines of 73+ characters. AGENTS.md is stricter: no line may reach 72. Run `check-commit-msg.sh` |
| Pre-commit hook | Optional. It runs php-cs-fixer with the host PHP and fails with a fatal error if that PHP is older than Core needs. `qa.sh` runs cgl in Docker |
| Versions | `main` = `composer.json` → `branch-alias.dev-main`. Bugfix targets: `gerrit.py branches` (main + maintained LTS from get.typo3.org); `git branch -r` also lists dead branches. Never guess |
| Changelog | `typo3/sysext/core/Documentation/Changelog/<Typo3Version::BRANCH>/`. Read `…/Changelog/Howto.rst` in the checkout. `*Scanned` tag only for Breaking/Deprecation |
| AI disclosure | In the Gerrit comment (`templates/gerrit-disclosure.md`), **never** a `Co-Authored-By` trailer in the commit |

## Hard rules

- **Check the premise first.** Verify the reported bug, feedback or change number against the code and against `gerrit.py status`. Report any discrepancy before you act, e.g. "already escaped", "no such comment", "someone else uploaded the latest patch set".
- Commit only when the human asked for it (AGENTS.md). Work on a topic branch (`change-<topic>`), never on local `main`, so a later reset cannot destroy your work.
- One change = exactly one commit on top of `origin/main`, with its own Forge issue. Update it with `git commit --amend`; keep the `Change-Id`.
- Commit with `git commit -s`. The `Signed-off-by` certifies the Developer Certificate of Origin in the human's name, so point it out at the review gate.
- Possibly exploitable (unescaped output editors can influence, missing access check, token bypass): stop. No public commit, ticket, push or Slack. Point to https://typo3.org/community/teams/security/contact-us/. If you are unsure, ask the human before any public step.
- Features and `[!!!]` target `main` only. A deprecation is `[TASK]` or `[FEATURE]`, never `[!!!]`.
- `git push` needs a yes given *at the review gate*. "Just push it", "quickly" or a yes given before the human saw the diff does not count. If the human has no time, leave the commit local; nothing is lost.
- You never post to Gerrit: no `gerrit review`, no comments, no votes. You draft them, and the human posts them in the web UI. There is no exception for time pressure or for "do it via ssh for me". Authors never vote on their own change.
- No `Co-Authored-By` in Core commits. Generic agent attribution rules do not apply here; disclosure goes into the Gerrit comment.

## What to read for the situation

| Situation | Read |
|---|---|
| No checkout, push fails, hooks missing | `references/setup.md` (+ `scripts/check-setup.sh`) |
| User reports a Core bug / wants a ticket | `references/issue.md` |
| Fixing a bug or building a feature | `references/patch.md` |
| Reviewer comments or Core CI failed | `references/patch.md` → "Iterate" (+ `gerrit.py status/comments/ci`) |
| Deprecation, breaking change, changelog | `references/changelog-deprecation.md` |
| Review or test someone else's change | `references/review.md` |
| Documentation-only patch | `references/docs-patch.md` |
| Error messages from git/Gerrit | `references/troubleshooting.md` |
| `command -v git-ai` succeeds | `references/git-ai.md` |
| Human unavailable (weekend, meeting) | `references/patch.md` → "Handover" |

## Scripts (run inside the checkout; `bash`/`python3`, read-only towards servers)

| Script | Purpose |
|---|---|
| `bash scripts/quickstart-check.sh [--online]` | whole guide Quickstart (steps 1-5): tools, accounts, Git, DDEV, TYPO3 instance |
| `bash scripts/check-setup.sh [--fix] [--online]` | verify/complete clone, pushurl, hooks, template |
| `bash scripts/qa.sh [--dry-run] [--fix]` | runTests suites matching the HEAD commit's files |
| `bash scripts/check-commit-msg.sh [file]` | lint a commit message (default HEAD) |
| `bash scripts/preflight.sh` | pre-push gate: one commit, Change-Id, message, rst/prefix match, headers, assets, security, notes |
| `python3 scripts/gerrit.py status\|comments [--all]\|ci\|fetch <change>` | owner/uploader, votes and reviewer messages, threads, failed CI jobs, fetch commands |
| `python3 scripts/gerrit.py files\|diff <change>` | read a change without touching the checkout |
| `python3 scripts/gerrit.py forge <issue>` | does the Forge issue exist, which tracker and status |
| `python3 scripts/gerrit.py branches` | main + maintained LTS branches |

Prefix every script with `${CLAUDE_SKILL_DIR}/` (the skill directory, see top).

## Enforced by plugin hooks

Installed as a plugin, a `PreToolUse` hook (`hooks/guard.py`) enforces the hard rules:
- a push to Gerrit runs `preflight.sh` first and is denied if it fails; otherwise the human is asked to confirm;
- posting to Gerrit is always denied;
- `Co-Authored-By` in a Core commit is denied.

A denied call is the rule working, so fix the cause instead of rephrasing the command to slip past the hook.

## The human review gate (before every push)

Present exactly this, then wait:

1. `git show --stat HEAD` and the full `git show HEAD` (with `git-ai`: the AI-authored lines first, see `references/git-ai.md`)
2. The `preflight.sh` result (must be `PREFLIGHT OK`, WARN lines answered) and which `qa.sh` suites ran green. Mention that `Signed-off-by` certifies the DCO in the human's name
3. The filled disclosure comment from `templates/gerrit-disclosure.md`, and when iterating, the reply drafts for each reviewer thread
4. The exact command: `git push origin HEAD:refs/for/main`, and the question whether to run it

After the push, give the review URL and remind the human to post the disclosure comment.

## Common mistakes

| Mistake | Instead |
|---|---|
| `git fetch origin refs/changes/…` | `python3 scripts/gerrit.py fetch <change>` (fetches from review.typo3.org; branch for authors, worktree for reviewers) |
| Reading only unresolved threads | Vote reasons often sit in patch-set messages or resolved comments: `gerrit.py status`, `comments --all` |
| Adding `htmlspecialchars()` because the report says "unescaped" | Trace the value to the output first; `implodeAttributes(…, true)` and Fluid already escape |
| A new commit for review feedback | `git commit -a --amend`, same Change-Id, new patch set |
| Trusting the hook to reject bad messages | `check-commit-msg.sh`, then `preflight.sh` |
| Guessing `Releases:` or version folders | `git branch -r`, `composer.json` branch-alias; the human decides backports |
| Reading CI failures as a guess | `gerrit.py ci <change>` → failed job + local reproduction command |
| Forgetting compiled JS/CSS | `qa.sh` runs `-s build`; amend `Resources/Public` changes |
