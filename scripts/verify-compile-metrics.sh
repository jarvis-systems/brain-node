#!/usr/bin/env bash
#
# Compile Metrics Verification — Validates compiled artifact sizes and gating
# Usage: scripts/verify-compile-metrics.sh
#
# Compiles both modes, checks line counts, gating keywords, and skills-first artifacts.
# Exit codes:
#   0 - All checks passed
#   1 - Verification failed
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_MD="$PROJECT_ROOT/.claude/CLAUDE.md"
AGENTS_MD="$PROJECT_ROOT/AGENTS.md"
GEMINI_MD="$PROJECT_ROOT/GEMINI.md"
QWEN_MD="$PROJECT_ROOT/QWEN.md"
CODEX_DOC_MAX=32768
CODEX_SKILLS_DIR="$PROJECT_ROOT/.codex/skills"
CLAUDE_SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

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
        ERRORS=$((ERRORS + 1))
    fi
}

check_file() {
    local label="$1"
    local path="$2"

    if [ -f "$path" ]; then
        echo -e "${GREEN}[PASS]${NC} $label"
    else
        echo -e "${RED}[FAIL]${NC} $label (missing: $path)"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "=========================================="
echo "Compile Metrics Verification"
echo "=========================================="
echo ""

# --- Standard/Standard ---
echo -e "${YELLOW}Phase 1: standard/standard${NC}"
STRICT_MODE=standard COGNITIVE_LEVEL=standard php "$PROJECT_ROOT/cli/bin/brain" compile --no-interaction >/dev/null 2>&1

LINES_STD=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
check "standard line count <= 300" 300 "$LINES_STD" "le"

GATED_LEVELS=$(grep -ciE 'Level brain|Level architect|Level specialist|Level tool' "$CLAUDE_MD" 2>/dev/null || true)
check "gated levels absent in standard" 0 "$GATED_LEVELS"

GATED_ERRORS=$(grep -ciE 'Error delegation failed|Error agent timeout|Error invalid response|Error context loss|Error resource exceeded' "$CLAUDE_MD" 2>/dev/null || true)
check "gated errors absent in standard" 0 "$GATED_ERRORS"

GATED_VALIDATION=$(grep -ciE 'Validation semantic|Validation structural|Validation policy|Validation actions' "$CLAUDE_MD" 2>/dev/null || true)
check "gated validation absent in standard" 0 "$GATED_VALIDATION"

ALWAYS_ON=$(grep -ciE 'Delegation-limit|Escalation policy|Exploration delegation' "$CLAUDE_MD" 2>/dev/null || true)
check "always-on content present in standard" 0 "$ALWAYS_ON" "gt"

# Skills-first baseline checks
BANNED_UNCERTAINTY=$(grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|cookbook.*when uncertain|before assuming.*cookbook' "$CLAUDE_MD" 2>/dev/null || true)
check "no uncertainty→cookbook triggers in standard" 0 "$BANNED_UNCERTAINTY"

MIGRATED_RULES_STD=$(grep -ciE 'Cookbook calls ONLY via|Gate 5.*compile-time preset|NOT a runtime uncertainty trigger|Multi-probe-mandatory|Triggered-suggestion|Estimate-required|CompilationSystemKnowledge' "$CLAUDE_MD" 2>/dev/null || true)
check "migrated cookbook/self-dev rules absent from standard baseline" 0 "$MIGRATED_RULES_STD"

EVIDENCE_CONTRACT=$(grep -ciE 'Evidence-contract.*CRITICAL|PLAN-ONLY.*EVIDENCE-ONLY' "$CLAUDE_MD" 2>/dev/null || true)
check "evidence contract rule present in standard" 0 "$EVIDENCE_CONTRACT" "gt"

# Multi-surface brain instruction checks (all clients)
if [ -f "$AGENTS_MD" ]; then
    EC_AGENTS=$(grep -ciE 'Evidence-contract.*CRITICAL' "$AGENTS_MD" 2>/dev/null || true)
    check "evidence contract in AGENTS.md (codex/opencode)" 0 "$EC_AGENTS" "gt"
    AGENTS_BYTES=$(wc -c < "$AGENTS_MD" | tr -d ' ')
    check "AGENTS.md size <= codex doc limit ($CODEX_DOC_MAX)" "$CODEX_DOC_MAX" "$AGENTS_BYTES" "le"
else
    echo -e "${RED}[FAIL]${NC} AGENTS.md missing after compile"; ERRORS=$((ERRORS + 1))
fi

if [ -f "$GEMINI_MD" ]; then
    EC_GEMINI=$(grep -ciE 'Evidence-contract.*CRITICAL' "$GEMINI_MD" 2>/dev/null || true)
    check "evidence contract in GEMINI.md (gemini)" 0 "$EC_GEMINI" "gt"
else
    echo -e "${RED}[FAIL]${NC} GEMINI.md missing after compile"; ERRORS=$((ERRORS + 1))
fi

if [ -f "$QWEN_MD" ]; then
    EC_QWEN=$(grep -ciE 'Evidence-contract.*CRITICAL' "$QWEN_MD" 2>/dev/null || true)
    check "evidence contract in QWEN.md (qwen)" 0 "$EC_QWEN" "gt"
fi

echo ""

# --- Skills-first artifacts ---
echo -e "${YELLOW}Phase 1b: skills-first artifacts${NC}"
check_file "Codex native Brain DSL skill" "$CODEX_SKILLS_DIR/brain-prompt-dsl-generation/SKILL.md"
check_file "Codex native Brain DSL reference" "$CODEX_SKILLS_DIR/brain-prompt-dsl-generation/references/php-api.md"
check_file "Codex native vector-memory skill" "$CODEX_SKILLS_DIR/vector-memory/SKILL.md"
check_file "Claude flat Brain DSL skill" "$CLAUDE_SKILLS_DIR/brain-prompt-dsl-generation.md"
check_file "Claude flat Brain DSL bundled reference" "$CLAUDE_SKILLS_DIR/brain-prompt-dsl-generation/references/php-api.md"
echo ""

# --- Paranoid/Exhaustive ---
echo -e "${YELLOW}Phase 2: paranoid/exhaustive${NC}"
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive php "$PROJECT_ROOT/cli/bin/brain" compile --no-interaction >/dev/null 2>&1

LINES_EXH=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
check "exhaustive line count >= 380" 380 "$LINES_EXH" "ge"
check "exhaustive line count <= 450" 450 "$LINES_EXH" "le"

DEEP_LEVELS=$(grep -ciE 'Level brain|Level architect|Level specialist|Level tool' "$CLAUDE_MD" 2>/dev/null || true)
check "deep authority levels present in exhaustive" 0 "$DEEP_LEVELS" "gt"

DEEP_ERRORS=$(grep -ciE 'Error delegation failed|Error agent timeout' "$CLAUDE_MD" 2>/dev/null || true)
check "deep errors present in exhaustive" 0 "$DEEP_ERRORS" "gt"

DEEP_VALIDATION=$(grep -ciE 'Validation semantic|Validation structural' "$CLAUDE_MD" 2>/dev/null || true)
check "deep validation present in exhaustive" 0 "$DEEP_VALIDATION" "gt"

# Skills-first baseline checks
BANNED_UNCERTAINTY_EXH=$(grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|cookbook.*when uncertain|before assuming.*cookbook' "$CLAUDE_MD" 2>/dev/null || true)
check "no uncertainty→cookbook triggers in exhaustive" 0 "$BANNED_UNCERTAINTY_EXH"

MIGRATED_RULES_EXH=$(grep -ciE 'Cookbook calls ONLY via|Gate 5.*compile-time preset|NOT a runtime uncertainty trigger|Multi-probe-mandatory|Triggered-suggestion|Estimate-required|CompilationSystemKnowledge' "$CLAUDE_MD" 2>/dev/null || true)
check "migrated cookbook/self-dev rules absent from exhaustive baseline" 0 "$MIGRATED_RULES_EXH"

EVIDENCE_CONTRACT_EXH=$(grep -ciE 'Evidence-contract.*CRITICAL|PLAN-ONLY.*EVIDENCE-ONLY' "$CLAUDE_MD" 2>/dev/null || true)
check "evidence contract rule present in exhaustive" 0 "$EVIDENCE_CONTRACT_EXH" "gt"

# Multi-surface brain instruction checks (all clients, exhaustive)
# Note: AGENTS.md size check omitted in exhaustive — Codex uses standard mode only
if [ -f "$AGENTS_MD" ]; then
    EC_AGENTS_EXH=$(grep -ciE 'Evidence-contract.*CRITICAL' "$AGENTS_MD" 2>/dev/null || true)
    check "evidence contract in AGENTS.md (exhaustive)" 0 "$EC_AGENTS_EXH" "gt"
else
    echo -e "${RED}[FAIL]${NC} AGENTS.md missing after exhaustive compile"; ERRORS=$((ERRORS + 1))
fi

if [ -f "$GEMINI_MD" ]; then
    EC_GEMINI_EXH=$(grep -ciE 'Evidence-contract.*CRITICAL' "$GEMINI_MD" 2>/dev/null || true)
    check "evidence contract in GEMINI.md (exhaustive)" 0 "$EC_GEMINI_EXH" "gt"
else
    echo -e "${RED}[FAIL]${NC} GEMINI.md missing after exhaustive compile"; ERRORS=$((ERRORS + 1))
fi

if [ -f "$QWEN_MD" ]; then
    EC_QWEN_EXH=$(grep -ciE 'Evidence-contract.*CRITICAL' "$QWEN_MD" 2>/dev/null || true)
    check "evidence contract in QWEN.md (exhaustive)" 0 "$EC_QWEN_EXH" "gt"
fi

echo ""

# --- Restore ---
echo -e "${YELLOW}Restoring standard/standard${NC}"
STRICT_MODE=standard COGNITIVE_LEVEL=standard php "$PROJECT_ROOT/cli/bin/brain" compile --no-interaction >/dev/null 2>&1

# --- Mandatory anchors across all surfaces ---
echo -e "${YELLOW}Phase 3: Mandatory anchors (all surfaces)${NC}"
SURFACES=("$CLAUDE_MD" "$AGENTS_MD" "$GEMINI_MD" "$QWEN_MD")
SURFACE_NAMES=("CLAUDE.md" "AGENTS.md" "GEMINI.md" "QWEN.md")
ANCHORS=("No-secret-output" "Quality-gates-mandatory" "Compile-single-writer" "Never-write-compiled")

for i in "${!SURFACES[@]}"; do
    sf="${SURFACES[$i]}"
    sn="${SURFACE_NAMES[$i]}"
    if [ ! -f "$sf" ]; then
        echo -e "${RED}[FAIL]${NC} $sn missing"; ERRORS=$((ERRORS + 1))
        continue
    fi
    for anchor in "${ANCHORS[@]}"; do
        count=$(grep -c "$anchor" "$sf" 2>/dev/null || true)
        if [ "$count" -gt 0 ]; then
            echo -e "${GREEN}[PASS]${NC} $sn has $anchor"
        else
            echo -e "${RED}[FAIL]${NC} $sn missing anchor: $anchor"
            ERRORS=$((ERRORS + 1))
        fi
    done
done
echo ""

# --- Dev baseline audit guard ---
echo -e "${YELLOW}Phase 4: Dev audit baseline${NC}"
if bash "$PROJECT_ROOT/scripts/audit-enterprise.sh" >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC} dev audit smoke completed"
else
    echo -e "${YELLOW}[INFO]${NC} dev audit reported issues; compile metrics continue. Run scripts/audit-enterprise.sh for the enterprise audit gate."
fi

echo ""

# --- ENV Override Verification ---
echo -e "${YELLOW}Phase 5: ENV override verification${NC}"
OPENCODE_AGENT="$PROJECT_ROOT/.opencode/agents/web-research-master.md"
TEST_MODEL="zai-coding-plan/test-model-override"

# Compile with injected env override
WEB_RESEARCH_MASTER_MODEL="$TEST_MODEL" php "$PROJECT_ROOT/cli/bin/brain" compile --no-interaction opencode >/dev/null 2>&1

if [ -f "$OPENCODE_AGENT" ]; then
    COMPILED_MODEL=$(grep -E '^model:' "$OPENCODE_AGENT" | head -1 | sed 's/model: *//' | sed 's/\\//g' | tr -d '"' | tr -d "'" || true)
    if [ "$COMPILED_MODEL" = "$TEST_MODEL" ]; then
        echo -e "${GREEN}[PASS]${NC} ENV override works: WEB_RESEARCH_MASTER_MODEL → model in compiled output"
    else
        echo -e "${RED}[FAIL]${NC} ENV override broken: expected '$TEST_MODEL', got '$COMPILED_MODEL'"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} OpenCode agent missing after compile"; ERRORS=$((ERRORS + 1))
fi

# Restore standard compile
STRICT_MODE=standard COGNITIVE_LEVEL=standard php "$PROJECT_ROOT/cli/bin/brain" compile --no-interaction >/dev/null 2>&1

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
