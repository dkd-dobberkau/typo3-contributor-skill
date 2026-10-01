"""Tests for scripts/gerrit.py (offline, anonymized fixtures of real API responses)."""
import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures" / "gerrit"
spec = importlib.util.spec_from_file_location("gerrit", ROOT / "scripts" / "gerrit.py")
gerrit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gerrit)


def load(name):
    return gerrit.parse_gerrit_json((FIXTURES / name).read_text())


class ParseTest(unittest.TestCase):
    def test_strips_xssi_prefix(self):
        self.assertEqual(gerrit.parse_gerrit_json(")]}'\n{\"a\": 1}"), {"a": 1})


class SummaryTest(unittest.TestCase):
    def setUp(self):
        self.summary = gerrit.summarize_change(load("change.json"))

    def test_basics(self):
        self.assertEqual(self.summary["number"], 94827)
        self.assertEqual(self.summary["status"], "NEW")
        self.assertEqual(self.summary["branch"], "main")
        self.assertEqual(self.summary["patchset"], 3)
        self.assertEqual(self.summary["ref"], "refs/changes/27/94827/3")

    def test_fetch_uses_review_server_not_origin(self):
        self.assertEqual(
            self.summary["fetch_command"],
            "git fetch https://review.typo3.org/Packages/TYPO3.CMS refs/changes/27/94827/3",
        )

    def test_owner_and_uploader(self):
        self.assertEqual(self.summary["owner"], "Reviewer 2")
        self.assertEqual(self.summary["uploader"], "Reviewer 2")

    def test_human_messages_exclude_ci_and_uploads(self):
        messages = self.summary["human_messages"]
        authors = [message["author"] for message in messages]
        self.assertNotIn("core-ci", authors)
        self.assertIn(("Reviewer 3", 3), [(message["author"], message["patchset"]) for message in messages])
        self.assertFalse(any(message["text"].startswith("Uploaded patch set") for message in messages))


    def test_votes(self):
        self.assertIn(("Reviewer 3", -1), self.summary["votes"]["Verified"])
        self.assertIn(("core-ci", 1), self.summary["votes"]["Verified"])

    def test_latest_ci_result(self):
        ci = self.summary["ci"]
        self.assertEqual(ci["patchset"], 3)
        self.assertTrue(ci["happy"])
        self.assertRegex(ci["pipeline_url"], r"^https://git\.typo3\.org/typo3/CI/cms/-/pipelines/\d+$")
        self.assertEqual(ci["pipeline_id"], int(ci["pipeline_url"].rsplit("/", 1)[1]))


class CiParsingTest(unittest.TestCase):
    def test_unhappy_message(self):
        messages = [
            {"_revision_number": 1, "author": {"name": "core-ci"}, "message": "Patch Set 1: Verified+1\n\nCore CI is happy: https://git.typo3.org/typo3/CI/cms/-/pipelines/1"},
            {"_revision_number": 2, "author": {"name": "core-ci"}, "message": "Patch Set 2: Verified-1\n\nCore CI is not happy: https://git.typo3.org/typo3/CI/cms/-/pipelines/2"},
        ]
        ci = gerrit.latest_ci(messages)
        self.assertEqual(ci, {"patchset": 2, "happy": False, "pipeline_url": "https://git.typo3.org/typo3/CI/cms/-/pipelines/2", "pipeline_id": 2})

    def test_no_ci_yet(self):
        self.assertIsNone(gerrit.latest_ci([{"_revision_number": 1, "author": {"name": "x"}, "message": "Uploaded patch set 1."}]))


class CommentsTest(unittest.TestCase):
    def test_unresolved_threads_use_last_comment_state(self):
        threads = gerrit.unresolved_threads(load("comments.json"))
        files = {t["file"] for t in threads}
        self.assertIn("typo3/sysext/core/Classes/Log/LogManager.php", files)
        # thread resolution follows the latest comment; replies are folded into their root
        roots = [t for t in threads if t["file"] == "typo3/sysext/core/Classes/Log/LogManager.php"]
        self.assertEqual(sorted(t["line"] for t in roots), [175, 211])
        self.assertTrue(all(t["replies"] == 1 for t in roots))
        # resolved patchset-level comment is not listed
        self.assertEqual([t for t in threads if t["file"] == "/PATCHSET_LEVEL"].__len__(), 1)

    def test_include_resolved(self):
        all_threads = gerrit.unresolved_threads(load("comments.json"), include_resolved=True)
        unresolved = gerrit.unresolved_threads(load("comments.json"))
        self.assertGreater(len(all_threads), len(unresolved))
        self.assertTrue(any(not thread["unresolved"] for thread in all_threads))

    def test_resolved_by_reply(self):
        comments = {"a.php": [
            {"id": "r", "line": 3, "updated": "2026-01-01 10:00:00.000000000", "message": "fix", "unresolved": True, "author": {"name": "A"}},
            {"id": "s", "in_reply_to": "r", "line": 3, "updated": "2026-01-02 10:00:00.000000000", "message": "Done", "unresolved": False, "author": {"name": "B"}},
        ]}
        self.assertEqual(gerrit.unresolved_threads(comments), [])


class JobsTest(unittest.TestCase):
    def test_failed_jobs(self):
        jobs = json.loads((FIXTURES / "jobs-failed.json").read_text())
        failed = gerrit.failed_jobs(jobs)
        self.assertEqual(failed[0]["name"], "phpstan php 8.5 pre-merge")
        self.assertTrue(failed[0]["web_url"].startswith("https://git.typo3.org/typo3/CI/cms/-/jobs/"))

    def test_local_reproduction_hint(self):
        self.assertEqual(gerrit.reproduce_hint("phpstan php 8.5 pre-merge"), "Build/Scripts/runTests.sh -b docker -p 8.5 -s phpstan")
        self.assertEqual(gerrit.reproduce_hint("functional sqlite php 8.6 pre-merge 3/12"), "Build/Scripts/runTests.sh -b docker -p 8.6 -d sqlite -s functional")
        self.assertEqual(gerrit.reproduce_hint("cgl pre-merge"), "Build/Scripts/runTests.sh -b docker -s cglGit -n")


class FetchModesTest(unittest.TestCase):
    def test_modes(self):
        commands = gerrit.fetch_commands(94827, "refs/changes/27/94827/3")
        self.assertEqual(commands["fetch"], "git fetch https://review.typo3.org/Packages/TYPO3.CMS refs/changes/27/94827/3")
        self.assertEqual(commands["author"], "git checkout -B change-94827 FETCH_HEAD")
        self.assertEqual(commands["review"], "git worktree add ../review-94827 FETCH_HEAD")


class BranchesTest(unittest.TestCase):
    def test_supported_branches_from_get_typo3_org(self):
        majors = json.loads((FIXTURES / "majors.json").read_text())
        self.assertEqual(gerrit.supported_branches(majors, "2026-10-01"), ["main", "14.3", "13.4"])
        self.assertEqual(gerrit.supported_branches(majors, "2028-01-15"), ["main", "14.3"])



class OwnershipAndIssueTest(unittest.TestCase):
    def setUp(self):
        self.summary = gerrit.summarize_change(load("change.json"))

    def test_usernames(self):
        self.assertEqual(self.summary["owner_username"], "owner-user")
        self.assertEqual(self.summary["uploader_username"], "owner-user")

    def test_own_change_by_ssh_user(self):
        self.assertTrue(gerrit.is_own_change(self.summary, "owner-user"))
        self.assertFalse(gerrit.is_own_change(self.summary, "someone-else"))
        self.assertFalse(gerrit.is_own_change(self.summary, None))

    def test_issues_from_commit_message(self):
        self.assertEqual(self.summary["resolves"], [110222])
        self.assertEqual(self.summary["related"], [110100])


class FilesTest(unittest.TestCase):
    def test_files_without_commit_msg(self):
        files = gerrit.summarize_files(load("files.json"))
        paths = [entry["path"] for entry in files]
        self.assertNotIn("/COMMIT_MSG", paths)
        self.assertTrue(any(path.endswith(".rst") for path in paths))
        self.assertTrue(all({"path", "status", "inserted", "deleted"} <= set(entry) for entry in files))


class PatchTest(unittest.TestCase):
    def test_decode(self):
        import base64
        self.assertEqual(gerrit.decode_patch(base64.b64encode(b"From abc\n").decode()), "From abc\n")
        self.assertEqual(gerrit.decode_patch(")]}'\n\"From abc\\n\""), "From abc\n")


class ForgeTest(unittest.TestCase):
    def test_issue_summary(self):
        issue = gerrit.summarize_issue(json.loads((FIXTURES / "forge-issue.json").read_text()))
        self.assertEqual(issue, {
            "id": 110864, "tracker": "Bug", "status": "Resolved",
            "subject": "Copied content elements take their language from the preceding record",
            "project": "TYPO3 Core", "category": "DataHandler aka TCEmain",
        })


class ThreadsOutputTest(unittest.TestCase):
    def test_empty_threads_message(self):
        import io, contextlib
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            gerrit.print_threads([])
        self.assertEqual(buffer.getvalue().strip(), "no comment threads")


if __name__ == "__main__":
    unittest.main()
