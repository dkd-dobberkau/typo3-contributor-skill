#!/usr/bin/env bash
# Pre-push gate for a TYPO3 Core change. Run inside the Core checkout.
# Usage: preflight.sh [base-ref]   (default: origin/main)
# Exit 0 = ready for the human's push decision, 1 = errors found.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE=${1:-origin/main}

errors=0
error() { echo "ERROR [$1] $2"; errors=$((errors + 1)); }
warn() { echo "WARN [$1] $2"; }
ok() { echo "ok    $1"; }

git rev-parse --git-dir >/dev/null 2>&1 || { error not-a-repo "Not inside a git checkout."; exit 1; }
git_dir=$(git rev-parse --git-dir)

# --- exactly one commit ahead (no accidental relation chain) ----------------
ahead=$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo "?")
if [ "$ahead" = 1 ]; then
    ok "exactly one commit ahead of $BASE"
else
    error ahead-count "HEAD is $ahead commit(s) ahead of $BASE; a Gerrit change must be exactly one commit (more = relation chain, 0 = nothing to push)."
fi

# --- hooks -------------------------------------------------------------------
if [ -x "$git_dir/hooks/commit-msg" ]; then
    ok "commit-msg hook installed"
else
    error hook-missing "commit-msg hook missing or not executable: cp Build/git-hooks/commit-msg $git_dir/hooks/ && chmod +x $git_dir/hooks/commit-msg (or: composer gerrit:setup)"
fi

message=$(git log -1 --format=%B)
subject=$(git log -1 --format=%s)

if grep -qE '^Change-Id: I[0-9a-f]{40}$' <<<"$message"; then
    ok "Change-Id present"
else
    error change-id-missing "No Change-Id in HEAD. Install the hook, then: git commit --amend --no-edit"
fi

# --- commit message ----------------------------------------------------------
if msg_output=$(bash "$SCRIPT_DIR/check-commit-msg.sh" 2>&1); then
    ok "commit message valid"
    grep '^WARN' <<<"$msg_output"
else
    error commit-msg "Commit message has errors:"
    sed 's/^/        /' <<<"$msg_output"
fi

# --- Developer Certificate of Origin (AGENTS.md: sign off every commit) -------
signoff=$(grep -E '^Signed-off-by: ' <<<"$message" | tail -1)
author="$(git log -1 --format='%an <%ae>')"
if [ -z "$signoff" ]; then
    error signoff "No Signed-off-by (DCO, in the human's name): git commit --amend -s --no-edit && bash $SCRIPT_DIR/fix-trailer-order.sh"
elif [ "$signoff" != "Signed-off-by: $author" ]; then
    warn signoff-author "$signoff differs from the author $author."
else
    ok "Signed-off-by matches the author"
fi

# --- working tree ------------------------------------------------------------
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    error dirty-tree "Uncommitted changes in tracked files. Amend them (git commit -a --amend) or discard them before pushing:"
    git status --short --untracked-files=no | sed 's/^/        /'
else
    ok "no uncommitted changes in tracked files"
fi

# --- files of the HEAD commit ------------------------------------------------
changed=$(git show --name-status --format= HEAD)
added_files=$(awk '$1 == "A" { print $2 }' <<<"$changed")
all_files=$(awk '{ print $NF }' <<<"$changed")

# new PHP classes/tests need strict_types + license header
while IFS= read -r file; do
    case $file in
        */Classes/*.php | */Tests/*.php) ;;
        *) continue ;;
    esac
    content=$(git show "HEAD:$file")
    if ! grep -q 'declare(strict_types=1);' <<<"$content" || ! grep -q 'This file is part of the TYPO3 CMS project' <<<"$content"; then
        error php-header "$file: new PHP files need declare(strict_types=1); and the TYPO3 license header."
    fi
done <<<"$added_files"

# changed TypeScript/SCSS sources need the compiled files in the same commit
if grep -q '^Build/Sources/' <<<"$all_files"; then
    if grep -qE '^typo3/sysext/[^/]+/Resources/Public/' <<<"$all_files"; then
        ok "Build/Sources changed together with compiled Resources/Public files"
    else
        error assets-missing "Build/Sources changed but no compiled files: run Build/Scripts/runTests.sh -b docker -s build and amend the result."
    fi
fi

# changelog rst consistency with the subject
changelog_files=$(grep -E '^typo3/sysext/core/Documentation/Changelog/.+\.rst$' <<<"$all_files" | grep -v '/Index.rst$' || true)
has_type() { grep -qE "/$1-[0-9]+-[^/]+\.rst$" <<<"$changelog_files"; }

if has_type Breaking && ! [[ $subject =~ ^\[!!!\] ]]; then
    error changelog-type "A Breaking-*.rst is part of the commit: the subject must start with [!!!]."
fi
if [[ $subject =~ ^\[!!!\] ]] && ! has_type Breaking; then
    error changelog-missing "[!!!] needs a Breaking-<issue>-<Title>.rst in typo3/sysext/core/Documentation/Changelog/<version>/."
fi
if has_type Deprecation; then
    if [[ $subject =~ ^\[!!!\] ]] || ! [[ $subject =~ ^(\[!!!\])?\[(TASK|FEATURE)\] ]]; then
        error changelog-type "Deprecations must be [TASK] or [FEATURE] and never [!!!]."
    fi
fi
if [[ $subject =~ ^(\[!!!\])?\[FEATURE\] ]] && ! has_type Feature; then
    error changelog-missing "[FEATURE] needs a Feature-<issue>-<Title>.rst in typo3/sysext/core/Documentation/Changelog/<version>/."
fi
while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Scanner tags are mandatory for Breaking and Deprecation files only (Changelog/Howto.rst)
    [[ $file =~ /(Breaking|Deprecation)-[0-9]+-[^/]+\.rst$ ]] || continue
    git cat-file -e "HEAD:$file" 2>/dev/null || continue
    index_line=$(git show "HEAD:$file" | grep -E '^\.\.\s+index::' | tail -1)
    tag_count=$(grep -oE '\b(FullyScanned|PartiallyScanned|NotScanned)\b' <<<"$index_line" | wc -l | tr -d ' ')
    if [ "$tag_count" != 1 ]; then
        error changelog-scanner-tag "$file: Breaking/Deprecation files need exactly one of FullyScanned, PartiallyScanned, NotScanned in the last '..  index::' line."
    fi
done <<<"$changelog_files"

# --- security ----------------------------------------------------------------
if [[ $subject =~ \[SECURITY\] ]]; then
    error security "Security fixes are never pushed publicly. Stop and contact the TYPO3 Security Team: https://typo3.org/community/teams/security/contact-us/"
fi

# Heuristic: added escaping or access checks may fix an unreported vulnerability.
# Kept narrow on purpose (~5% of recent Core commits match).
security_hits=$(git show --format= --unified=0 HEAD -- '*.php' '*.html' '*.ts' '*.js' \
    | grep -E '^\+' | grep -v '^+++' \
    | grep -oE 'htmlspecialchars|htmlentities|escapeHtml|f:format\.htmlspecialchars|isAdmin\(|checkRecordEditAccess|doesUserHaveAccess|hash_equals|validateToken' \
    | sort -u | tr '\n' ' ')
if [ -n "$security_hits" ]; then
    warn security-heuristic "The diff adds ${security_hits}– if the old behaviour was exploitable (XSS, access bypass, token check), stop and contact the Security Team instead of pushing publicly. Confirm with the human."
fi

# --- push configuration (never push git notes such as refs/notes/ai) ---------
if git config --get-all remote.origin.push 2>/dev/null | grep -q 'refs/notes'; then
    error notes-push "remote.origin.push includes refs/notes; git notes (e.g. git-ai attribution) must stay local. Remove it: git config --unset-all remote.origin.push 'refs/notes'"
fi

# --- identity ----------------------------------------------------------------
author_email=$(git log -1 --format=%ae)
config_email=$(git config user.email || true)
if [ -n "$config_email" ] && [ "$author_email" != "$config_email" ]; then
    warn author-email "Commit author <$author_email> differs from user.email <$config_email>; Gerrit rejects unregistered emails."
fi

echo
if [ "$errors" -eq 0 ]; then
    echo "PREFLIGHT OK – show the diff to the human and ask before: git push origin HEAD:refs/for/main"
else
    echo "PREFLIGHT FAILED – $errors error(s)."
fi
[ "$errors" -eq 0 ]
