---
type: regex
target: last_message
pattern: "runTests\\.sh[^\\n`]*-s acceptance"
match: not_contains
---

No command line with the removed acceptance suite (mentioning that it no longer exists is fine).
