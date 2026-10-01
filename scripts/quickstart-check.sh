#!/usr/bin/env bash
# Check a machine against the Contribution Guide Quickstart, steps 1-5:
# https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/Quickstart/Index.html
# Usage: quickstart-check.sh [--online]
#   --online  also test Docker, SSH to Gerrit and the TYPO3 backend URL
# Env: TYPO3_CORE_DIR (default $HOME/work/TYPO3-Contribute)
# Read-only: changes nothing. Exit 0 = steps 1-5 complete.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE=${TYPO3_CORE_DIR:-$HOME/work/TYPO3-Contribute}
online=0
[ "${1:-}" = --online ] && online=1

problems=0
ok() { echo "ok      $1"; }
missing() { echo "MISSING [$1] $2"; problems=$((problems + 1)); }
info() { echo "info    $1"; }
step() { echo; echo "== Step $1"; }

# --- 1. Prerequisites ---------------------------------------------------------
step "1: Prerequisites"
RUNTIME=${TYPO3_CONTRIB_RUNTIME:-docker}
for tool in bash git ssh "$RUNTIME" ddev; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool: $(command -v "$tool")"
    else
        missing "tool-$tool" "$tool is not installed (see guide: Quickstart Prerequisites)"
    fi
done
command -v ddev >/dev/null 2>&1 && info "$(ddev --version 2>/dev/null | head -1)"
if [ "$online" -eq 1 ]; then
    if "$RUNTIME" info >/dev/null 2>&1; then ok "$RUNTIME running"; else missing runtime-running "$RUNTIME is not running"; fi
fi

# --- 2. Accounts (mostly manual) ----------------------------------------------
step "2: Accounts"
if [ "$online" -eq 1 ]; then
    greeting=$(ssh -o BatchMode=yes -o ConnectTimeout=10 review.typo3.org 2>&1 | grep -o 'Hi [^,]*' | head -1)
    if [ -n "$greeting" ]; then ok "Gerrit SSH login works ($greeting)"; else missing gerrit-ssh "SSH login to review.typo3.org failed (key uploaded in Gerrit?)"; fi
fi
info "manual: my.typo3.org account (SSO) — https://my.typo3.org"
info "manual: logged in once at https://review.typo3.org, SSH key uploaded, commit email registered (Settings → Email Addresses)"
info "manual: Forge login via SSO — https://forge.typo3.org"
info "manual (recommended): Slack #typo3-cms-coredev — https://typo3.org/community/meet/chat-slack/"

# --- 3. Git ---------------------------------------------------------------------
step "3: Git"
if git_output=$(bash "$SCRIPT_DIR/check-setup.sh" 2>&1); then
    ok "Git setup (check-setup.sh: SETUP OK)"
else
    missing git-setup "check-setup.sh reports gaps; run: bash $SCRIPT_DIR/check-setup.sh --fix"
    grep -E '^(MISSING|STALE)' <<<"$git_output" | sed 's/^/        /'
fi
[ -d "$CORE/.git" ] || { echo; echo "QUICKSTART INCOMPLETE – no checkout at $CORE"; exit 1; }

# --- 4. DDEV ----------------------------------------------------------------------
step "4: DDEV"
config="$CORE/.ddev/config.yaml"
yaml_value() { sed -n "s/^$1:[[:space:]]*//p" "$config" | head -1 | tr -d "\"'"; }
if [ ! -f "$config" ]; then
    missing ddev-config "No .ddev/config.yaml – run the guide's 'ddev config' (project t3c-main, type typo3, docroot .)"
else
    name=$(yaml_value name)
    ok "DDEV project '$name' (type $(yaml_value type), docroot $(yaml_value docroot))"
    [ "$name" = t3c-main ] || info "project name '$name' differs from the guide convention 't3c-main' (fine, URLs change)"
    [ "$(yaml_value type)" = typo3 ] || missing ddev-type "project type must be 'typo3'"
    [ "$(yaml_value docroot)" = . ] || missing ddev-docroot "docroot must be '.' (Core legacy mode)"

    php=$(yaml_value php_version)
    required=$(python3 -c "import json,re,sys; r=json.load(open(sys.argv[1]))['require'].get('php',''); m=re.search(r'(\d+\.\d+)', r); print(m.group(1) if m else '')" "$CORE/composer.json" 2>/dev/null)
    if [ -n "$required" ] && [ -n "$php" ] && [ "$(printf '%s\n%s\n' "$required" "$php" | sort -V | head -1)" != "$required" ]; then
        missing ddev-php "DDEV php_version $php is below Core's requirement $required: ddev config --php-version=$required && ddev restart"
    else
        ok "PHP $php (Core requires ${required:-?})"
    fi

    status=$(ddev list -j 2>/dev/null | python3 -c "
import json, os, sys
core = os.path.realpath(sys.argv[1])
for project in json.load(sys.stdin).get('raw', []):
    if os.path.realpath(project.get('approot', '')) == core:
        print(project.get('status', '')); break
" "$CORE" 2>/dev/null)
    if [ "$status" = running ]; then
        ok "DDEV project running"
    else
        missing ddev-running "DDEV project is ${status:-not registered}: cd $CORE && ddev start"
    fi
fi

# --- 5. TYPO3 -----------------------------------------------------------------------
step "5: TYPO3"
if [ -d "$CORE/vendor" ]; then ok "composer dependencies installed"; else missing composer "vendor/ missing: Build/Scripts/runTests.sh -b docker -s composerInstall"; fi
if [ -f "$CORE/typo3conf/system/settings.php" ]; then
    ok "TYPO3 installed (typo3conf/system/settings.php)"
    states="$CORE/typo3conf/PackageStates.php"
    for extension in styleguide indexed_search; do
        if [ -f "$states" ] && grep -q "'$extension'" "$states"; then
            ok "EXT:$extension active"
        else
            missing "$extension" "EXT:$extension not active: ddev typo3 extension:activate $extension"
        fi
    done
else
    missing typo3-installed "TYPO3 not set up: ddev typo3 setup … (guide: Quickstart 'Set up TYPO3')"
fi
if [ "$online" -eq 1 ] && [ -f "$config" ]; then
    url="https://$(yaml_value name).ddev.site/typo3/"
    code=$(curl -sk -o /dev/null -w '%{http_code}' "$url")
    case $code in
        200 | 302 | 303) ok "backend reachable: $url ($code)" ;;
        *) missing backend "backend $url answered $code" ;;
    esac
fi

echo
if [ "$problems" -eq 0 ]; then
    echo "QUICKSTART OK (steps 1-5). Next: create a patch – references/patch.md"
else
    echo "QUICKSTART INCOMPLETE – $problems finding(s)."
    exit 1
fi
