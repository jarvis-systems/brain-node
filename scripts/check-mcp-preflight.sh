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
OUTPUT=$(php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{not json}' --json || true)
if ! echo "$OUTPUT" | grep -q "invalid_json"; then
    echo "FAIL: mcp:call did not catch invalid JSON input"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS: invalid JSON caught"

# 2. Test schema validation failed
log_check "schema validation failed"
# vector-task tool task_get requires task_id (int)
OUTPUT=$(php cli/bin/brain mcp:call --server=vector-task --tool=task_get --input='{"wrong_key":1}' --json || true)
if ! echo "$OUTPUT" | grep -q "schema_validation_failed"; then
    echo "FAIL: mcp:call did not catch schema validation failure"
    echo "Got: $OUTPUT"
    exit 1
fi
if ! echo "$OUTPUT" | grep -q "Missing required property: task_id"; then
    echo "FAIL: mcp:call error message did not specify missing property"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS: schema validation works"

# 3. Test trace output contract
log_check "trace output contract"
OUTPUT=$(php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --json --trace)
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
OUT1=$(php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --json --trace)
OUT2=$(php cli/bin/brain mcp:call --server=mock-echo --tool=mock-echo --input='{"text":"hello"}' --json --trace)
ID1=$(echo "$OUT1" | jq -r '.request_id')
ID2=$(echo "$OUT2" | jq -r '.request_id')
if [[ "$ID1" != "$ID2" ]]; then
    echo "FAIL: request_id is not deterministic"
    exit 1
fi
echo "  PASS: trace deterministic and complete"

echo "PASS: MCP preflight + trace verified"
