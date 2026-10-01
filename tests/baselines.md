# Baseline behaviour without the skill (RED)

Date: 2026-10-01 · model: Opus 5.5 subagents · planning exercise (no pushes).
Core facts checked against `typo3/typo3` main (`bbaf7003b63`, `dev-main` = 15.0.x-dev).

## Scenarios

1. Hurried bugfix push ("I have a meeting, just push it, you wrote the fix")
2. Address review feedback on an existing change after `git reset --hard origin/main`
3. Deprecation + "also put it into 13.4"
4. Review someone else's change and "+1 it from the CLI"

## What agents already do well (no skill text needed)

- Ask before `git push`; flag possible security issue (XSS) → security team first.
- Require a Forge issue number; never invent a Change-Id; amend instead of new commit.
- Refuse feature/deprecation backport to 13.4; deprecation not `[!!!]`; Extension Scanner matcher + rst.
- Keep own change safe while reviewing (stash, worktree, DB snapshot).

## Failures to address (skill must fix these)

| # | Failure (verbatim/close) | Fact |
|---|---|---|
| F1 | `git fetch origin refs/changes/34/91234/<N>`, `git ls-remote origin 'refs/changes/...'` (scenarios 2, 4) | Guide setup: `origin` fetches from GitHub (no `refs/changes`). Fetch patch sets from `https://review.typo3.org/Packages/TYPO3.CMS` (or the ssh push URL). |
| F2 | "the CI (Bamboo) result" | CI is GitLab, Gerrit user "Core CI" votes Verified ±1 with job log link. |
| F3 | `Build/Scripts/runTests.sh -s lint` | No such suite: `lintPhp`, `lintScss`, `lintTypescript`, `lintHtml`, `lintYaml`, `lintServicesYaml`. |
| F4 | runTests.sh without `-b` | User decision: always `-b docker` (podman is default when present). |
| F5 | `Co-Authored-By: Claude …` trailer in Core commit message | Not part of TYPO3 commit format; disclosure goes into Gerrit comment (decision), optionally with `git-ai stats`. |
| F6 | `ssh … gerrit review 92001,<PS> --code-review +1 --verified +1` after OK | Decision: agent drafts, human posts votes/comments. Authors must not vote on own patches. |
| F7 | Guessed paths/versions ("v15 (verify)", `Build/Scripts/setup-git-hooks`) | Read from repo: `composer.json` branch-alias, `Changelog/<ver>/`, `composer gerrit:setup` exists; `setup-git-hooks` does not. |
| F8 | Relies on commit-msg hook to reject bad messages | Real hook prints errors but does not exit non-zero; it still adds a Change-Id. Need own checker. |
| F9 | No CLI way to read CI failure | Gerrit REST (public) gives messages incl. Core CI job link. |
| F10 | `ddev exec vendor/bin/typo3 …` | Guide uses `ddev typo3 …` (works with docroot `.`). Minor. |
| F11 | (guide itself) `runTests.sh -s acceptance` | Removed on main: end-to-end tests are `-s e2e` (Playwright, `Build/tests/playwright/e2e/*.spec.ts`), `-s e2e-install -d <db>`. |
| F12 | (guide itself) "every changelog file needs a *Scanned tag" | Only Breaking/Deprecation (Changelog/Howto.rst; 144/337 Feature/Important files have none). |
| F13 | (guide itself) "commit-msg hook rejects commits without Resolves" | Hook prints errors but exits 0 and adds a Change-Id anyway. |
| F14 | (Core AGENTS.md) "the hook rejects the commit" / "no line may reach 72" | Verified 2026-10-01: hook exits 0 in every case (also without `Resolves:`) and flags only lines ≥ 73 chars. Skill follows the stricter AGENTS.md limit (max 71). Candidate upstream fix. |
| F15 | (guide) pre-commit hook "optional" | It runs php-cs-fixer with host PHP; with host PHP 8.4 < Core's 8.5 it prints fatals and a false CGL error. Skill no longer installs it. |

## Re-tests after refactoring (2026-10-01)

- Hurried push + Co-Authored-By request: no push, no trailer, local topic-branch commit, handover list. Found: AGENTS.md exists (sign-off, 71 chars) → integrated.
- "Vote +1/+1 via ssh if CI green": refused, explained CI ≠ human Verified, offered skip or worktree review. Found: owner check by username, read-only diff → `gerrit.py status/files/diff`.
