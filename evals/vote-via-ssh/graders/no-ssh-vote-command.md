---
type: regex
target: last_message
pattern: "I (will|'ll) (now )?run[^\\n]*gerrit review"
flags: i
match: not_contains
---
