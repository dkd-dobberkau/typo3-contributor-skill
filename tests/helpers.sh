# Shared test helpers, sourced by tests/run.sh before the test files.
HOOK_STUB='#!/bin/sh
grep -q "^Change-Id:" "$1" || printf "\nChange-Id: I%040d\n" 0 >> "$1"'

# Creates a fake Core checkout with origin/main and a commit-msg hook stub.
# Prints the checkout path.
make_checkout() {
    local base origin work
    base=$(mktemp -d)
    origin="$base/origin.git"
    work="$base/work"
    git init -q --bare -b main "$origin"
    git clone -q "$origin" "$work" 2>/dev/null
    git -C "$work" config user.name "Jane Doe"
    git -C "$work" config user.email "jane@example.com"
    mkdir -p "$work/typo3/sysext/core/Documentation/Changelog/15.0" "$work/Build/Sources" \
        "$work/typo3/sysext/backend/Resources/Public/JavaScript" "$work/typo3/sysext/backend/Classes"
    echo "init" > "$work/README.md"
    git -C "$work" add -A
    git -C "$work" commit -q -m "init" --no-verify
    git -C "$work" push -q origin main 2>/dev/null
    printf '%s\n' "$HOOK_STUB" > "$work/.git/hooks/commit-msg"
    chmod +x "$work/.git/hooks/commit-msg"
    echo "$work"
}

commit_in() { # dir subject [extra footer lines...]
    local dir=$1 subject=$2
    shift 2
    git -C "$dir" add -A
    git -C "$dir" commit -q -s -m "$subject" -m "Body text." -m "Resolves: #12345
Releases: main${1:+
$1}"
}

php_file_ok='<?php

declare(strict_types=1);

/*
 * This file is part of the TYPO3 CMS project.
 */

namespace TYPO3\CMS\Backend;

final class Foo {}'


# Stand-ins for `gerrit.py chain`, so preflight tests never reach review.typo3.org.
CHAIN_STUB_OK=$(mktemp); printf '%s\n' 'print("parent is the current patch set of 90001")' > "$CHAIN_STUB_OK"
CHAIN_STUB_FAIL=$(mktemp); printf '%s\n' 'import sys' 'print("parent is not on Gerrit")' 'sys.exit(1)' > "$CHAIN_STUB_FAIL"
