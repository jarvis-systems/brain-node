#!/usr/bin/env bash
#
# Check MCP Call Bridge v1 contract
# Usage: scripts/check-mcp-call.sh
#
# Uses sequential-thinking for testing (allowed tool: think)
# Mock-echo was removed as user-facing MCP junk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

# Reset budget to avoid exhaustion when running repeatedly via audit
# Use BRAIN_TEST_MODE=1 to reset the same path that test calls use
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:budget-reset >/dev/null 2>&1 || true

# 1. Test kill-switch (uses sequential-thinking, any server works)
log_check "Testing kill-switch"
BRAIN_DISABLE_MCP=true php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"test"}' > output.json || true
if ! grep -q "MCP_DISABLED" output.json; then
    echo "FAIL: Kill-switch did not block mcp:call"
    exit 1
fi
echo "  PASS: Kill-switch blocks"

# 2. Test blocked tool (sequential-thinking only allows 'think', so 'forbidden-tool' should be blocked)
log_check "Testing blocked tool"
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=forbidden-tool --input='{"text":"test"}' > output.json || true
if ! grep -q "MCP_CALL_BLOCKED" output.json; then
    echo "FAIL: Forbidden tool was not blocked"
    exit 1
fi
echo "  PASS: Policy blocks forbidden tool"

# 2b. Test blocked server (not in external tools allowlist)
# Use a server that's in registry but with an unauthorized tool
log_check "Testing blocked server/tool combination"
php cli/bin/brain mcp:call --server=sequential-thinking --tool=unauthorized-tool --input='{}' > output.json || true
if ! grep -q "MCP_CALL_BLOCKED" output.json; then
    echo "FAIL: Unauthorized tool on authorized server was not blocked"
    exit 1
fi
echo "  PASS: Policy blocks unauthorized tool on server"

# 3. Test successful call with sequential-thinking
# Note: External MCP servers may not be available in all environments
# If the server returns an error, we still verify the JSON structure
log_check "Testing successful call structure"
EXIT_CODE=0
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"test thought","thoughtNumber":1,"totalThoughts":1,"nextThoughtNeeded":false}' 1>output.json 2>err.txt || EXIT_CODE=$?

# Check stderr hygiene (should always be empty)
if [[ -s err.txt ]]; then
    echo "FAIL: Stderr is not empty (byte-count > 0)"
    cat err.txt
    exit 1
fi

# Check JSON validity (should always be valid JSON)
if ! jq -e . >/dev/null 2>&1 < output.json; then
    echo "FAIL: Output is not valid JSON"
    exit 1
fi

# Check single-line output
LINES=$(wc -l < output.json | tr -d ' ')
if [[ "$LINES" != "0" && "$LINES" != "1" ]]; then
    echo "FAIL: Output is not single-line JSON"
    exit 1
fi

# Check for required keys
if ! grep -q '"ok":' output.json; then
    echo "FAIL: Missing 'ok' key in response"
    exit 1
fi

# Note: External servers may return errors (tool not found, server not running, etc.)
# We verify the JSON structure is correct regardless of the server response
echo "  PASS: Valid JSON structure + empty stderr + single-line output"

# 4. Verify JSON output stability
log_check "Verifying JSON output stability"
# The output should have stable keys regardless of success/error
ACTUAL_KEYS=$(jq -r 'keys | sort | join(",")' output.json)
EXPECTED_KEYS="enabled,kill_switch_env,ok,redactions_applied,server,tool"
# May also have 'data' or 'error' key
if [[ "$ACTUAL_KEYS" != "$EXPECTED_KEYS" ]] && [[ "$ACTUAL_KEYS" != "data,$EXPECTED_KEYS" ]] && [[ "$ACTUAL_KEYS" != "error,$EXPECTED_KEYS" ]] && [[ "$ACTUAL_KEYS" != "data,$EXPECTED_KEYS" ]] && [[ "$ACTUAL_KEYS" != "error,enabled,kill_switch_env,ok,redactions_applied,server,tool" ]]; then
    echo "FAIL: JSON output keys are not stable/ordered. Got: $ACTUAL_KEYS"
    exit 1
fi
echo "  PASS: Stable JSON output"

# 5. Verify default mode stderr hygiene (debug mode requires working server)
log_check "Verifying stderr hygiene"
DEFAULT_OUT=$(mktemp)
DEFAULT_ERR=$(mktemp)
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=sequential-thinking --tool=think --input='{"thought":"test","thoughtNumber":1,"totalThoughts":1,"nextThoughtNeeded":false}' > "$DEFAULT_OUT" 2> "$DEFAULT_ERR" || true
if [[ -s "$DEFAULT_ERR" ]]; then
    echo "FAIL: Default mode leaked to stderr"
    cat "$DEFAULT_ERR"
    exit 1
fi
rm -f "$DEFAULT_OUT" "$DEFAULT_ERR"
echo "  PASS: Default stderr empty"

rm output.json err.txt 2>/dev/null || true
echo "PASS: MCP call bridge v1 verified"
