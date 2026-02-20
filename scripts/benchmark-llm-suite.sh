#!/bin/bash
#
# Brain LLM Benchmark Suite — Behavioral benchmarks via Brain CLI
# Usage: scripts/benchmark-llm-suite.sh [options]
#
# Tests that compiled Brain/agents respond correctly to structured prompts:
# - Knowledge verification (iron rules, delegation, directories)
# - MCP format compliance (correct tool call syntax)
# - Governance reasoning (precedence, violations, cookbook policy)
#
# All checks are grep-based on response text. No subjective evaluation.
#
# Options:
#   --json                  Output JSON report only
#   --mode standard|exhaustive   Compilation mode (default: standard)
#   --profile ci|full       ci=L1+L2 only, full=all (default: full)
#   --scenario <id>         Run single scenario by ID
#   --model <name>          Override AI model (default: sonnet)
#   --dry-run               Validate scenarios without AI calls
#   --timeout <seconds>     Per-scenario timeout (default: 120)
#   --yolo                  Pass --yolo to Brain CLI (bypass permissions)
#
# Exit codes:
#   0 - All scenarios passed
#   1 - One or more scenarios failed
#   2 - Setup/dependency error
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCENARIOS_DIR="$PROJECT_ROOT/.docs/benchmarks/scenarios"
AI_CMD="$PROJECT_ROOT/cli/bin/ai"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT

# Defaults
JSON_MODE=false
MODE="standard"
COGNITIVE="standard"
PROFILE="full"
SINGLE_SCENARIO=""
MODEL="sonnet"
DRY_RUN=false
TIMEOUT=120
YOLO=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --mode)
            MODE="$2"
            case "$MODE" in
                standard) COGNITIVE="standard" ;;
                exhaustive) COGNITIVE="exhaustive" ;;
                paranoid) COGNITIVE="exhaustive" ;;
                *) echo "Unknown mode: $MODE" >&2; exit 2 ;;
            esac
            shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --scenario) SINGLE_SCENARIO="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --yolo) YOLO=true; shift ;;
        -h|--help)
            head -30 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# Dependency checks
check_deps() {
    local ok=true
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required. Install: brew install jq" >&2
        ok=false
    fi
    if [ ! -x "$AI_CMD" ]; then
        echo "ERROR: Brain CLI not found at $AI_CMD" >&2
        ok=false
    fi
    if [ ! -d "$SCENARIOS_DIR" ]; then
        echo "ERROR: Scenarios directory not found: $SCENARIOS_DIR" >&2
        ok=false
    fi
    $ok || exit 2
}

# Counters
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_DURATION_MS=0
RESULTS=()

# Global banned patterns (applied to ALL scenarios in ALL modes)
GLOBAL_BANNED=(
    "when uncertain"
    "Trigger.*Uncertainty"
    "before assuming.*cookbook"
)

log() { $JSON_MODE || echo -e "$@"; }

# ============================================================
# Parse JSONL output from Brain CLI --json mode
# Writes: response text → $1, token metrics → $2
# ============================================================
parse_cli_output() {
    local raw_file="$1"
    local msg_file="$2"
    local metrics_file="$3"

    > "$msg_file"
    echo "0 0" > "$metrics_file"

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local dtype
        dtype=$(echo "$line" | jq -r '.type // ""' 2>/dev/null) || continue
        case "$dtype" in
            message)
                echo "$line" | jq -r '.content // ""' 2>/dev/null >> "$msg_file"
                ;;
            result)
                local it ot
                it=$(echo "$line" | jq -r '.inputTokens // 0' 2>/dev/null)
                ot=$(echo "$line" | jq -r '.outputTokens // 0' 2>/dev/null)
                echo "$it $ot" > "$metrics_file"
                ;;
        esac
    done < "$raw_file"
}

# ============================================================
# Check: pattern count in file (case-insensitive)
# Returns: match count
# ============================================================
count_pattern() {
    local file="$1"
    local pattern="$2"
    grep -ciE "$pattern" "$file" 2>/dev/null || echo "0"
}

# ============================================================
# Run a single scenario
# ============================================================
run_scenario() {
    local scenario_file="$1"

    local sid stitle sdiff sprompt smax_out stimeout
    sid=$(jq -r '.id' "$scenario_file")
    stitle=$(jq -r '.title' "$scenario_file")
    sdiff=$(jq -r '.difficulty' "$scenario_file")
    sprompt=$(jq -r '.prompt' "$scenario_file")
    smax_out=$(jq -r '.max_output_tokens // 2000' "$scenario_file")
    stimeout=$(jq -r '.timeout_s // '"$TIMEOUT"'' "$scenario_file")

    log "\n${CYAN}[$sid] $stitle${NC} ${DIM}($sdiff)${NC}"
    ((TOTAL++))

    local scenario_status="PASS"
    local checks=()
    local response_text=""
    local input_tokens=0
    local output_tokens=0
    local duration_ms=0

    if $DRY_RUN; then
        log "  ${DIM}[DRY-RUN] Scenario validated, AI call skipped${NC}"
        # Validate scenario JSON structure
        local valid=true
        for field in id title difficulty prompt; do
            if [ "$(jq -r ".$field // empty" "$scenario_file")" = "" ]; then
                log "  ${RED}[ERROR] Missing required field: $field${NC}"
                valid=false
            fi
        done
        if $valid; then
            checks+=("{\"check\":\"schema-valid\",\"status\":\"PASS\"}")
            log "  ${GREEN}[PASS] scenario schema valid${NC}"
        else
            checks+=("{\"check\":\"schema-valid\",\"status\":\"FAIL\"}")
            scenario_status="FAIL"
        fi
    else
        # Build CLI command
        local cli_args=(claude --ask "$sprompt" --json --model "$MODEL")
        $YOLO && cli_args+=(--yolo)

        # Run Brain CLI
        local start_ns
        start_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")

        local raw_file="$TMP_DIR/raw_${sid}.jsonl"
        cd "$PROJECT_ROOT"
        STRICT_MODE="$MODE" COGNITIVE_LEVEL="$COGNITIVE" \
            timeout "$stimeout" "$AI_CMD" "${cli_args[@]}" > "$raw_file" 2>/dev/null || true

        local end_ns
        end_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")
        duration_ms=$(( (end_ns - start_ns) / 1000000 ))

        # Parse output
        local msg_file="$TMP_DIR/msg_${sid}.txt"
        local metrics_file="$TMP_DIR/metrics_${sid}.txt"
        parse_cli_output "$raw_file" "$msg_file" "$metrics_file"

        response_text=$(cat "$msg_file" 2>/dev/null || echo "")
        read -r input_tokens output_tokens < "$metrics_file" 2>/dev/null || true
        input_tokens=${input_tokens:-0}
        output_tokens=${output_tokens:-0}

        # Check: response received
        if [ -z "$response_text" ] || [ "$response_text" = "null" ]; then
            log "  ${RED}[ERROR] No response received${NC}"
            scenario_status="ERROR"
            ((ERRORS++))
            checks+=("{\"check\":\"response-received\",\"status\":\"FAIL\",\"detail\":\"empty response\"}")
        else
            checks+=("{\"check\":\"response-received\",\"status\":\"PASS\"}")
        fi

        # Check: global banned patterns
        for pattern in "${GLOBAL_BANNED[@]}"; do
            local cnt
            cnt=$(count_pattern "$msg_file" "$pattern")
            local pname
            pname=$(echo "$pattern" | sed 's/\\.*//; s/ /-/g' | head -c 30)
            if [ "$cnt" -gt 0 ]; then
                checks+=("{\"check\":\"global-banned:$pname\",\"status\":\"FAIL\",\"detail\":\"$cnt matches\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] global-banned: '$pname' found $cnt times${NC}"
            else
                checks+=("{\"check\":\"global-banned:$pname\",\"status\":\"PASS\"}")
            fi
        done

        # Check: scenario-specific required patterns
        while IFS= read -r pattern; do
            [ -z "$pattern" ] && continue
            local cnt
            cnt=$(count_pattern "$msg_file" "$pattern")
            local pname
            pname=$(echo "$pattern" | sed 's/\\.*//; s/|.*//; s/ /-/g' | head -c 30)
            if [ "$cnt" -gt 0 ]; then
                checks+=("{\"check\":\"required:$pname\",\"status\":\"PASS\",\"detail\":\"$cnt matches\"}")
                log "  ${GREEN}[PASS] required: '$pname' found${NC}"
            else
                checks+=("{\"check\":\"required:$pname\",\"status\":\"FAIL\",\"detail\":\"not found\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] required: '$pname' not found in response${NC}"
            fi
        done < <(jq -r '.checks.required_patterns // [] | .[]' "$scenario_file" 2>/dev/null)

        # Check: scenario-specific banned patterns
        while IFS= read -r pattern; do
            [ -z "$pattern" ] && continue
            local cnt
            cnt=$(count_pattern "$msg_file" "$pattern")
            local pname
            pname=$(echo "$pattern" | sed 's/\\.*//; s/|.*//; s/ /-/g' | head -c 30)
            if [ "$cnt" -gt 0 ]; then
                checks+=("{\"check\":\"banned:$pname\",\"status\":\"FAIL\",\"detail\":\"$cnt matches\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] banned: '$pname' found $cnt times${NC}"
            else
                checks+=("{\"check\":\"banned:$pname\",\"status\":\"PASS\"}")
                log "  ${GREEN}[PASS] banned: '$pname' absent${NC}"
            fi
        done < <(jq -r '.checks.banned_patterns // [] | .[]' "$scenario_file" 2>/dev/null)

        # Check: output token budget
        if [ "$output_tokens" -gt 0 ] && [ "$output_tokens" -gt "$smax_out" ] 2>/dev/null; then
            checks+=("{\"check\":\"token-budget\",\"status\":\"FAIL\",\"detail\":\"$output_tokens > $smax_out\"}")
            scenario_status="FAIL"
            log "  ${RED}[FAIL] token-budget: $output_tokens > $smax_out${NC}"
        else
            checks+=("{\"check\":\"token-budget\",\"status\":\"PASS\",\"detail\":\"$output_tokens <= $smax_out\"}")
            log "  ${GREEN}[PASS] token-budget: $output_tokens <= $smax_out${NC}"
        fi

        # Check: mode leakage (standard mode only)
        if [ "$MODE" = "standard" ]; then
            local leakage_patterns=("Decompose task into objectives" "Level brain|Level architect" "Formulate and execute initial web search")
            for lp in "${leakage_patterns[@]}"; do
                local lcnt
                lcnt=$(count_pattern "$msg_file" "$lp")
                if [ "$lcnt" -gt 0 ]; then
                    local lpname
                    lpname=$(echo "$lp" | sed 's/|.*//; s/ /-/g' | head -c 25)
                    checks+=("{\"check\":\"mode-leakage:$lpname\",\"status\":\"FAIL\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] mode-leakage: '$lpname' found${NC}"
                fi
            done
        fi

        log "  ${DIM}tokens: in=$input_tokens out=$output_tokens | ${#response_text} chars | ${duration_ms}ms${NC}"
    fi

    # Update counters
    case "$scenario_status" in
        PASS) ((PASSED++)) ;;
        FAIL) ((FAILED++)) ;;
        ERROR) ;; # already counted
    esac

    TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + input_tokens))
    TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + output_tokens))
    TOTAL_DURATION_MS=$((TOTAL_DURATION_MS + duration_ms))

    # Record result JSON
    local checks_json=""
    if [ ${#checks[@]} -gt 0 ]; then
        checks_json=$(IFS=,; echo "${checks[*]}")
    fi
    local rchars=${#response_text}
    RESULTS+=("{\"id\":\"$sid\",\"title\":\"$stitle\",\"difficulty\":\"$sdiff\",\"status\":\"$scenario_status\",\"duration_ms\":$duration_ms,\"input_tokens\":$input_tokens,\"output_tokens\":$output_tokens,\"response_chars\":$rchars,\"checks\":[$checks_json]}")
}

# ============================================================
# MAIN
# ============================================================
main() {
    check_deps

    log "\n${YELLOW}Brain LLM Benchmark Suite${NC}"
    log "${DIM}Mode: $MODE/$COGNITIVE | Profile: $PROFILE | Model: $MODEL${NC}"
    if $DRY_RUN; then
        log "${DIM}DRY-RUN: validating scenarios only${NC}"
    fi
    log ""

    # Collect scenario files
    local scenarios=()
    if [ -n "$SINGLE_SCENARIO" ]; then
        local found
        found=$(find "$SCENARIOS_DIR" -name "*${SINGLE_SCENARIO}*" -type f 2>/dev/null | head -1)
        if [ -z "$found" ]; then
            echo "Scenario '$SINGLE_SCENARIO' not found in $SCENARIOS_DIR" >&2
            exit 2
        fi
        scenarios+=("$found")
    else
        for sf in "$SCENARIOS_DIR"/*.json; do
            [ -f "$sf" ] || continue
            # Profile filter: ci skips L3
            if [ "$PROFILE" = "ci" ]; then
                local diff
                diff=$(jq -r '.difficulty' "$sf" 2>/dev/null)
                [ "$diff" = "L3" ] && continue
            fi
            scenarios+=("$sf")
        done
    fi

    if [ ${#scenarios[@]} -eq 0 ]; then
        echo "No scenarios found in $SCENARIOS_DIR" >&2
        exit 2
    fi

    log "Running ${#scenarios[@]} scenario(s)...\n"

    # Sort by filename (L1 before L2 before L3)
    IFS=$'\n' scenarios=($(sort <<< "${scenarios[*]}")); unset IFS

    for sf in "${scenarios[@]}"; do
        run_scenario "$sf"
    done

    # Report
    if $JSON_MODE; then
        local results_json=""
        if [ ${#RESULTS[@]} -gt 0 ]; then
            results_json=$(IFS=,; echo "${RESULTS[*]}")
        fi
        local rate="0.0"
        [ "$TOTAL" -gt 0 ] && rate=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)
        cat <<EOF
{"total":$TOTAL,"passed":$PASSED,"failed":$FAILED,"errors":$ERRORS,"pass_rate":"${rate}%","mode":"$MODE","cognitive":"$COGNITIVE","profile":"$PROFILE","model":"$MODEL","dry_run":$DRY_RUN,"total_input_tokens":$TOTAL_INPUT_TOKENS,"total_output_tokens":$TOTAL_OUTPUT_TOKENS,"total_duration_ms":$TOTAL_DURATION_MS,"scenarios":[$results_json]}
EOF
    else
        echo ""
        echo "=========================================="
        local rate="0.0"
        [ "$TOTAL" -gt 0 ] && rate=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)
        echo "LLM Benchmark: $PASSED/$TOTAL passed ($rate%)"
        echo "  Mode: $MODE/$COGNITIVE | Model: $MODEL | Profile: $PROFILE"
        echo "  Tokens: in=$TOTAL_INPUT_TOKENS out=$TOTAL_OUTPUT_TOKENS"
        echo "  Duration: ${TOTAL_DURATION_MS}ms"
        echo ""
        if [ "$FAILED" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
            echo -e "${RED}FAILED: $FAILED failed, $ERRORS errors${NC}"
            exit 1
        else
            echo -e "${GREEN}PASSED: All $TOTAL scenarios passed${NC}"
        fi
    fi
}

main
