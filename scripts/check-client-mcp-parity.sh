#!/usr/bin/env bash
#
# Check 51: Client MCP Parity
# Validates parity between direct CLI and MCP paths for docs/diagnose/list_masters.
#
# Sub-checks (each must assert stderr=0 + valid JSON + key presence):
#   A) diagnose direct: valid JSON + self_hosting key
#   B) diagnose via MCP: valid JSON + self_hosting key
#   C) list_masters direct: valid JSON + non-empty object
#   D) list_masters via MCP: valid JSON + non-empty object
#   E) docs direct: valid JSON + schema_version + files keys
#   F) docs via MCP: valid JSON + schema_version + files keys
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Helper: check stderr is empty and output is valid JSON
check_stderr_and_json() {
    local stderr_file
    stderr_file=$(mktemp)
    local output
    output=$(eval "$1" 2>"$stderr_file")
    local stderr_bytes
    stderr_bytes=$(wc -c < "$stderr_file" | tr -d ' ')
    rm -f "$stderr_file"

    if [[ "$stderr_bytes" -gt 0 ]]; then
        echo "STDERR_NOT_EMPTY:$stderr_bytes"
        return 1
    fi

    if ! echo "$output" | jq empty 2>/dev/null; then
        echo "INVALID_JSON"
        return 1
    fi

    echo "$output"
    return 0
}

# Helper: call MCP via JSON-RPC
call_mcp_tool() {
    local tool_name="$1"
    local args="$2"
    local request="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool_name\",\"arguments\":$args}}"
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

# A) diagnose direct: valid JSON + self_hosting key
check_A() {
    local result
    result=$(check_stderr_and_json "php cli/bin/brain diagnose")

    if [[ "$result" == "STDERR_NOT_EMPTY:"* || "$result" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] diagnose direct: $result"
        return
    fi

    if ! echo "$result" | jq -e 'has("self_hosting")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] diagnose direct: missing 'self_hosting' key"
        return
    fi
}

# B) diagnose via MCP: valid JSON + self_hosting key
check_B() {
    local response
    response=$(call_mcp_tool "diagnose" "{}")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] diagnose MCP: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')

    if ! echo "$text" | jq -e 'has("self_hosting")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] diagnose MCP: missing 'self_hosting' key in result.content.text"
        return
    fi
}

# C) list_masters direct: valid JSON + non-empty object
check_C() {
    local result
    result=$(check_stderr_and_json "php cli/bin/brain list:masters claude --json")

    if [[ "$result" == "STDERR_NOT_EMPTY:"* || "$result" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] list_masters direct: $result"
        return
    fi

    if ! echo "$result" | jq -e 'type == "object" and length > 0' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] list_masters direct: not a non-empty object"
        return
    fi
}

# D) list_masters via MCP: valid JSON + non-empty object
check_D() {
    local response
    response=$(call_mcp_tool "list_masters" "{}")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] list_masters MCP: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')

    if ! echo "$text" | jq -e 'type == "object" and length > 0' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[D] list_masters MCP: not a non-empty object in result.content.text"
        return
    fi
}

# E) docs direct: valid JSON + schema_version + files keys
check_E() {
    local result
    result=$(check_stderr_and_json "php cli/bin/brain docs --limit=1")

    if [[ "$result" == "STDERR_NOT_EMPTY:"* || "$result" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] docs direct: $result"
        return
    fi

    if ! echo "$result" | jq -e 'has("schema_version") and has("files")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] docs direct: missing 'schema_version' or 'files' key"
        return
    fi
}

# F) docs via MCP: valid JSON + schema_version + files keys
check_F() {
    local response
    response=$(call_mcp_tool "docs_search" "{\"query\":\"mcp\",\"limit\":1}")

    if [[ "$response" == "STDERR_NOT_EMPTY:"* || "$response" == "INVALID_JSON" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] docs MCP: $response"
        return
    fi

    local text
    text=$(echo "$response" | jq -r '.result.content[0].text // empty')

    if ! echo "$text" | jq -e 'has("schema_version") and has("files")' >/dev/null 2>&1; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] docs MCP: missing 'schema_version' or 'files' key in result.content.text"
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

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 51: Client MCP Parity ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 51: Client MCP Parity"
exit 0
