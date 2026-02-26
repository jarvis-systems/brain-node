#!/usr/bin/env bash
#
# Brain Benchmark Suite — Formal metrics for compiled artifacts
# Usage: scripts/benchmark-suite.sh [--json]
#
# Metrics: schema-valid %, cookbook pulls, compiled lines, grep-invariants
# No subjective text evaluation. All checks are binary PASS/FAIL.
#
# Exit codes:
#   0 - All scenarios passed
#   1 - One or more scenarios failed
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
CORE_DIR="$PROJECT_ROOT/core"

JSON_MODE=false
[ "${1:-}" = "--json" ] && JSON_MODE=true

TOTAL=0
PASSED=0
FAILED=0
RESULTS=()

check() {
    local id="$1"
    local label="$2"
    local expected="$3"
    local actual="$4"
    local op="${5:-eq}"

    TOTAL=$((TOTAL + 1))
    local pass=0
    case "$op" in
        eq) [ "$actual" -eq "$expected" ] 2>/dev/null && pass=1 ;;
        gt) [ "$actual" -gt "$expected" ] 2>/dev/null && pass=1 ;;
        lt) [ "$actual" -lt "$expected" ] 2>/dev/null && pass=1 ;;
        le) [ "$actual" -le "$expected" ] 2>/dev/null && pass=1 ;;
        ge) [ "$actual" -ge "$expected" ] 2>/dev/null && pass=1 ;;
        ne) [ "$actual" -ne "$expected" ] 2>/dev/null && pass=1 ;;
    esac

    local status="PASS"
    if [ "$pass" -eq 1 ]; then
        PASSED=$((PASSED + 1))
        $JSON_MODE || echo -e "  ${GREEN}[PASS]${NC} $id: $label (actual=$actual)"
    else
        FAILED=$((FAILED + 1))
        status="FAIL"
        $JSON_MODE || echo -e "  ${RED}[FAIL]${NC} $id: $label (expected $op $expected, actual=$actual)"
    fi
    RESULTS+=("{\"id\":\"$id\",\"label\":\"$label\",\"status\":\"$status\",\"expected\":\"$op $expected\",\"actual\":$actual}")
}

# ============================================================
# PHASE 0: Compile standard mode
# ============================================================
$JSON_MODE || echo -e "\n${YELLOW}Phase 0: Compiling standard/standard${NC}"
cd "$PROJECT_ROOT"
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile --no-interaction >/dev/null 2>&1

# ============================================================
# SCENARIO 1: Brain line count budget
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 1: Brain compiled size${NC}"
BRAIN_LINES=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
check "S01a" "CLAUDE.md <= 450 lines" 450 "$BRAIN_LINES" "le"
check "S01b" "CLAUDE.md >= 200 lines (not empty)" 200 "$BRAIN_LINES" "ge"

# ============================================================
# SCENARIO 2: Agent line count budgets
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 2: Agent compiled sizes${NC}"
AGENT_TOTAL=0
for agent_file in "$AGENTS_DIR"/*.md; do
    agent_name=$(basename "$agent_file" .md)
    agent_lines=$(wc -l < "$agent_file" | tr -d ' ')
    AGENT_TOTAL=$((AGENT_TOTAL + agent_lines))
    check "S02-$agent_name" "agent $agent_name <= 400 lines" 400 "$agent_lines" "le"
done
check "S02-total" "agents total <= 1600 lines" 1600 "$AGENT_TOTAL" "le"

# ============================================================
# SCENARIO 3: Grand total budget
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 3: Grand total budget${NC}"
GRAND_TOTAL=$((BRAIN_LINES + AGENT_TOTAL))
check "S03" "grand total <= 2000 lines" 2000 "$GRAND_TOTAL" "le"

# ============================================================
# SCENARIO 4: Cookbook pull count (should be bounded)
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 4: Cookbook pull references${NC}"
COOKBOOK_BRAIN=$(grep -ciE 'cookbook\(' "$CLAUDE_MD" 2>/dev/null || true)
check "S04a" "Brain cookbook refs <= 4" 4 "$COOKBOOK_BRAIN" "le"

for agent_file in "$AGENTS_DIR"/*.md; do
    agent_name=$(basename "$agent_file" .md)
    cookbook_count=$(grep -ciE 'cookbook\(' "$agent_file" 2>/dev/null || true)
    check "S04-$agent_name" "agent $agent_name cookbook refs <= 4" 4 "$cookbook_count" "le"
done

# ============================================================
# SCENARIO 5: No uncertainty→cookbook triggers
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 5: Cookbook governance invariants${NC}"
for f in "$CLAUDE_MD" "$AGENTS_DIR"/*.md; do
    fname=$(basename "$f" .md)
    banned=$(grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|before assuming.*cookbook' "$f" 2>/dev/null || true)
    check "S05-$fname" "no uncertainty triggers in $fname" 0 "$banned"
done

# ============================================================
# SCENARIO 6: Deep-only content absent in standard
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 6: Deep-only content gating (standard)${NC}"
# SequentialReasoning deep phases
SEQ_DEEP=$(grep -ciE 'Decompose task into objectives' "$CLAUDE_MD" 2>/dev/null || true)
check "S06a" "no deep sequential phases in Brain" 0 "$SEQ_DEEP"

# WebResearch deep phases
for agent_file in "$AGENTS_DIR"/*.md; do
    agent_name=$(basename "$agent_file" .md)
    web_deep=$(grep -ciE 'Formulate and execute initial web search' "$agent_file" 2>/dev/null || true)
    if [ "$agent_name" = "web-research-master" ]; then
        check "S06-$agent_name" "no deep web phases in $agent_name" 0 "$web_deep"
    fi
done

# DelegationProtocols deep content
DELEG_DEEP=$(grep -ciE 'Level brain|Level architect|Level specialist' "$CLAUDE_MD" 2>/dev/null || true)
check "S06d" "no deep delegation levels in Brain" 0 "$DELEG_DEEP"

# ============================================================
# SCENARIO 7: Always-on content present
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 7: Always-on content present${NC}"
# Brain operational constraints
ALWAYS_BRAIN=$(grep -ciE 'Delegation-limit|Escalation policy' "$CLAUDE_MD" 2>/dev/null || true)
check "S07a" "operational constraints in Brain" 0 "$ALWAYS_BRAIN" "gt"

# SequentialReasoning compact (in agents, not Brain)
SEQ_COMPACT=0
for agent_file in "$AGENTS_DIR"/*.md; do
    c=$(grep -ciE 'Strict sequential execution' "$agent_file" 2>/dev/null || true)
    SEQ_COMPACT=$((SEQ_COMPACT + c))
done
check "S07b" "compact phase-flow in agents" 0 "$SEQ_COMPACT" "gt"

# Cookbook governance
GOV=$(grep -ciE 'Cookbook calls ONLY via' "$CLAUDE_MD" 2>/dev/null || true)
check "S07c" "cookbook governance in Brain" 0 "$GOV" "gt"

# ============================================================
# SCENARIO 8: MCP syntax - no legacy
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 8: MCP syntax validation${NC}"
LEGACY_COUNT=0
for f in "$CLAUDE_MD" "$AGENTS_DIR"/*.md; do
    legacy=$(grep -cE 'Mcp[A-Z][a-zA-Z]+::call\(' "$f" 2>/dev/null || true)
    LEGACY_COUNT=$((LEGACY_COUNT + legacy))
done
check "S08" "zero legacy MCP syntax" 0 "$LEGACY_COUNT"

# ============================================================
# SCENARIO 9: Iron rules present across all agents
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 9: Iron rules coverage${NC}"
for agent_file in "$AGENTS_DIR"/*.md; do
    agent_name=$(basename "$agent_file" .md)
    iron=$(grep -ciE 'Iron Rules' "$agent_file" 2>/dev/null || true)
    check "S09-$agent_name" "iron rules in $agent_name" 0 "$iron" "gt"
done

# ============================================================
# SCENARIO 10: Schema tests pass
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 10: Schema tests${NC}"
TEST_OUTPUT=$(cd "$CORE_DIR" && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php --no-configuration --bootstrap vendor/autoload.php 2>&1 || true)
TEST_OK=$(echo "$TEST_OUTPUT" | grep -c 'OK' || true)
check "S10" "MCP schema tests pass" 0 "$TEST_OK" "gt"

# ============================================================
# SCENARIO 11: MCP lint pass
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 11: MCP lint${NC}"
LINT_OUTPUT=$(bash "$SCRIPT_DIR/lint-mcp-syntax.sh" 2>&1 || true)
LINT_OK=$(echo "$LINT_OUTPUT" | grep -c 'PASSED' || true)
check "S11" "MCP lint passes" 0 "$LINT_OK" "gt"

# ============================================================
# SCENARIO 12: Compile idempotency
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 12: Compile idempotency${NC}"
# Portable hash: md5 (macOS) or md5sum (Linux)
if command -v md5sum &>/dev/null; then
    HASH_BEFORE=$(md5sum "$CLAUDE_MD" | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
    HASH_BEFORE=$(md5 -q "$CLAUDE_MD")
else
    HASH_BEFORE="no-hash-tool"
fi
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile --no-interaction >/dev/null 2>&1
if command -v md5sum &>/dev/null; then
    HASH_AFTER=$(md5sum "$CLAUDE_MD" | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
    HASH_AFTER=$(md5 -q "$CLAUDE_MD")
else
    HASH_AFTER="no-hash-tool"
fi
IDEM=$( [ "$HASH_BEFORE" = "$HASH_AFTER" ] && echo 1 || echo 0 )
check "S12" "compile is idempotent" 1 "$IDEM"

# ============================================================
# SCENARIO 13: Agent count stable
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 13: Agent count${NC}"
AGENT_COUNT=$(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
check "S13" "agent count = 5" 5 "$AGENT_COUNT"

# ============================================================
# SCENARIO 14: Mode delta (exhaustive > standard)
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 14: Mode delta${NC}"
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile --no-interaction >/dev/null 2>&1
LINES_EXH=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
DELTA=$((LINES_EXH - BRAIN_LINES))
check "S14a" "exhaustive > standard" 0 "$DELTA" "gt"
check "S14b" "delta >= 300 (gating effective)" 300 "$DELTA" "ge"

# Restore standard
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile --no-interaction >/dev/null 2>&1

# ============================================================
# SCENARIO 15: Gate 5 reinterpretation present
# ============================================================
$JSON_MODE || echo -e "\n${CYAN}Scenario 15: Gate 5 reinterpretation${NC}"
GATE5=$(grep -ciE 'NOT a runtime uncertainty trigger' "$CLAUDE_MD" 2>/dev/null || true)
check "S15" "gate5 reinterpretation in Brain" 0 "$GATE5" "gt"

# ============================================================
# SUMMARY
# ============================================================
if $JSON_MODE; then
    echo ""
    echo "{\"total\":$TOTAL,\"passed\":$PASSED,\"failed\":$FAILED,\"pass_rate\":\"$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)%\",\"scenarios\":[$(IFS=,; echo "${RESULTS[*]}")]}"
else
    echo ""
    echo "=========================================="
    RATE=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)
    echo "Benchmark Suite: $PASSED/$TOTAL passed ($RATE%)"
    echo "  Brain: $BRAIN_LINES lines | Agents: $AGENT_TOTAL lines | Grand: $GRAND_TOTAL lines"
    echo "  Standard: $BRAIN_LINES | Exhaustive: $LINES_EXH | Delta: $DELTA"
    echo ""
    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}FAILED: $FAILED scenario(s) failed${NC}"
        exit 1
    else
        echo -e "${GREEN}PASSED: All $TOTAL scenarios passed${NC}"
        exit 0
    fi
fi
