#!/usr/bin/env bash
#
# Check MCP Preflight validation + Trace contract
# Usage: scripts/check-mcp-preflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

# 1. Test invalid JSON fail-fast
log_check "invalid JSON fail-fast"
OUTPUT=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{not json}' || true)
if ! echo "$OUTPUT" | grep -q "invalid_json"; then
    echo "FAIL: mcp:call did not catch invalid JSON input"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS: invalid JSON caught"

# 2. Test schema validation failed
log_check "schema validation failed"
# vector-task tool task_get requires task_id (int)
OUTPUT=$(php cli/bin/brain mcp:call --server=vector-task --tool=task_get --input='{"wrong_key":1}' || true)
if ! echo "$OUTPUT" | grep -q "schema_validation_failed"; then
    echo "FAIL: mcp:call did not catch schema validation failure"
    echo "Got: $OUTPUT"
    exit 1
fi
if ! echo "$OUTPUT" | grep -q "Input missing a required property."; then
    echo "FAIL: mcp:call error message did not use generic required property message"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS: schema validation works"

# Reset budget to avoid exhaustion
rm -f memory/mcp-budget.json
rm -f dist/tmp/mcp-budget.json
php cli/bin/brain mcp:budget-reset >/dev/null 2>&1 || true

# 3. Test trace output contract
log_check "trace output contract"
OUTPUT=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --trace)
if ! echo "$OUTPUT" | jq -e '.request_id' >/dev/null; then
    echo "FAIL: mcp:call --trace missing request_id"
    exit 1
fi
if ! echo "$OUTPUT" | jq -e '.redactions_applied' >/dev/null; then
    echo "FAIL: mcp:call --trace missing redactions_applied flag"
    exit 1
fi
echo "  PASS: trace output contract valid"

# 4. Verify trace determinism
log_check "trace determinism"
OUT1=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --trace)
OUT2=$(BRAIN_TEST_MODE=1 php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --trace)
ID1=$(echo "$OUT1" | jq -r '.request_id')
ID2=$(echo "$OUT2" | jq -r '.request_id')
if [[ "$ID1" != "$ID2" ]]; then
    echo "FAIL: request_id is not deterministic"
    exit 1
fi
echo "  PASS: trace deterministic and complete"

echo "PASS: MCP preflight + trace verified"
