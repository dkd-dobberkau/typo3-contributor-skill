# Documentation-only patch (system extension docs, changelog wording)

System extension manuals (`typo3/sysext/<ext>/Documentation/`) and the Core changelog live in the Core mono-repo. You cannot contribute through the read-only split repos (`github.com/typo3-cms/*`). A GitHub PR against `typo3/typo3` gets converted to Gerrit by a bot. That path is error-prone, so prefer the Gerrit workflow.

You need the setup (clone, pushurl, hooks) but not DDEV.

1. Edit the `.rst` files. Format: reST, 4-space indent, `..  directive::` with two spaces. Cheat sheet: https://docs.typo3.org/permalink/h2document:rest-cheat-sheet
2. Render locally:
   ```bash
   cd typo3/sysext/<ext>
   docker run --rm --pull always -v "$(pwd)":/project -t ghcr.io/typo3-documentation/render-guides:latest --config=Documentation
   open Documentation-GENERATED-temp/Index.html
   ```
   Or, after committing: `Build/Scripts/runTests.sh -b "$RT" -s checkRstRenderingChanged`. For live editing: `-s watchRst`.
3. Forge issue: tracker Task, category Documentation, and the TYPO3 version it applies to.
4. Commit as `[DOCS] <subject>` with `Resolves:` and `Releases:`. Docs patches for TYPO3 documentation repos that depend on a Core patch use `Depends: <Change-Id of the Core patch>`.
5. `qa.sh` (runs `checkRst`), then `preflight.sh`, then the human review gate and push, as in `references/patch.md`.

`Documentation-GENERATED-temp/` is git-ignored; remove it with `-s cleanRenderedDocumentation` when done.
