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
php cli/bin/brain mcp:call --server=mock-echo --tool=forbidden-tool --input='{"text":"test"}' > output.json || true
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

# 3. Test successful redacted call
log_check "Testing successful redacted call"
php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' > output.json
if ! grep -q '"ok":true' output.json; then
    echo "FAIL: Successful call failed"
    exit 1
fi
if ! grep -q "\[REDACTED\]" output.json; then
    echo "FAIL: Sensitive token was not redacted"
    exit 1
fi
echo "  PASS: Successful call + redaction"

# 4. Verify JSON output stability
log_check "Verifying JSON output stability"
# Sort keys in output and compare
ACTUAL_KEYS=$(jq -r 'keys | join(",")' output.json)
EXPECTED_KEYS="data,ok,server,tool"
if [[ "$ACTUAL_KEYS" != "$EXPECTED_KEYS" ]]; then
    echo "FAIL: JSON output keys are not stable/ordered. Got: $ACTUAL_KEYS"
    exit 1
fi
echo "  PASS: Stable JSON output"

rm output.json
echo "PASS: MCP call bridge v1 verified"

function log_check() {
    echo "Checking: $1..."
}
