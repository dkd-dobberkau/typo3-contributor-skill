# Sourced by tests/run.sh
QUICKSTART="$ROOT/scripts/quickstart-check.sh"

# Fake Core checkout that passes check-setup.sh, plus a stub `ddev` on PATH.
# Prints "home core bin".
quickstart_env() {
    local home core bin
    home=$(mktemp -d)
    mkdir -p "$home/.ssh"
    printf 'Host review.typo3.org\n    Port 29418\n    User jane-doe\n' > "$home/.ssh/config"
    core=$(make_checkout)
    git -C "$core" remote set-url origin https://github.com/typo3/typo3.git
    mkdir -p "$core/Build/git-hooks"
    printf '#!/bin/sh\n' > "$core/Build/git-hooks/commit-msg"
    printf '{"require": {"php": "^8.5"}}\n' > "$core/composer.json"
    HOME=$home TYPO3_CORE_DIR=$core GIT_CONFIG_GLOBAL=$home/.gitconfig bash "$ROOT/scripts/check-setup.sh" --fix >/dev/null 2>&1
    bin=$(mktemp -d)
    cat > "$bin/ddev" <<'STUB'
#!/bin/sh
case "$1 $2" in
    "--version "*) echo "ddev version v1.25.4" ;;
    "list -j") cat "$FAKE_DDEV_LIST" ;;
esac
STUB
    chmod +x "$bin/ddev"
    echo "$home $core $bin"
}

complete_quickstart() { # core
    mkdir -p "$1/.ddev" "$1/typo3conf/system" "$1/vendor"
    printf 'name: t3c-main\ntype: typo3\ndocroot: .\nphp_version: "8.5"\n' > "$1/.ddev/config.yaml"
    echo "<?php return [];" > "$1/typo3conf/system/settings.php"
    printf "<?php return ['packages' => ['styleguide' => [], 'indexed_search' => []]];\n" > "$1/typo3conf/PackageStates.php"
}

ddev_list() { # core status -> path of fake `ddev list -j` output
    local file
    file=$(mktemp)
    printf '{"raw": [{"name": "t3c-main", "status": "%s", "approot": "%s", "type": "typo3"}]}\n' "$2" "$1" > "$file"
    echo "$file"
}

run_quickstart() { # home core bin list-file
    HOME=$1 TYPO3_CORE_DIR=$2 GIT_CONFIG_GLOBAL=$1/.gitconfig PATH="$3:$PATH" FAKE_DDEV_LIST=$4 \
        bash "$QUICKSTART" 2>&1
}

expect_quickstart() { # name expected(ok|rule[,rule]) home core bin list
    local name=$1 expected=$2 output rule
    if output=$(run_quickstart "$3" "$4" "$5" "$6"); then
        [ "$expected" = ok ] && pass || fail "quickstart $name: expected $expected, passed: $output"
        return
    fi
    if [ "$expected" = ok ]; then
        fail "quickstart $name: expected ok, got: $output"
        return
    fi
    for rule in ${expected//,/ }; do
        grep -qE "MISSING +\[$rule\]" <<<"$output" || { fail "quickstart $name: missing [$rule] in: $output"; return; }
    done
    pass
}

# fresh checkout: DDEV and TYPO3 steps missing, Git step ok
read -r home core bin <<<"$(quickstart_env)"
: "${home:?}" "${core:?}" "${bin:?}"
empty_list=$(mktemp); echo '{"raw": []}' > "$empty_list"
expect_quickstart fresh "ddev-config,typo3-installed" "$home" "$core" "$bin" "$empty_list"
output=$(run_quickstart "$home" "$core" "$bin" "$empty_list")
grep -q "Step 3" <<<"$output" && grep -q "ok .*Git setup" <<<"$output" && pass || fail "quickstart should report Git step ok: $output"
grep -q "my.typo3.org" <<<"$output" && pass || fail "quickstart should print the account checklist: $output"

# complete and running
complete_quickstart "$core"
expect_quickstart complete ok "$home" "$core" "$bin" "$(ddev_list "$core" running)"

# DDEV stopped
expect_quickstart stopped ddev-running "$home" "$core" "$bin" "$(ddev_list "$core" stopped)"

# PHP version below the Core requirement
sed -i '' 's/php_version: "8.5"/php_version: "8.4"/' "$core/.ddev/config.yaml" 2>/dev/null \
    || sed -i 's/php_version: "8.5"/php_version: "8.4"/' "$core/.ddev/config.yaml"
expect_quickstart php ddev-php "$home" "$core" "$bin" "$(ddev_list "$core" running)"
complete_quickstart "$core"

# styleguide not activated
printf "<?php return ['packages' => ['indexed_search' => []]];\n" > "$core/typo3conf/PackageStates.php"
expect_quickstart styleguide styleguide "$home" "$core" "$bin" "$(ddev_list "$core" running)"
