#!/usr/bin/env bash
#
# Check brain-tools MCP Server Artifact
# Usage: scripts/check-brain-tools-mcp-artifact.sh
#
# Validates:
#   A) brain-tools exists in compiled .mcp.json
#   B) args contain 'mcp:serve' and '--agent'
#   C) no absolute paths in command/args
#   D) stderr=0 for a smoke call via mcp:serve --agent
#
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/brain-cli.sh"

cd "$PROJECT_ROOT"

MCP_FILE="$PROJECT_ROOT/.mcp.json"

# A) brain-tools exists in compiled .mcp.json
echo "A) Testing brain-tools exists in .mcp.json..."
if [[ ! -f "$MCP_FILE" ]]; then
    echo "FAIL: .mcp.json not found - run 'brain compile' first"
    exit 1
fi

if ! jq -e '.mcpServers["brain-tools"]' "$MCP_FILE" >/dev/null 2>&1; then
    echo "FAIL: brain-tools not found in .mcp.json"
    cat "$MCP_FILE"
    exit 1
fi
echo "  PASS: brain-tools exists in .mcp.json"

# B) args contain 'mcp:serve' and '--agent'
echo "B) Testing args contain mcp:serve and --agent..."

COMMAND=$(jq -r '.mcpServers["brain-tools"].command' "$MCP_FILE")
if [[ "$COMMAND" != "brain" ]]; then
    echo "FAIL: brain-tools command expected 'brain', got '$COMMAND'"
    exit 1
fi

ARGS=$(jq -r '.mcpServers["brain-tools"].args | join(" ")' "$MCP_FILE")
if [[ "$ARGS" != *"mcp:serve"* ]]; then
    echo "FAIL: brain-tools args missing 'mcp:serve'"
    echo "  Got: $ARGS"
    exit 1
fi
if [[ "$ARGS" != *"--agent"* ]]; then
    echo "FAIL: brain-tools args missing '--agent'"
    echo "  Got: $ARGS"
    exit 1
fi
echo "  PASS: args contain mcp:serve and --agent"

# C) no absolute paths or forbidden repo-relative paths in command/args
echo "C) Testing no absolute or forbidden paths..."
if [[ "$COMMAND" == /* ]]; then
    echo "FAIL: command is absolute path: $COMMAND"
    exit 1
fi

if echo "$ARGS" | grep -qE '/(Users|home|var|etc|tmp)/'; then
    echo "FAIL: args contain absolute path"
    echo "  Got: $ARGS"
    exit 1
fi

if echo "$ARGS" | grep -qE 'cli/bin/brain'; then
    echo "FAIL: args contain forbidden 'cli/bin/brain' (should be portable 'brain')"
    echo "  Got: $ARGS"
    exit 1
fi
echo "  PASS: no absolute or forbidden paths"

# D) stderr=0 for smoke call via mcp:serve --agent
echo "D) Testing stderr=0 for smoke call..."
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude brain_cli mcp:serve 1>/tmp/bt_out.json 2>/tmp/bt_err.txt

BYTES=$(wc -c < /tmp/bt_err.txt | tr -d ' ')
if [[ "$BYTES" -ne 0 ]]; then
    echo "FAIL: stderr not empty ($BYTES bytes)"
    cat /tmp/bt_err.txt
    rm -f /tmp/bt_out.json /tmp/bt_err.txt
    exit 1
fi

if ! jq -e '.result.tools' /tmp/bt_out.json >/dev/null 2>&1; then
    echo "FAIL: tools/list did not return valid result"
    cat /tmp/bt_out.json
    rm -f /tmp/bt_out.json /tmp/bt_err.txt
    exit 1
fi

TOOL_COUNT=$(jq '.result.tools | length' /tmp/bt_out.json)
if [[ "$TOOL_COUNT" -ne 3 ]]; then
    echo "FAIL: expected 3 tools, got $TOOL_COUNT"
    rm -f /tmp/bt_out.json /tmp/bt_err.txt
    exit 1
fi

echo "  PASS: smoke call stderr=0, returns 3 tools"

# Cleanup
rm -f /tmp/bt_out.json /tmp/bt_err.txt

echo ""
echo "PASS: brain-tools MCP artifact verified (4/4 checks)"
exit 0
