# Sourced by tests/run.sh
GUARD="$ROOT/hooks/guard.py"
SESSION_ENV="$ROOT/hooks/session-env.sh"

hook_input() { # cwd command
    python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$2"
}

expect_guard() { # name expected(deny|ask|none) cwd command [grep-pattern]
    local name=$1 expected=$2 output decision
    output=$(hook_input "$3" "$4" | python3 "$GUARD")
    decision=$(python3 -c 'import json,sys; d=sys.stdin.read().strip(); print(json.loads(d)["hookSpecificOutput"]["permissionDecision"] if d else "none")' <<<"$output")
    if [ "$decision" != "$expected" ]; then
        fail "guard $name: expected $expected, got $decision ($output)"
    elif [ -n "${5:-}" ] && ! grep -q -- "$5" <<<"$output"; then
        fail "guard $name: reason lacks '$5': $output"
    else
        pass
    fi
}

core=$(make_checkout)
git -C "$core" config remote.origin.pushurl ssh://jane-doe@review.typo3.org:29418/Packages/TYPO3.CMS.git
other=$(make_checkout)

# push of a change that fails preflight (nothing ahead) -> deny with preflight output
expect_guard push-preflight-fails deny "$core" "git push origin HEAD:refs/for/main" "PREFLIGHT"
# push of a clean change -> ask (human review gate)
printf '%s\n' "$php_file_ok" > "$core/typo3/sysext/backend/Classes/Foo.php"
commit_in "$core" "[BUGFIX] Add foo"
expect_guard push-ok ask "$core" "git push origin HEAD:refs/for/main" "review gate"
expect_guard push-cd-form ask "$other" "cd $core && git push origin HEAD:refs/for/main" "review gate"
# pushes elsewhere are not touched
expect_guard push-other-repo none "$other" "git push origin main"
# posting to Gerrit is never allowed
expect_guard gerrit-review deny "$other" "ssh -p 29418 jane-doe@review.typo3.org gerrit review 96241,1 --code-review +1" "human posts"
expect_guard gerrit-alias deny "$other" "ssh review.typo3.org gerrit review --verified +1 96241,1"
expect_guard gerrit-rest-post deny "$other" "curl -X POST https://review.typo3.org/a/changes/96241/revisions/current/review -d @vote.json"
expect_guard gerrit-query-ok none "$other" "ssh -p 29418 review.typo3.org gerrit query change:96241"
expect_guard gerrit-rest-get-ok none "$other" "curl -s https://review.typo3.org/changes/96241"
# Co-Authored-By only blocked in the Core checkout
expect_guard coauthor-core deny "$core" 'git commit -m "[TASK] Foo" -m "Co-Authored-By: Claude <noreply@anthropic.com>"' "Gerrit comment"
expect_guard coauthor-other none "$other" 'git commit -m "feat: foo" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
# unrelated commands
expect_guard unrelated none "$core" "ls -la"
# malformed input never blocks
if output=$(echo "not json" | python3 "$GUARD") && [ -z "$output" ]; then pass; else fail "guard should ignore malformed input: $output"; fi

# session-env.sh exports configured options, nothing when unset
envfile=$(mktemp)
CLAUDE_ENV_FILE=$envfile CLAUDE_PLUGIN_OPTION_CONTAINER_RUNTIME=podman CLAUDE_PLUGIN_OPTION_CORE_DIR=/data/core bash "$SESSION_ENV"
if grep -q "export TYPO3_CONTRIB_RUNTIME=podman" "$envfile" && grep -q "export TYPO3_CORE_DIR=/data/core" "$envfile"; then pass; else fail "session-env should export options: $(cat "$envfile")"; fi
envfile=$(mktemp)
CLAUDE_ENV_FILE=$envfile bash "$SESSION_ENV"
[ ! -s "$envfile" ] && pass || fail "session-env should write nothing when options are unset: $(cat "$envfile")"
envfile=$(mktemp)
CLAUDE_ENV_FILE=$envfile CLAUDE_PLUGIN_OPTION_CONTAINER_RUNTIME='docker; rm -rf /' bash "$SESSION_ENV"
grep -q "rm -rf" "$envfile" && fail "session-env must reject invalid runtime values" || pass
