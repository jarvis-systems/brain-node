#!/usr/bin/env bash
#
# Check MCP Discovery v1 contract
# Usage: scripts/check-mcp-discovery.sh
#
# Uses sequential-thinking for testing (allowed tool: think)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

# 1. Test mcp:list schema and sorting
log_check "mcp:list"
LIST_OUTPUT=$(php cli/bin/brain mcp:list)

# Check enabled and kill_switch_env
if [[ $(echo "$LIST_OUTPUT" | jq -r '.enabled') != "true" ]]; then
    echo "FAIL: mcp:list reported disabled when enabled"
    exit 1
fi

# Check sorting of servers
SERVERS=$(echo "$LIST_OUTPUT" | jq -r '.data.servers[].id')
SORTED_SERVERS=$(echo "$SERVERS" | sort)
if [[ "$SERVERS" != "$SORTED_SERVERS" ]]; then
    echo "FAIL: servers in mcp:list are not sorted ASC"
    echo "Got: $SERVERS"
    exit 1
fi

# Check allowed_tools sorting for vector-memory
TOOLS=$(echo "$LIST_OUTPUT" | jq -r '.data.servers[] | select(.id == "vector-memory") | .allowed_tools | join(",")')
if [[ "$TOOLS" != "search,stats,upsert" ]]; then
    echo "FAIL: allowed_tools for vector-memory not sorted or incomplete. Got: $TOOLS"
    exit 1
fi
echo "  PASS: mcp:list valid"

# 2. Test mcp:describe with sequential-thinking (allowed tool: think)
log_check "mcp:describe --server=sequential-thinking"
DESC_OUTPUT=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:describe --server=sequential-thinking)

if [[ $(echo "$DESC_OUTPUT" | jq -r '.server') != "sequential-thinking" ]]; then
    echo "FAIL: mcp:describe --server=sequential-thinking returned wrong server"
    exit 1
fi

# Check that only allowed tools are present
TOOL_COUNT=$(echo "$DESC_OUTPUT" | jq '.data.tools | length')
if [[ "$TOOL_COUNT" -ne 1 ]]; then
    echo "FAIL: mcp:describe returned $TOOL_COUNT tools, expected 1 for sequential-thinking"
    exit 1
fi

TOOL_NAME=$(echo "$DESC_OUTPUT" | jq -r '.data.tools[0].name')
if [[ "$TOOL_NAME" != "think" ]]; then
    echo "FAIL: mcp:describe returned wrong tool for sequential-thinking: $TOOL_NAME"
    exit 1
fi
echo "  PASS: mcp:describe valid"

# 3. Test mcp:describe forbidden tool exclusion
log_check "mcp:describe exclusion"
# vector-task has many tools in schema, but only 3 allowed in policy
TASK_TOOLS=$(php cli/bin/brain mcp:describe --server=vector-task | jq -r '.data.tools[].name' | sort | tr '\n' ' ')
EXPECTED_TASK_TOOLS="task_create task_get task_list "
if [[ "$TASK_TOOLS" != "$EXPECTED_TASK_TOOLS" ]]; then
    echo "FAIL: mcp:describe did not filter tools for vector-task correctly"
    echo "Got: $TASK_TOOLS"
    echo "Exp: $EXPECTED_TASK_TOOLS"
    exit 1
fi
echo "  PASS: mcp:describe exclusion works"

# 4. Test kill-switch
log_check "Discovery kill-switch"
BRAIN_DISABLE_MCP=true php cli/bin/brain mcp:list > list_disabled.json || true
if [[ $(jq -r '.enabled' list_disabled.json) != "false" ]]; then
    echo "FAIL: mcp:list did not honor kill-switch"
    exit 1
fi

BRAIN_DISABLE_MCP=true php cli/bin/brain mcp:describe --server=vector-task > desc_disabled.json || true
if [[ $(jq -r '.error.code' desc_disabled.json) != "MCP_DISABLED" ]]; then
    echo "FAIL: mcp:describe did not honor kill-switch"
    exit 1
fi
echo "  PASS: Kill-switch blocks discovery"

rm list_disabled.json desc_disabled.json
echo "PASS: MCP discovery v1 verified"
