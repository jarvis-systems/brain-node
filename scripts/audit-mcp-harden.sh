#!/usr/bin/env bash
#
# Audit hardened MCP calls: budget + retries + normalized errors + contracts + JSON correctness + no leakage
# Usage: scripts/audit-mcp-harden.sh
#
# Uses sequential-thinking for testing (allowed tool: think)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Audit: $1..."
}

function assert_json() {
    if ! echo "$1" | jq empty 2>/dev/null; then
        echo "FAIL: Invalid JSON output."
        echo "Raw: $1"
        exit 1
    fi
}

function assert_single_line_json() {
    local output="$1"
    local name="$2"
    local nl_count=$(echo -n "$output" | wc -l | tr -d ' ')
    if [[ $nl_count -gt 0 ]]; then
        echo "FAIL: $name output contains internal newlines (expected single-line JSON)"
        exit 1
    fi
}

function assert_no_leakage() {
    local output="$1"
    local forbidden_server="${2:-}"
    local forbidden_tool="${3:-}"
    
    local msg=$(echo "$output" | jq -r '.error.message // ""')
    local hint=$(echo "$output" | jq -r '.error.hint // ""')

    if [[ -n "$forbidden_server" ]]; then
        if echo "$msg" | grep -qiE "$forbidden_server"; then
            echo "FAIL: Error message leaks server name: $forbidden_server"
            exit 1
        fi
        if echo "$hint" | grep -qiE "$forbidden_server"; then
            echo "FAIL: Error hint leaks server name: $forbidden_server"
            exit 1
        fi
    fi

    if [[ -n "$forbidden_tool" ]]; then
        if echo "$msg" | grep -qiE "$forbidden_tool"; then
            echo "FAIL: Error message leaks tool name: $forbidden_tool"
            exit 1
        fi
        if echo "$hint" | grep -qiE "$forbidden_tool"; then
            echo "FAIL: Error hint leaks tool name: $forbidden_tool"
            exit 1
        fi
    fi
}

# Ensure clean state
rm -f memory/mcp-budget.json
rm -f dist/tmp/mcp-budget.json

# 1. Test budget enforcement and canonical location
log_check "Budget enforcement and canonical location"
env BRAIN_TEST_MODE=1 BRAIN_MCP_CALL_BUDGET=2 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"t1"}' > out1.json
assert_json "$(cat out1.json)"
if ! grep -q "memory/mcp-budget.json" <(php cli/bin/brain mcp:guardrails); then
    echo "FAIL: Budget file not at canonical location."
    exit 1
fi
echo "  PASS: Budget location and JSON verified."

# 2. Test normalized error contract and redactions_applied + no leakage
log_check "Normalized error contract and no leakage (blocked call)"
SERVER="vector-memory"
TOOL="non-existent-tool-secret"
OUTPUT=$(php cli/bin/brain mcp:call --server="$SERVER" --tool="$TOOL" || true)
assert_json "$OUTPUT"
assert_no_leakage "$OUTPUT" "$SERVER" "$TOOL"

if ! echo "$OUTPUT" | grep -q '"redactions_applied":false'; then
    echo "FAIL: Error output missing redactions_applied:false"
    exit 1
fi
# Hint should be generic
if ! echo "$OUTPUT" | grep -q "brain mcp:describe --server=<server>"; then
    echo "FAIL: Blocked call hint is not generic enough. Expected '--server=<server>'"
    exit 1
fi
echo "  PASS: Error contract, JSON, and strict no-leakage verified."

# 3. Test deterministic ordering (list)
log_check "Deterministic ordering (mcp:list)"
LIST=$(php cli/bin/brain mcp:list)
assert_json "$LIST"
assert_single_line_json "$LIST" "mcp:list"
SERVERS=$(echo "$LIST" | jq -r '.data.servers[].id')
SORTED=$(echo "$SERVERS" | sort)
if [[ "$SERVERS" != "$SORTED" ]]; then
    echo "FAIL: Servers not sorted alphabetically."
    echo "Got: $SERVERS"
    exit 1
fi
echo "  PASS: mcp:list sorted and JSON valid."

# 4. Test --trace and no timestamps
log_check "Trace contract and determinism"
# Regular call
CALL1=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"hello"}')
assert_json "$CALL1"
if echo "$CALL1" | grep -q "request_id"; then
    echo "FAIL: request_id present without --trace"
    exit 1
fi
# Trace call
CALL2=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"hello"}' --trace)
assert_json "$CALL2"
if ! echo "$CALL2" | jq -e '.request_id' >/dev/null; then
    echo "FAIL: request_id missing with --trace"
    exit 1
fi
echo "  PASS: Trace and determinism verified."

# 5. Schema validation failure (preflight)
log_check "Schema validation failure (preflight) no leakage"
SERVER="vector-task"
TOOL="task_get"
OUTPUT=$(php cli/bin/brain mcp:call --server="$SERVER" --tool="$TOOL" --input='{}' || true)
assert_json "$OUTPUT"
assert_no_leakage "$OUTPUT" "$SERVER" "$TOOL"
if ! echo "$OUTPUT" | grep -q "schema_validation_failed"; then
    echo "FAIL: Expected schema_validation_failed reason"
    exit 1
fi
echo "  PASS: Preflight JSON and no-leakage verified."

# 6. Invalid JSON input
log_check "Invalid JSON input"
OUTPUT=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{not-json}' || true)
assert_json "$OUTPUT"
if ! echo "$OUTPUT" | grep -q "invalid_json"; then
    echo "FAIL: Expected invalid_json reason"
    exit 1
fi
echo "  PASS: Invalid input JSON contract verified."

# Cleanup
rm -f out1.json
rm -f memory/mcp-budget.json
rm -f dist/tmp/mcp-budget.json

echo "PASS: MCP strict hardening audit successful."
