#!/usr/bin/env bash
#
# Check CLI command signature policy
# Usage: scripts/check-command-contract.sh
#
# Policy:
#   1. All commands MUST be namespaced (contain ":") UNLESS explicitly allowlisted
#   2. Banned signatures: migrate, install, run (too generic)
#   3. Storage paths MUST use lowercase "memory/" not "Memory/"
#
# Exit codes:
#   0 - All checks pass
#   1 - Policy violations detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI_SRC="$PROJECT_ROOT/cli/src/Console"

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
# Check 1: Command signature policy
# ─────────────────────────────────────────────────────────────────────────────

# Allowlisted bare commands (no namespace required)
# These are core Brain commands that are intentionally short
ALLOWLIST=(
    "init"
    "status"
    "compile"
    "docs"
    "diagnose"
    "add"
    "detail"
    "list"
    "update"
    "script"
    "board"
)

# Banned signatures (too generic, must be namespaced)
BANNED=(
    "migrate"
    "install"
    "run"
)

# Extract all signatures from CLI commands
signatures=$(grep -rh "\$signature" "$CLI_SRC" --include="*.php" 2>/dev/null | \
    grep -E "signature\s*[.=]" | \
    sed -n "s/.*['\"]\([a-z][a-z:_]*\).*/\1/p" | \
    sort -u || true)

if [[ -z "$signatures" ]]; then
    echo -e "${YELLOW}WARN: No command signatures found${NC}"
fi

# Check each signature
while IFS= read -r sig; do
    [[ -z "$sig" ]] && continue
    
    # Get bare command name (before any space or {)
    bare_name=$(echo "$sig" | cut -d':' -f1 | cut -d' ' -f1)
    
    # Check if banned
    for banned in "${BANNED[@]}"; do
        if [[ "$bare_name" == "$banned" ]]; then
            echo -e "${RED}FAIL: Banned signature '$bare_name' - must be namespaced (e.g., 'mcp:$bare_name')${NC}"
            ((errors++))
        fi
    done
    
    # Check if namespaced or allowlisted
    if [[ "$sig" != *":"* ]]; then
        allowed=false
        for allow in "${ALLOWLIST[@]}"; do
            if [[ "$bare_name" == "$allow" ]]; then
                allowed=true
                break
            fi
        done
        
        if [[ "$allowed" == false ]]; then
            echo -e "${RED}FAIL: Non-namespaced command '$bare_name' - add to allowlist or namespace it${NC}"
            ((errors++))
        fi
    fi
done <<< "$signatures"

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: Storage path casing (only lowercase memory/ allowed)
# ─────────────────────────────────────────────────────────────────────────────

uppercase_memory=$(grep -rn "'Memory/" "$PROJECT_ROOT/cli/src" --include="*.php" 2>/dev/null | grep -v "test\|Test" || true)
uppercase_memory2=$(grep -rn '"Memory/' "$PROJECT_ROOT/cli/src" --include="*.php" 2>/dev/null | grep -v "test\|Test" || true)

if [[ -n "$uppercase_memory" ]] || [[ -n "$uppercase_memory2" ]]; then
    echo -e "${RED}FAIL: Uppercase 'Memory/' path found - use lowercase 'memory/'${NC}"
    [[ -n "$uppercase_memory" ]] && echo "$uppercase_memory"
    [[ -n "$uppercase_memory2" ]] && echo "$uppercase_memory2"
    ((errors++))
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: No new sqlite db names without updating check-storage-roots.sh
# ─────────────────────────────────────────────────────────────────────────────

# Get expected DB names from check-storage-roots.sh
expected_dbs=$(grep -E "brain\.sqlite|tasks\.db|vector_memory\.db" "$PROJECT_ROOT/scripts/check-storage-roots.sh" 2>/dev/null | head -5 || true)

# Check for any .sqlite or .db references in code that aren't in the expected list
# This is a soft check - just warn

db_refs=$(grep -rn "\.sqlite\|\.db" "$PROJECT_ROOT/cli/src" --include="*.php" 2>/dev/null | \
    grep -v "tasks\.db\|brain\.sqlite\|vector_memory\|memory\.db\|credentials\.sqlite" | \
    grep -v "test\|Test\|vendor" | head -5 || true)

if [[ -n "$db_refs" ]]; then
    echo -e "${YELLOW}WARN: Found DB references that may need audit update:${NC}"
    echo "$db_refs" | while read -r line; do
        echo "  $line"
    done
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}FAIL: $errors command contract violation(s)${NC}"
    exit 1
fi

echo -e "${GREEN}PASS: Command contract policy satisfied${NC}"
exit 0
