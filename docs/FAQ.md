# FAQ

## General

### What does this skill do?

It guides an AI agent (Claude Code) and a human through a TYPO3 Core contribution: setup, Forge issue,
diagnosis, patch, QA, commit, push to Gerrit, iterating on feedback, and reviewing other people's changes.
It follows the official [Contribution Workflow Guide](https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/)
and corrects the places where the guide is outdated. See the [workflow diagram](contribution-workflow.svg).

### Is AI allowed to contribute to TYPO3 Core?

Yes, under human supervision. The Core checkout ships an `AGENTS.md` for agents; it is authoritative and
this skill follows it. The human reviews every line, signs off, decides every push and discloses the AI
assistance in a Gerrit comment.

### What does the agent do, and what does the human do?

| Agent | Human |
|---|---|
| Reads Forge, Gerrit and Core CI (read-only) | Creates Forge tickets |
| Diagnoses, writes tests and code | Confirms the diagnosis or API design |
| Commits when asked, runs `qa.sh` and `preflight.sh` | Reviews the full diff at the review gate |
| Drafts tickets, disclosure, replies and votes | Says yes to each push |
| Pushes after that yes | Posts all comments and votes in the Gerrit web UI |

### Why doesn't the agent post comments or votes itself?

Comments and votes speak for the human in a public community. A vote also has a meaning ("I read it",
"I tested it") that only the human can vouch for. The plugin's guard hook therefore denies `gerrit review`
and Gerrit REST writes, with no exception for time pressure.

## Setup

### What do I need?

git, bash, python3, Docker or Podman, and a typo3.org account with an SSH key uploaded to Gerrit and the
commit email registered as a Gerrit identity. DDEV is only needed for manual testing in the browser.
`bash scripts/quickstart-check.sh --online` checks all of it.

### Plugin or personal skill?

The plugin is recommended: it adds the guard hooks and the `container_runtime` / `core_dir` options.
The symlinked personal skill has the same instructions but no hooks. Install only one, or the skill is listed twice.

### Where does the Core checkout live?

`~/work/TYPO3-Contribute` by default, as in the guide. Change it with the plugin option `core_dir`
or `TYPO3_CORE_DIR`.

### Can I use Podman instead of Docker?

Yes. Set the plugin option `container_runtime` to `podman` (or `TYPO3_CONTRIB_RUNTIME=podman`). All scripts
pass it to `runTests.sh -b`.

### Why is `git fetch origin refs/changes/…` failing?

`origin` fetches from GitHub, which has no `refs/changes`. Patch sets come from review.typo3.org;
`python3 scripts/gerrit.py fetch <change>` prints the right commands. Pushes go to Gerrit via the `pushurl`.

## Patches

### Do I always need a Forge issue?

Yes. Every commit has its own Forge issue (`Resolves: #<id>`). The agent drafts a ticket if none exists;
the human creates it. The agent never invents an issue number.

### What if the bug might be a security issue?

Stop. No public commit, ticket, push or Slack message. Report it to the
[TYPO3 Security Team](https://typo3.org/community/teams/security/contact-us/). If in doubt, the agent asks
before any public step.

### Which tests does `qa.sh` run?

The `runTests.sh` suites that match the files in the HEAD commit, e.g. `cglGit`, `lintPhp`, `phpstan`
and the nearest unit/functional tests for PHP, `build` and the linters for `Build/Sources`, `normalizeXliff`
for XLIFF. `qa.sh --dry-run` shows the list without running it. The first run pulls container images and
takes a while.

### What does `preflight.sh` check?

Exactly one commit ahead of `origin/main`, the commit-msg hook and a Change-Id, a valid commit message,
`Signed-off-by` matching the author, a clean working tree, license headers and `strict_types` in new PHP files,
compiled assets next to changed sources, a changelog rst that matches the prefix, no notes refspec,
and a security heuristic. It must print
`PREFLIGHT OK`; its WARN lines need an answer from the human.

### Why isn't the commit-msg hook enough?

The Core hook never blocks: it exits 0 even without `Resolves:` and only flags lines of 73+ characters.
`AGENTS.md` is stricter (no line may reach 72). `check-commit-msg.sh` enforces the stricter rules.

### Why no `Co-Authored-By` trailer?

The Core commit rules do not use it. AI assistance is disclosed in the Gerrit comment instead
(`templates/gerrit-disclosure.md`). The guard hook denies `Co-Authored-By` in Core commits.

### What does `Signed-off-by` mean here?

`git commit -s` certifies the Developer Certificate of Origin in the human's name. The agent points this out
at the review gate, because the human takes responsibility for the change.

### Which branches go into `Releases:`?

Candidates come from `python3 scripts/gerrit.py branches` (main plus maintained LTS). Bugfixes start on `main`;
an LTS branch is only included if the bug exists there. Features and `[!!!]` changes are `main` only.
The backport scope is the human's call.

## Review gate and push

### What is the review gate?

Before every push the agent shows the full diff, the `preflight.sh` and `qa.sh` results, the DCO note,
the filled disclosure comment and the exact push command, then waits. Only a yes given at that point counts;
"just push it" before seeing the diff does not.

### What if I have no time to review?

The commit stays local and nothing is lost. The agent writes a handover: branch, stashes, preflight output,
green suites, open questions and the push command.

### The guard hook denied my push. What now?

The rule is working. Usually `preflight.sh` failed; fix what it reports instead of rephrasing the command.

## Iterating

### A reviewer left comments or Core CI is red. How do I update the change?

`gerrit.py status`, `comments --all` and `ci` show votes, all threads (including resolved ones, where vote
reasons often hide) and the failed jobs with a local reproduction command. Fetch the latest patch set,
fix, run `qa.sh`, then `git commit -a --amend`. Same Change-Id, new patch set, never a new commit.
The agent drafts one reply per thread; the human posts them.

### My push created a second change instead of a patch set.

The Change-Id was changed or removed. The human abandons the duplicate; amend with the original Change-Id.

### CI is red but everything is green locally.

Usually a stale base. `git fetch origin && git rebase origin/main`, then rerun the job with the flags
`gerrit.py ci` prints (PHP version, DBMS).

## Reviewing others

### Can I review other people's changes with the agent?

Yes. The agent reads the change with `gerrit.py status/comments/diff`, tests it in a separate worktree,
goes through the review checklist and drafts the vote and comment. The human posts them. A green Core CI is
not a reason for a human Verified +1; that means "I tested it". Authors never vote on their own change.

## Optional git-ai

### What is git-ai for?

[git-ai](https://usegitai.com) records which lines an agent wrote, as local git notes. The skill uses it,
if installed, to show AI-written lines first at the review gate and to put a percentage into the disclosure.
The notes never go to Gerrit; `preflight.sh` blocks configured notes refspecs.

## More help

- Error messages: [`references/troubleshooting.md`](../references/troubleshooting.md)
- Setup and reset: [`references/setup.md`](../references/setup.md)
- Design decisions: [`DESIGN.md`](DESIGN.md)
