#!/usr/bin/env bash
#
# Check 53: MCP Serve JSON-RPC Framing Contract
# Validates exactly 1 JSON-RPC response per request, stdout-only, stderr=0.
#
# Sub-checks:
#   A) initialize → exactly 1 JSON object, stderr=0
#   B) tools/list → exactly 1 JSON object, stderr=0
#   C) tools/call docs_search → exactly 1 JSON object, stderr=0
#   D) tools/call diagnose → exactly 1 JSON object, stderr=0
#   E) kill-switch (BRAIN_DISABLE_MCP=true) → error.code=-32001 AND error.data.reason=="MCP_DISABLED", stderr=0
#   F) invalid JSON input → error.code=-32700 AND error.message=="Parse error", stderr=0
#   G) missing method → error.code=-32600 AND error.message=="Invalid Request", stderr=0
#   H) unknown method → error.code=-32601 AND error.message=="Method not found", stderr=0
#   I) unknown tool name → error.code=-32602 AND error.data.reason=="INVALID_INPUT", stderr=0
#   J) unknown arg for diagnose → error.code=-32602 AND error.data.reason=="INVALID_INPUT", stderr=0
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Helper: call mcp:serve, capture stdout/stderr, verify framing
call_and_verify() {
    local request="$1"
    local stderr_file
    stderr_file=$(mktemp)
    local stdout_file
    stdout_file=$(mktemp)

    echo "$request" | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve >"$stdout_file" 2>"$stderr_file"

    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')

    # Check stderr is empty
    if [[ "$stderr_bytes" -gt 0 ]]; then
        local stderr_content
        stderr_content=$(cat "$stderr_file")
        rm -f "$stderr_file" "$stdout_file"
        echo "STDERR_NOT_EMPTY:$stderr_bytes:$stderr_content"
        return 1
    fi

    # Check exactly 1 line
    local line_count
    line_count=$(wc -l < "$stdout_file" | tr -d ' ')

    if [[ "$line_count" -ne 1 ]]; then
        rm -f "$stderr_file" "$stdout_file"
        echo "MULTIPLE_LINES:$line_count"
        return 1
    fi

    # Check valid JSON
    local response
    response=$(cat "$stdout_file")
    if ! echo "$response" | jq empty 2>/dev/null; then
        rm -f "$stderr_file" "$stdout_file"
        echo "INVALID_JSON"
        return 1
    fi

    # Check exactly 1 JSON-RPC object (starts with {"jsonrpc")
    local jsonrpc_count
    jsonrpc_count=$(echo "$response" | grep -c '{"jsonrpc"' || true)
    if [[ "$jsonrpc_count" -ne 1 ]]; then
        rm -f "$stderr_file" "$stdout_file"
        echo "MULTIPLE_JSONRPC:$jsonrpc_count"
        return 1
    fi

    rm -f "$stderr_file" "$stdout_file"
    echo "$response"
    return 0
}

# A) initialize → exactly 1 JSON object, stderr=0
check_A() {
    local request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "MULTIPLE_LINES:"* || "$response" == "INVALID_JSON" || "$response" == "MULTIPLE_JSONRPC:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] initialize: $response"
        return
    fi

    local protocol_version
    protocol_version=$(echo "$response" | jq -r '.result.protocolVersion // empty')
    if [[ "$protocol_version" != "2024-11-05" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] initialize: wrong protocolVersion (got: $protocol_version)"
    fi
}

# B) tools/list → exactly 1 JSON object, stderr=0
check_B() {
    local request='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "MULTIPLE_LINES:"* || "$response" == "INVALID_JSON" || "$response" == "MULTIPLE_JSONRPC:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] tools/list: $response"
        return
    fi

    local tool_count
    tool_count=$(echo "$response" | jq '.result.tools | length')
    if [[ "$tool_count" != "3" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] tools/list: wrong tool count (expected 3, got: $tool_count)"
    fi
}

# C) tools/call docs_search → exactly 1 JSON object, stderr=0
check_C() {
    local request='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"mcp","limit":1}}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "MULTIPLE_LINES:"* || "$response" == "INVALID_JSON" || "$response" == "MULTIPLE_JSONRPC:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] docs_search: $response"
        return
    fi

    local content_type
    content_type=$(echo "$response" | jq -r '.result.content[0].type // empty')
    if [[ "$content_type" != "text" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] docs_search: wrong content.type (got: $content_type)"
    fi
}

# D) tools/call diagnose → exactly 1 JSON object, stderr=0
check_D() {
    local request='{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "MULTIPLE_LINES:"* || "$response" == "INVALID_JSON" || "$response" == "MULTIPLE_JSONRPC:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] diagnose: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')
    if ! echo "$text" | jq -e 'has("self_hosting")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] diagnose: missing self_hosting in result.content[0].text"
    fi
}

# E) kill-switch → error.code=-32001 AND error.data.reason=="MCP_DISABLED", stderr=0
check_E() {
    local request='{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}'
    local stderr_file
    stderr_file=$(mktemp)
    local stdout_file
    stdout_file=$(mktemp)

    BRAIN_DISABLE_MCP=true bash -c "echo '$request' | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve" >"$stdout_file" 2>"$stderr_file"

    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')

    if [[ "$stderr_bytes" -gt 0 ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] kill-switch: stderr not empty ($stderr_bytes bytes)"
        rm -f "$stderr_file" "$stdout_file"
        return
    fi

    local response
    response=$(cat "$stdout_file")
    rm -f "$stderr_file" "$stdout_file"

    local code reason
    code=$(echo "$response" | jq -r '.error.code // empty')
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')

    if [[ "$code" != "-32001" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] kill-switch: error.code != -32001 (got: $code)"
    fi

    if [[ "$reason" != "MCP_DISABLED" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] kill-switch: error.data.reason != MCP_DISABLED (got: $reason)"
    fi
}

# F) invalid JSON input → error.code=-32700 AND error.message=="Parse error", stderr=0
check_F() {
    local request='{"jsonrpc":"2.0","id":99,"method":"test"'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] invalid JSON: stderr not empty"
        return
    fi

    if [[ "$response" == "MULTIPLE_LINES:"* || "$response" == "INVALID_JSON" || "$response" == "MULTIPLE_JSONRPC:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] invalid JSON: $response"
        return
    fi

    local code message
    code=$(echo "$response" | jq -r '.error.code // empty')
    message=$(echo "$response" | jq -r '.error.message // empty')

    if [[ "$code" != "-32700" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] invalid JSON: error.code != -32700 (got: $code)"
    fi

    if [[ "$message" != "Parse error" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] invalid JSON: error.message != 'Parse error' (got: $message)"
    fi
}

# G) missing method → error.code=-32600 AND error.message=="Invalid Request", stderr=0
check_G() {
    local request='{"jsonrpc":"2.0","id":6,"params":{}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] missing method: stderr not empty"
        return
    fi

    local code message
    code=$(echo "$response" | jq -r '.error.code // empty')
    message=$(echo "$response" | jq -r '.error.message // empty')

    if [[ "$code" != "-32600" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] missing method: error.code != -32600 (got: $code)"
    fi

    if [[ "$message" != "Invalid Request" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] missing method: error.message != 'Invalid Request' (got: $message)"
    fi
}

# H) unknown method → error.code=-32601 AND error.message=="Method not found", stderr=0
check_H() {
    local request='{"jsonrpc":"2.0","id":7,"method":"unknown/method","params":{}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown method: stderr not empty"
        return
    fi

    local code message
    code=$(echo "$response" | jq -r '.error.code // empty')
    message=$(echo "$response" | jq -r '.error.message // empty')

    if [[ "$code" != "-32601" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown method: error.code != -32601 (got: $code)"
    fi

    if [[ "$message" != "Method not found" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] unknown method: error.message != 'Method not found' (got: $message)"
    fi
}

# I) unknown tool name → error.code=-32602 AND error.data.reason=="INVALID_INPUT", stderr=0
check_I() {
    local request='{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[I] unknown tool: stderr not empty"
        return
    fi

    local code reason
    code=$(echo "$response" | jq -r '.error.code // empty')
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')

    if [[ "$code" != "-32602" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[I] unknown tool: error.code != -32602 (got: $code)"
    fi

    if [[ "$reason" != "INVALID_INPUT" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[I] unknown tool: error.data.reason != INVALID_INPUT (got: $reason)"
    fi
}

# J) unknown arg for diagnose → error.code=-32602 AND error.data.reason=="INVALID_INPUT", stderr=0
check_J() {
    local request='{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"diagnose","arguments":{"x":1}}}'
    local response
    response=$(call_and_verify "$request")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[J] unknown arg: stderr not empty"
        return
    fi

    local code reason
    code=$(echo "$response" | jq -r '.error.code // empty')
    reason=$(echo "$response" | jq -r '.error.data.reason // empty')

    if [[ "$code" != "-32602" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[J] unknown arg: error.code != -32602 (got: $code)"
    fi

    if [[ "$reason" != "INVALID_INPUT" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[J] unknown arg: error.data.reason != INVALID_INPUT (got: $reason)"
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
check_I
check_J

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 53: MCP Serve Framing Contract ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 53: MCP Serve Framing Contract"
exit 0
