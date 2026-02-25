#!/usr/bin/env bash
#
# Check MCP Tool Policy contract
# Usage: scripts/check-mcp-tool-policy.sh
#
# Validates:
#   1. MCP tool allowlist exists and is valid JSON
#   2. All commands in "allowed" exist in CLI inventory
#   3. No forbidden commands appear in "allowed"
#
# Canonical sources (resolution order):
#   1. .brain-config/mcp-tools.allowlist.json (self-hosting override)
#   2. .brain/config/mcp-tools.allowlist.json (consumer override)
#   3. cli/mcp-tools.allowlist.json (CLI default)
#
# Exit codes:
#   0 - All checks pass
#   1 - Policy violations detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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
# Resolution: find policy file (canonical order)
# ─────────────────────────────────────────────────────────────────────────────

resolve_policy_file() {
    # 1. Self-hosting override (real directory, not symlinked)
    if [[ -f "$PROJECT_ROOT/.brain-config/mcp-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/.brain-config/mcp-tools.allowlist.json"
        return 0
    fi
    
    # 2. Consumer override (in .brain/ directory)
    if [[ -f "$PROJECT_ROOT/.brain/config/mcp-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/.brain/config/mcp-tools.allowlist.json"
        return 0
    fi
    
    # 3. CLI default (shipped with package)
    if [[ -f "$PROJECT_ROOT/cli/mcp-tools.allowlist.json" ]]; then
        echo "$PROJECT_ROOT/cli/mcp-tools.allowlist.json"
        return 0
    fi
    
    return 1
}

if ! POLICY_FILE=$(resolve_policy_file); then
    echo -e "${RED}FAIL: No MCP tool policy file found${NC}"
    echo "  Expected one of:"
    echo "    .brain-config/mcp-tools.allowlist.json (self-hosting)"
    echo "    .brain/config/mcp-tools.allowlist.json (consumer)"
    echo "    cli/mcp-tools.allowlist.json (CLI default)"
    echo ""
    echo "  Remediation: CLI install corrupted - reinstall jarvis-brain/cli"
    exit 1
fi

echo -e "${GREEN}INFO: Policy file: $POLICY_FILE${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Validate JSON structure
# ─────────────────────────────────────────────────────────────────────────────

if ! jq -e . "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Invalid JSON in policy file${NC}"
    ((errors++))
fi

if ! jq -e .version "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Missing or invalid 'version' field${NC}"
    ((errors++))
fi

if ! jq -e .allowed "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Missing or invalid 'allowed' field${NC}"
    ((errors++))
fi

if ! jq -e .never "$POLICY_FILE" >/dev/null 2>&1; then
    echo -e "${RED}FAIL: Missing or invalid 'never' field${NC}"
    ((errors++))
fi

if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}INFO: JSON structure valid${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Extract allowed commands
# ─────────────────────────────────────────────────────────────────────────────

allowed_commands=$(jq -r '.allowed[]' "$POLICY_FILE" 2>/dev/null | sort -u | tr '\n' ' ' || true)

if [[ -z "$allowed_commands" ]]; then
    echo -e "${RED}FAIL: No allowed commands defined${NC}"
    ((errors++))
fi

echo -e "${GREEN}INFO: Allowed commands: ${allowed_commands:-none}${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Verify allowed commands exist in CLI
# ─────────────────────────────────────────────────────────────────────────────

cli_signatures=$(grep -rh "\$signature" "$CLI_DIR" --include="*.php" 2>/dev/null | \
    grep -E "signature\s*[.=]" | \
    sed -n "s/.*['\"]\\([a-z][a-z:_]*\\).*/\\1/p" | \
    sort -u | tr '\n' ' ' || true)

# Exempt known MCP tools that are not CLI commands
exempt_mcp_tools=("search" "sequentialThinking" "mock-echo")

for cmd in $allowed_commands; do
    # Skip exemption check
    is_exempt=0
    for exempt in "${exempt_mcp_tools[@]}"; do
        if [[ "$cmd" == "$exempt" ]]; then
            is_exempt=1
            break
        fi
    done

    if [[ $is_exempt -eq 1 ]]; then
        continue
    fi

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
# Check no forbidden commands in allowed
# ─────────────────────────────────────────────────────────────────────────────

forbidden_commands=("compile" "init" "make:" "memory:hygiene" "release:" "update" "add" "detail" "mcp:migrate")

for cmd in $allowed_commands; do
    for forbidden in "${forbidden_commands[@]}"; do
        if [[ "$cmd" == "$forbidden"* ]]; then
            echo -e "${RED}FAIL: Forbidden command '$cmd' found in allowed list${NC}"
            ((errors++))
        fi
    done
done

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}FAIL: $errors MCP tool policy violation${NC}"
    exit 1
fi

echo -e "${GREEN}PASS: MCP tool policy valid${NC}"
exit 0
