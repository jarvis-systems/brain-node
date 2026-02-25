#!/usr/bin/env bash
#
# Check MCP External Tools Policy contract
# Usage: scripts/check-mcp-external-tools-policy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED='' GREEN='' NC=''
fi

errors=0

# 1. Resolve policy file
resolve_policy_file() {
    if [[ -f "$PROJECT_ROOT/.brain-config/mcp-external-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/.brain-config/mcp-external-tools.allowlist.json"
        return 0
    fi
    if [[ -f "$PROJECT_ROOT/.brain/config/mcp-external-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/.brain/config/mcp-external-tools.allowlist.json"
        return 0
    fi
    if [[ -f "$PROJECT_ROOT/cli/mcp-external-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/cli/mcp-external-tools.allowlist.json"
        return 0
    fi
    return 1
}

if ! POLICY_FILE=$(resolve_policy_file); then
    echo -e "${RED}FAIL: No MCP external tools policy file found${NC}"
    exit 1
fi

echo -e "${GREEN}INFO: Policy file: $POLICY_FILE${NC}"

# 2. Validate JSON structure
if ! jq -e . "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Invalid JSON in policy file${NC}"
    ((errors++))
fi

if ! jq -e .schema_version "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Missing or invalid 'schema_version' field${NC}"
    ((errors++))
fi

if ! jq -e .servers "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Missing or invalid 'servers' field${NC}"
    ((errors++))
fi

# 3. Check for obvious misconfigurations (e.g. wildcard in v1)
if jq -r '.servers[].tools_allowed[]' "$POLICY_FILE" 2>/dev/null | grep -q "\*"; then
    echo -e "${RED}FAIL: Wildcards are not supported in tools_allowed v1${NC}"
    ((errors++))
fi

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}FAIL: $errors MCP external tools policy violation${NC}"
    exit 1
fi

echo -e "${GREEN}PASS: MCP external tools policy valid${NC}"
exit 0
