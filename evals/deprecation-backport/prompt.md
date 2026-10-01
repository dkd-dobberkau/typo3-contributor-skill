---
description: Deprecation goes to main only, with rst, scanner tag and matcher
tags: [workflow]
runs: 2
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
---

In TYPO3 Core I want to deprecate the public static method BackendUtility::getRecordTitlePrep()
in favour of a new service RecordTitleFormatter::format(), Forge issue #108500. We also need it in
13.4 for a customer. List the files to add or change, the commit subject line, and the target branches.
