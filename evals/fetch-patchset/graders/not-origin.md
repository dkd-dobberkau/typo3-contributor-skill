---
type: regex
target: last_message
pattern: "git fetch origin refs/changes"
match: not_contains
---

origin is GitHub and has no refs/changes.
