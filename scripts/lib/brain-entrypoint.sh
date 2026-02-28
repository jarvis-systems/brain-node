#!/usr/bin/env bash
#
# Brain Entrypoint Helper — Portable CLI invocation for consumer projects
# Source this file to get resolve_brain_entrypoint() and brain() functions.
#
# Usage:
#   source scripts/lib/brain-entrypoint.sh
#   brain docs --validate
#   brain compile --contract
#
# Resolution order:
#   1. Repo-local entrypoint: cli/bin/brain (if exists)
#   2. Global brain binary: which brain (if exists and passes health check)
#   3. FAIL with actionable error
#
# Never uses:
#   - php vendor/bin/brain (wrong for this repo structure)
#   - Relative paths without PROJECT_ROOT resolution
#

_BRAIN_ENTRYPOINT_SOURCED=1

# ── Resolve project root ─────────────────────────────────────────────────────

_brain_resolve_project_root() {
    local script_dir
    
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [[ -n "${0:-}" ]]; then
        script_dir="$(cd "$(dirname "$0")" && pwd)"
    else
        echo "ERROR: Cannot resolve script directory" >&2
        return 1
    fi

    # Look for .brain directory to identify project root
    local current="$script_dir"
    while [[ "$current" != "/" ]]; do
        if [[ -d "$current/.brain" ]]; then
            echo "$current"
            return 0
        fi
        current="$(dirname "$current")"
    done

    # Fallback: assume scripts/lib structure
    if [[ -f "$script_dir/lib/brain-entrypoint.sh" ]]; then
        dirname "$script_dir"
    else
        dirname "$(dirname "$script_dir")"
    fi
}

# ── Resolve brain entrypoint ────────────────────────────────────────────────

resolve_brain_entrypoint() {
    local project_root
    project_root="$(_brain_resolve_project_root 2>/dev/null)" || return 1

    # Option 1: Repo-local entrypoint (preferred for development)
    local local_entrypoint="$project_root/cli/bin/brain"
    if [[ -f "$local_entrypoint" && -x "$local_entrypoint" ]]; then
        echo "$local_entrypoint"
        return 0
    fi

    # Option 2: Global brain binary (consumer projects)
    local global_brain
    if global_brain=$(command -v brain 2>/dev/null) && [[ -n "$global_brain" ]]; then
        # Health check: ensure it's not a broken composer stub
        if "$global_brain" --version >/dev/null 2>&1; then
            echo "$global_brain"
            return 0
        else
            echo "ERROR: Global brain binary exists but fails health check: $global_brain" >&2
            echo "       This may be a broken composer stub." >&2
            echo "       Install brain globally: composer global require jarvis-brain/cli" >&2
            return 1
        fi
    fi

    # Option 3: Fail with actionable error
    echo "ERROR: Cannot resolve brain entrypoint" >&2
    echo "" >&2
    echo "  Tried:" >&2
    echo "    - Repo-local: $local_entrypoint (not found)" >&2
    echo "    - Global: brain (not in PATH)" >&2
    echo "" >&2
    echo "  Solutions:" >&2
    echo "    - In repo: cd cli && composer install" >&2
    echo "    - Consumer: composer global require jarvis-brain/cli" >&2
    return 1
}

# ── brain() function for convenient invocation ──────────────────────────────

BRAIN_ENTRYPOINT_CACHE=""

brain() {
    if [[ -z "$BRAIN_ENTRYPOINT_CACHE" ]]; then
        BRAIN_ENTRYPOINT_CACHE=$(resolve_brain_entrypoint) || return 1
    fi

    php "$BRAIN_ENTRYPOINT_CACHE" "$@"
}

# ── brain_raw() for capturing output ────────────────────────────────────────

brain_raw() {
    if [[ -z "$BRAIN_ENTRYPOINT_CACHE" ]]; then
        BRAIN_ENTRYPOINT_CACHE=$(resolve_brain_entrypoint) || return 1
    fi

    php "$BRAIN_ENTRYPOINT_CACHE" "$@"
}

# ── Self-test ───────────────────────────────────────────────────────────────

brain_entrypoint_self_test() {
    echo "Testing brain-entrypoint.sh..."
    
    local entrypoint
    if ! entrypoint=$(resolve_brain_entrypoint); then
        echo "FAIL: resolve_brain_entrypoint returned error"
        return 1
    fi
    
    echo "PASS: Entrypoint resolved: $entrypoint"
    
    if ! brain --version >/dev/null 2>&1; then
        echo "FAIL: brain --version failed"
        return 1
    fi
    
    echo "PASS: brain --version works"
    
    local contract_output
    if ! contract_output=$(brain_raw compile --contract --no-interaction 2>&1); then
        echo "FAIL: brain compile --contract failed"
        echo "$contract_output"
        return 1
    fi
    
    if ! echo "$contract_output" | jq -e '.ok' >/dev/null 2>&1; then
        echo "FAIL: compile --contract output missing .ok key"
        echo "$contract_output"
        return 1
    fi
    
    echo "PASS: brain compile --contract produces valid JSON"
    
    echo ""
    echo "All self-tests passed!"
    return 0
}

# Run self-test if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    brain_entrypoint_self_test
    exit $?
fi
