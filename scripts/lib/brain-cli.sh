#!/usr/bin/env bash
#
# Brain CLI Helper — Canonical invocation for repo-local brain entrypoint
# Source this file to get brain_cli() function.
#
# Usage:
#   source scripts/lib/brain-cli.sh
#   brain_cli docs --validate
#   brain_cli mcp:serve
#
# Never use:
#   - `brain` (global composer stub)
#   - `php vendor/bin/brain` (wrong for this repo)
#   - Relative paths without PROJECT_ROOT
#

_BRAIN_CLI_SOURCED=1

_brain_cli_resolve_project_root() {
    local script_dir
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [[ -n "${0:-}" ]]; then
        script_dir="$(cd "$(dirname "$0")" && pwd)"
    else
        echo "ERROR: Cannot resolve script directory" >&2
        return 1
    fi

    if [[ -f "$script_dir/lib/brain-cli.sh" ]]; then
        dirname "$script_dir"
    else
        dirname "$(dirname "$script_dir")"
    fi
}

BRAIN_CLI_PROJECT_ROOT="${BRAIN_CLI_PROJECT_ROOT:-$(_brain_cli_resolve_project_root 2>/dev/null)}"

if [[ -z "${BRAIN_CLI_PROJECT_ROOT:-}" ]]; then
    echo "ERROR: Cannot resolve PROJECT_ROOT for brain CLI" >&2
    return 1 2>/dev/null || exit 1
fi

BRAIN_CLI_ENTRYPOINT="$BRAIN_CLI_PROJECT_ROOT/cli/bin/brain"

brain_cli() {
    if [[ ! -f "$BRAIN_CLI_ENTRYPOINT" ]]; then
        echo "ERROR: Brain CLI entrypoint missing: $BRAIN_CLI_ENTRYPOINT" >&2
        echo "       Run: cd cli && composer install" >&2
        return 1 2>/dev/null || exit 1
    fi

    if [[ ! -x "$BRAIN_CLI_ENTRYPOINT" ]]; then
        echo "ERROR: Brain CLI entrypoint not executable: $BRAIN_CLI_ENTRYPOINT" >&2
        echo "       Run: chmod +x $BRAIN_CLI_ENTRYPOINT" >&2
        return 1 2>/dev/null || exit 1
    fi

    php "$BRAIN_CLI_ENTRYPOINT" "$@"
}

brain_cli_raw() {
    if [[ ! -f "$BRAIN_CLI_ENTRYPOINT" ]]; then
        return 1 2>/dev/null || exit 1
    fi
    php "$BRAIN_CLI_ENTRYPOINT" "$@"
}
