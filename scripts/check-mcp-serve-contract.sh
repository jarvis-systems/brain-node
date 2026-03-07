#!/usr/bin/env bash
#
# Check MCP Serve Contract: brain-tools JSON-RPC stdio adapter
# Usage: scripts/check-mcp-serve-contract.sh
#
# Validates:
#   A) initialize returns JSON-RPC 2.0 result with serverInfo.name == "brain-tools"
#   B) tools/list returns exactly 3 tools: docs_search, diagnose, list_masters
#   C) tools/call docs_search returns result.content.type=="text" AND valid JSON
#   D) tools/call diagnose returns result.content.type=="text" AND valid JSON
#   E) kill-switch: BRAIN_DISABLE_MCP=true blocks tools/call with MCP_DISABLED
#   F) invalid JSON returns JSON-RPC error, stderr=0 (no PHP warnings)
#   G) unknown tool returns error, stderr=0
#
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/brain-cli.sh"

cd "$PROJECT_ROOT"

function check_stderr_empty() {
    local err_file="$1"
    local bytes=$(wc -c < "$err_file" | tr -d ' ')
    if [[ "$bytes" -ne 0 ]]; then
        echo "FAIL: stderr not empty ($bytes bytes)"
        cat "$err_file" | head -5
        return 1
    fi
    return 0
}

# A) Initialize contract
echo "A) Testing initialize..."
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.jsonrpc == "2.0" and .result.serverInfo.name == "brain-tools"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: initialize missing brain-tools serverInfo"
    cat /tmp/mcp_out.json
    exit 1
fi
echo "  PASS: initialize returns brain-tools"

# B) tools/list contract - exactly 3 tools
echo "B) Testing tools/list..."
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
tool_count=$(jq '.result.tools | length' /tmp/mcp_out.json 2>/dev/null || echo "0")
if [[ "$tool_count" -ne 3 ]]; then
    echo "FAIL: tools/list expected 3 tools, got $tool_count"
    exit 1
fi
tool_names=$(jq -r '.result.tools[].name' /tmp/mcp_out.json | sort | tr '\n' ' ')
expected_names="diagnose docs_search list_masters "
if [[ "$tool_names" != "$expected_names" ]]; then
    echo "FAIL: tools/list names mismatch"
    echo "  Expected: $expected_names"
    echo "  Got: $tool_names"
    exit 1
fi
echo "  PASS: tools/list returns 3 correct tools"

# C) tools/call docs_search contract
echo "C) Testing docs_search..."
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"test","limit":1}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.result.content[0].type == "text"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: docs_search missing content[0].type=text"
    exit 1
fi
if ! jq -r '.result.content[0].text' /tmp/mcp_out.json | jq -e '.total_matches' >/dev/null 2>&1; then
    echo "FAIL: docs_search content[0].text not valid JSON with total_matches"
    exit 1
fi
echo "  PASS: docs_search returns valid JSON"

# D) tools/call diagnose contract
echo "D) Testing diagnose..."
echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.result.content[0].type == "text"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: diagnose missing content.type=text"
    exit 1
fi
if ! jq -r '.result.content[0].text' /tmp/mcp_out.json | jq -e '.self_hosting' >/dev/null 2>&1; then
    echo "FAIL: diagnose content.text not valid JSON with self_hosting"
    exit 1
fi
echo "  PASS: diagnose returns valid JSON"

# E) Kill-switch contract
echo "E) Testing kill-switch..."
echo '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}' | BRAIN_DISABLE_MCP=true BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.data.reason == "MCP_DISABLED"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: kill-switch did not return MCP_DISABLED"
    cat /tmp/mcp_out.json
    exit 1
fi
echo "  PASS: kill-switch blocks with MCP_DISABLED"

# F) Invalid JSON contract (no PHP warnings in stderr)
echo "F) Testing invalid JSON handling..."
echo '{"jsonrpc":"2.0","id":99,"method":"test"' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.code == -32700' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: invalid JSON did not return PARSE_ERROR (-32700)"
    cat /tmp/mcp_out.json
    exit 1
fi
echo "  PASS: invalid JSON returns PARSE_ERROR, stderr=0"

# G) Unknown tool contract
echo "G) Testing unknown tool handling..."
echo '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"nonexistent.tool","arguments":{}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: unknown tool did not return error"
    cat /tmp/mcp_out.json
    exit 1
fi
reason=$(jq -r '.error.data.reason' /tmp/mcp_out.json 2>/dev/null || echo "")
if [[ "$reason" != "INVALID_INPUT" ]]; then
    echo "FAIL: unknown tool error reason expected INVALID_INPUT, got: $reason"
    exit 1
fi
message=$(jq -r '.error.message' /tmp/mcp_out.json 2>/dev/null || echo "")
if [[ "$message" != "Invalid params" ]]; then
    echo "FAIL: unknown tool error message expected 'Invalid params', got: $message"
    exit 1
fi
echo "  PASS: unknown tool returns error, stderr=0"

# H) Stderr hygiene for all tool calls
echo "H) Testing stderr hygiene for all tools..."

# docs_search
echo '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"test","limit":1}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1

# diagnose
echo '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1

# list_masters
echo '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"list_masters","arguments":{}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1

echo "  PASS: all tool calls have stderr=0"

# I) docs_search validate=true passthrough
echo "I) Testing docs_search validate=true passthrough..."
echo '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"docs_search","arguments":{"validate":true}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.result.content[0].type == "text"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: validate=true did not return text response"
    exit 1
fi
# Validate mode returns documents array with valid/invalid counts
validate_text=$(jq -r '.result.content[0].text' /tmp/mcp_out.json 2>/dev/null || echo "")
if ! echo "$validate_text" | jq -e '.summary.valid' >/dev/null 2>&1; then
    echo "FAIL: validate=true response missing summary.valid"
    exit 1
fi
echo "  PASS: docs_search validate=true executes non-search mode"

# J) docs_search cache-health=true passthrough
echo "J) Testing docs_search cache-health=true passthrough..."
echo '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"docs_search","arguments":{"cache-health":true}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.result.content[0].type == "text"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: cache-health=true did not return text response"
    exit 1
fi
echo "  PASS: docs_search cache-health=true executes"

# K) list_masters JSON validity
echo "K) Testing list_masters JSON validity..."
echo '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_masters","arguments":{}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.result.content[0].type == "text"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: list_masters missing content.type=text"
    exit 1
fi
if ! jq -r '.result.content[0].text' /tmp/mcp_out.json | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "FAIL: list_masters content.text not valid JSON object"
    exit 1
fi
echo "  PASS: list_masters returns valid JSON"

# L) missing method field => INVALID_REQUEST
echo "L) Testing missing method field..."
echo '{"jsonrpc":"2.0","id":13}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.code == -32600' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: missing method did not return INVALID_REQUEST (-32600)"
    cat /tmp/mcp_out.json
    exit 1
fi
if ! jq -e '.error.data.reason == "INVALID_REQUEST"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: missing method reason not INVALID_REQUEST"
    exit 1
fi
echo "  PASS: missing method returns INVALID_REQUEST, stderr=0"

# M) unknown method => METHOD_NOT_FOUND
echo "M) Testing unknown method..."
echo '{"jsonrpc":"2.0","id":14,"method":"unknown_method","params":{}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.code == -32601' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: unknown method did not return METHOD_NOT_FOUND (-32601)"
    cat /tmp/mcp_out.json
    exit 1
fi
if ! jq -e '.error.data.reason == "METHOD_NOT_FOUND"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: unknown method reason not METHOD_NOT_FOUND"
    exit 1
fi
message=$(jq -r '.error.message' /tmp/mcp_out.json 2>/dev/null || echo "")
if [[ "$message" != "Method not found" ]]; then
    echo "FAIL: unknown method message expected 'Method not found', got: $message"
    exit 1
fi
echo "  PASS: unknown method returns METHOD_NOT_FOUND, stderr=0"

# N) diagnose unknown arg => INVALID_INPUT
echo "N) Testing diagnose unknown arg..."
echo '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"diagnose","arguments":{"invalid_option":true}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.data.reason == "INVALID_INPUT"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: diagnose unknown arg did not return INVALID_INPUT"
    cat /tmp/mcp_out.json
    exit 1
fi
echo "  PASS: diagnose unknown arg returns INVALID_INPUT, stderr=0"

# O) list_masters agent arg => INVALID_INPUT (agent is server-side, not tool arg)
echo "O) Testing list_masters agent arg (rejected - agent is server-side)..."
echo '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"list_masters","arguments":{"agent":"claude"}}}' | BRAIN_AGENT_ID=claude brain mcp:serve 1>/tmp/mcp_out.json 2>/tmp/mcp_err.txt
check_stderr_empty /tmp/mcp_err.txt || exit 1
if ! jq -e '.error.data.reason == "INVALID_INPUT"' /tmp/mcp_out.json >/dev/null 2>&1; then
    echo "FAIL: list_masters agent arg did not return INVALID_INPUT"
    cat /tmp/mcp_out.json
    exit 1
fi
echo "  PASS: list_masters agent arg returns INVALID_INPUT, stderr=0"

# Cleanup
rm -f /tmp/mcp_out.json /tmp/mcp_err.txt

echo ""
echo "PASS: mcp:serve contract verified (15/15 checks)"
exit 0
