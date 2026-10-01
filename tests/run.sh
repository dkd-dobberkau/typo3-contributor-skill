#!/usr/bin/env bash
# Plain-bash test runner for scripts/. Usage: bash tests/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

# shellcheck source=helpers.sh
source "$ROOT/tests/helpers.sh"

for test_file in "$ROOT"/tests/test_*.sh; do
    # shellcheck source=/dev/null
    source "$test_file"
done

if python3 "$ROOT/tests/test_gerrit.py" >/dev/null 2>&1; then
    pass
else
    fail "python tests (python3 tests/test_gerrit.py)"
fi

echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
