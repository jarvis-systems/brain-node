#!/usr/bin/env bash
#
# Check MCP Registry contract
# Usage: scripts/check-mcp-registry.sh
#
# Validates:
#   1. MCP registry exists and is valid JSON
#   2. IDs are unique
#   3. Servers are sorted by id ASC
#   4. All classes exist (optional, if possible)
#
# Canonical sources (resolution order):
#   1. .brain-config/mcp-registry.json (self-hosting override)
#   2. .brain/config/mcp-registry.json (consumer override)
#   3. cli/mcp-registry.json (CLI default)

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

resolve_registry_file() {
    if [[ -f "$PROJECT_ROOT/.brain-config/mcp-registry.json" ]]; then
        echo "$PROJECT_ROOT/.brain-config/mcp-registry.json"
        return 0
    fi
    if [[ -f "$PROJECT_ROOT/.brain/config/mcp-registry.json" ]]; then
        echo "$PROJECT_ROOT/.brain/config/mcp-registry.json"
        return 0
    fi
    if [[ -f "$PROJECT_ROOT/cli/mcp-registry.json" ]]; then
        echo "$PROJECT_ROOT/cli/mcp-registry.json"
        return 0
    fi
    return 1
}

if ! REGISTRY_FILE=$(resolve_registry_file); then
    echo -e "${RED}FAIL: No MCP registry file found${NC}"
    exit 1
fi

echo -e "${GREEN}INFO: Registry file: $REGISTRY_FILE${NC}"

if ! jq -e . "$REGISTRY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Invalid JSON in registry file${NC}"
    exit 1
fi

# Check version
if ! jq -e '.version == "1.0.0"' "$REGISTRY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Unsupported or missing version in registry${NC}"
    ((errors++))
fi

# Check unique IDs
ids=$(jq -r '.servers[].id' "$REGISTRY_FILE")
dup_ids=$(echo "$ids" | sort | uniq -d)
if [[ -n "$dup_ids" ]]; then
    echo -e "${RED}FAIL: Duplicate server IDs found: $dup_ids${NC}"
    ((errors++))
fi

# Check deterministic sorting
sorted_ids=$(echo "$ids" | sort)
if [[ "$ids" != "$sorted_ids" ]]; then
    echo -e "${RED}FAIL: Servers are not sorted by ID ASC in registry${NC}"
    ((errors++))
fi

if [[ $errors -gt 0 ]]; then
    exit 1
fi

echo -e "${GREEN}PASS: MCP registry valid${NC}"
exit 0
