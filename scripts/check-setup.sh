#!/usr/bin/env bash
# Verify (and with --fix, complete) a TYPO3 Core contribution checkout.
# Usage: check-setup.sh [--fix] [--online]
#   --fix     set missing repo-local git config and install hooks (never overwrites differing values)
#   --online  also test SSH to Gerrit and Docker
# Env: TYPO3_CORE_DIR (default $HOME/work/TYPO3-Contribute)
set -u

fix=0
online=0
for arg in "$@"; do
    case $arg in
        --fix) fix=1 ;;
        --online) online=1 ;;
    esac
done

CORE=${TYPO3_CORE_DIR:-$HOME/work/TYPO3-Contribute}
problems=0
ok() { echo "ok      $1"; }
missing() { echo "MISSING [$1] $2"; problems=$((problems + 1)); }
stale() { echo "STALE   [$1] $2"; problems=$((problems + 1)); }
info() { echo "info    $1"; }

if [ ! -d "$CORE/.git" ]; then
    missing core-dir "$CORE is not a git checkout. Clone: git clone https://github.com/typo3/typo3.git $CORE"
    exit 1
fi
git_core() { git -C "$CORE" "$@"; }
ok "checkout at $CORE"

origin=$(git_core config remote.origin.url || true)
case $origin in
    *github.com/typo3/typo3* | *github.com/TYPO3/typo3* | *review.typo3.org*) ok "origin $origin" ;;
    *) missing origin "remote.origin.url is '$origin', expected https://github.com/typo3/typo3.git" ;;
esac

# --- identity ----------------------------------------------------------------
for key in user.name user.email; do
    if [ -n "$(git_core config "$key" || true)" ]; then
        ok "$key = $(git_core config "$key")"
    else
        missing "$key" "Set it to your typo3.org identity: git -C $CORE config $key '...' (email must be registered in Gerrit)"
    fi
done

# --- Gerrit push URL from ~/.ssh/config ---------------------------------------
gerrit_user=$(awk '
    tolower($1) == "host" { in_block = 0; for (i = 2; i <= NF; i++) if ($i == "review.typo3.org") in_block = 1 }
    in_block && tolower($1) == "user" { print $2; exit }
' "$HOME/.ssh/config" 2>/dev/null)
if [ -z "$gerrit_user" ]; then
    missing ssh-user "No 'Host review.typo3.org' with 'User <typo3.org username>' in ~/.ssh/config"
else
    ok "Gerrit user from ~/.ssh/config: $gerrit_user"
fi

expected_pushurl="ssh://${gerrit_user:-<user>}@review.typo3.org:29418/Packages/TYPO3.CMS.git"
pushurl=$(git_core config remote.origin.pushurl || true)
if [ -z "$pushurl" ]; then
    if [ "$fix" -eq 1 ] && [ -n "$gerrit_user" ]; then
        git_core config remote.origin.pushurl "$expected_pushurl" && ok "set pushurl $expected_pushurl"
    else
        missing pushurl "git -C $CORE config remote.origin.pushurl $expected_pushurl"
    fi
elif [ "$pushurl" = "$expected_pushurl" ]; then
    ok "pushurl $pushurl"
else
    info "pushurl is $pushurl (differs from $expected_pushurl; left unchanged)"
fi

if git_core config --get-all remote.origin.push 2>/dev/null | grep -q 'refs/notes'; then
    missing notes-push "remote.origin.push pushes refs/notes – git notes (git-ai) must stay local"
fi

# --- repo-local options --------------------------------------------------------
if [ "$(git_core config branch.autosetuprebase || true)" = remote ]; then
    ok "branch.autosetuprebase = remote"
elif [ "$fix" -eq 1 ]; then
    git_core config branch.autosetuprebase remote && ok "set branch.autosetuprebase = remote"
else
    missing autosetuprebase "git -C $CORE config branch.autosetuprebase remote"
fi

template=$(git_core config commit.template || true)
if [ -n "$template" ]; then
    ok "commit.template = $template"
elif [ "$fix" -eq 1 ]; then
    template="$HOME/.gitmessage-typo3.txt"
    [ -f "$template" ] || printf '%s\n' '[BUGFIX|TASK|FEATURE|DOCS] ' '' 'Resolves: #' 'Releases: main' > "$template"
    git_core config commit.template "$template" && ok "set commit.template = $template"
else
    missing commit-template "git -C $CORE config commit.template ~/.gitmessage-typo3.txt"
fi

# --- hooks ---------------------------------------------------------------------
hooks_dir=$(git_core rev-parse --git-path hooks)
case $hooks_dir in /*) ;; *) hooks_dir="$CORE/$hooks_dir" ;; esac
check_hook() { # name source
    local name=$1 source="$CORE/$2" target="$hooks_dir/$1"
    if [ ! -f "$source" ]; then
        info "no $2 in this checkout"
        return
    fi
    if [ -x "$target" ] && cmp -s "$source" "$target"; then
        ok "hook $name up to date"
    elif [ "$fix" -eq 1 ]; then
        mkdir -p "$hooks_dir" && cp "$source" "$target" && chmod +x "$target" && ok "installed hook $name"
    elif [ -f "$target" ]; then
        stale "hook-$name" "$target differs from $2: cp $2 $target && chmod +x $target"
    else
        missing "hook-$name" "cp $2 $target && chmod +x $target (or: composer gerrit:setup)"
    fi
}
check_hook commit-msg Build/git-hooks/commit-msg
# The optional Core pre-commit hook runs php-cs-fixer with the *host* PHP. When that is older than
# the Core requirement it fails with a fatal error. qa.sh runs cglGit in a container instead.
if [ -f "$hooks_dir/pre-commit" ]; then
    info "pre-commit hook installed (optional). It needs host PHP matching Core; remove it if commits print PHP fatals."
else
    info "pre-commit hook not installed (optional; qa.sh runs cglGit in Docker)"
fi

# --- optional tooling ------------------------------------------------------------
if command -v git-ai >/dev/null 2>&1; then
    allowed=$(git-ai config allow_repositories 2>/dev/null | tr -d '\n ')
    case $allowed in
        *typo3*) ok "git-ai installed, tracking allowed for Core ($allowed)" ;;
        *) info "git-ai installed; scope it to Core: git-ai config --add allow_repositories '*typo3/typo3*' and git-ai install-hooks" ;;
    esac
else
    info "git-ai not installed (optional: line-level AI attribution for human review)"
fi

if [ "$online" -eq 1 ]; then
    if ssh -o BatchMode=yes -o ConnectTimeout=10 review.typo3.org gerrit version >/dev/null 2>&1; then
        ok "SSH to review.typo3.org works"
    else
        missing ssh "ssh -p 29418 ${gerrit_user:-<user>}@review.typo3.org failed (key in Gerrit? see Troubleshooting)"
    fi
    if docker info >/dev/null 2>&1; then ok "docker running"; else missing docker "Docker is not running (runTests.sh -b docker)"; fi
fi

echo
if [ "$problems" -eq 0 ]; then
    echo "SETUP OK"
else
    echo "SETUP INCOMPLETE – $problems finding(s)${fix:+}. Re-run with --fix for repo-local config and hooks."
    exit 1
fi
