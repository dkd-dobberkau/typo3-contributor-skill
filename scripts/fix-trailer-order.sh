#!/usr/bin/env bash
# Move the Change-Id trailer of HEAD to the end of the footer (needed after `git commit --amend -s`,
# which appends Signed-off-by after an existing Change-Id). Keeps the Change-Id byte-identical.
set -eu
git log -1 --format=%B \
    | awk '/^Change-Id:/ { change_id = $0; next } { lines[n++] = $0 }
           END { while (n > 0 && lines[n-1] == "") n--; for (i = 0; i < n; i++) print lines[i]; if (change_id) print change_id }' \
    | git commit -q --amend -F -
git log -1 --format=%B | git interpret-trailers --parse
