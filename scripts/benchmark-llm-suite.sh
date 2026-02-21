#!/usr/bin/env bash
#
# Brain LLM Benchmark Suite — Behavioral benchmarks via Brain CLI
# Usage: scripts/benchmark-llm-suite.sh [options]
#
# Tests that compiled Brain/agents respond correctly to structured prompts:
# - Knowledge verification (iron rules, delegation, directories)
# - MCP format compliance (correct tool call syntax)
# - Governance reasoning (precedence, violations, cookbook policy)
# - Multi-turn sessions with session resume (--resume)
# - Telemetry-based tool verification (expected_tools)
#
# Checks: grep-based on response text + ToolUse DTO telemetry. No subjective evaluation.
#
# Options:
#   --json                  Output JSON report only
#   --mode standard|exhaustive   Compilation mode (default: standard)
#   --profile <name>        smoke|ci|telemetry-ci|full|adversarial-matrix (default: full)
#   --scenario <id>         Run single scenario by ID
#   --model <name>          Override AI model (default: sonnet)
#   --dry-run               Validate scenarios without AI calls
#   --timeout <seconds>     Per-scenario timeout (default: 120)
#   --yolo                  Pass --yolo to Brain CLI (bypass permissions)
#   --matrix                Run matrix stress harness (4 configs × stress subset)
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

# Model tier hierarchy for min_model_tier gating
model_tier() {
    case "$1" in
        haiku) echo 1 ;;
        sonnet) echo 2 ;;
        opus) echo 3 ;;
        *) echo 0 ;;
    esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCENARIOS_DIR="$PROJECT_ROOT/.docs/benchmarks/scenarios"
BASELINES_FILE="$PROJECT_ROOT/.docs/benchmarks/baselines/baselines.json"
TMP_DIR=$(mktemp -d)

# macOS-compatible timeout wrapper
if command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
else
    # Pure bash fallback: run command with background kill after N seconds
    _timeout_fallback() {
        local secs="$1"; shift
        "$@" &
        local pid=$!
        ( sleep "$secs" && kill -TERM "$pid" 2>/dev/null ) &
        local watchdog=$!
        wait "$pid" 2>/dev/null
        local rc=$?
        kill -TERM "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
        return $rc
    }
    TIMEOUT_CMD="_timeout_fallback"
fi

# CLI path resolution: env → local → global
if [ -n "${BRAIN_AI_CMD:-}" ]; then
    AI_CMD="$BRAIN_AI_CMD"
elif [ -x "$PROJECT_ROOT/cli/bin/ai" ]; then
    AI_CMD="$PROJECT_ROOT/cli/bin/ai"
elif command -v ai &>/dev/null; then
    AI_CMD="ai"
else
    AI_CMD=""
fi

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
MATRIX=false

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
        --matrix) MATRIX=true; shift ;;
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
    if [ -z "$AI_CMD" ]; then
        echo "ERROR: Brain CLI not found. Set BRAIN_AI_CMD, place cli/bin/ai locally, or install 'ai' globally." >&2
        ok=false
    elif [ ! -x "$AI_CMD" ] && ! command -v "$AI_CMD" &>/dev/null; then
        echo "ERROR: Brain CLI not executable: $AI_CMD" >&2
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
SKIPPED=0
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_DURATION_MS=0
TOTAL_MCP_CALLS=0
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
    local tools_file="$4"
    local session_file="${5:-/dev/null}"

    > "$msg_file"
    echo "0 0" > "$metrics_file"
    > "$tools_file"

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local dtype
        dtype=$(echo "$line" | jq -r '.type // ""' 2>/dev/null) || continue
        case "$dtype" in
            init)
                echo "$line" | jq -r '.sessionId // ""' 2>/dev/null > "$session_file"
                ;;
            message)
                echo "$line" | jq -r '.content // ""' 2>/dev/null >> "$msg_file"
                ;;
            tool_use)
                local tname
                tname=$(echo "$line" | jq -r '.name // ""' 2>/dev/null)
                echo "$tname" >> "$tools_file"
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
    local result
    result=$(grep -ciE "$pattern" "$file" 2>/dev/null) || result=0
    echo "$result"
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
    local mcp_calls=0

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

        # Export env vars for CLI subprocess
        export STRICT_MODE="$MODE" COGNITIVE_LEVEL="$COGNITIVE"
        [ -n "${BRAIN_CLI_DEBUG:-}" ] && export BRAIN_CLI_DEBUG

        # Run Brain CLI
        local start_ns
        start_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")

        local raw_file="$TMP_DIR/raw_${sid}.jsonl"
        local err_file="$TMP_DIR/err_${sid}.log"
        cd "$PROJECT_ROOT"
        $TIMEOUT_CMD "$stimeout" "$AI_CMD" "${cli_args[@]}" > "$raw_file" 2>"$err_file" || true

        local end_ns
        end_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")
        duration_ms=$(( (end_ns - start_ns) / 1000000 ))

        # Parse output
        local msg_file="$TMP_DIR/msg_${sid}.txt"
        local metrics_file="$TMP_DIR/metrics_${sid}.txt"
        local tools_file="$TMP_DIR/tools_${sid}.txt"
        parse_cli_output "$raw_file" "$msg_file" "$metrics_file" "$tools_file"

        response_text=$(cat "$msg_file" 2>/dev/null || echo "")
        read -r input_tokens output_tokens < "$metrics_file" 2>/dev/null || true
        input_tokens=${input_tokens:-0}
        output_tokens=${output_tokens:-0}
        mcp_calls=$(wc -l < "$tools_file" 2>/dev/null | tr -d ' ')
        mcp_calls=${mcp_calls:-0}

        # Check: response received
        if [ -z "$response_text" ] || [ "$response_text" = "null" ]; then
            log "  ${RED}[ERROR] No response received${NC}"
            scenario_status="ERROR"
            ((ERRORS++))
            checks+=("{\"check\":\"response-received\",\"status\":\"FAIL\",\"detail\":\"empty response\"}")
        else
            checks+=("{\"check\":\"response-received\",\"status\":\"PASS\"}")
        fi

        # Check: DTO schema (init + message + result present)
        local has_init has_message has_result
        has_init=$(grep -c '"type":"init"' "$raw_file" 2>/dev/null) || has_init=0
        has_message=$(grep -c '"type":"message"' "$raw_file" 2>/dev/null) || has_message=0
        has_result=$(grep -c '"type":"result"' "$raw_file" 2>/dev/null) || has_result=0
        if [ "$has_init" -gt 0 ] && [ "$has_message" -gt 0 ] && [ "$has_result" -gt 0 ]; then
            checks+=("{\"check\":\"dto-schema\",\"status\":\"PASS\",\"detail\":\"init=$has_init msg=$has_message result=$has_result\"}")
            log "  ${GREEN}[PASS] dto-schema: init=$has_init msg=$has_message result=$has_result${NC}"
        else
            checks+=("{\"check\":\"dto-schema\",\"status\":\"FAIL\",\"detail\":\"init=$has_init msg=$has_message result=$has_result\"}")
            scenario_status="FAIL"
            log "  ${RED}[FAIL] dto-schema: init=$has_init msg=$has_message result=$has_result (all 3 required)${NC}"
        fi

        # Check: duration within timeout
        local timeout_ms=$((stimeout * 1000))
        if [ "$duration_ms" -le "$timeout_ms" ]; then
            checks+=("{\"check\":\"duration\",\"status\":\"PASS\",\"detail\":\"${duration_ms}ms <= ${timeout_ms}ms\"}")
            log "  ${GREEN}[PASS] duration: ${duration_ms}ms <= ${timeout_ms}ms${NC}"
        else
            checks+=("{\"check\":\"duration\",\"status\":\"FAIL\",\"detail\":\"${duration_ms}ms > ${timeout_ms}ms\"}")
            scenario_status="FAIL"
            log "  ${RED}[FAIL] duration: ${duration_ms}ms > ${timeout_ms}ms${NC}"
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

        # Check: expected MCP calls range (if specified in scenario)
        local mcp_min mcp_max
        mcp_min=$(jq -r '.checks.expected_mcp_calls.min // empty' "$scenario_file" 2>/dev/null)
        mcp_max=$(jq -r '.checks.expected_mcp_calls.max // empty' "$scenario_file" 2>/dev/null)
        if [ -n "$mcp_min" ] && [ -n "$mcp_max" ]; then
            if [ "$mcp_calls" -ge "$mcp_min" ] && [ "$mcp_calls" -le "$mcp_max" ]; then
                checks+=("{\"check\":\"mcp-calls-range\",\"status\":\"PASS\",\"detail\":\"$mcp_calls in [$mcp_min..$mcp_max]\"}")
                log "  ${GREEN}[PASS] mcp-calls-range: $mcp_calls in [$mcp_min..$mcp_max]${NC}"
            else
                checks+=("{\"check\":\"mcp-calls-range\",\"status\":\"FAIL\",\"detail\":\"$mcp_calls not in [$mcp_min..$mcp_max]\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] mcp-calls-range: $mcp_calls not in [$mcp_min..$mcp_max]${NC}"
            fi
        fi

        # Check: expected specific tools in tool_use events (telemetry-based)
        while IFS= read -r tool_name; do
            [ -z "$tool_name" ] && continue
            if grep -qF "$tool_name" "$tools_file" 2>/dev/null; then
                checks+=("{\"check\":\"expected-tool:$tool_name\",\"status\":\"PASS\"}")
                log "  ${GREEN}[PASS] expected-tool: '$tool_name'${NC}"
            else
                checks+=("{\"check\":\"expected-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"not in tool_use events\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] expected-tool: '$tool_name' not in tool_use${NC}"
            fi
        done < <(jq -r '.checks.expected_tools // [] | .[]' "$scenario_file" 2>/dev/null)

        # Check: banned specific tools — MUST NOT appear in tool_use events
        while IFS= read -r tool_name; do
            [ -z "$tool_name" ] && continue
            if grep -qF "$tool_name" "$tools_file" 2>/dev/null; then
                checks+=("{\"check\":\"banned-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"found in tool_use events\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] banned-tool: '$tool_name' found in tool_use${NC}"
            else
                checks+=("{\"check\":\"banned-tool:$tool_name\",\"status\":\"PASS\"}")
                log "  ${GREEN}[PASS] banned-tool: '$tool_name' absent${NC}"
            fi
        done < <(jq -r '.checks.banned_tools // [] | .[]' "$scenario_file" 2>/dev/null)

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

        log "  ${DIM}tokens: in=$input_tokens out=$output_tokens | mcp=$mcp_calls | ${#response_text} chars | ${duration_ms}ms${NC}"
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
    TOTAL_MCP_CALLS=$((TOTAL_MCP_CALLS + mcp_calls))

    # Record result JSON
    local checks_json=""
    if [ ${#checks[@]} -gt 0 ]; then
        checks_json=$(IFS=,; echo "${checks[*]}")
    fi
    local rchars=${#response_text}
    RESULTS+=("{\"id\":\"$sid\",\"title\":\"$stitle\",\"difficulty\":\"$sdiff\",\"status\":\"$scenario_status\",\"executed_model\":\"$MODEL\",\"duration_ms\":$duration_ms,\"input_tokens\":$input_tokens,\"output_tokens\":$output_tokens,\"mcp_calls_count\":$mcp_calls,\"response_chars\":$rchars,\"checks\":[$checks_json]}")
}

# ============================================================
# Run a multi-turn scenario (type: "multi")
# ============================================================
run_multi_turn_scenario() {
    local scenario_file="$1"

    local sid stitle sdiff smax_out stimeout num_turns
    sid=$(jq -r '.id' "$scenario_file")
    stitle=$(jq -r '.title' "$scenario_file")
    sdiff=$(jq -r '.difficulty' "$scenario_file")
    smax_out=$(jq -r '.max_output_tokens // 3000' "$scenario_file")
    stimeout=$(jq -r '.timeout_s // '"$TIMEOUT"'' "$scenario_file")
    num_turns=$(jq -r '.turns | length' "$scenario_file")

    log "\n${CYAN}[$sid] $stitle${NC} ${DIM}($sdiff, ${num_turns} turns)${NC}"
    ((TOTAL++))

    local scenario_status="PASS"
    local checks=()
    local total_response=""
    local total_input_tokens=0
    local total_output_tokens=0
    local total_mcp_calls=0
    local session_id=""

    if $DRY_RUN; then
        log "  ${DIM}[DRY-RUN] Multi-turn scenario validated, AI calls skipped${NC}"
        local valid=true
        for field in id title difficulty; do
            if [ "$(jq -r ".$field // empty" "$scenario_file")" = "" ]; then
                log "  ${RED}[ERROR] Missing required field: $field${NC}"
                valid=false
            fi
        done
        if [ "$num_turns" -lt 2 ]; then
            log "  ${RED}[ERROR] Multi-turn requires >= 2 turns, got $num_turns${NC}"
            valid=false
        fi
        local t=0
        while [ "$t" -lt "$num_turns" ]; do
            local ask
            ask=$(jq -r ".turns[$t].ask // empty" "$scenario_file")
            if [ -z "$ask" ]; then
                log "  ${RED}[ERROR] Turn $t missing 'ask' field${NC}"
                valid=false
            fi
            ((t++))
        done
        if $valid; then
            checks+=("{\"check\":\"schema-valid\",\"status\":\"PASS\"}")
            log "  ${GREEN}[PASS] multi-turn schema valid ($num_turns turns)${NC}"
        else
            checks+=("{\"check\":\"schema-valid\",\"status\":\"FAIL\"}")
            scenario_status="FAIL"
        fi
    else
        local start_ns
        start_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")

        local t=0
        while [ "$t" -lt "$num_turns" ]; do
            local ask
            ask=$(jq -r ".turns[$t].ask" "$scenario_file")
            local turn_label="turn$((t+1))"

            log "  ${DIM}--- $turn_label ---${NC}"

            # Build CLI command
            local cli_args=(claude --ask "$ask" --json --model "$MODEL")
            if [ "$t" -gt 0 ] && [ -n "$session_id" ]; then
                cli_args=(claude --resume "$session_id" --ask "$ask" --json --model "$MODEL")
            fi
            $YOLO && cli_args+=(--yolo)

            export STRICT_MODE="$MODE" COGNITIVE_LEVEL="$COGNITIVE"
            [ -n "${BRAIN_CLI_DEBUG:-}" ] && export BRAIN_CLI_DEBUG

            local raw_file="$TMP_DIR/raw_${sid}_t${t}.jsonl"
            local err_file="$TMP_DIR/err_${sid}_t${t}.log"
            local session_file="$TMP_DIR/session_${sid}.txt"
            cd "$PROJECT_ROOT"
            $TIMEOUT_CMD "$stimeout" "$AI_CMD" "${cli_args[@]}" > "$raw_file" 2>"$err_file" || true

            # Parse output
            local msg_file="$TMP_DIR/msg_${sid}_t${t}.txt"
            local metrics_file="$TMP_DIR/metrics_${sid}_t${t}.txt"
            local tools_file="$TMP_DIR/tools_${sid}_t${t}.txt"
            parse_cli_output "$raw_file" "$msg_file" "$metrics_file" "$tools_file" "$session_file"

            local turn_text
            turn_text=$(cat "$msg_file" 2>/dev/null || echo "")
            local turn_in turn_out
            read -r turn_in turn_out < "$metrics_file" 2>/dev/null || true
            turn_in=${turn_in:-0}
            turn_out=${turn_out:-0}
            local turn_mcp
            turn_mcp=$(wc -l < "$tools_file" 2>/dev/null | tr -d ' ')
            turn_mcp=${turn_mcp:-0}

            total_response+="$turn_text"
            total_input_tokens=$((total_input_tokens + turn_in))
            total_output_tokens=$((total_output_tokens + turn_out))
            total_mcp_calls=$((total_mcp_calls + turn_mcp))

            # Extract session_id from first turn
            if [ "$t" -eq 0 ]; then
                session_id=$(cat "$session_file" 2>/dev/null | tr -d '[:space:]')
                if [ -z "$session_id" ]; then
                    log "  ${RED}[ERROR] No sessionId in init DTO${NC}"
                    scenario_status="ERROR"
                    ((ERRORS++))
                    checks+=("{\"check\":\"session-init\",\"status\":\"FAIL\"}")
                    break
                fi
                checks+=("{\"check\":\"session-init\",\"status\":\"PASS\",\"detail\":\"${session_id:0:8}...\"}")
                log "  ${GREEN}[PASS] session-init: ${session_id:0:8}...${NC}"
            fi

            # Check: turn response received
            if [ -z "$turn_text" ] || [ "$turn_text" = "null" ]; then
                checks+=("{\"check\":\"${turn_label}:response\",\"status\":\"FAIL\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] $turn_label: empty response${NC}"
            else
                checks+=("{\"check\":\"${turn_label}:response\",\"status\":\"PASS\"}")
            fi

            # Check: per-turn required patterns
            while IFS= read -r pattern; do
                [ -z "$pattern" ] && continue
                local cnt
                cnt=$(count_pattern "$msg_file" "$pattern")
                local pname
                pname=$(echo "$pattern" | sed 's/\\.*//; s/|.*//; s/ /-/g' | head -c 30)
                if [ "$cnt" -gt 0 ]; then
                    checks+=("{\"check\":\"${turn_label}:required:$pname\",\"status\":\"PASS\",\"detail\":\"$cnt matches\"}")
                    log "  ${GREEN}[PASS] $turn_label required: '$pname'${NC}"
                else
                    checks+=("{\"check\":\"${turn_label}:required:$pname\",\"status\":\"FAIL\",\"detail\":\"not found\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] $turn_label required: '$pname' not found${NC}"
                fi
            done < <(jq -r ".turns[$t].checks.required_patterns // [] | .[]" "$scenario_file" 2>/dev/null)

            # Check: per-turn banned patterns
            while IFS= read -r pattern; do
                [ -z "$pattern" ] && continue
                local cnt
                cnt=$(count_pattern "$msg_file" "$pattern")
                local pname
                pname=$(echo "$pattern" | sed 's/\\.*//; s/|.*//; s/ /-/g' | head -c 30)
                if [ "$cnt" -gt 0 ]; then
                    checks+=("{\"check\":\"${turn_label}:banned:$pname\",\"status\":\"FAIL\",\"detail\":\"$cnt matches\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] $turn_label banned: '$pname' found${NC}"
                else
                    checks+=("{\"check\":\"${turn_label}:banned:$pname\",\"status\":\"PASS\"}")
                fi
            done < <(jq -r ".turns[$t].checks.banned_patterns // [] | .[]" "$scenario_file" 2>/dev/null)

            # Check: per-turn expected_mcp_calls
            local tmcp_min tmcp_max
            tmcp_min=$(jq -r ".turns[$t].checks.expected_mcp_calls.min // empty" "$scenario_file" 2>/dev/null)
            tmcp_max=$(jq -r ".turns[$t].checks.expected_mcp_calls.max // empty" "$scenario_file" 2>/dev/null)
            if [ -n "$tmcp_min" ] && [ -n "$tmcp_max" ]; then
                if [ "$turn_mcp" -ge "$tmcp_min" ] && [ "$turn_mcp" -le "$tmcp_max" ]; then
                    checks+=("{\"check\":\"${turn_label}:mcp-range\",\"status\":\"PASS\",\"detail\":\"$turn_mcp in [$tmcp_min..$tmcp_max]\"}")
                    log "  ${GREEN}[PASS] $turn_label mcp-range: $turn_mcp in [$tmcp_min..$tmcp_max]${NC}"
                else
                    checks+=("{\"check\":\"${turn_label}:mcp-range\",\"status\":\"FAIL\",\"detail\":\"$turn_mcp not in [$tmcp_min..$tmcp_max]\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] $turn_label mcp-range: $turn_mcp not in [$tmcp_min..$tmcp_max]${NC}"
                fi
            fi

            # Check: per-turn expected_tools
            while IFS= read -r tool_name; do
                [ -z "$tool_name" ] && continue
                if grep -qF "$tool_name" "$tools_file" 2>/dev/null; then
                    checks+=("{\"check\":\"${turn_label}:expected-tool:$tool_name\",\"status\":\"PASS\"}")
                    log "  ${GREEN}[PASS] $turn_label expected-tool: '$tool_name'${NC}"
                else
                    checks+=("{\"check\":\"${turn_label}:expected-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"not in tool_use events\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] $turn_label expected-tool: '$tool_name' not in tool_use${NC}"
                fi
            done < <(jq -r ".turns[$t].checks.expected_tools // [] | .[]" "$scenario_file" 2>/dev/null)

            # Check: per-turn banned_tools — MUST NOT appear in tool_use events
            while IFS= read -r tool_name; do
                [ -z "$tool_name" ] && continue
                if grep -qF "$tool_name" "$tools_file" 2>/dev/null; then
                    checks+=("{\"check\":\"${turn_label}:banned-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"found in tool_use events\"}")
                    scenario_status="FAIL"
                    log "  ${RED}[FAIL] $turn_label banned-tool: '$tool_name' found in tool_use${NC}"
                else
                    checks+=("{\"check\":\"${turn_label}:banned-tool:$tool_name\",\"status\":\"PASS\"}")
                    log "  ${GREEN}[PASS] $turn_label banned-tool: '$tool_name' absent${NC}"
                fi
            done < <(jq -r ".turns[$t].checks.banned_tools // [] | .[]" "$scenario_file" 2>/dev/null)

            log "  ${DIM}$turn_label: tokens in=$turn_in out=$turn_out | mcp=$turn_mcp | ${#turn_text} chars${NC}"

            ((t++))
        done

        local end_ns
        end_ns=$(date +%s%N 2>/dev/null || echo "$(($(date +%s) * 1000000000))")
        local duration_ms=$(( (end_ns - start_ns) / 1000000 ))

        # Scenario-level checks: global banned
        local all_msg_file="$TMP_DIR/msg_${sid}_all.txt"
        > "$all_msg_file"
        local i=0
        while [ "$i" -lt "$num_turns" ]; do
            cat "$TMP_DIR/msg_${sid}_t${i}.txt" >> "$all_msg_file" 2>/dev/null
            ((i++))
        done

        for pattern in "${GLOBAL_BANNED[@]}"; do
            local cnt
            cnt=$(count_pattern "$all_msg_file" "$pattern")
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

        # Scenario-level banned patterns
        while IFS= read -r pattern; do
            [ -z "$pattern" ] && continue
            local cnt
            cnt=$(count_pattern "$all_msg_file" "$pattern")
            local pname
            pname=$(echo "$pattern" | sed 's/\\.*//; s/|.*//; s/ /-/g' | head -c 30)
            if [ "$cnt" -gt 0 ]; then
                checks+=("{\"check\":\"banned:$pname\",\"status\":\"FAIL\",\"detail\":\"$cnt matches\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] banned: '$pname' found $cnt times${NC}"
            else
                checks+=("{\"check\":\"banned:$pname\",\"status\":\"PASS\"}")
            fi
        done < <(jq -r '.checks.banned_patterns // [] | .[]' "$scenario_file" 2>/dev/null)

        # Scenario-level banned_tools — aggregate across all turns
        local all_tools_file="$TMP_DIR/tools_${sid}_all.txt"
        > "$all_tools_file"
        local ti=0
        while [ "$ti" -lt "$num_turns" ]; do
            cat "$TMP_DIR/tools_${sid}_t${ti}.txt" >> "$all_tools_file" 2>/dev/null
            ((ti++))
        done
        while IFS= read -r tool_name; do
            [ -z "$tool_name" ] && continue
            if grep -qF "$tool_name" "$all_tools_file" 2>/dev/null; then
                checks+=("{\"check\":\"banned-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"found in tool_use events\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] banned-tool: '$tool_name' found in tool_use${NC}"
            else
                checks+=("{\"check\":\"banned-tool:$tool_name\",\"status\":\"PASS\"}")
                log "  ${GREEN}[PASS] banned-tool: '$tool_name' absent${NC}"
            fi
        done < <(jq -r '.checks.banned_tools // [] | .[]' "$scenario_file" 2>/dev/null)

        # Scenario-level expected_tools — aggregate across all turns
        while IFS= read -r tool_name; do
            [ -z "$tool_name" ] && continue
            if grep -qF "$tool_name" "$all_tools_file" 2>/dev/null; then
                checks+=("{\"check\":\"expected-tool:$tool_name\",\"status\":\"PASS\"}")
                log "  ${GREEN}[PASS] expected-tool: '$tool_name'${NC}"
            else
                checks+=("{\"check\":\"expected-tool:$tool_name\",\"status\":\"FAIL\",\"detail\":\"not in tool_use events\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] expected-tool: '$tool_name' not in tool_use${NC}"
            fi
        done < <(jq -r '.checks.expected_tools // [] | .[]' "$scenario_file" 2>/dev/null)

        # Scenario-level expected MCP calls range
        local mcp_min mcp_max
        mcp_min=$(jq -r '.checks.expected_mcp_calls.min // empty' "$scenario_file" 2>/dev/null)
        mcp_max=$(jq -r '.checks.expected_mcp_calls.max // empty' "$scenario_file" 2>/dev/null)
        if [ -n "$mcp_min" ] && [ -n "$mcp_max" ]; then
            if [ "$total_mcp_calls" -ge "$mcp_min" ] && [ "$total_mcp_calls" -le "$mcp_max" ]; then
                checks+=("{\"check\":\"mcp-calls-range\",\"status\":\"PASS\",\"detail\":\"$total_mcp_calls in [$mcp_min..$mcp_max]\"}")
                log "  ${GREEN}[PASS] mcp-calls-range: $total_mcp_calls in [$mcp_min..$mcp_max]${NC}"
            else
                checks+=("{\"check\":\"mcp-calls-range\",\"status\":\"FAIL\",\"detail\":\"$total_mcp_calls not in [$mcp_min..$mcp_max]\"}")
                scenario_status="FAIL"
                log "  ${RED}[FAIL] mcp-calls-range: $total_mcp_calls not in [$mcp_min..$mcp_max]${NC}"
            fi
        fi

        # Scenario-level token budget
        if [ "$total_output_tokens" -gt 0 ] && [ "$total_output_tokens" -gt "$smax_out" ] 2>/dev/null; then
            checks+=("{\"check\":\"token-budget\",\"status\":\"FAIL\",\"detail\":\"$total_output_tokens > $smax_out\"}")
            scenario_status="FAIL"
            log "  ${RED}[FAIL] token-budget: $total_output_tokens > $smax_out${NC}"
        else
            checks+=("{\"check\":\"token-budget\",\"status\":\"PASS\",\"detail\":\"$total_output_tokens <= $smax_out\"}")
            log "  ${GREEN}[PASS] token-budget: $total_output_tokens <= $smax_out${NC}"
        fi

        # Scenario-level duration
        local timeout_ms=$((stimeout * 1000))
        if [ "$duration_ms" -le "$timeout_ms" ]; then
            checks+=("{\"check\":\"duration\",\"status\":\"PASS\",\"detail\":\"${duration_ms}ms <= ${timeout_ms}ms\"}")
            log "  ${GREEN}[PASS] duration: ${duration_ms}ms <= ${timeout_ms}ms${NC}"
        else
            checks+=("{\"check\":\"duration\",\"status\":\"FAIL\",\"detail\":\"${duration_ms}ms > ${timeout_ms}ms\"}")
            scenario_status="FAIL"
            log "  ${RED}[FAIL] duration: ${duration_ms}ms > ${timeout_ms}ms${NC}"
        fi

        log "  ${DIM}total: tokens in=$total_input_tokens out=$total_output_tokens | mcp=$total_mcp_calls | ${#total_response} chars | ${duration_ms}ms${NC}"

        # Update counters
        TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + total_input_tokens))
        TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + total_output_tokens))
        TOTAL_DURATION_MS=$((TOTAL_DURATION_MS + duration_ms))
        TOTAL_MCP_CALLS=$((TOTAL_MCP_CALLS + total_mcp_calls))
    fi

    # Update counters
    case "$scenario_status" in
        PASS) ((PASSED++)) ;;
        FAIL) ((FAILED++)) ;;
        ERROR) ;; # already counted
    esac

    # Record result JSON
    local checks_json=""
    if [ ${#checks[@]} -gt 0 ]; then
        checks_json=$(IFS=,; echo "${checks[*]}")
    fi
    local rchars=${#total_response}
    RESULTS+=("{\"id\":\"$sid\",\"title\":\"$stitle\",\"difficulty\":\"$sdiff\",\"status\":\"$scenario_status\",\"executed_model\":\"$MODEL\",\"duration_ms\":${duration_ms:-0},\"input_tokens\":$total_input_tokens,\"output_tokens\":$total_output_tokens,\"mcp_calls_count\":$total_mcp_calls,\"response_chars\":$rchars,\"turns\":$num_turns,\"checks\":[$checks_json]}")
}

# ============================================================
# Matrix stress harness: 4 configs × stress subset
# ============================================================
run_matrix() {
    # Load stress scenario IDs and per-config budgets from baselines
    local matrix_profile="${1:-matrix}"
    local mp=".profiles[\"$matrix_profile\"]"
    local stress_ids=()
    if [ -f "$BASELINES_FILE" ]; then
        while IFS= read -r sid; do
            [ -n "$sid" ] && stress_ids+=("$sid")
        done < <(jq -r "$mp.stress_scenarios // empty | .[]?" "$BASELINES_FILE" 2>/dev/null)
    fi
    [ ${#stress_ids[@]} -eq 0 ] && stress_ids=("MT-001" "MT-002" "MT-003" "ST-001")

    local budget_tokens budget_duration budget_mcp
    if [ -f "$BASELINES_FILE" ]; then
        budget_tokens=$(jq -r "$mp.max_total_output_tokens // 6000" "$BASELINES_FILE" 2>/dev/null)
        budget_duration=$(jq -r "$mp.max_total_duration_ms // 480000" "$BASELINES_FILE" 2>/dev/null)
        budget_mcp=$(jq -r "$mp.max_total_mcp_calls // 15" "$BASELINES_FILE" 2>/dev/null)
    else
        budget_tokens=6000; budget_duration=480000; budget_mcp=15
    fi

    # Hard cap = baseline × 1.2
    local cap_tokens=$((budget_tokens * 120 / 100))
    local cap_duration=$((budget_duration * 120 / 100))
    local cap_mcp=$((budget_mcp * 120 / 100))

    log "\n${YELLOW}Brain LLM Matrix Stress Harness${NC}"
    log "${DIM}Model: $MODEL | Stress subset: ${stress_ids[*]}${NC}"
    log "${DIM}Budget/config: tokens=$budget_tokens (cap=$cap_tokens) duration=${budget_duration}ms mcp=$budget_mcp (cap=$cap_mcp)${NC}"
    $DRY_RUN && log "${DIM}DRY-RUN: validating scenarios only${NC}"
    log ""

    # Collect stress scenario files
    local stress_scenarios=()
    for sid in "${stress_ids[@]}"; do
        local found
        found=$(find "$SCENARIOS_DIR" -name "*${sid}*" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            stress_scenarios+=("$found")
        else
            log "  ${RED}WARNING: Stress scenario $sid not found${NC}"
        fi
    done

    if [ ${#stress_scenarios[@]} -eq 0 ]; then
        echo "ERROR: No stress scenarios found" >&2
        exit 2
    fi
    IFS=$'\n' stress_scenarios=($(sort <<< "${stress_scenarios[*]}")); unset IFS

    # Configs: (STRICT_MODE:COGNITIVE_LEVEL)
    local configs=("standard:standard" "standard:exhaustive" "paranoid:standard" "paranoid:exhaustive")
    log "Running ${#stress_scenarios[@]} scenarios × ${#configs[@]} configs = $((${#stress_scenarios[@]} * ${#configs[@]})) total runs\n"

    local config_results=()
    local grand_total=0 grand_passed=0 grand_failed=0 grand_errors=0
    local grand_in_tokens=0 grand_out_tokens=0 grand_duration=0 grand_mcp=0
    local configs_passed=0

    for config in "${configs[@]}"; do
        local cfg_mode="${config%%:*}"
        local cfg_cognitive="${config##*:}"

        MODE="$cfg_mode"
        COGNITIVE="$cfg_cognitive"
        TOTAL=0; PASSED=0; FAILED=0; ERRORS=0
        TOTAL_INPUT_TOKENS=0; TOTAL_OUTPUT_TOKENS=0
        TOTAL_DURATION_MS=0; TOTAL_MCP_CALLS=0
        RESULTS=()

        log "${YELLOW}━━━ Config: $cfg_mode/$cfg_cognitive ━━━${NC}\n"

        for sf in "${stress_scenarios[@]}"; do
            local stype
            stype=$(jq -r '.type // "single"' "$sf" 2>/dev/null)
            case "$stype" in
                multi) run_multi_turn_scenario "$sf" ;;
                *) run_scenario "$sf" ;;
            esac
        done

        local rate="0.0"
        [ "$TOTAL" -gt 0 ] && rate=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)

        local results_json=""
        [ ${#RESULTS[@]} -gt 0 ] && results_json=$(IFS=,; echo "${RESULTS[*]}")

        # Cost guard: regression check per config
        local budget_status="OK"
        if ! $DRY_RUN && [ -f "$BASELINES_FILE" ]; then
            local mini_report="$TMP_DIR/matrix_${cfg_mode}_${cfg_cognitive}.json"
            echo "{\"total\":$TOTAL,\"passed\":$PASSED,\"failed\":$FAILED,\"errors\":$ERRORS,\"pass_rate\":\"${rate}%\",\"profile\":\"matrix\",\"model\":\"$MODEL\",\"dry_run\":false,\"total_input_tokens\":$TOTAL_INPUT_TOKENS,\"total_output_tokens\":$TOTAL_OUTPUT_TOKENS,\"total_mcp_calls\":$TOTAL_MCP_CALLS,\"total_duration_ms\":$TOTAL_DURATION_MS,\"scenarios\":[]}" > "$mini_report"

            local reg_rc=0
            bash "$SCRIPT_DIR/benchmark-regression-check.sh" "$mini_report" --strict > "$TMP_DIR/reg_${cfg_mode}_${cfg_cognitive}.log" 2>&1 || reg_rc=$?

            while IFS= read -r rline; do
                log "  $rline"
            done < "$TMP_DIR/reg_${cfg_mode}_${cfg_cognitive}.log"

            if [ "$reg_rc" -ne 0 ]; then
                budget_status="FAIL:regression"
                log "  ${RED}[COST GUARD] Budget blowup: $cfg_mode/$cfg_cognitive${NC}"
            fi
        fi

        config_results+=("{\"mode\":\"$cfg_mode\",\"cognitive\":\"$cfg_cognitive\",\"total\":$TOTAL,\"passed\":$PASSED,\"failed\":$FAILED,\"errors\":$ERRORS,\"pass_rate\":\"${rate}%\",\"total_input_tokens\":$TOTAL_INPUT_TOKENS,\"total_output_tokens\":$TOTAL_OUTPUT_TOKENS,\"total_duration_ms\":$TOTAL_DURATION_MS,\"total_mcp_calls\":$TOTAL_MCP_CALLS,\"budget_status\":\"$budget_status\",\"scenarios\":[$results_json]}")

        grand_total=$((grand_total + TOTAL))
        grand_passed=$((grand_passed + PASSED))
        grand_failed=$((grand_failed + FAILED))
        grand_errors=$((grand_errors + ERRORS))
        grand_in_tokens=$((grand_in_tokens + TOTAL_INPUT_TOKENS))
        grand_out_tokens=$((grand_out_tokens + TOTAL_OUTPUT_TOKENS))
        grand_duration=$((grand_duration + TOTAL_DURATION_MS))
        grand_mcp=$((grand_mcp + TOTAL_MCP_CALLS))

        if [ "$budget_status" = "OK" ] && [ "$FAILED" -eq 0 ] && [ "$ERRORS" -eq 0 ]; then
            ((configs_passed++))
            log "  ${GREEN}[$cfg_mode/$cfg_cognitive] PASS ($PASSED/$TOTAL, ${TOTAL_OUTPUT_TOKENS} tokens)${NC}\n"
        else
            log "  ${RED}[$cfg_mode/$cfg_cognitive] FAIL (budget=$budget_status failed=$FAILED)${NC}\n"
        fi
    done

    # Build stress_scenarios JSON array
    local stress_json
    stress_json=$(printf '%s\n' "${stress_ids[@]}" | jq -R . | jq -sc .)

    # Output consolidated report
    if $JSON_MODE; then
        local configs_json
        configs_json=$(IFS=,; echo "${config_results[*]}")
        cat <<EOF
{"matrix":true,"model":"$MODEL","dry_run":$DRY_RUN,"stress_scenarios":$stress_json,"configs":[$configs_json],"summary":{"total_configs":${#configs[@]},"configs_passed":$configs_passed,"total_scenarios":$grand_total,"total_passed":$grand_passed,"total_failed":$grand_failed,"total_errors":$grand_errors,"total_input_tokens":$grand_in_tokens,"total_output_tokens":$grand_out_tokens,"total_duration_ms":$grand_duration,"total_mcp_calls":$grand_mcp}}
EOF
    else
        echo ""
        echo "=========================================="
        echo "Matrix Stress: $configs_passed/${#configs[@]} configs passed, $grand_passed/$grand_total scenarios"
        echo "  Model: $MODEL | Tokens: in=$grand_in_tokens out=$grand_out_tokens"
        echo "  MCP: $grand_mcp | Duration: ${grand_duration}ms"
        echo ""
        if [ "$configs_passed" -lt "${#configs[@]}" ] || [ "$grand_failed" -gt 0 ]; then
            echo -e "${RED}MATRIX FAILED${NC}"
            exit 1
        else
            echo -e "${GREEN}MATRIX PASSED${NC}"
        fi
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    check_deps

    # Auto-trigger matrix mode for matrix-type profiles
    case "$PROFILE" in
        adversarial-matrix) MATRIX=true ;;
    esac

    if $MATRIX; then
        local matrix_prof="matrix"
        case "$PROFILE" in
            adversarial-matrix) matrix_prof="adversarial-matrix" ;;
        esac
        run_matrix "$matrix_prof"
        return
    fi

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
            local diff
            diff=$(jq -r '.difficulty' "$sf" 2>/dev/null)
            # Profile filter
            local sid_check
            sid_check=$(jq -r '.id' "$sf" 2>/dev/null)
            case "$PROFILE" in
                smoke)
                    # Smoke runs only S0 scenarios
                    [ "$diff" != "S0" ] && continue
                    ;;
                ci)
                    # CI: L1+L2+ST+CMD, skip L3/MT/S0/ADV/CMD-AUTO
                    [ "$diff" = "L3" ] && continue
                    [ "$diff" = "S0" ] && continue
                    case "$sid_check" in MT-*|ADV-*|CMD-AUTO-*) continue ;; esac
                    ;;
                telemetry-ci)
                    # Smoke + cheap L1 + MCP L2 + telemetry ST + multi-turn MT + learn protocol
                    case "$sid_check" in
                        S00-*) ;; # include smoke
                        L1-001|L1-002|L1-003) ;; # 3 cheapest L1
                        L2-001|L2-002) ;; # MCP format checks
                        ST-001) ;; # telemetry tool check
                        MT-001|MT-002) ;; # multi-turn
                        MT-LP-001|MT-LP-002|MT-LP-003) ;; # constitutional learn protocol
                        *) continue ;;
                    esac
                    ;;
                full)
                    # Everything except S0, ADV, and CMD-AUTO (separate profile)
                    [ "$diff" = "S0" ] && continue
                    case "$sid_check" in ADV-*|CMD-AUTO-*) continue ;; esac
                    ;;
                cmd-auto)
                    # Auto-generated command knowledge scenarios only
                    case "$sid_check" in
                        CMD-AUTO-*) ;; # include
                        *) continue ;;
                    esac
                    ;;
            esac
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
        # Model gating: skip scenario if current model below min_model_tier
        local min_tier_name
        min_tier_name=$(jq -r '.min_model_tier // empty' "$sf" 2>/dev/null)
        if [ -n "$min_tier_name" ]; then
            local current_t required_t
            current_t=$(model_tier "$MODEL")
            required_t=$(model_tier "$min_tier_name")
            if [ "$current_t" -lt "$required_t" ]; then
                local skip_sid skip_title skip_diff
                skip_sid=$(jq -r '.id' "$sf")
                skip_title=$(jq -r '.title' "$sf")
                skip_diff=$(jq -r '.difficulty' "$sf")
                log "\n${YELLOW}[$skip_sid] $skip_title${NC} ${DIM}($skip_diff) — SKIP: model $MODEL < min_model_tier $min_tier_name${NC}"
                ((TOTAL++))
                ((SKIPPED++))
                RESULTS+=("{\"id\":\"$skip_sid\",\"title\":\"$skip_title\",\"difficulty\":\"$skip_diff\",\"status\":\"SKIP\",\"skip_reason\":\"model_not_supported: $MODEL < $min_tier_name\",\"executed_model\":\"$MODEL\",\"duration_ms\":0,\"input_tokens\":0,\"output_tokens\":0,\"mcp_calls_count\":0,\"response_chars\":0,\"checks\":[]}")
                continue
            fi
        fi

        local stype
        stype=$(jq -r '.type // "single"' "$sf" 2>/dev/null)
        case "$stype" in
            multi) run_multi_turn_scenario "$sf" ;;
            *) run_scenario "$sf" ;;
        esac
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
{"total":$TOTAL,"passed":$PASSED,"failed":$FAILED,"skipped":$SKIPPED,"errors":$ERRORS,"pass_rate":"${rate}%","mode":"$MODE","cognitive":"$COGNITIVE","profile":"$PROFILE","model":"$MODEL","dry_run":$DRY_RUN,"total_input_tokens":$TOTAL_INPUT_TOKENS,"total_output_tokens":$TOTAL_OUTPUT_TOKENS,"total_mcp_calls":$TOTAL_MCP_CALLS,"total_duration_ms":$TOTAL_DURATION_MS,"scenarios":[$results_json]}
EOF
    else
        echo ""
        echo "=========================================="
        local rate="0.0"
        [ "$TOTAL" -gt 0 ] && rate=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)
        echo "LLM Benchmark: $PASSED/$TOTAL passed ($rate%)"
        echo "  Mode: $MODE/$COGNITIVE | Model: $MODEL | Profile: $PROFILE"
        echo "  Tokens: in=$TOTAL_INPUT_TOKENS out=$TOTAL_OUTPUT_TOKENS"
        echo "  MCP calls: $TOTAL_MCP_CALLS"
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
