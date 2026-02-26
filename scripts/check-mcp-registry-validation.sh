#!/usr/bin/env bash
#
# Check MCP Registry Validation contract
# Usage: scripts/check-mcp-registry-validation.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# 1. Ensure validator file exists
if [[ ! -f "cli/src/Services/McpRegistryValidator.php" ]]; then
    echo "FAIL: McpRegistryValidator service missing"
    exit 1
fi

# 2. Synthetic invalid case: Create a temporary invalid registry
TMP_REGISTRY=".brain-config/mcp-registry.tmp.json"
BACKUP_REGISTRY=".brain-config/mcp-registry.json.bak"

cleanup() {
    if [[ -f "$BACKUP_REGISTRY" ]]; then
        mv "$BACKUP_REGISTRY" ".brain-config/mcp-registry.json"
    fi
    rm -f "$TMP_REGISTRY"
}

trap cleanup EXIT

if [[ -f ".brain-config/mcp-registry.json" ]]; then
    cp ".brain-config/mcp-registry.json" "$BACKUP_REGISTRY"
fi

# Create an invalid registry (missing class)
cat > ".brain-config/mcp-registry.json" <<'EOF'
{
  "version": "1.0.0",
  "servers": [
    {
      "id": "invalid-server",
      "class": "BrainNode\\Mcp\\NonExistentServer",
      "transport": "stdio",
      "enabled": true
    }
  ]
}
EOF

# Try to run compile (should fail)
# We use a valid agent name to ensure we reach handleBridge
set +e
OUTPUT=$(php cli/bin/brain compile claude 2>&1)
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "FAIL: Compile succeeded with invalid registry entry"
    exit 1
fi

if [[ ! "$OUTPUT" =~ "code=MCP_REGISTRY_INVALID" ]]; then
    echo "FAIL: Expected error code MCP_REGISTRY_INVALID missing in output"
    echo "Actual output: $OUTPUT"
    exit 1
fi

if [[ ! "$OUTPUT" =~ "reason=class_missing" ]]; then
    echo "FAIL: Expected reason class_missing missing in output"
    echo "Actual output: $OUTPUT"
    exit 1
fi

echo "PASS: MCP registry validation verified (fail-fast works)"
exit 0
