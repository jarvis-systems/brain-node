#!/usr/bin/env bash
#
# Check 50: MCP tools/call Contract
# Validates JSON-RPC 2.0 success and error envelopes at tools/call boundary.
#
# Sub-checks (each must assert stderr=0 + valid JSON):
#   A) docs_search success (query="mcp", limit=1)
#   B) diagnose success
#   C) list_masters success
#   D) kill-switch blocks (error.data.reason == MCP_DISABLED, code == -32001)
#   E) invalid JSON request (code == -32700)
#   F) missing method field (code == -32600)
#   G) unknown tool (code == -32602, reason == INVALID_INPUT)
#   H) unknown arg for diagnose (code == -32602, reason == INVALID_INPUT)
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Helper: call mcp:serve and check stderr + JSON validity
call_mcp() {
    local request="$1"
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        echo "STDERR_NOT_EMPTY:$stderr_bytes"
        return 1
    fi

    if ! echo "$response" | jq empty 2>/dev/null; then
        echo "INVALID_JSON"
        return 1
    fi

    echo "$response"
    return 0
}

# A) docs_search success
check_A() {
    local request='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"mcp","limit":1}}}'
    local response
    response=$(call_mcp "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] docs_search: $response"
        return
    fi

    local content_type
    content_type=$(echo "$response" | jq -r '.result.content[0].type // empty')
    if [[ "$content_type" != "text" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] docs_search: result.content[0].type != text (got: $content_type)"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')
    if ! echo "$text" | jq -e 'type == "object"' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] docs_search: result.content[0].text is not valid JSON object"
        return
    fi
}

# B) diagnose success
check_B() {
    local request='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}'
    local response
    response=$(call_mcp "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] diagnose: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')
    if ! echo "$text" | jq -e 'has("self_hosting")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] diagnose: result.content[0].text missing 'self_hosting' key"
        return
    fi
}

# C) list_masters success
check_C() {
    local request='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_masters","arguments":{}}}'
    local response
    response=$(call_mcp "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] list_masters: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')
    if ! echo "$text" | jq -e 'type == "object"' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] list_masters: result.content[0].text is not valid JSON object"
        return
    fi
}

# D) kill-switch blocks
check_D() {
    local request='{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"test"}}}'
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(BRAIN_DISABLE_MCP=true bash -c "echo '$request' | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>'$stderr_file'")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] kill-switch: stderr not empty ($stderr_bytes bytes)"
        return
    fi

    local reason
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')
    local code
    code=$(echo "$response" | jq -r '.error.code // empty')

    if [[ "$reason" != "MCP_DISABLED" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] kill-switch: reason != MCP_DISABLED (got: $reason)"
        return
    fi

    if [[ "$code" != "-32001" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] kill-switch: code != -32001 (got: $code)"
        return
    fi
}

# E) invalid JSON request
check_E() {
    local request='{"jsonrpc":"2.0","id":99,"method":"test"'
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] invalid JSON: stderr not empty ($stderr_bytes bytes)"
        return
    fi

    local code
    code=$(echo "$response" | jq -r '.error.code // empty')

    if [[ "$code" != "-32700" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] invalid JSON: code != -32700 (got: $code)"
        return
    fi
}

# F) missing method field
check_F() {
    local request='{"jsonrpc":"2.0","id":5,"params":{}}'
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] missing method: stderr not empty ($stderr_bytes bytes)"
        return
    fi

    local code
    code=$(echo "$response" | jq -r '.error.code // empty')

    if [[ "$code" != "-32600" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] missing method: code != -32600 (got: $code)"
        return
    fi
}

# G) unknown tool
check_G() {
    local request='{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}'
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] unknown tool: stderr not empty ($stderr_bytes bytes)"
        return
    fi

    local reason
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')
    local code
    code=$(echo "$response" | jq -r '.error.code // empty')

    if [[ "$reason" != "INVALID_INPUT" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] unknown tool: reason != INVALID_INPUT (got: $reason)"
        return
    fi

    if [[ "$code" != "-32602" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] unknown tool: code != -32602 (got: $code)"
        return
    fi
}

# H) unknown arg for diagnose
check_H() {
    local request='{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"diagnose","arguments":{"x":1}}}'
    local stderr_file
    stderr_file=$(mktemp)
    local response
    response=$(echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown arg: stderr not empty ($stderr_bytes bytes)"
        return
    fi

    local reason
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')
    local code
    code=$(echo "$response" | jq -r '.error.code // empty')

    if [[ "$reason" != "INVALID_INPUT" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown arg: reason != INVALID_INPUT (got: $reason)"
        return
    fi

    if [[ "$code" != "-32602" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown arg: code != -32602 (got: $code)"
        return
    fi
}

# Run all checks
check_A
check_B
check_C
check_D
check_E
check_F
check_G
check_H

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 50: MCP tools/call Contract ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 50: MCP tools/call Contract"
exit 0
