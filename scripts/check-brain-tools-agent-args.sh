#!/usr/bin/env bash
#
# Check brain-tools Agent Args Injection
# Usage: scripts/check-brain-tools-agent-args.sh
#
# Validates:
#   A) .mcp.json brain-tools args contain --agent with non-empty value
#   B) list_masters inputSchema has no properties (empty schema)
#   C) No agent field in list_masters tool input (server-side only)
#
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/brain-cli.sh"

cd "$PROJECT_ROOT"

MCP_FILE="$PROJECT_ROOT/.mcp.json"

# A) brain-tools args contain --agent with non-empty value
echo "A) Testing brain-tools args contain --agent with value..."

if [[ ! -f "$MCP_FILE" ]]; then
    echo "FAIL: .mcp.json not found - run 'brain compile' first"
    exit 1
fi

ARGS=$(jq -c '.mcpServers["brain-tools"].args // []' "$MCP_FILE")

if [[ "$ARGS" == "null" ]] || [[ "$ARGS" == "[]" ]]; then
    echo "FAIL: brain-tools args missing or empty"
    exit 1
fi

AGENT_INDEX=$(echo "$ARGS" | jq 'index("--agent")')
if [[ "$AGENT_INDEX" == "null" ]]; then
    echo "FAIL: --agent not found in brain-tools args"
    echo "  Got: $ARGS"
    exit 1
fi

AGENT_VALUE_INDEX=$((AGENT_INDEX + 1))
AGENT_VALUE=$(echo "$ARGS" | jq -r ".[$AGENT_VALUE_INDEX]")

if [[ -z "$AGENT_VALUE" ]] || [[ "$AGENT_VALUE" == "null" ]]; then
    echo "FAIL: Agent ID value missing after --agent"
    echo "  Args: $ARGS"
    exit 1
fi

echo "  PASS: --agent $AGENT_VALUE found in args"

# B) list_masters inputSchema has no properties (empty schema)
echo "B) Testing list_masters inputSchema is empty..."

TOOLS_RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude brain_cli mcp:serve 2>/dev/null)

if [[ -z "$TOOLS_RESPONSE" ]]; then
    echo "FAIL: No response from mcp:serve"
    exit 1
fi

LIST_MASTERS_SCHEMA=$(echo "$TOOLS_RESPONSE" | jq -c '.result.tools[] | select(.name == "list_masters") | .inputSchema' 2>/dev/null)

if [[ -z "$LIST_MASTERS_SCHEMA" ]] || [[ "$LIST_MASTERS_SCHEMA" == "null" ]]; then
    echo "FAIL: list_masters tool not found or missing inputSchema"
    exit 1
fi

PROPERTIES=$(echo "$LIST_MASTERS_SCHEMA" | jq -c '.properties')
REQUIRED=$(echo "$LIST_MASTERS_SCHEMA" | jq -c '.required')

if [[ "$PROPERTIES" != "{}" ]] && [[ "$PROPERTIES" != "null" ]]; then
    echo "FAIL: list_masters inputSchema.properties must be empty"
    echo "  Got: $PROPERTIES"
    exit 1
fi

if [[ "$REQUIRED" != "[]" ]] && [[ "$REQUIRED" != "null" ]]; then
    echo "FAIL: list_masters inputSchema.required must be empty"
    echo "  Got: $REQUIRED"
    exit 1
fi

echo "  PASS: list_masters inputSchema is empty"

# C) No agent field in list_masters tool input (server-side only)
echo "C) Testing list_masters rejects agent in input..."

CALL_RESPONSE=$(echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_masters","arguments":{"agent":"test"}}}' | BRAIN_AGENT_ID=claude brain_cli mcp:serve 2>/dev/null)

if echo "$CALL_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    ERROR_REASON=$(echo "$CALL_RESPONSE" | jq -r '.error.data.reason // .error.message // "unknown"')
    if [[ "$ERROR_REASON" == *"INVALID_INPUT"* ]] || [[ "$ERROR_REASON" == *"not supported"* ]]; then
        echo "  PASS: list_masters correctly rejects agent in input"
    else
        echo "FAIL: list_masters returned unexpected error: $ERROR_REASON"
        exit 1
    fi
else
    echo "FAIL: list_masters should reject agent in input but didn't return error"
    echo "  Response: $CALL_RESPONSE"
    exit 1
fi

echo ""
echo "PASS: brain-tools agent args verified (3/3 checks)"
exit 0
