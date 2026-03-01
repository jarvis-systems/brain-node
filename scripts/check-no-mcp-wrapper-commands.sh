#!/usr/bin/env bash
#
# No MCP Wrapper Commands Check (brain-tools)
# Ensures mcp:serve is the ONLY MCP entrypoint for brain-tools internal tools.
# Shadow wrapper commands would bypass the thin adapter contract.
#
# This check forbids commands that would create parallel implementations
# of brain-tools functionality (docs_search, diagnose, list_masters).
#
# NOTE: mcp:list, mcp:call, mcp:describe, etc. are for EXTERNAL MCP servers
# (context7, vector-memory, etc.) and are NOT forbidden by this check.
#
# Usage: scripts/check-no-mcp-wrapper-commands.sh
#
# Exit codes:
#   0 - No wrapper commands found
#   1 - One or more forbidden wrapper commands exist
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI_COMMANDS_DIR="$PROJECT_ROOT/cli/src/Console/Commands"

# Forbidden: Commands that would shadow brain-tools tools
# These would bypass mcp:serve and create parallel implementations
FORBIDDEN_FILES=(
    "McpDocsSearchCommand.php"
    "McpDiagnoseCommand.php"
    "McpListMastersCommand.php"
)

VIOLATIONS=()

for forbidden in "${FORBIDDEN_FILES[@]}"; do
    if [[ -f "$CLI_COMMANDS_DIR/$forbidden" ]]; then
        VIOLATIONS+=("$forbidden")
    fi
done

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
    echo "ERROR: Forbidden brain-tools wrapper commands detected in cli/src/Console/Commands/" >&2
    echo "" >&2
    echo "mcp:serve is the ONLY MCP entrypoint for brain-tools." >&2
    echo "These files would bypass the thin adapter contract:" >&2
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v" >&2
    done
    echo "" >&2
    echo "Use mcp:serve instead. All brain-tools logic must go through McpServeCommand." >&2
    exit 1
fi

echo "OK: No brain-tools wrapper commands found"
exit 0
