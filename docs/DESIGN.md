# typo3-contributor – Design

Status: draft, awaiting approval · 2026-10-01
Source: [TYPO3 Contribution Workflow Guide](https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/)
(GitHub `TYPO3-Documentation/TYPO3CMS-Guide-ContributionWorkflow`, read at `b5d4e84`, 2026-09-26)

## Goal

One Claude Code skill that guides a human contributor (and the agent working with them)
through TYPO3 Core contribution: setup, reporting issues, writing patches, reviewing/testing
others' patches and documentation/changelog patches – following the official guide and
closing the gaps where the guide is prose-only or web-UI-only.

## Decisions (from interview)

| Topic | Decision |
|---|---|
| Scope | Patch authoring, reviewing/testing, docs/changelog patches, issue reporting. Backports (merger-only) excluded. |
| Permissions | Read Gerrit/Forge freely. `git push` only after explicit user confirmation per push. Comments, votes and Forge tickets are drafted by the agent and posted by the human. |
| AI policy | AI may contribute; a human must supervise. Disclose AI assistance (Gerrit comment / Forge ticket). Human review of the full diff before every push is a mandatory step. |
| AI attribution | Optional local layer via `git-ai` (see below): line-level AI authorship as git notes, used to focus human review and to quantify the disclosure. Notes stay local. |
| Location | This directory as its own git repo, symlinked to `~/.claude/skills/typo3-contributor`. |
| Environment | Guide convention: `$HOME/work/TYPO3-Contribute`, DDEV project `t3c-main`; overridable via `TYPO3_CORE_DIR`. |
| Container runtime | Docker: always `runTests.sh -b docker`. |
| Language | English. |
| Shape | One skill, phase-structured; references loaded on demand. |
| Gerrit user | Read from `~/.ssh/config` (`Host review.typo3.org` → `User`). |
| Verification | Script tests + a real dry-run patch against a Core checkout (no push). |

## Layout

```
typo3-contributor-skill/
├── SKILL.md                     # entry: triggers, guardrails, phase router
├── references/
│   ├── setup.md                 # clone, git config, hooks, DDEV, SSH, troubleshooting
│   ├── issue.md                 # Forge bug report / task ticket drafting
│   ├── patch.md                 # diagnose → fix → QA → commit → push → iterate → reset
│   ├── commit-message.md        # full rules + examples
│   ├── qa-matrix.md             # which runTests.sh suites for which changed paths
│   ├── changelog.md             # rst types, path, index/scanner tags, rendering
│   ├── deprecation.md           # deprecation patterns + extension scanner matchers
│   ├── review.md                # cherry-pick, test, review checklist, vote draft
│   ├── docs-patch.md            # docs-only flow, render-guides
│   └── gerrit-forge-api.md      # read-only REST/SSH queries (CI status, comments)
├── templates/
│   ├── changelog/{Feature,Breaking,Deprecation,Important}.rst
│   ├── forge-bug.md, forge-task.md
│   └── gerrit-ai-disclosure.md
├── scripts/
│   ├── check-setup.sh           # verify/repair clone, remotes, hooks, template, SSH
│   ├── check-commit-msg.sh      # lint a commit message (file or HEAD)
│   ├── preflight.sh             # pre-push gate (see below)
│   ├── qa.sh                    # map changed files → runTests.sh suites, run them
│   ├── new-changelog.sh         # scaffold rst from template
│   ├── exception-code.sh        # unique timestamp exception code
│   └── gerrit.sh                # read-only: change status, CI votes, unresolved comments
├── tests/                       # bats-free plain shell tests for scripts/
└── docs/DESIGN.md
```

## Phases in SKILL.md

1. **setup** – `check-setup.sh`; idempotent; never overwrites user config without asking.
2. **issue** – draft Forge ticket from template; human submits; capture issue number.
3. **diagnose** (bugfix) – affected sysext, one piece of evidence, smallest reproducing test
   (aligned with user's "Diagnosis before fix" rule); confirm with user before editing.
4. **patch** – implement + tests; changelog/deprecation/scanner when applicable; build assets.
5. **qa** – `qa.sh` (changed-path → suites); `cglGit` fixes applied.
6. **commit** – template, `check-commit-msg.sh`.
7. **human review + push** – show full diff, AI disclosure reminder, `preflight.sh`,
   ask for confirmation, `git push origin HEAD:refs/for/main`.
8. **iterate** – `gerrit.sh` reads CI result + unresolved comments; amend (never new commit),
   keep Change-Id, re-run qa, confirm push.
9. **reset** – guide's reset block (stash, clean, reset to `origin/main`, composerInstall,
   cache flush/warmup, extension:setup).
10. **review** others – cherry-pick from Gerrit, test, checklist, draft comment + vote for human.
11. **docs** – docs-only path, render via `ghcr.io/typo3-documentation/render-guides`.

## Gap fills (not in the guide)

| Gap | Fill |
|---|---|
| Commit rules only prose | `check-commit-msg.sh`: keyword set, `[!!!]` position, deprecation ≠ `[!!!]`, subject ≤72 (warn >52), capital after keyword, blank line 2, body wrap 72 (URLs exempt), ≥1 `Resolves:`, one issue per line, space after colon, `Related` needs `Resolves`, `Releases:` present, no hand-written Change-Id on first commit. |
| No suite-per-change mapping | `qa-matrix.md` + `qa.sh`: PHP → `cglGit`, `lintPhp`, `phpstan`, nearest Unit/Functional dir; `Build/Sources` → `build`, `lintTypescript`/`lintScss`, compiled files must be staged; `*.xlf` → `normalizeXliff`; `*.rst` → render check; composer → `checkComposer`. |
| Changelog via Forger web tool only | rst templates incl. `..  index::` with exactly one of `FullyScanned/PartiallyScanned/NotScanned`; path discovered from repo (`typo3/sysext/core/Documentation/Changelog/<version>/`). |
| No pre-push gate | `preflight.sh`: exactly 1 commit ahead of `origin/main` (no accidental relation chain), hooks installed + executable, commit msg valid, Change-Id present after hook, no unstaged leftovers, compiled assets match sources, new PHP files have license header + `declare(strict_types=1)`, security keyword guard (`[SECURITY]` → stop, contact Security Team). |
| Gerrit only via web UI | `gerrit.sh` (public REST, read-only): change status, Core CI verified vote + job link, unresolved comments, latest patchset ref for cherry-pick. |
| `Releases:` → "ask in Slack" | suggest from `git branch -r` + guide rules (fix main first); human decides. |
| Exception timestamps unexplained | `exception-code.sh` → `date +%s`, grep for collisions. |
| Guide inconsistencies | standardize on explicit `git push origin HEAD:refs/for/main` and `-b docker`. |
| No AI guidance | Stance: AI may contribute, human supervises. Disclosure template (optionally with `git-ai stats`) + mandatory human diff review step. |

## Human supervision with git-ai (optional, local)

[git-ai](https://usegitai.com) records which lines
were written by an agent, as git notes under `refs/notes/ai`. It does not touch commit messages, so
TYPO3 commit rules and the `commit-msg` hook are unaffected.

How the skill uses it (only if `git-ai` is present; otherwise the skill falls back to plain diff review):

| Step | Command | Purpose |
|---|---|---|
| setup | `git-ai config set allow_repositories '<core remote glob>'`, `git-ai install-hooks` | scope tracking to the Core checkout; agent hooks (`checkpoint claude`) |
| before human review | `git-ai diff HEAD`, `git-ai blame <file>` | show AI-authored lines first – the human reviews those with priority |
| disclosure | `git-ai stats HEAD --json` | fill the Gerrit disclosure comment with the AI/human line share |
| iterate (amend/rebase) | – | git-ai carries attribution across amend/rebase |

Guardrails:
- **Notes never go to Gerrit.** Push is always the explicit `git push origin HEAD:refs/for/main`
  (single refspec). `preflight.sh` checks that no `refs/notes/*` push is configured for `origin`
  (`remote.origin.push`, notes push settings). Must be verified in the dry run, since git-ai
  documents syncing notes on push/fetch.
- Prompts may contain local paths or customer context: keep `prompt_storage` local, never `git-ai share`
  Core prompts publicly without the human's decision; consider `telemetry_oss` off.
- Attribution is a review aid, not a substitute: the mandatory human diff review stays.

## Guardrails (hard rules in SKILL.md)

- Never push, comment, vote or create tickets without explicit confirmation; posting is the human's job.
- Never invent or edit a `Change-Id`; never create a second commit for an existing change.
- Security issues: stop, no public push/ticket/Slack; point to typo3.org Security Team contact.
- Features only to `main`; breaking changes need `[!!!]` + Breaking rst.
- Don't vote on own patches.

## Verification plan

1. Shell tests for `check-commit-msg.sh` (good/bad fixtures for every rule), `preflight.sh`
   (temp git repo fixtures), `qa.sh` mapping (dry-run mode prints suites).
2. Real dry run: clone Core to `$HOME/work/TYPO3-Contribute`, run setup check, make a small
   real change (with test), run qa, commit, preflight – stop before push.
3. `gerrit.sh` against a real public change number.

## Open questions

- git-ai: does a plain `git push origin HEAD:refs/for/main` through the git-ai proxy also try to push
  `refs/notes/ai` to Gerrit? (verify in dry run; Gerrit would likely reject it).
- ~~Whether Forge REST (Redmine API key) should be added later for read-only issue lookup.~~ Resolved: the public JSON API needs no key; `gerrit.py forge --full` reads description, relations and comments. No Redmine MCP server, so the plugin stays read-only and setup-free.

## Changes after testing (2026-10-01)

- **Core `AGENTS.md` is authoritative** (loaded via the Core's `CLAUDE.md`). The skill defers to it and only adds human supervision, tooling and review flow. Adopted from it: `git commit -s` (DCO, pointed out at the gate), no line ≥ 72 chars, footer order, one Forge issue per commit, commits only on request, `CI=true` for test suites, changelog folder from `Typo3Version::BRANCH`, Forge JSON API.
- **Verified against Core instead of trusting docs:** the commit-msg hook never blocks; `-s acceptance` is gone (`-s e2e`); scanner tags are only required for Breaking/Deprecation; the optional pre-commit hook fails with host PHP < Core PHP, so it is no longer installed.
- **gerrit.py grew** `files`, `diff`, `forge`, `branches`, owner/uploader usernames ("this is YOUR change"), reviewer messages and `comments --all`, after GREEN tests showed vote reasons hide in resolved comments.
- **New:** `fix-trailer-order.sh` (after `--amend -s`), security heuristic in `preflight.sh` (~5 % of recent Core commits warn), topic branches, a handover section, and a reviewer disclosure variant.
- Dropped from the plan: `new-changelog.sh` and `exception-code.sh` (templates plus `date +%s` are enough).
- Still open: whether a git-ai git shim would push `refs/notes/ai` to Gerrit. The skill pushes with plain git and an explicit refspec, and `preflight.sh` blocks configured notes refspecs.
