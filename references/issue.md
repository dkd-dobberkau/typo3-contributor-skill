# Report an issue on Forge

Forge: https://forge.typo3.org/projects/typo3cms-core/issues/new. The human submits; you draft. **Security issues never go to Forge.** Send them to the Security Team: https://typo3.org/community/teams/security/contact-us/

Before drafting:
1. Search for duplicates: https://forge.typo3.org/projects/typo3cms-core/issues?set_filter=1&status_id=*&subject=~<words>
2. Confirm it is reproducible on a supported version, ideally current `main`.

Drafts: `templates/forge-bug.md` (bug) or `templates/forge-task.md` (task or feature).

- **Subject:** state what is wrong, specifically ("JSON element breaks HTML when placeholder contains quotes", not "JSON field bug").
- **Steps to reproduce:** a minimal TCA, TypoScript or site config, and the exact clicks.
- **Expected and actual result:** an error message or stack trace from `var/log/typo3_*.log`, plus a screenshot if it is a UI issue.
- **Environment:** TYPO3 version, PHP version, database, composer or classic mode, browser for UI issues.
- **Contributing a fix?** Add "I will create a patch for this."

After creation, write down the issue number for `Resolves:`.

## Issue status meaning

| Status | Meaning |
|---|---|
| New | Not triaged yet |
| Needs Feedback | The reporter needs to answer something |
| Accepted | Reproducible and valid. Anyone may work on it, no assignment needed |
| Under Review | A Gerrit change is linked. Reviewing or testing it speeds up the merge |
| Resolved | Merged. Older branches may not get the fix (LTS policy) |
| Closed | Not reproducible, outdated, out of scope, or no feedback |
