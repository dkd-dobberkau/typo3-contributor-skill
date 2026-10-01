# Sourced by tests/run.sh
QA="$ROOT/scripts/qa.sh"

qa_checkout() {
    local d
    d=$(make_checkout)
    mkdir -p "$d/typo3/sysext/backend/Classes/Form/Element" \
        "$d/typo3/sysext/backend/Tests/Unit/Form/Element" \
        "$d/typo3/sysext/backend/Tests/Functional/Form" \
        "$d/typo3/sysext/core/Resources/Private/Language" \
        "$d/vendor"
    touch "$d/typo3/sysext/backend/Tests/Unit/Form/Element/.keep" "$d/typo3/sysext/backend/Tests/Functional/Form/.keep"
    git -C "$d" add -A && git -C "$d" commit -q --no-verify -m init2 && git -C "$d" push -q origin main 2>/dev/null
    echo "$d"
}

expect_qa() { # name dir pattern [pattern...]  (each pattern must appear in dry-run output)
    local name=$1 dir=$2 output pattern
    shift 2
    output=$(cd "$dir" && bash "$QA" --dry-run 2>&1)
    for pattern in "$@"; do
        if [[ $pattern == '!'* ]]; then
            grep -qF -- "${pattern:1}" <<<"$output" && { fail "qa $name: unexpected '${pattern:1}' in: $output"; return; }
        else
            grep -qF -- "$pattern" <<<"$output" || { fail "qa $name: missing '$pattern' in: $output"; return; }
        fi
    done
    pass
}

RT="Build/Scripts/runTests.sh -b docker"
CIRT="CI=true Build/Scripts/runTests.sh -b docker"

# PHP class change -> cgl, lint, phpstan, nearest unit + functional tests
d=$(qa_checkout)
printf '%s\n' "$php_file_ok" > "$d/typo3/sysext/backend/Classes/Form/Element/JsonElement.php"
commit_in "$d" "[BUGFIX] Escape placeholder"
expect_qa php-class "$d" \
    "$RT -s cglGit -n" "$RT -s cglHeaderGit -n" "$RT -s lintPhp" "CI=true $RT -s phpstan" \
    "$CIRT -s unit typo3/sysext/backend/Tests/Unit/Form/Element/" \
    "$CIRT -s functional typo3/sysext/backend/Tests/Functional/Form/" \
    "!-s build" "!-s composerInstall"

# changed test file is run directly
d=$(qa_checkout)
printf '%s\n' "$php_file_ok" > "$d/typo3/sysext/backend/Tests/Unit/Form/Element/JsonElementTest.php"
commit_in "$d" "[TASK] Add test"
expect_qa php-test "$d" "$CIRT -s unit typo3/sysext/backend/Tests/Unit/Form/Element/JsonElementTest.php"

# TypeScript + SCSS -> lint + build
d=$(qa_checkout)
mkdir -p "$d/Build/Sources/TypeScript" "$d/Build/Sources/Sass"
echo "export {}" > "$d/Build/Sources/TypeScript/foo.ts"
echo "a{}" > "$d/Build/Sources/Sass/foo.scss"
commit_in "$d" "[TASK] Change frontend"
expect_qa frontend "$d" "$RT -s lintTypescript" "$RT -s lintScss" "$CIRT -s build" "!-s phpstan"

# XLIFF
d=$(qa_checkout)
echo "<xliff/>" > "$d/typo3/sysext/core/Resources/Private/Language/foo.xlf"
commit_in "$d" "[TASK] Add label"
expect_qa xliff "$d" "$RT -s normalizeXliff -n" "$RT -s checkIntegrityXliff"

# changelog rst + extension scanner config
d=$(qa_checkout)
mkdir -p "$d/typo3/sysext/install/Configuration/ExtensionScanner/Php"
echo "<?php return [];" > "$d/typo3/sysext/install/Configuration/ExtensionScanner/Php/MethodCallStaticMatcher.php"
printf 'x\n..  index:: PHP-API, FullyScanned, ext:core\n' > "$d/typo3/sysext/core/Documentation/Changelog/15.0/Deprecation-1-Foo.rst"
commit_in "$d" "[TASK] Deprecate foo"
expect_qa rst-scanner "$d" "$RT -s checkRst" "$RT -s checkExtensionScannerRst"

# composer + yaml
d=$(qa_checkout)
mkdir -p "$d/typo3/sysext/backend/Configuration"
echo "{}" > "$d/typo3/sysext/backend/composer.json"
echo "services: {}" > "$d/typo3/sysext/backend/Configuration/Services.yaml"
commit_in "$d" "[TASK] Change config"
expect_qa composer-yaml "$d" "$RT -s checkComposer" "$RT -s composerValidate" "$RT -s lintServicesYaml"

# missing vendor -> composerInstall first
d=$(qa_checkout)
rm -rf "$d/vendor"
echo x >> "$d/README.md"; commit_in "$d" "[TASK] Readme"
expect_qa no-vendor "$d" "$RT -s composerInstall"

# changed Playwright spec -> run that spec only
d=$(qa_checkout)
mkdir -p "$d/Build/tests/playwright/e2e/form-engine"
echo "test()" > "$d/Build/tests/playwright/e2e/form-engine/json.spec.ts"
commit_in "$d" "[TASK] Add e2e test"
expect_qa e2e-spec "$d" "$RT -s e2e Build/tests/playwright/e2e/form-engine/json.spec.ts" "!-s lintTypescript"

# help and unknown flags
d=$(qa_checkout)
if output=$(cd "$d" && bash "$QA" -h 2>&1) && grep -q "Usage: qa.sh" <<<"$output"; then pass; else fail "qa -h should print usage: $output"; fi
if output=$(cd "$d" && bash "$QA" --bogus 2>&1); then fail "qa --bogus should fail"; else grep -q "Usage: qa.sh" <<<"$output" && pass || fail "qa --bogus should print usage: $output"; fi

# database-related change -> hint to run functional tests on a real DBMS
d=$(qa_checkout)
mkdir -p "$d/typo3/sysext/core/Classes/Database"
printf '%s\n' "$php_file_ok" > "$d/typo3/sysext/core/Classes/Database/Foo.php"
commit_in "$d" "[BUGFIX] Fix query"
expect_qa db-hint "$d" "-d mariadb"
