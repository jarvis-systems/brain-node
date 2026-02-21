#!/usr/bin/env bash
#
# Benchmark regression check — compare run report against baseline budgets
#
# Usage: scripts/benchmark-regression-check.sh <report.json> [--threshold N] [--strict]
#
# Reads a benchmark report JSON and compares total_output_tokens, total_duration_ms,
# and total_mcp_calls against baseline budgets for the matching profile.
#
# Options:
#   --threshold N   Override threshold percentage (default: from baselines.json)
#   --strict        Exit 1 on regression (default: exit 0 with WARN)
#
# Exit codes:
#   0 - Within budget (or WARN in non-strict mode)
#   1 - Regression detected (strict mode)
#   2 - Missing input or baseline

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BASELINES_FILE="$PROJECT_ROOT/.docs/benchmarks/baselines/baselines.json"

REPORT_FILE=""
THRESHOLD=""
STRICT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --strict) STRICT=true; shift ;;
        -h|--help) head -18 "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
        *) REPORT_FILE="$1"; shift ;;
    esac
done

if [ -z "$REPORT_FILE" ] || [ ! -f "$REPORT_FILE" ]; then
    echo "ERROR: Report file required. Usage: $0 <report.json>" >&2
    exit 2
fi

if [ ! -f "$BASELINES_FILE" ]; then
    echo "ERROR: Baselines file not found: $BASELINES_FILE" >&2
    exit 2
fi

# Read report
PROFILE=$(jq -r '.profile' "$REPORT_FILE")
DRY_RUN=$(jq -r '.dry_run' "$REPORT_FILE")
ACTUAL_TOKENS=$(jq -r '.total_output_tokens' "$REPORT_FILE")
ACTUAL_DURATION=$(jq -r '.total_duration_ms' "$REPORT_FILE")
ACTUAL_MCP=$(jq -r '.total_mcp_calls' "$REPORT_FILE")
ACTUAL_SCENARIOS=$(jq -r '.total' "$REPORT_FILE")
PASSED=$(jq -r '.passed' "$REPORT_FILE")
FAILED=$(jq -r '.failed' "$REPORT_FILE")

if [ "$DRY_RUN" = "true" ]; then
    echo "Dry-run report — regression check skipped."
    exit 0
fi

# Read baseline for profile
BASELINE_TOKENS=$(jq -r ".profiles.\"$PROFILE\".max_total_output_tokens // empty" "$BASELINES_FILE")
BASELINE_DURATION=$(jq -r ".profiles.\"$PROFILE\".max_total_duration_ms // empty" "$BASELINES_FILE")
BASELINE_MCP=$(jq -r ".profiles.\"$PROFILE\".max_total_mcp_calls // empty" "$BASELINES_FILE")
BASELINE_SCENARIOS=$(jq -r ".profiles.\"$PROFILE\".scenarios // empty" "$BASELINES_FILE")

if [ -z "$BASELINE_TOKENS" ]; then
    echo "WARN: No baseline found for profile '$PROFILE'. Skipping regression check."
    exit 0
fi

# Resolve threshold
if [ -z "$THRESHOLD" ]; then
    THRESHOLD=$(jq -r '._meta.threshold_pct // 20' "$BASELINES_FILE")
fi

echo "Regression check: profile=$PROFILE threshold=${THRESHOLD}%"
echo "  Scenarios: actual=$ACTUAL_SCENARIOS baseline=$BASELINE_SCENARIOS (passed=$PASSED failed=$FAILED)"

REGRESSION=false

# Check: output tokens
TOKEN_LIMIT=$(( BASELINE_TOKENS * (100 + THRESHOLD) / 100 ))
if [ "$ACTUAL_TOKENS" -gt "$TOKEN_LIMIT" ]; then
    echo -e "  ${YELLOW}[WARN] output_tokens: $ACTUAL_TOKENS > $TOKEN_LIMIT (baseline=$BASELINE_TOKENS +${THRESHOLD}%)${NC}"
    REGRESSION=true
else
    echo -e "  ${GREEN}[OK] output_tokens: $ACTUAL_TOKENS <= $TOKEN_LIMIT${NC}"
fi

# Check: duration
DURATION_LIMIT=$(( BASELINE_DURATION * (100 + THRESHOLD) / 100 ))
if [ "$ACTUAL_DURATION" -gt "$DURATION_LIMIT" ]; then
    echo -e "  ${YELLOW}[WARN] duration_ms: $ACTUAL_DURATION > $DURATION_LIMIT (baseline=$BASELINE_DURATION +${THRESHOLD}%)${NC}"
    REGRESSION=true
else
    echo -e "  ${GREEN}[OK] duration_ms: $ACTUAL_DURATION <= $DURATION_LIMIT${NC}"
fi

# Check: MCP calls
MCP_LIMIT=$(( BASELINE_MCP * (100 + THRESHOLD) / 100 ))
if [ "$ACTUAL_MCP" -gt "$MCP_LIMIT" ]; then
    echo -e "  ${YELLOW}[WARN] mcp_calls: $ACTUAL_MCP > $MCP_LIMIT (baseline=$BASELINE_MCP +${THRESHOLD}%)${NC}"
    REGRESSION=true
else
    echo -e "  ${GREEN}[OK] mcp_calls: $ACTUAL_MCP <= $MCP_LIMIT${NC}"
fi

# Check: pass rate
if [ "$FAILED" -gt 0 ]; then
    echo -e "  ${RED}[FAIL] $FAILED scenario(s) failed${NC}"
    REGRESSION=true
fi

# Result
if $REGRESSION; then
    echo ""
    if $STRICT; then
        echo -e "${RED}REGRESSION DETECTED — strict mode, failing build${NC}"
        exit 1
    else
        echo -e "${YELLOW}REGRESSION WARNING — budgets exceeded (non-strict, not blocking)${NC}"
        exit 0
    fi
else
    echo ""
    echo -e "${GREEN}REGRESSION CHECK PASSED — all metrics within budget${NC}"
    exit 0
fi
