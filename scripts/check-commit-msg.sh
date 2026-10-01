#!/usr/bin/env bash
# Lint a TYPO3 Core commit message.
# Usage: check-commit-msg.sh [message-file]   (default: message of HEAD)
# Exit 0 = no errors (warnings allowed), 1 = errors found.
#
# Stricter than Build/git-hooks/commit-msg, which only prints errors and
# still lets the commit through. Rules follow the Contribution Guide
# (Appendix: Commit Message rules) and the regexes of the Core hook.
set -u

if [ $# -ge 1 ]; then
    raw=$(cat "$1")
else
    raw=$(git log -1 --format=%B)
fi

# Drop comment lines (commit template) and anything after a scissors/diff line.
message=$(printf '%s\n' "$raw" | sed -e '/^diff --git /,$d' -e '/^#/d')

errors=0
error() { echo "ERROR [$1] $2"; errors=$((errors + 1)); }
warn() { echo "WARN [$1] $2"; }

subject=$(printf '%s\n' "$message" | sed -n 1p)
second_line=$(printf '%s\n' "$message" | sed -n 2p)
keyword_regex='^(\[!!!\])?\[(BUGFIX|FEATURE|TASK|DOCS|SECURITY)\] '

# --- subject ---------------------------------------------------------------
if ! [[ $subject =~ ^\[ ]]; then
    error keyword-missing "Subject must start with [BUGFIX], [FEATURE], [TASK], [DOCS] or [SECURITY]."
elif [[ $subject =~ ^\[[A-Z]+\]\[!!!\] ]]; then
    error breaking-position "[!!!] must be at the very beginning: [!!!][FEATURE] ..."
elif ! [[ $subject =~ $keyword_regex ]]; then
    error keyword-invalid "Unknown keyword. Allowed: [BUGFIX] [FEATURE] [TASK] [DOCS] [SECURITY], optionally prefixed by [!!!]."
else
    summary=${subject#"${BASH_REMATCH[0]}"}
    if ! [[ $summary =~ ^[A-Z] ]]; then
        error subject-capital "Summary after the keyword must start with a capital letter."
    fi
    case $summary in
        *EXT:*) warn subject-ext "Avoid EXT:... in the subject." ;;
    esac
    case $summary in
        *.) warn subject-period "Subject should not end with a period." ;;
    esac
fi

# AGENTS.md: "No line of the message may reach 72 characters" (the hook itself only flags 73+).
if [ ${#subject} -gt 71 ]; then
    error subject-too-long "Subject has ${#subject} characters (max 71)."
elif [ ${#subject} -gt 52 ]; then
    warn subject-length "Subject has ${#subject} characters (aim for 52)."
fi

# --- structure -------------------------------------------------------------
if [ -n "$second_line" ]; then
    error blank-line "Line 2 must be empty (separates subject and body)."
fi

line_number=0
while IFS= read -r line; do
    line_number=$((line_number + 1))
    [ "$line_number" -eq 1 ] && continue
    if [ ${#line} -gt 71 ]; then
        if [[ $line =~ https?:// ]]; then
            warn body-url-length "Line $line_number has ${#line} characters (URL; allowed by the guide, the Core hook will complain)."
        else
            error body-too-long "Line $line_number has ${#line} characters (max 71)."
        fi
    fi
done <<<"$message"

# --- footer ----------------------------------------------------------------
if printf '%s\n' "$message" | grep -qE '^(Resolves|Related|Releases|Depends|Change-Id):[^ ]'; then
    error colon-space "A space after the colon is mandatory (e.g. 'Resolves: #12345')."
fi

if printf '%s\n' "$message" | grep -E '^(Resolves|Related): ' | grep -qvE '^(Resolves|Related): #[0-9]+$'; then
    error issue-per-line "One issue per line: 'Resolves: #12345' (no lists, no other text)."
fi

if ! printf '%s\n' "$message" | grep -qE '^Resolves: #[0-9]+$'; then
    error resolves-missing "At least one 'Resolves: #<forge issue>' line is required (Related: alone is not enough)."
fi

releases_line=$(printf '%s\n' "$message" | grep -E '^Releases:' | head -1)
if [ -z "$releases_line" ]; then
    error releases-missing "A 'Releases: main[, 14.3, ...]' line is required."
elif ! [[ $releases_line =~ ^Releases:\ (main|[0-9]+\.[0-9]+)(,\ *(main|[0-9]+\.[0-9]+))*$ ]]; then
    error releases-format "Releases must look like 'Releases: main, 13.4' (main or X.Y, comma separated)."
elif [[ $releases_line =~ [0-9]+\.[0-9]+ ]]; then
    if [[ $subject =~ ^\[!!!\] ]]; then
        error breaking-backport "Breaking changes ([!!!]) target main only."
    elif [[ $subject =~ ^\[FEATURE\] ]]; then
        error feature-backport "Features target main only (exceptions need release manager approval)."
    fi
fi

signoff_line=$(printf '%s\n' "$message" | grep -n '^Signed-off-by:' | tail -1 | cut -d: -f1)
changeid_line=$(printf '%s\n' "$message" | grep -n '^Change-Id:' | head -1 | cut -d: -f1)
if [ -n "$signoff_line" ] && [ -n "$changeid_line" ] && [ "$signoff_line" -gt "$changeid_line" ]; then
    error footer-order "Footer order: Resolves/Related, Releases, Signed-off-by, Change-Id last. Fix: bash scripts/fix-trailer-order.sh"
fi

if printf '%s\n' "$message" | grep -qiE '^Co-Authored-By:'; then
    error co-authored-by "No Co-Authored-By trailer in Core commits (ignore generic agent attribution rules); disclose AI help in the Gerrit comment (templates/gerrit-disclosure.md)."
fi

[ "$errors" -eq 0 ]
