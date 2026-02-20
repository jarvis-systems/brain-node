#!/bin/bash
#
# Compile Metrics Verification — Validates compiled artifact sizes and gating
# Usage: scripts/verify-compile-metrics.sh
#
# Compiles both modes, checks line counts and gating keywords.
# Exit codes:
#   0 - All checks passed
#   1 - Verification failed
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_MD="$PROJECT_ROOT/.claude/CLAUDE.md"

ERRORS=0

check() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    local op="${4:-eq}"

    local pass=0
    case "$op" in
        eq) [ "$actual" -eq "$expected" ] 2>/dev/null && pass=1 ;;
        gt) [ "$actual" -gt "$expected" ] 2>/dev/null && pass=1 ;;
        lt) [ "$actual" -lt "$expected" ] 2>/dev/null && pass=1 ;;
        le) [ "$actual" -le "$expected" ] 2>/dev/null && pass=1 ;;
        ge) [ "$actual" -ge "$expected" ] 2>/dev/null && pass=1 ;;
    esac

    if [ "$pass" -eq 1 ]; then
        echo -e "${GREEN}[PASS]${NC} $label (actual=$actual)"
    else
        echo -e "${RED}[FAIL]${NC} $label (expected ${op} $expected, actual=$actual)"
        ((ERRORS++))
    fi
}

echo "=========================================="
echo "Compile Metrics Verification"
echo "=========================================="
echo ""

# --- Standard/Standard ---
echo -e "${YELLOW}Phase 1: standard/standard${NC}"
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile >/dev/null 2>&1

LINES_STD=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
check "standard line count <= 400" 400 "$LINES_STD" "le"

GATED_LEVELS=$(grep -ciE 'Level brain|Level architect|Level specialist|Level tool' "$CLAUDE_MD" 2>/dev/null || true)
check "gated levels absent in standard" 0 "$GATED_LEVELS"

GATED_ERRORS=$(grep -ciE 'Error delegation failed|Error agent timeout|Error invalid response|Error context loss|Error resource exceeded' "$CLAUDE_MD" 2>/dev/null || true)
check "gated errors absent in standard" 0 "$GATED_ERRORS"

GATED_VALIDATION=$(grep -ciE 'Validation semantic|Validation structural|Validation policy|Validation actions' "$CLAUDE_MD" 2>/dev/null || true)
check "gated validation absent in standard" 0 "$GATED_VALIDATION"

ALWAYS_ON=$(grep -ciE 'Delegation-limit|Escalation policy|Exploration delegation' "$CLAUDE_MD" 2>/dev/null || true)
check "always-on content present in standard" 0 "$ALWAYS_ON" "gt"

# Cookbook governance checks (must pass in ALL modes)
BANNED_UNCERTAINTY=$(grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|cookbook.*when uncertain|before assuming.*cookbook' "$CLAUDE_MD" 2>/dev/null || true)
check "no uncertainty→cookbook triggers in standard" 0 "$BANNED_UNCERTAINTY"

GOVERNANCE_RULE=$(grep -ciE 'Cookbook calls ONLY via' "$CLAUDE_MD" 2>/dev/null || true)
check "cookbook governance rule present in standard" 0 "$GOVERNANCE_RULE" "gt"

GATE5_REINTERP=$(grep -ciE 'Gate 5.*compile-time preset|NOT a runtime uncertainty trigger' "$CLAUDE_MD" 2>/dev/null || true)
check "gate5 reinterpretation present in standard" 0 "$GATE5_REINTERP" "gt"

echo ""

# --- Paranoid/Exhaustive ---
echo -e "${YELLOW}Phase 2: paranoid/exhaustive${NC}"
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile >/dev/null 2>&1

LINES_EXH=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
check "exhaustive line count >= 700" 700 "$LINES_EXH" "gt"

DEEP_LEVELS=$(grep -ciE 'Level brain|Level architect' "$CLAUDE_MD" 2>/dev/null || true)
check "deep levels present in exhaustive" 0 "$DEEP_LEVELS" "gt"

DEEP_ERRORS=$(grep -ciE 'Error delegation failed|Error agent timeout' "$CLAUDE_MD" 2>/dev/null || true)
check "deep errors present in exhaustive" 0 "$DEEP_ERRORS" "gt"

DEEP_VALIDATION=$(grep -ciE 'Validation semantic|Validation structural' "$CLAUDE_MD" 2>/dev/null || true)
check "deep validation present in exhaustive" 0 "$DEEP_VALIDATION" "gt"

# Cookbook governance checks (must pass in ALL modes)
BANNED_UNCERTAINTY_EXH=$(grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|cookbook.*when uncertain|before assuming.*cookbook' "$CLAUDE_MD" 2>/dev/null || true)
check "no uncertainty→cookbook triggers in exhaustive" 0 "$BANNED_UNCERTAINTY_EXH"

GOVERNANCE_RULE_EXH=$(grep -ciE 'Cookbook calls ONLY via' "$CLAUDE_MD" 2>/dev/null || true)
check "cookbook governance rule present in exhaustive" 0 "$GOVERNANCE_RULE_EXH" "gt"

GATE5_REINTERP_EXH=$(grep -ciE 'Gate 5.*compile-time preset|NOT a runtime uncertainty trigger' "$CLAUDE_MD" 2>/dev/null || true)
check "gate5 reinterpretation present in exhaustive" 0 "$GATE5_REINTERP_EXH" "gt"

echo ""

# --- Restore ---
echo -e "${YELLOW}Restoring standard/standard${NC}"
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile >/dev/null 2>&1

echo ""
echo "=========================================="
echo "Summary: standard=$LINES_STD lines, exhaustive=$LINES_EXH lines, delta=$((LINES_EXH - LINES_STD))"

if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}FAILED: $ERRORS check(s) failed${NC}"
    exit 1
else
    echo -e "${GREEN}PASSED: All checks passed${NC}"
    exit 0
fi
