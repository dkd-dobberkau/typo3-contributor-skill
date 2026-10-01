#!/usr/bin/env bash
# Run the runTests.sh suites that match the files changed by the HEAD commit.
# Usage: qa.sh [--dry-run] [--fix] [base-ref]   (default base: origin/main)
#   --dry-run  only print the commands
#   --fix      run cglGit/cglHeaderGit/normalizeXliff without -n (modifies files; amend afterwards)
# Run inside the Core checkout, after committing (cglGit checks the latest commit).
set -u

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }

dry_run=0
fix=0
BASE=origin/main
for arg in "$@"; do
    case $arg in
        --dry-run) dry_run=1 ;;
        --fix) fix=1 ;;
        -h | --help) usage; exit 0 ;;
        -*) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
        *) BASE=$arg ;;
    esac
done

RUNTESTS="Build/Scripts/runTests.sh -b docker"
dry_flag="-n"
[ "$fix" -eq 1 ] && dry_flag=""

files=$(git diff --name-only "$BASE...HEAD")
commands=()
add() {
    local cmd="$RUNTESTS $*"
    # AGENTS.md runs test and build suites with CI=true (non-interactive output)
    case " $* " in
        *" -s unit "* | *" -s unitRandom "* | *" -s functional "* | *" -s build "* | *" -s e2e "* | *" -s phpstan "*) cmd="CI=true $cmd" ;;
    esac
    local existing
    for existing in "${commands[@]+"${commands[@]}"}"; do
        [ "$existing" = "$cmd" ] && return
    done
    commands+=("$cmd")
}
has() { grep -qE "$1" <<<"$files"; }

[ -d vendor ] || add -s composerInstall

# --- PHP -------------------------------------------------------------------
if has '\.php$'; then
    add -s cglGit $dry_flag
    add -s cglHeaderGit $dry_flag
    add -s lintPhp
    add -s phpstan
fi

# Tests for changed PHP: changed test files directly, else nearest Tests/Unit|Functional dir.
nearest_test_dir() { # extension relative-path-below-Classes kind
    local dir
    dir="typo3/sysext/$1/Tests/$3/$(dirname "$2")"
    while [ "$dir" != "typo3/sysext/$1/Tests/$3" ] && [ ! -d "$dir" ]; do
        dir=$(dirname "$dir")
    done
    [ -d "$dir" ] && [ "$dir" != "typo3/sysext/$1/Tests/$3" ] && echo "$dir/"
}
while IFS= read -r file; do
    [ -z "$file" ] && continue
    if [[ $file =~ ^typo3/sysext/[^/]+/Tests/(Unit|Functional)/.+Test\.php$ ]]; then
        suite=$(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}")
        add -s "$suite" "$file"
    elif [[ $file =~ ^typo3/sysext/([^/]+)/Classes/(.+\.php)$ ]]; then
        extension=${BASH_REMATCH[1]}
        relative=${BASH_REMATCH[2]}
        unit_dir=$(nearest_test_dir "$extension" "$relative" Unit)
        functional_dir=$(nearest_test_dir "$extension" "$relative" Functional)
        [ -n "$unit_dir" ] && add -s unit "$unit_dir"
        [ -n "$functional_dir" ] && add -s functional "$functional_dir"
        if [ -z "$unit_dir" ] && [ -z "$functional_dir" ]; then
            echo "NOTE  no Tests/Unit or Tests/Functional mirror for $file – consider adding a test." >&2
        fi
    fi
done <<<"$files"

# Database-related changes: the default functional run uses sqlite; CI also runs mariadb/mysql/postgres.
if has '(/Classes/Database/|/Classes/DataHandling/|(^|/)ext_tables\.sql$|/Classes/Persistence/|/Classes/Schema/)'; then
    while IFS= read -r cmd; do
        [[ $cmd == *" -s functional "* ]] && add -d mariadb -s functional "${cmd##* -s functional }"
    done < <(printf '%s\n' "${commands[@]+"${commands[@]}"}")
    echo "NOTE  database-related change: also run functional tests with -d mariadb and -d postgres (CI runs both)." >&2
fi

# --- frontend ----------------------------------------------------------------
has '^Build/Sources/.*\.ts$' && add -s lintTypescript
has '^Build/Sources/.*\.scss$' && add -s lintScss
has '^Build/Sources/' && add -s build
while IFS= read -r spec; do
    add -s e2e "$spec"
done < <(grep -E '^Build/tests/playwright/.+\.spec\.ts$' <<<"$files")

# --- XLIFF, rst, configuration -----------------------------------------------
if has '\.xlf$'; then
    add -s normalizeXliff $dry_flag
    add -s checkIntegrityXliff
fi
has '\.rst$' && add -s checkRst
has '/Configuration/ExtensionScanner/|Changelog/.+/(Breaking|Deprecation)-' && add -s checkExtensionScannerRst
if has '(^|/)composer\.json$'; then
    add -s checkComposer
    add -s composerValidate
fi
has '(^|/)Services\.yaml$' && add -s lintServicesYaml
has '\.ya?ml$' && grep -vE '(^|/)Services\.yaml$' <<<"$files" | grep -qE '\.ya?ml$' && add -s lintYaml

if [ ${#commands[@]} -eq 0 ]; then
    echo "No matching suites for the changed files."
    exit 0
fi

if [ "$dry_run" -eq 1 ]; then
    printf '%s\n' "${commands[@]}"
    exit 0
fi

failed=()
for cmd in "${commands[@]}"; do
    echo "==> $cmd"
    if ! bash -c "$cmd"; then
        failed+=("$cmd")
    fi
done

if has '^Build/Sources/' && [ -n "$(git status --porcelain -- 'typo3/sysext/*/Resources/Public')" ]; then
    echo "NOTE  build changed compiled files – stage them and amend: git add typo3/sysext/*/Resources/Public && git commit --amend --no-edit"
fi

echo
if [ ${#failed[@]} -eq 0 ]; then
    echo "QA OK (${#commands[@]} suite(s)). End-to-end tests run only for changed specs; for other UI changes pick a spec: -s e2e Build/tests/playwright/e2e/<area>/<file>.spec.ts"
else
    echo "QA FAILED:"
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
