#!/usr/bin/env bash
#
# Check MCP Call Bridge v1 contract
# Usage: scripts/check-mcp-call.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

# Reset budget to avoid exhaustion when running repeatedly via audit
php cli/bin/brain mcp:budget-reset >/dev/null 2>&1 || true

# 1. Test kill-switch
log_check "Testing kill-switch"
BRAIN_DISABLE_MCP=true php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"test"}' > output.json || true
if ! grep -q "MCP_DISABLED" output.json; then
    echo "FAIL: Kill-switch did not block mcp:call"
    exit 1
fi
echo "  PASS: Kill-switch blocks"

# 2. Test blocked tool
log_check "Testing blocked tool"
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=forbidden-tool --input='{"text":"test"}' > output.json || true
if ! grep -q "MCP_CALL_BLOCKED" output.json; then
    echo "FAIL: Forbidden tool was not blocked"
    exit 1
fi
echo "  PASS: Policy blocks forbidden tool"

# 2b. Test blocked server (not in external tools allowlist)
# We use sequential-thinking but try to call a tool that isn't allowed
log_check "Testing blocked server/tool combination"
php cli/bin/brain mcp:call --server=sequential-thinking --tool=unauthorized-tool --input='{}' > output.json || true
if ! grep -q "MCP_CALL_BLOCKED" output.json; then
    echo "FAIL: Unauthorized tool on authorized server was not blocked"
    exit 1
fi
echo "  PASS: Policy blocks unauthorized tool on server"

# 3. Test successful redacted call and stderr hygiene
log_check "Testing successful redacted call"
EXIT_CODE=0
BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' 1>output.json 2>err.txt || EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "FAIL: Successful call exited with $EXIT_CODE"
    exit 1
fi
if [[ -s err.txt ]]; then
    echo "FAIL: Stderr is not empty (byte-count > 0)"
    cat err.txt
    exit 1
fi
if ! jq -e . >/dev/null 2>&1 < output.json; then
    echo "FAIL: Output is not valid JSON"
    exit 1
fi
LINES=$(wc -l < output.json | tr -d ' ')
if [[ "$LINES" != "0" && "$LINES" != "1" ]]; then
    echo "FAIL: Output is not single-line JSON"
    exit 1
fi
if ! grep -q '"ok":true' output.json; then
    echo "FAIL: Successful call failed (content)"
    exit 1
fi
if ! grep -q "\[REDACTED\]" output.json; then
    echo "FAIL: Sensitive token was not redacted"
    exit 1
fi
echo "  PASS: Successful call + empty stderr + single-line JSON + redaction"

# 4. Verify JSON output stability
log_check "Verifying JSON output stability"
# Sort keys in output and compare
ACTUAL_KEYS=$(jq -r 'keys | join(",")' output.json)
EXPECTED_KEYS="data,enabled,kill_switch_env,ok,redactions_applied,server,tool"
if [[ "$ACTUAL_KEYS" != "$EXPECTED_KEYS" ]]; then
    echo "FAIL: JSON output keys are not stable/ordered. Got: $ACTUAL_KEYS"
    exit 1
fi
echo "  PASS: Stable JSON output"

# 5. Verify default mode stderr hygiene and debug mode
log_check "Verifying DX-safe debug mode and stderr hygiene"
DEFAULT_OUT=$(mktemp)
DEFAULT_ERR=$(mktemp)
BRAIN_TEST_MODE=1 BRAIN_MCP_DEBUG= BRAIN_MCP_DEBUG_VERBOSE= php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"throw"}' > "$DEFAULT_OUT" 2> "$DEFAULT_ERR" || true
if [[ -s "$DEFAULT_ERR" ]]; then
    echo "FAIL: Default mode leaked to stderr"
    cat "$DEFAULT_ERR"
    exit 1
fi
if grep -q '"debug":' "$DEFAULT_OUT"; then
    echo "FAIL: Default mode leaked debug keys"
    exit 1
fi
DEBUG_OUT=$(mktemp)
BRAIN_TEST_MODE=1 BRAIN_MCP_DEBUG=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"throw"}' > "$DEBUG_OUT" 2> /dev/null || true
if ! grep -q '"debug":' "$DEBUG_OUT"; then
    echo "FAIL: Debug mode missing debug keys"
    exit 1
fi
rm -f "$DEFAULT_OUT" "$DEFAULT_ERR" "$DEBUG_OUT"
echo "  PASS: Default stderr empty, debug keys isolated to debug mode"

rm output.json
echo "PASS: MCP call bridge v1 verified"

function log_check() {
    echo "Checking: $1..."
}
