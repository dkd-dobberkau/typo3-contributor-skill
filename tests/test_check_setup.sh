# Sourced by tests/run.sh
SETUP="$ROOT/scripts/check-setup.sh"

setup_env() { # prints "home core"
    local home core
    home=$(mktemp -d)
    mkdir -p "$home/.ssh"
    printf 'Host review.typo3.org\n    Port 29418\n    User jane-doe\n' > "$home/.ssh/config"
    core=$(make_checkout)
    git -C "$core" remote set-url origin https://github.com/typo3/typo3.git
    mkdir -p "$core/Build/git-hooks/unix+mac"
    printf '#!/bin/sh\necho commit-msg\n' > "$core/Build/git-hooks/commit-msg"
    printf '#!/bin/sh\necho pre-commit\n' > "$core/Build/git-hooks/unix+mac/pre-commit"
    rm -f "$core/.git/hooks/commit-msg"
    echo "$home $core"
}

run_setup() { # home core [args]
    local home=$1 core=$2
    shift 2
    HOME=$home TYPO3_CORE_DIR=$core GIT_CONFIG_GLOBAL=$home/.gitconfig bash "$SETUP" "$@" 2>&1
}

# fresh checkout: reports missing pushurl + hooks, exits non-zero
read -r home core <<<"$(setup_env)"
: "${home:?setup_env failed}" "${core:?setup_env failed}"
if output=$(run_setup "$home" "$core"); then
    fail "check-setup fresh: expected failure, got: $output"
else
    grep -q "MISSING \[pushurl\]" <<<"$output" && grep -q "MISSING \[hook-commit-msg\]" <<<"$output" \
        && pass || fail "check-setup fresh: missing findings in: $output"
fi

# --fix sets repo-local config from ~/.ssh/config user and installs hooks
if output=$(run_setup "$home" "$core" --fix); then
    pushurl=$(git -C "$core" config remote.origin.pushurl)
    if [ "$pushurl" = "ssh://jane-doe@review.typo3.org:29418/Packages/TYPO3.CMS.git" ] \
        && [ -x "$core/.git/hooks/commit-msg" ] && [ ! -e "$core/.git/hooks/pre-commit" ] \
        && [ "$(git -C "$core" config branch.autosetuprebase)" = remote ] \
        && [ -n "$(git -C "$core" config commit.template)" ]; then
        pass
    else
        fail "check-setup --fix did not configure everything (pushurl=$pushurl): $output"
    fi
else
    fail "check-setup --fix failed: $output"
fi

# second run is clean
if output=$(run_setup "$home" "$core"); then pass; else fail "check-setup after fix: $output"; fi

# stale hook (differs from Build/git-hooks) is reported
printf '#!/bin/sh\necho old\n' > "$core/.git/hooks/commit-msg"
output=$(run_setup "$home" "$core")
grep -qE "STALE +\[hook-commit-msg\]" <<<"$output" && pass || fail "check-setup stale hook not reported: $output"

# a different existing pushurl is never overwritten by --fix
git -C "$core" config remote.origin.pushurl ssh://someone-else@review.typo3.org:29418/Packages/TYPO3.CMS.git
run_setup "$home" "$core" --fix >/dev/null
[ "$(git -C "$core" config remote.origin.pushurl)" = "ssh://someone-else@review.typo3.org:29418/Packages/TYPO3.CMS.git" ] \
    && pass || fail "check-setup --fix overwrote a custom pushurl"

# missing core dir
output=$(HOME=$home TYPO3_CORE_DIR=$home/nope bash "$SETUP" 2>&1)
grep -q "MISSING \[core-dir\]" <<<"$output" && pass || fail "check-setup missing core dir: $output"
