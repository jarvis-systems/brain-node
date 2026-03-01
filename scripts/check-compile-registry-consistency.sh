#!/usr/bin/env bash
#
# Check consistency between MCP registry and compiled output
# Usage: scripts/check-compile-registry-consistency.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# 1. Get resolved state from brain mcp:list
LIST_OUTPUT=$(php cli/bin/brain mcp:list)
IS_ENABLED=$(echo "$LIST_OUTPUT" | jq -r '.enabled')

if [[ "$IS_ENABLED" == "false" ]]; then
    # If disabled, .mcp.json should have no servers
    if [[ -f ".mcp.json" ]]; then
        SERVER_COUNT=$(jq -r '.mcpServers | length' .mcp.json)
        if [[ "$SERVER_COUNT" -gt 0 ]]; then
            echo "FAIL: MCP is disabled via kill-switch but .mcp.json contains servers"
            exit 1
        fi
    fi
    echo "PASS: MCP compile consistency verified (disabled)"
    exit 0
fi

# 2. Get enabled IDs from registry (via mcp:list)
REGISTRY_IDS=$(echo "$LIST_OUTPUT" | jq -r '.data.servers[] | select(.enabled == true) | .id' | sort | tr '
' ' ')

# 3. Get IDs from .mcp.json (excluding brain-tools builtin)
if [[ -f ".mcp.json" ]]; then
    # brain-tools is a builtin internal server (not in registry) - exclude from comparison
    # All other servers should match registry 1:1
    COMPILED_IDS=$(jq -r '.mcpServers | keys[]' .mcp.json | grep -v "^brain-tools$" | sort | tr '\n' ' ')
else
    COMPILED_IDS=""
fi

# 4. Compare
if [[ "$REGISTRY_IDS" != "$COMPILED_IDS" ]]; then
    echo "FAIL: Compiled MCP servers do not match registry"
    echo "Registry (enabled): $REGISTRY_IDS"
    echo "Compiled: $COMPILED_IDS"
    exit 1
fi

echo "PASS: MCP compile consistency verified"
exit 0
