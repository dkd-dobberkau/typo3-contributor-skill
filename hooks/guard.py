#!/usr/bin/env python3
"""PreToolUse guard for TYPO3 Core contributions (Bash tool).

Enforces the skill's hard rules mechanically:
- a push to Gerrit runs preflight.sh first: denied if it fails, otherwise
  "ask" so the human confirms at the review gate;
- posting to Gerrit (gerrit review/abandon/submit/..., REST writes) is denied;
- Co-Authored-By in a commit inside the Core checkout is denied.

Everything else (other repositories, other commands) is left alone.
Prints nothing and exits 0 when it has no opinion or cannot parse its input.
"""
import json
import os
import re
import shlex
import subprocess
import sys

SCRIPTS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts")
GERRIT_HOST = "review.typo3.org"
GERRIT_WRITE = re.compile(r"\bgerrit\s+(review|abandon|restore|submit|set-reviewers|set-topic|set-head|create-project|rename-project)\b")
REST_WRITE = re.compile(r"(-X\s*(POST|PUT|DELETE)\b|--request\s+(POST|PUT|DELETE)\b|\s(-d|--data\S*)\s)")
PUSH = re.compile(r"\bgit\s+(?:-C\s+(\S+)\s+)?push\b")
COMMIT = re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?commit\b")
# git commands that change HEAD or the working tree; preflight.sh runs before the whole command
HEAD_CHANGE = re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?(checkout|switch|reset|rebase|commit|cherry-pick|merge|pull|am|revert|stash)\b")
CD_PREFIX = re.compile(r"^\s*cd\s+(\S+)\s*&&")


def decision(kind, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": kind,
        "permissionDecisionReason": reason,
    }}))


def target_dir(cwd, command):
    """Directory the git command acts on: `cd X &&` prefix or `git -C X`, else cwd."""
    directory = cwd
    cd = CD_PREFIX.match(command)
    if cd:
        directory = os.path.join(cwd, os.path.expanduser(shlex.split(cd.group(1))[0]))
    push = PUSH.search(command)
    if push and push.group(1):
        directory = os.path.join(directory, os.path.expanduser(push.group(1)))
    return directory


def is_core_checkout(directory):
    try:
        urls = subprocess.run(
            ["git", "-C", directory, "config", "--get-regexp", r"^remote\.origin\.(push)?url$"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return GERRIT_HOST in urls


def check(cwd, command):
    if GERRIT_HOST in command and (GERRIT_WRITE.search(command) or ("curl" in command and REST_WRITE.search(command))):
        return decision("deny", "Posting to Gerrit (votes, comments, abandon, submit) is not done by the agent: "
                                "draft the text, the human posts it in the Gerrit web UI.")

    is_push, is_commit = PUSH.search(command), COMMIT.search(command)
    if not (is_push or is_commit):
        return None  # fast path: the hook runs for every Bash call in every project
    directory = target_dir(cwd, command)
    core = is_core_checkout(directory)

    if is_commit and core and re.search(r"co-authored-by", command, re.IGNORECASE):
        return decision("deny", "No Co-Authored-By in TYPO3 Core commits (Core AGENTS.md: do not credit "
                                "tooling). Disclose AI help in the Gerrit comment instead (templates/gerrit-disclosure.md).")

    if is_push and (core or GERRIT_HOST in command):
        if HEAD_CHANGE.search(command[:is_push.start()]):
            return decision("deny", "The push follows a git command that changes HEAD or the working tree in the "
                                    "same call, but preflight.sh runs before the call and would check the old HEAD. "
                                    "Run that command first, then push in a separate call.")
        try:
            result = subprocess.run(["bash", os.path.join(SCRIPTS, "preflight.sh")], cwd=directory,
                                    capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.SubprocessError) as error:
            return decision("deny", f"preflight.sh could not run ({error}); push blocked.")
        if result.returncode != 0:
            return decision("deny", "preflight.sh failed, push blocked:\n" + (result.stdout + result.stderr)[-3000:])
        return decision("ask", "TYPO3 review gate: preflight passed. The human must have seen the full diff "
                               "and confirm this push to Gerrit.")
    return None


def main():
    try:
        data = json.load(sys.stdin)
        command = data["tool_input"]["command"]
        cwd = data.get("cwd") or os.getcwd()
    except (ValueError, KeyError, TypeError):
        return 0
    if data.get("tool_name", "Bash") != "Bash" or not isinstance(command, str):
        return 0
    check(cwd, command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
