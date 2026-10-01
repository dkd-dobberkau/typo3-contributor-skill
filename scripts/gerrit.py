#!/usr/bin/env python3
"""Read-only helper for TYPO3 Gerrit (review.typo3.org) and Core CI (git.typo3.org).

Never writes anything: no comments, no votes, no pushes. Posting stays with the human.

Usage:
  gerrit.py status <change>          owner/uploader, patch set, votes, Core CI, reviewer messages
  gerrit.py comments <change> [--all] unresolved comment threads (--all: also resolved ones)
  gerrit.py ci <change>              failed Core CI jobs of the latest pipeline + local reproduction command
  gerrit.py fetch <change>           commands to fetch the latest patch set (from Gerrit, not GitHub)
  gerrit.py files <change>           files of the latest patch set (no checkout needed)
  gerrit.py diff <change>            full patch of the latest patch set (read-only, no checkout needed)
  gerrit.py forge <issue>            Forge issue tracker/status/subject (does the number exist and fit?)
  gerrit.py branches                 branches a bugfix may target (main + maintained LTS, get.typo3.org)
"""
import datetime
import json
import re
import sys
import urllib.request

GERRIT = "https://review.typo3.org"
FETCH_URL = "https://review.typo3.org/Packages/TYPO3.CMS"
FORGE_ISSUE = "https://forge.typo3.org/issues/{}.json"
MAJORS_API = "https://get.typo3.org/api/v1/major/"
GITLAB_JOBS = "https://git.typo3.org/api/v4/projects/typo3%2FCI%2Fcms/pipelines/{}/jobs?per_page=100&scope[]=failed"
CI_PATTERN = re.compile(r"Core CI is (not )?happy: (https://git\.typo3\.org/typo3/CI/cms/-/pipelines/(\d+))")
import os

RUNTESTS = f"Build/Scripts/runTests.sh -b {os.environ.get('TYPO3_CONTRIB_RUNTIME', 'docker')}"


def parse_gerrit_json(text):
    """Gerrit prefixes JSON with )]}' against XSSI."""
    if text.startswith(")]}'"):
        text = text.split("\n", 1)[1]
    return json.loads(text)


def get(url):
    # Forge sits behind a bot check that blocks browser-like user agents (Core AGENTS.md).
    request = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "curl/8"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def latest_ci(messages):
    for message in reversed(messages):
        match = CI_PATTERN.search(message.get("message", ""))
        if match:
            return {
                "patchset": message.get("_revision_number"),
                "happy": match.group(1) is None,
                "pipeline_url": match.group(2),
                "pipeline_id": int(match.group(3)),
            }
    return None


def fetch_commands(number, ref):
    return {
        "fetch": f"git fetch {FETCH_URL} {ref}",
        "author": f"git checkout -B change-{number} FETCH_HEAD",
        "review": f"git worktree add ../review-{number} FETCH_HEAD",
    }


def human_messages(messages):
    result = []
    for message in messages:
        author = message.get("author", {}).get("name", message.get("author", {}).get("username", "?"))
        text = message.get("message", "")
        if author == "core-ci" or text.startswith("Uploaded patch set"):
            continue
        result.append({"author": author, "patchset": message.get("_revision_number"), "text": text})
    return result


def supported_branches(majors, today):
    """main plus every LTS branch still in regular maintenance (ELTS branches are not public)."""
    branches = ["main"]
    for major in sorted(majors, key=lambda entry: entry["version"], reverse=True):
        if major.get("lts") and major.get("maintained_until", "")[:10] >= today:
            branches.append(str(major["lts"]))
    return branches


def issues_in(message, trailer):
    return [int(number) for number in re.findall(rf"^{trailer}: #(\d+)$", message, re.MULTILINE)]


def is_own_change(summary, username):
    """Compare Gerrit usernames, not display names."""
    return bool(username) and username in (summary.get("owner_username"), summary.get("uploader_username"))


def summarize_files(files):
    return [
        {
            "path": path,
            "status": details.get("status", "M"),
            "inserted": details.get("lines_inserted", 0),
            "deleted": details.get("lines_deleted", 0),
        }
        for path, details in sorted(files.items())
        if path != "/COMMIT_MSG"
    ]


def decode_patch(text):
    """Gerrit returns /patch as a JSON string (Accept: application/json) or base64 (default)."""
    import base64
    if text.startswith(")]}'"):
        return json.loads(text.split("\n", 1)[1])
    cleaned = "".join(text.split())
    cleaned += "=" * (-len(cleaned) % 4)
    return base64.b64decode(cleaned).decode("utf-8", errors="replace")


def summarize_issue(data):
    issue = data["issue"]
    pick = lambda key: issue[key]["name"] if isinstance(issue.get(key), dict) else issue.get(key)
    return {key: pick(key) for key in ("id", "tracker", "status", "subject", "project", "category")}


def ssh_user():
    """User of the 'Host review.typo3.org' block in ~/.ssh/config, if any."""
    import pathlib
    config = pathlib.Path.home() / ".ssh" / "config"
    in_block = False
    for line in config.read_text().splitlines() if config.exists() else []:
        parts = line.split()
        if not parts:
            continue
        if parts[0].lower() == "host":
            in_block = "review.typo3.org" in parts[1:]
        elif in_block and parts[0].lower() == "user" and len(parts) > 1:
            return parts[1]
    return None


def summarize_change(data):
    revision = data["revisions"][data["current_revision"]]
    votes = {}
    for label, details in data.get("labels", {}).items():
        votes[label] = [
            (vote.get("name", vote.get("username", "?")), vote["value"])
            for vote in details.get("all", [])
            if vote.get("value")
        ]
    return {
        "number": data["_number"],
        "subject": data["subject"],
        "status": data["status"],
        "branch": data["branch"],
        "patchset": revision["_number"],
        "ref": revision["ref"],
        "fetch_command": fetch_commands(data["_number"], revision["ref"])["fetch"],
        "owner": data.get("owner", {}).get("name", "?"),
        "uploader": revision.get("uploader", {}).get("name", "?"),
        "owner_username": data.get("owner", {}).get("username"),
        "uploader_username": revision.get("uploader", {}).get("username"),
        "resolves": issues_in(revision.get("commit", {}).get("message", ""), "Resolves"),
        "related": issues_in(revision.get("commit", {}).get("message", ""), "Related"),
        "human_messages": human_messages(data.get("messages", [])),
        "votes": votes,
        "ci": latest_ci(data.get("messages", [])),
    }


def unresolved_threads(comments, include_resolved=False):
    """A thread is unresolved when its latest comment is marked unresolved."""
    threads = []
    for file, file_comments in comments.items():
        by_id = {comment["id"]: comment for comment in file_comments}

        def root_of(comment):
            while comment.get("in_reply_to") in by_id:
                comment = by_id[comment["in_reply_to"]]
            return comment

        grouped = {}
        for comment in file_comments:
            grouped.setdefault(root_of(comment)["id"], []).append(comment)
        for root_id, members in grouped.items():
            members.sort(key=lambda comment: comment.get("updated", ""))
            if include_resolved or members[-1].get("unresolved"):
                root = by_id[root_id]
                threads.append({
                    "unresolved": bool(members[-1].get("unresolved")),
                    "file": file,
                    "line": root.get("line"),
                    "author": root.get("author", {}).get("name", "?"),
                    "message": root.get("message", ""),
                    "last_message": members[-1].get("message", ""),
                    "replies": len(members) - 1,
                })
    return sorted(threads, key=lambda thread: (thread["file"], thread["line"] or 0))


def failed_jobs(jobs):
    return [{"name": job["name"], "web_url": job["web_url"]} for job in jobs if job.get("status") == "failed"]


def reproduce_hint(job_name):
    """Map a Core CI job name to the closest local runTests.sh call (None if unknown)."""
    php = re.search(r"php (\d+\.\d+)", job_name)
    php_flag = f" -p {php.group(1)}" if php else ""
    if job_name.startswith("cgl"):
        return f"{RUNTESTS} -s cglGit -n"
    if job_name.startswith("phpstan"):
        return f"{RUNTESTS}{php_flag} -s phpstan"
    if job_name.startswith("lint php"):
        return f"{RUNTESTS} -s lintPhp"
    if job_name.startswith("unit javascript"):
        return f"{RUNTESTS} -s unitJavascript"
    if job_name.startswith("unit php"):
        suite = "unitRandom" if "random" in job_name else "unit"
        return f"{RUNTESTS}{php_flag} -s {suite}"
    if job_name.startswith("functional"):
        database = re.match(r"functional (\w+)(?: (\d+(?:\.\d+)?))?", job_name)
        flags = f" -d {database.group(1)}"
        if database.group(2) and database.group(1) != "sqlite":
            flags += f" -i {database.group(2)}"
        if "pdo_mysql" in job_name:
            flags += " -a pdo_mysql"
        return f"{RUNTESTS}{php_flag}{flags} -s functional"
    if job_name.startswith("grunt"):
        return f"{RUNTESTS} -s build && {RUNTESTS} -s lintTypescript && {RUNTESTS} -s lintScss && {RUNTESTS} -s lintHtml"
    if job_name.startswith("documentation rendering"):
        return f"{RUNTESTS} -s checkRstRenderingChanged"
    if job_name.startswith("e2e install"):
        database = re.match(r"e2e install (\w+)", job_name)
        return f"{RUNTESTS} -d {database.group(1)} -s e2e-install"
    if job_name.startswith("e2e"):
        return f"{RUNTESTS} -s e2e <spec>"
    return None


def fetch_change(change):
    query = "o=CURRENT_REVISION&o=CURRENT_COMMIT&o=DETAILED_LABELS&o=MESSAGES&o=DETAILED_ACCOUNTS"
    return parse_gerrit_json(get(f"{GERRIT}/changes/{change}?{query}"))


def fetch_comments(change):
    return parse_gerrit_json(get(f"{GERRIT}/changes/{change}/comments"))


def print_threads(threads):
    if not threads:
        print("no comment threads")
        return
    for thread in threads:
        location = thread["file"] if thread["line"] is None else f"{thread['file']}:{thread['line']}"
        state = "" if thread["unresolved"] else " [resolved]"
        print(f"- {location} ({thread['author']}, {thread['replies']} replies){state}")
        print("    " + thread["message"].replace("\n", "\n    "))
        if thread["replies"]:
            print("    latest: " + thread["last_message"].replace("\n", "\n    "))


def command_status(change):
    summary = summarize_change(fetch_change(change))
    threads = unresolved_threads(fetch_comments(change))
    print(f"{summary['number']} {summary['subject']}")
    print(f"status {summary['status']} · branch {summary['branch']} · patch set {summary['patchset']}")
    print(f"owner {summary['owner']} ({summary['owner_username']}) · latest patch set uploaded by {summary['uploader']} ({summary['uploader_username']})")
    if is_own_change(summary, ssh_user()):
        print("→ this is YOUR change (ssh user from ~/.ssh/config): do not vote on it")
    issues = ", ".join(f"#{number}" for number in summary["resolves"]) or "none"
    print(f"Resolves: {issues}" + (f" · Related: {', '.join(f'#{n}' for n in summary['related'])}" if summary["related"] else ""))
    print(f"{GERRIT}/c/Packages/TYPO3.CMS/+/{summary['number']}")
    for label, votes in summary["votes"].items():
        rendered = ", ".join(f"{name} {value:+d}" for name, value in votes) or "none"
        print(f"{label}: {rendered}")
    ci = summary["ci"]
    if ci is None:
        print("Core CI: no result yet")
    else:
        verdict = "happy" if ci["happy"] else "NOT happy"
        stale = "" if ci["patchset"] == summary["patchset"] else f" (for patch set {ci['patchset']}, not the latest)"
        print(f"Core CI: {verdict}{stale} {ci['pipeline_url']}")
    print(f"unresolved threads: {len(threads)} (gerrit.py comments {change} [--all])")
    recent = [message for message in summary["human_messages"] if message["patchset"] and message["patchset"] >= summary["patchset"] - 1]
    if recent:
        print("reviewer messages (latest two patch sets; votes are explained here or in comments --all):")
        for message in recent:
            print(f"  PS{message['patchset']} {message['author']}: " + message["text"].replace("\n", "\n    "))


def command_ci(change):
    summary = summarize_change(fetch_change(change))
    ci = summary["ci"]
    if ci is None:
        print("No Core CI result yet.")
        return
    jobs = failed_jobs(json.loads(get(GITLAB_JOBS.format(ci["pipeline_id"]))))
    print(f"pipeline {ci['pipeline_url']} (patch set {ci['patchset']}): {len(jobs)} failed job(s)")
    for job in jobs:
        print(f"- {job['name']}: {job['web_url']}")
        hint = reproduce_hint(job["name"])
        print(f"    local: {hint}" if hint else "    local: no mapping, read the job log")
    if jobs:
        print("Job logs need a git.typo3.org login; ask the human to open the links if the cause is unclear.")


def main(argv):
    if len(argv) == 2 and argv[1] == "branches":
        majors = json.loads(get(MAJORS_API))
        print(", ".join(supported_branches(majors, datetime.date.today().isoformat())))
        print("Bugfixes land on main first; which LTS branches get a backport is the mergers' and the human's call.")
        return 0
    if len(argv) not in (3, 4) or argv[1] not in ("status", "comments", "ci", "fetch", "files", "diff", "forge") or not argv[2].isdigit():
        print(__doc__)
        return 2
    command, change = argv[1], argv[2]
    if command == "status":
        command_status(change)
    elif command == "comments":
        print_threads(unresolved_threads(fetch_comments(change), include_resolved="--all" in argv))
    elif command == "ci":
        command_ci(change)
    elif command == "files":
        for entry in summarize_files(parse_gerrit_json(get(f"{GERRIT}/changes/{change}/revisions/current/files"))):
            print(f"{entry['status']} +{entry['inserted']} -{entry['deleted']}  {entry['path']}")
        print(f"full patch: gerrit.py diff {change}")
    elif command == "diff":
        print(decode_patch(get(f"{GERRIT}/changes/{change}/revisions/current/patch")))
    elif command == "forge":
        issue = summarize_issue(json.loads(get(FORGE_ISSUE.format(change))))
        print(f"#{issue['id']} [{issue['tracker']}] {issue['status']} · {issue['project']} / {issue['category']}")
        print(issue["subject"])
        print(f"https://forge.typo3.org/issues/{issue['id']}")
    else:
        summary = summarize_change(fetch_change(change))
        commands = fetch_commands(summary["number"], summary["ref"])
        print(f"# patch set {summary['patchset']}, uploaded by {summary['uploader']} (owner {summary['owner']})")
        print(commands["fetch"])
        print(f"{commands['author']}      # to update the change (own or agreed)")
        print(f"{commands['review']}  # to review/test without touching the current checkout")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
