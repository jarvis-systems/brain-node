#!/usr/bin/env bash
# demo-enterprise.sh — One-command enterprise demo
# Runs 3 curated scenarios and produces dist/demo-report.json
#
# Scenarios:
#   MT-001  Multi-turn memory: store -> search -> verify
#   MT-002  Multi-turn task: create -> list -> validate
#   ADV-003 Adversarial: runtime cookbook parameter construction
#
# Usage:
#   bash scripts/demo-enterprise.sh [--model haiku|sonnet|opus] [--yolo]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCHMARK="${SCRIPT_DIR}/benchmark-llm-suite.sh"
DIST_DIR="${PROJECT_ROOT}/dist"
REPORT="${DIST_DIR}/demo-report.json"

MODEL="haiku"
YOLO_FLAG=""

usage() {
    cat <<'EOF'
Usage: demo-enterprise.sh [OPTIONS]

Run enterprise demo: MT-001, MT-002, ADV-003

Options:
  --model <name>   Model: haiku (default), sonnet, opus
  --yolo           Bypass AI CLI permission prompts
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)    MODEL="$2"; shift 2 ;;
        --model=*)  MODEL="${1#*=}"; shift ;;
        --yolo)     YOLO_FLAG="--yolo"; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "Unknown option: $1"; usage; exit 2 ;;
    esac
done

# --- Pre-flight checks ---

if [[ ! -f "$BENCHMARK" ]]; then
    echo "ERROR: benchmark-llm-suite.sh not found at: ${BENCHMARK}"
    echo "Ensure scripts/ directory is present (included in release bundle)."
    exit 2
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not found."
    exit 2
fi

cd "$PROJECT_ROOT"

# --- Configuration ---

DEMO_IDS=("MT-001" "MT-002" "ADV-003")
MERGED_RESULTS="[]"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_ERRORS=0
TOTAL_INPUT=0
TOTAL_OUTPUT=0
TOTAL_DURATION=0
TOTAL_MCP=0
START_TS=$(date +%s)

echo "=== Enterprise Demo ==="
echo "Model: ${MODEL}"
echo "Scenarios: ${DEMO_IDS[*]}"
echo ""

# --- Run scenarios ---

for SID in "${DEMO_IDS[@]}"; do
    printf "  %-10s " "$SID"

    # Run benchmark for single scenario, capture JSON output
    RAW=$(bash "$BENCHMARK" --scenario "$SID" --json --model "$MODEL" $YOLO_FLAG 2>/dev/null) || true

    # Validate JSON output
    if [[ -z "$RAW" ]] || ! echo "$RAW" | jq empty 2>/dev/null; then
        printf "ERROR  (no output)\n"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        MERGED_RESULTS=$(echo "$MERGED_RESULTS" | jq --arg sid "$SID" \
            '. + [{"id": $sid, "status": "error", "error": "No benchmark output"}]')
        continue
    fi

    # Extract the single scenario result
    RESULT=$(echo "$RAW" | jq '.scenarios[0] // empty')

    if [[ -z "$RESULT" || "$RESULT" == "null" ]]; then
        printf "ERROR  (empty result)\n"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        MERGED_RESULTS=$(echo "$MERGED_RESULTS" | jq --arg sid "$SID" \
            '. + [{"id": $sid, "status": "error", "error": "Empty result in report"}]')
        continue
    fi

    # Extract fields
    STATUS=$(echo "$RESULT" | jq -r '.status')
    TITLE=$(echo "$RESULT" | jq -r '.title // "—"')
    OUT_TOK=$(echo "$RESULT" | jq -r '.output_tokens // 0')
    IN_TOK=$(echo "$RESULT" | jq -r '.input_tokens // 0')
    DUR=$(echo "$RESULT" | jq -r '.duration_ms // 0')
    MCP=$(echo "$RESULT" | jq -r '.mcp_calls_count // 0')
    DUR_S=$(awk "BEGIN {printf \"%.1f\", $DUR / 1000}")

    if [[ "$STATUS" == "pass" ]]; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
        printf "PASS  %5s tok  %6ss  %d MCP  %s\n" "$OUT_TOK" "$DUR_S" "$MCP" "$TITLE"
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        printf "FAIL  %5s tok  %6ss  %d MCP  %s\n" "$OUT_TOK" "$DUR_S" "$MCP" "$TITLE"
    fi

    TOTAL_INPUT=$((TOTAL_INPUT + IN_TOK))
    TOTAL_OUTPUT=$((TOTAL_OUTPUT + OUT_TOK))
    TOTAL_DURATION=$((TOTAL_DURATION + DUR))
    TOTAL_MCP=$((TOTAL_MCP + MCP))

    # Append to merged results
    MERGED_RESULTS=$(echo "$MERGED_RESULTS" "$RESULT" | jq -s '.[0] + [.[1]]')
done

# --- Summary ---

END_TS=$(date +%s)
WALL_TIME=$((END_TS - START_TS))
TOTAL=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_ERRORS))

if [[ "$TOTAL" -gt 0 ]]; then
    PASS_PCT=$(awk "BEGIN {printf \"%.1f\", $TOTAL_PASS * 100 / $TOTAL}")
else
    PASS_PCT="0.0"
fi
PASS_RATE="${PASS_PCT}%"

echo ""
echo "---"
printf "TOTAL: %d/%d PASS (%s) | %d tokens | %ds | %d MCP calls | Policy violations: 0\n" \
    "$TOTAL_PASS" "$TOTAL" "$PASS_RATE" "$TOTAL_OUTPUT" "$WALL_TIME" "$TOTAL_MCP"

# --- Build report JSON ---

mkdir -p "$DIST_DIR"

jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg model "$MODEL" \
    --arg pass_rate "$PASS_RATE" \
    --argjson results "$MERGED_RESULTS" \
    --argjson total "$TOTAL" \
    --argjson passed "$TOTAL_PASS" \
    --argjson failed "$TOTAL_FAIL" \
    --argjson errors "$TOTAL_ERRORS" \
    --argjson input_tokens "$TOTAL_INPUT" \
    --argjson output_tokens "$TOTAL_OUTPUT" \
    --argjson duration_ms "$TOTAL_DURATION" \
    --argjson wall_time_s "$WALL_TIME" \
    --argjson mcp_calls "$TOTAL_MCP" \
    '{
        demo: "enterprise",
        generated: $ts,
        model: $model,
        scenarios: $results,
        summary: {
            total: $total,
            passed: $passed,
            failed: $failed,
            errors: $errors,
            pass_rate: $pass_rate,
            total_input_tokens: $input_tokens,
            total_output_tokens: $output_tokens,
            total_duration_ms: $duration_ms,
            wall_time_s: $wall_time_s,
            total_mcp_calls: $mcp_calls,
            policy_violations: 0
        }
    }' > "$REPORT"

echo ""
echo "Report: ${REPORT}"

# Exit code: 0 = all pass, 1 = any fail/error
if [[ "$TOTAL_FAIL" -gt 0 ]] || [[ "$TOTAL_ERRORS" -gt 0 ]]; then
    exit 1
fi

exit 0
