# Changelog, deprecation, extension scanner

Authoritative format: `typo3/sysext/core/Documentation/Changelog/Howto.rst` in the checkout. Read it when unsure.

## When an rst file is needed

| Change | File | Subject |
|---|---|---|
| New feature (also small) | `Feature-<issue>-<UpperCamelTitle>.rst` | `[FEATURE]`, main only |
| Breaking change | `Breaking-<issue>-<Title>.rst` | `[!!!][TASK]` / `[!!!][FEATURE]`, main only |
| Deprecation, including "new replacement API + deprecate the old one" | `Deprecation-<issue>-<Title>.rst` only, describing the replacement in Migration | `[TASK]` (Core precedent), never `[!!!]` |
| Important note (behaviour change, no break) | `Important-<issue>-<Title>.rst` | any |
| Plain bugfix/task | none | |

Add a Feature file next to a Deprecation file only if the new API offers more than a replacement.

## Folder

Use the minor version the change **will be released in** (Howto.rst):
- `main` only: `typo3/sysext/core/Documentation/Changelog/<BRANCH>/`. `BRANCH` is the constant in `typo3/sysext/core/Classes/Information/Typo3Version.php` (AGENTS.md: authoritative; `composer.json` branch-alias mirrors it).
- Also backported to an LTS branch (only Important files for bugfixes): `Changelog/<lts>.x/`, e.g. `14.3.x/`, both in main and in the backport.

The toctree uses globs, so you do not edit any index file.

## Writing the file

Start from `templates/changelog/<Type>.rst`:
- `{TIMESTAMP}` = `date +%s`, `{ISSUE}` = Forge number.
- `{HEADLINE_RULE}` = `=` repeated to the exact headline length.
- `NEXT_MAJOR` = main major + 1.

Sections:
- Feature: Description, Impact.
- Deprecation and Breaking: Description, Impact, Affected installations, Migration.
- Important: Description.

Last line: `..  index::` with tags such as `Backend`, `Frontend`, `PHP-API`, `TCA`, `TypoScript`, `Fluid`, `JavaScript`, `CLI`, `Database`, `FAL`, `RTE`, `TSConfig`, `LocalConfiguration`, plus `ext:<extension>`. **Breaking and Deprecation** also need exactly one of `FullyScanned`, `PartiallyScanned`, `NotScanned`.

Check it: `Build/Scripts/runTests.sh -b "$RT" -s checkRst`. To render it: `-s checkRstRenderingChanged` (after commit).

The web generator at https://forger.typo3.com/utilities/rst produces the same skeleton. Offer it to the human as an alternative.

## Deprecating PHP API

Wording as used in Core (AGENTS.md short form: `@deprecated since v15, will be removed in v16`):

```php
/**
 * @deprecated since TYPO3 v15.0, will be removed in TYPO3 v16.0. Use Bar::baz() instead.
 */
public static function foo($value)
{
    trigger_error(
        'Foo::foo() will be removed in TYPO3 v16.0. Use ' . Bar::class . '::baz() instead.',
        E_USER_DEPRECATED
    );
    return GeneralUtility::makeInstance(Bar::class)->baz((string)$value); // keep working
}
```

- **Arguments:** check `func_num_args()` and trigger the same way.
- **Public property or method that becomes protected:** use `TYPO3\CMS\Core\Compatibility\PublicPropertyDeprecationTrait` (`$deprecatedPublicProperties`) or `PublicMethodDeprecationTrait` (`$deprecatedPublicMethods`).
- **Core callers:** migrate all of them. Core itself must not trigger the deprecation.
- **Tests:**
  - Tests of the new code go in its own test class.
  - Tests that still call the deprecated API are kept with `#[IgnoreDeprecations]` (`use PHPUnit\Framework\Attributes\IgnoreDeprecations;`), as in Core.
- **Precedent:** `git log --oneline --grep='Deprecate' -- <file>` usually shows a merged change with the same shape. Copy its structure.

## Extension scanner

Add a matcher whenever PHP API is deprecated or removed: `typo3/sysext/install/Configuration/ExtensionScanner/Php/<Matcher>.php`. Pick the file by kind, e.g. `MethodCallStaticMatcher`, `MethodCallMatcher`, `ClassNameMatcher`, `MethodArgumentDroppedMatcher`, `PropertyPublicMatcher`, `ConstructorArgumentMatcher`. Add new entries at the end:

```php
'TYPO3\CMS\Foo\Utility\Foo::foo' => [
    'numberOfMandatoryArguments' => 1,
    'maximumNumberOfArguments' => 1,
    'restFiles' => [
        'Deprecation-12345-FooFoo.rst',
    ],
],
```

- `FullyScanned`: a matcher finds every usage the rst describes. Core uses it for static method matchers, even though `self::`/`static::` calls in subclasses are missed.
- `PartiallyScanned`: matchers cover only some of the cases; say which ones in the rst.
- `NotScanned`: the change cannot be matched, e.g. behaviour or configuration changes.

Verify:
- `Build/Scripts/runTests.sh -b "$RT" -s checkExtensionScannerRst`
- `-s unit typo3/sysext/install/Tests/Unit/ExtensionScanner/`

## Backport requests ("we need it in 14.3 / 13.4")

Features, deprecations and breaking changes go to `main` only. Explain this to the human. A project that needs it earlier can use a project-level class or a patch via `cweagans/composer-patches`. Only release managers make exceptions.
