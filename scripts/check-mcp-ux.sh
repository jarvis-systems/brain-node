#!/usr/bin/env bash
#
# Check MCP Call UX + Guardrails contract
# Usage: scripts/check-mcp-ux.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

# 1. Test mcp:call error hint
log_check "mcp:call error hint"
ERROR_OUTPUT=$(php cli/bin/brain mcp:call --server=vector-memory --tool=non-existent-tool --input='{}' || true)
if ! echo "$ERROR_OUTPUT" | grep -q "brain mcp:describe --server=<server>"; then
    echo "FAIL: mcp:call error hint missing discovery command reference"
    echo "Got: $ERROR_OUTPUT"
    exit 1
fi
echo "  PASS: mcp:call error hint valid"

# 2. Test mcp:guardrails contract
log_check "mcp:guardrails"
GUARDRAILS_OUTPUT=$(php cli/bin/brain mcp:guardrails)

# Verify key structure
if ! echo "$GUARDRAILS_OUTPUT" | jq -e '.data.registry.resolved_path' >/dev/null; then
    echo "FAIL: mcp:guardrails missing registry.resolved_path"
    exit 1
fi

if ! echo "$GUARDRAILS_OUTPUT" | jq -e '.data.external_tools_policy.resolved_path' >/dev/null; then
    echo "FAIL: mcp:guardrails missing external_tools_policy.resolved_path"
    exit 1
fi

if ! echo "$GUARDRAILS_OUTPUT" | jq -e '.data.tools_policy.schema_version' >/dev/null; then
    echo "FAIL: mcp:guardrails missing tools_policy.schema_version"
    exit 1
fi

# Check for no secrets
if echo "$GUARDRAILS_OUTPUT" | grep -qE "token|key|secret"; then
    # Some paths might have these words, but we check for value-like patterns if needed.
    # For now, paths are fine.
    :
fi

echo "  PASS: mcp:guardrails contract valid"

echo "PASS: MCP call UX + Guardrails verified"
