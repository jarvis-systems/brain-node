#!/usr/bin/env bash
#
# Check MCP Tool Policy contract
# Usage: scripts/check-mcp-tool-policy.sh
#
# Validates:
#   1. config/brain/mcp-tools.yaml exists and is valid YAML
#   2. All commands in categories exist in CLI inventory
#   3. No forbidden commands appear in allowed categories
#   4. Never-list doesn't overlap with allowed categories
#
# Exit codes:
#   0 - All checks pass
#   1 - Policy violations detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICY_FILE="$PROJECT_ROOT/config/brain/mcp-tools.yaml"
CLI_DIR="$PROJECT_ROOT/cli/src/Console"

cd "$PROJECT_ROOT"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

errors=0

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: Policy file exists
# ─────────────────────────────────────────────────────────────────────────────

if [[ ! -f "$POLICY_FILE" ]]; then
    echo -e "${RED}FAIL: Policy file not found: $POLICY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}INFO: Policy file exists: $POLICY_FILE${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: Valid YAML structure (basic grep-based validation)
# ─────────────────────────────────────────────────────────────────────────────

# Basic YAML structure check - verify key sections exist with proper indentation
if ! grep -qE "^version:" "$POLICY_FILE"; then
    echo -e "${RED}FAIL: Missing 'version:' at root level${NC}"
    ((errors++))
fi

if ! grep -qE "^categories:" "$POLICY_FILE"; then
    echo -e "${RED}FAIL: Missing 'categories:' at root level${NC}"
    ((errors++))
fi

if ! grep -qE "^clients:" "$POLICY_FILE"; then
    echo -e "${RED}FAIL: Missing 'clients:' at root level${NC}"
    ((errors++))
fi

if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}INFO: YAML structure valid (basic check)${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: Extract allowed commands from policy
# ─────────────────────────────────────────────────────────────────────────────

# Get commands from DEFAULT_READONLY and OPTIONAL_READONLY categories
allowed_commands=$(grep -A 20 "DEFAULT_READONLY:" "$POLICY_FILE" 2>/dev/null | grep -E '^\s+-\s+' | sed 's/.*-\s*//' | tr -d '"' || true)
allowed_commands="$allowed_commands $(grep -A 20 "OPTIONAL_READONLY:" "$POLICY_FILE" 2>/dev/null | grep -E '^\s+-\s+' | sed 's/.*-\s*//' | tr -d '"' || true)"

# Normalize
allowed_commands=$(echo "$allowed_commands" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')

# ─────────────────────────────────────────────────────────────────────────────
# Check 4: Verify never section exists and has content
# ─────────────────────────────────────────────────────────────────────────────

if ! grep -q "reason_by_command:" "$POLICY_FILE"; then
    echo -e "${RED}FAIL: Missing 'reason_by_command:' in never section${NC}"
    ((errors++))
fi

# Count entries in reason_by_command (simple heuristic: lines with colons after reason_by_command)
never_count=$(sed -n '/reason_by_command:/,/^clients:/p' "$POLICY_FILE" 2>/dev/null | \
    grep -cE '^\s+"?[a-z]' || echo "0")

if [[ "$never_count" -lt 5 ]]; then
    echo -e "${YELLOW}WARN: Only $never_count commands in never list (expected 10+)${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 5: Verify allowed commands exist in CLI
# ─────────────────────────────────────────────────────────────────────────────

cli_signatures=$(grep -rh "\$signature" "$CLI_DIR" --include="*.php" 2>/dev/null | \
    grep -E "signature\s*[.=]" | \
    sed -n "s/.*['\"]\([a-z][a-z:_]*\).*/\1/p" | \
    sort -u | tr '\n' ' ' || true)

for cmd in $allowed_commands; do
    # Handle wildcards
    if [[ "$cmd" == *"*"* ]]; then
        prefix=$(echo "$cmd" | cut -d'*' -f1)
        if ! echo "$cli_signatures" | grep -q "$prefix"; then
            echo -e "${RED}FAIL: No CLI commands match wildcard '$cmd'${NC}"
            ((errors++))
        fi
    else
        if ! echo " $cli_signatures " | grep -q " $cmd "; then
            echo -e "${RED}FAIL: Command '$cmd' in policy but not found in CLI${NC}"
            ((errors++))
        fi
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Check 6: No forbidden commands in allowed categories
# ─────────────────────────────────────────────────────────────────────────────

# List of commands that should NEVER be in allowed categories
forbidden_commands=("compile" "init" "make:" "memory:hygiene" "release:" "update" "add" "detail" "mcp:migrate")

for cmd in $allowed_commands; do
    for forbidden in "${forbidden_commands[@]}"; do
        if [[ "$cmd" == "$forbidden"* ]]; then
            echo -e "${RED}FAIL: Forbidden command '$cmd' found in allowed categories${NC}"
            ((errors++))
        fi
    done
done

# ─────────────────────────────────────────────────────────────────────────────
# Check 7: Required structure elements
# ─────────────────────────────────────────────────────────────────────────────

required_elements=("version:" "kill_switch_env:" "categories:" "never:" "clients:")
for elem in "${required_elements[@]}"; do
    if ! grep -q "$elem" "$POLICY_FILE" 2>/dev/null; then
        echo -e "${RED}FAIL: Missing required element '$elem' in policy${NC}"
        ((errors++))
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}FAIL: $errors MCP tool policy violation(s)${NC}"
    exit 1
fi

echo -e "${GREEN}PASS: MCP tool policy valid${NC}"
echo "  Allowed commands: ${allowed_commands:-none}"
echo "  Never-list entries: ${never_count:-?}"
exit 0
