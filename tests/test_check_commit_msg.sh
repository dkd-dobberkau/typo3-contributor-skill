# Sourced by tests/run.sh
CHECKER="$ROOT/scripts/check-commit-msg.sh"
FIXTURES="$ROOT/tests/fixtures/commit-msg"

for fixture in "$FIXTURES"/good/*.txt; do
    if output=$(bash "$CHECKER" "$fixture" 2>&1); then
        pass
    else
        fail "commit-msg good/$(basename "$fixture") rejected: $output"
    fi
done

for fixture in "$FIXTURES"/bad/*.txt; do
    # file name (without .N.txt / .txt) is the expected rule id
    rule=$(basename "$fixture" .txt)
    rule=${rule%.[0-9]}
    if output=$(bash "$CHECKER" "$fixture" 2>&1); then
        fail "commit-msg bad/$(basename "$fixture") accepted"
    elif ! grep -q "ERROR \[$rule\]" <<<"$output"; then
        fail "commit-msg bad/$(basename "$fixture") missing ERROR [$rule], got: $output"
    else
        pass
    fi
done

# warnings do not fail: 53-72 char subject, URL line > 72
warn_msg=$(mktemp)
printf '%s\n' "[BUGFIX] Escape the placeholder attribute in JSON elements" "" "Resolves: #1" "Releases: main" > "$warn_msg"
if output=$(bash "$CHECKER" "$warn_msg" 2>&1) && grep -q "WARN \[subject-length\]" <<<"$output"; then
    pass
else
    fail "commit-msg subject 53-72 chars should warn, got: $output"
fi
rm -f "$warn_msg"

# reads HEAD message when no file is given
repo=$(mktemp -d)
git -C "$repo" init -q
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty \
    -m "[TASK] Do something" -m "Resolves: #1
Releases: main"
if (cd "$repo" && bash "$CHECKER" >/dev/null 2>&1); then pass; else fail "commit-msg should read HEAD message"; fi
rm -rf "$repo"
