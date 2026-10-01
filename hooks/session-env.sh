#!/usr/bin/env bash
# SessionStart hook: export the plugin options for every Bash call of the session.
# Unset options export nothing, so the scripts fall back to their defaults.
set -u
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0

runtime=${CLAUDE_PLUGIN_OPTION_CONTAINER_RUNTIME:-}
case $runtime in
    docker | podman) echo "export TYPO3_CONTRIB_RUNTIME=$runtime" >> "$CLAUDE_ENV_FILE" ;;
esac

core_dir=${CLAUDE_PLUGIN_OPTION_CORE_DIR:-}
if [ -n "$core_dir" ]; then
    printf 'export TYPO3_CORE_DIR=%q\n' "$core_dir" >> "$CLAUDE_ENV_FILE"
fi
exit 0
