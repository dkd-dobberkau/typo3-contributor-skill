# Sourced by tests/run.sh
PREFLIGHT="$ROOT/scripts/preflight.sh"
expect_preflight() { # name expected(ok|rule) dir
    local name=$1 expected=$2 dir=$3 output
    if output=$(cd "$dir" && bash "$PREFLIGHT" 2>&1); then
        [ "$expected" = ok ] && pass || fail "preflight $name: expected ERROR [$expected], passed: $output"
    else
        if [ "$expected" = ok ]; then
            fail "preflight $name: expected ok, got: $output"
        elif grep -q "ERROR \[$expected\]" <<<"$output"; then
            pass
        else
            fail "preflight $name: expected ERROR [$expected], got: $output"
        fi
    fi
}

# 0. missing Signed-off-by (AGENTS.md: sign off every commit)
d=$(make_checkout)
echo x >> "$d/README.md"; git -C "$d" add -A
git -C "$d" commit -q -m "[BUGFIX] Change readme" -m "Resolves: #1
Releases: main"
expect_preflight missing-signoff signoff "$d"

# 1. clean single bugfix commit passes
d=$(make_checkout)
printf '%s\n' "$php_file_ok" > "$d/typo3/sysext/backend/Classes/Foo.php"
commit_in "$d" "[BUGFIX] Add foo"
expect_preflight clean-commit ok "$d"

# 2. two commits ahead -> relation chain
echo x >> "$d/README.md"; commit_in "$d" "[TASK] Second change"
expect_preflight relation-chain ahead-count "$d"

# 3. nothing to push
d=$(make_checkout)
expect_preflight nothing-ahead ahead-count "$d"

# 4. missing hook
d=$(make_checkout); rm "$d/.git/hooks/commit-msg"
echo x >> "$d/README.md"; commit_in "$d" "[BUGFIX] Change readme"
expect_preflight missing-hook hook-missing "$d"

# 5. missing Change-Id (hook bypassed)
d=$(make_checkout)
echo x >> "$d/README.md"; git -C "$d" add -A
git -C "$d" commit -q --no-verify -m "[BUGFIX] Change readme" -m "Resolves: #1
Releases: main"
expect_preflight missing-change-id change-id-missing "$d"

# 6. invalid commit message
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "fix readme"
expect_preflight bad-message commit-msg "$d"

# 7. uncommitted changes to tracked files
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "[BUGFIX] Change readme"
echo y >> "$d/README.md"
expect_preflight dirty-tree dirty-tree "$d"

# 8. new PHP file without strict_types / license header
d=$(make_checkout)
printf '<?php\nnamespace X;\nclass Foo {}\n' > "$d/typo3/sysext/backend/Classes/Foo.php"
commit_in "$d" "[TASK] Add foo"
expect_preflight php-header php-header "$d"

# 9. Build/Sources changed without compiled files
d=$(make_checkout)
echo "export {}" > "$d/Build/Sources/foo.ts"
commit_in "$d" "[TASK] Change foo module"
expect_preflight assets-missing assets-missing "$d"

# 10. Build/Sources with compiled file passes
d=$(make_checkout)
echo "export {}" > "$d/Build/Sources/foo.ts"
echo "export{}" > "$d/typo3/sysext/backend/Resources/Public/JavaScript/foo.js"
commit_in "$d" "[TASK] Change foo module"
expect_preflight assets-ok ok "$d"

# 11. Breaking rst without [!!!]
d=$(make_checkout)
printf 'Breaking\n\n..  index:: PHP-API, NotScanned, ext:core\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Breaking-12345-Foo.rst"
commit_in "$d" "[TASK] Remove foo"
expect_preflight breaking-without-prefix changelog-type "$d"

# 12. [!!!] without Breaking rst
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "[!!!][TASK] Remove foo"
expect_preflight prefix-without-breaking-rst changelog-missing "$d"

# 13. Deprecation rst with [!!!]
d=$(make_checkout)
printf 'Deprecation\n\n..  index:: PHP-API, FullyScanned, ext:core\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Deprecation-12345-Foo.rst"
printf 'Breaking\n\n..  index:: PHP-API, NotScanned, ext:core\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Breaking-12345-Bar.rst"
commit_in "$d" "[!!!][TASK] Deprecate foo"
expect_preflight deprecation-breaking changelog-type "$d"

# 14. Deprecation rst without scanner tag
d=$(make_checkout)
printf 'Deprecation\n\n..  index:: PHP-API, ext:backend\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Deprecation-12345-Foo.rst"
commit_in "$d" "[TASK] Deprecate foo"
expect_preflight scanner-tag changelog-scanner-tag "$d"

# 14b. Feature rst without scanner tag is fine (tag only for Breaking/Deprecation)
d=$(make_checkout)
printf 'Feature\n\n..  index:: Backend, ext:backend\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Feature-12345-Foo.rst"
commit_in "$d" "[FEATURE] Add foo"
expect_preflight feature-without-scanner-tag ok "$d"

# 15. [FEATURE] with proper Feature rst passes
d=$(make_checkout)
printf 'Feature\n\n..  index:: Backend, NotScanned, ext:backend\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Feature-12345-Foo.rst"
commit_in "$d" "[FEATURE] Add foo"
expect_preflight feature-ok ok "$d"

# 16. [SECURITY] stops
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "[SECURITY] Escape foo"
expect_preflight security security "$d"

# 17. notes push configured for origin
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "[BUGFIX] Change readme"
git -C "$d" config --add remote.origin.push 'refs/notes/*:refs/notes/*'
expect_preflight notes-push notes-push "$d"

# 18. Co-Authored-By is an error (disclosure goes into the Gerrit comment)
d=$(make_checkout)
echo x >> "$d/README.md"; commit_in "$d" "[BUGFIX] Change readme" "Co-Authored-By: Bot <bot@example.com>"
expect_preflight co-authored-error commit-msg "$d"

# 19. escaping/permission changes in a public bugfix -> security warning (not an error)
d=$(make_checkout)
printf '%s\n' "$php_file_ok" | sed 's/final class Foo {}/final class Foo { public function a($v) { return htmlspecialchars($v); } }/' > "$d/typo3/sysext/backend/Classes/Foo.php"
commit_in "$d" "[BUGFIX] Escape foo"
output=$(cd "$d" && bash "$PREFLIGHT" 2>&1)
grep -q "WARN \[security-heuristic\]" <<<"$output" && pass || fail "preflight should warn about escaping changes: $output"

# 20. fix-trailer-order.sh moves Change-Id behind a late Signed-off-by
d=$(make_checkout)
echo x >> "$d/README.md"; git -C "$d" add -A
git -C "$d" commit -q -m "[BUGFIX] Change readme" -m "Resolves: #1
Releases: main"
git -C "$d" commit -q --amend -s --no-edit
(cd "$d" && bash "$ROOT/scripts/fix-trailer-order.sh" >/dev/null)
last=$(git -C "$d" log -1 --format=%B | git interpret-trailers --parse | tail -1)
if [[ $last == Change-Id:* ]] && (cd "$d" && bash "$ROOT/scripts/check-commit-msg.sh" >/dev/null); then pass; else fail "fix-trailer-order: last trailer is '$last'"; fi
