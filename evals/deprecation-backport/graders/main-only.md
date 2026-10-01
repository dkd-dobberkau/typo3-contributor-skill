---
type: llm
weight: 2
---

Look only at what the response says about target branches. PASS if it targets main only and
explains that the deprecation / new API is not backported to 13.4 (LTS branches take bugfixes only).
FAIL if it proposes adding the change to 13.4.
