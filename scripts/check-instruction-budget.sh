#!/usr/bin/env bash
#
# Instruction Budget Check — Enforce compiled artifact size budgets
#
# Usage: scripts/check-instruction-budget.sh [--strict] [--update] [--json]
#
# Measures line counts of compiled instruction artifacts (.claude/)
# and compares against baselines in .docs/benchmarks/baselines/instruction-budgets.json.
#
# Options:
#   --strict    Exit 1 on any budget exceeded (default: WARN only)
#   --update    Update baselines file with current measurements
#   --json      Output JSON report only (suppress human-readable output)
#
# Exit codes:
#   0 - All within budget (or WARN in non-strict)
#   1 - Budget exceeded (strict mode)
#   2 - Missing baselines or configuration error
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUDGETS_FILE="$PROJECT_ROOT/.docs/benchmarks/baselines/instruction-budgets.json"

STRICT=false
UPDATE=false
JSON_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --strict) STRICT=true; shift ;;
        --update) UPDATE=true; shift ;;
        --json) JSON_ONLY=true; shift ;;
        -h|--help) head -18 "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# Colors (disabled in non-interactive or JSON mode)
if [[ -t 1 ]] && ! $JSON_ONLY; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

log() { if ! $JSON_ONLY; then echo -e "$@"; fi; }

# ── Measure current artifacts ────────────────────────────────────────────

ARTIFACT_KEYS=""
ARTIFACT_VALS=""

add_measurement() {
    local key="$1" val="$2"
    ARTIFACT_KEYS="$ARTIFACT_KEYS $key"
    ARTIFACT_VALS="$ARTIFACT_VALS $val"
}

get_measurement() {
    local target="$1"
    local i=1
    for key in $ARTIFACT_KEYS; do
        if [[ "$key" == "$target" ]]; then
            echo "$ARTIFACT_VALS" | cut -d' ' -f$((i+1))
            return
        fi
        i=$((i+1))
    done
    echo "0"
}

# Commands
for f in "$PROJECT_ROOT"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    lines=$(wc -l < "$f" | tr -d ' ')
    add_measurement "commands/$name" "$lines"
done

# Agents
for f in "$PROJECT_ROOT"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    lines=$(wc -l < "$f" | tr -d ' ')
    add_measurement "agents/$name" "$lines"
done

# Brain
if [[ -f "$PROJECT_ROOT/.claude/CLAUDE.md" ]]; then
    lines=$(wc -l < "$PROJECT_ROOT/.claude/CLAUDE.md" | tr -d ' ')
    add_measurement "brain/CLAUDE" "$lines"
fi

# ── Calculate totals ──────────────────────────────────────────────────────

COMMANDS_TOTAL=0
AGENTS_TOTAL=0
BRAIN_TOTAL=0

for key in $ARTIFACT_KEYS; do
    val=$(get_measurement "$key")
    case "$key" in
        commands/*) COMMANDS_TOTAL=$((COMMANDS_TOTAL + val)) ;;
        agents/*) AGENTS_TOTAL=$((AGENTS_TOTAL + val)) ;;
        brain/*) BRAIN_TOTAL=$((BRAIN_TOTAL + val)) ;;
    esac
done

GRAND_TOTAL=$((COMMANDS_TOTAL + AGENTS_TOTAL + BRAIN_TOTAL))

# ── Update mode: write current measurements as baselines ──────────────────

if $UPDATE; then
    mkdir -p "$(dirname "$BUDGETS_FILE")"

    # Build artifacts JSON object
    artifacts_json="{"
    first=true
    for key in $(echo "$ARTIFACT_KEYS" | tr ' ' '\n' | sort); do
        [[ -z "$key" ]] && continue
        val=$(get_measurement "$key")
        if $first; then first=false; else artifacts_json+=","; fi
        artifacts_json+="\"$key\":$val"
    done
    artifacts_json+="}"

    jq -n \
        --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson artifacts "$artifacts_json" \
        --argjson commands_total "$COMMANDS_TOTAL" \
        --argjson agents_total "$AGENTS_TOTAL" \
        --argjson brain_total "$BRAIN_TOTAL" \
        --argjson grand_total "$GRAND_TOTAL" \
        '{
            "_meta": {
                "description": "Instruction budget baselines — compiled artifact line counts. Budget = baseline + threshold_pct headroom.",
                "date": $date,
                "threshold_pct": 10,
                "action": "strict"
            },
            "budgets": {
                "commands_total": { "max_lines": (($commands_total * 110 / 100) | floor), "baseline": $commands_total },
                "agents_total": { "max_lines": (($agents_total * 110 / 100) | floor), "baseline": $agents_total },
                "brain_total": { "max_lines": (($brain_total * 110 / 100) | floor), "baseline": $brain_total },
                "grand_total": { "max_lines": (($grand_total * 110 / 100) | floor), "baseline": $grand_total }
            },
            "artifacts": $artifacts,
            "required_safety_rules": {
                "description": "CRITICAL safety rules that must exist in init-* command artifacts",
                "applies_to": "init-*",
                "rules": [
                    "No-hallucination",
                    "No-secret-exfiltration",
                    "No-secrets-in-storage",
                    "No-destructive-git"
                ]
            }
        }' > "$BUDGETS_FILE"

    log "${GREEN}Updated baselines:${NC} $BUDGETS_FILE"
    log "  Commands: $COMMANDS_TOTAL lines"
    log "  Agents:   $AGENTS_TOTAL lines"
    log "  Brain:    $BRAIN_TOTAL lines"
    log "  Total:    $GRAND_TOTAL lines"
    exit 0
fi

# ── Check mode: compare against baselines ──────────────────────────────────

if [[ ! -f "$BUDGETS_FILE" ]]; then
    log "${RED}ERROR: Baselines file not found: $BUDGETS_FILE${NC}"
    log "Run: scripts/check-instruction-budget.sh --update"
    exit 2
fi

THRESHOLD=$(jq -r '._meta.threshold_pct // 10' "$BUDGETS_FILE")
REGRESSION=false
DETAILS_JSON="[]"

log "${BOLD}Instruction Budget Check${NC} (threshold=${THRESHOLD}%)"
log ""

# Check totals
check_budget() {
    local label="$1" actual="$2" budget_key="$3"

    local max_lines baseline
    max_lines=$(jq -r ".budgets.\"$budget_key\".max_lines // empty" "$BUDGETS_FILE")
    baseline=$(jq -r ".budgets.\"$budget_key\".baseline // empty" "$BUDGETS_FILE")

    if [[ -z "$max_lines" ]]; then
        log "  ${YELLOW}[SKIP]${NC} $label — no baseline"
        return
    fi

    local delta=$((actual - baseline))
    local delta_pct=0
    if [[ $baseline -gt 0 ]]; then
        delta_pct=$((delta * 100 / baseline))
    fi

    if [[ $actual -gt $max_lines ]]; then
        log "  ${RED}[OVER]${NC} $label: $actual lines > $max_lines max (baseline=$baseline, +${delta_pct}%)"
        REGRESSION=true
        DETAILS_JSON=$(echo "$DETAILS_JSON" | jq \
            --arg label "$label" \
            --argjson actual "$actual" \
            --argjson max "$max_lines" \
            --argjson baseline "$baseline" \
            --argjson delta "$delta" \
            '. + [{"label": $label, "status": "over", "actual": $actual, "max": $max, "baseline": $baseline, "delta": $delta}]')
    else
        log "  ${GREEN}[OK]${NC}   $label: $actual lines <= $max_lines max (baseline=$baseline, ${delta_pct}%)"
        DETAILS_JSON=$(echo "$DETAILS_JSON" | jq \
            --arg label "$label" \
            --argjson actual "$actual" \
            --argjson max "$max_lines" \
            --argjson baseline "$baseline" \
            --argjson delta "$delta" \
            '. + [{"label": $label, "status": "ok", "actual": $actual, "max": $max, "baseline": $baseline, "delta": $delta}]')
    fi
}

check_budget "Commands total" "$COMMANDS_TOTAL" "commands_total"
check_budget "Agents total" "$AGENTS_TOTAL" "agents_total"
check_budget "Brain total" "$BRAIN_TOTAL" "brain_total"
check_budget "Grand total" "$GRAND_TOTAL" "grand_total"

log ""

# Per-artifact breakdown
log "${BOLD}Per-artifact breakdown:${NC}"

for key in $(echo "$ARTIFACT_KEYS" | tr ' ' '\n' | sort); do
    [[ -z "$key" ]] && continue
    val=$(get_measurement "$key")
    baseline_val=$(jq -r ".artifacts.\"$key\" // empty" "$BUDGETS_FILE")
    if [[ -n "$baseline_val" ]] && [[ "$baseline_val" != "null" ]]; then
        delta=$((val - baseline_val))
        if [[ $delta -gt 0 ]]; then
            log "  ${YELLOW}$key${NC}: $val (+$delta)"
        elif [[ $delta -lt 0 ]]; then
            log "  ${GREEN}$key${NC}: $val ($delta)"
        else
            log "  $key: $val (=)"
        fi
    else
        log "  ${CYAN}$key${NC}: $val (new)"
    fi
done

# Safety rules check
log ""
log "${BOLD}Safety rules presence:${NC}"

SAFETY_RULES=$(jq -r '.required_safety_rules.rules[]' "$BUDGETS_FILE" 2>/dev/null || true)
APPLIES_TO=$(jq -r '.required_safety_rules.applies_to // "*"' "$BUDGETS_FILE" 2>/dev/null || true)
SAFETY_FAIL=false

for cmd_file in "$PROJECT_ROOT"/.claude/commands/*.md; do
    [[ -f "$cmd_file" ]] || continue
    cmd_name=$(basename "$cmd_file" .md)

    # Check if applies_to pattern matches this command
    case "$APPLIES_TO" in
        "*") ;; # matches all
        *)
            # Convert glob to regex-like check
            applies_pattern="${APPLIES_TO//\*/.*}"
            if ! echo "$cmd_name" | grep -qE "^${applies_pattern}$" 2>/dev/null; then
                log "  ${CYAN}[SKIP]${NC} $cmd_name (pattern: $APPLIES_TO)"
                continue
            fi
            ;;
    esac

    missing=""
    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        if ! grep -qi "$rule" "$cmd_file" 2>/dev/null; then
            missing="$missing $rule"
        fi
    done <<< "$SAFETY_RULES"

    if [[ -n "$missing" ]]; then
        log "  ${RED}[MISS]${NC} $cmd_name: missing rules:$missing"
        SAFETY_FAIL=true
    else
        log "  ${GREEN}[OK]${NC}   $cmd_name: all safety rules present"
    fi
done

# JSON output
if $JSON_ONLY; then
    reg_val="false"; $REGRESSION && reg_val="true"
    sf_val="false"; $SAFETY_FAIL && sf_val="true"
    jq -n \
        --argjson commands_total "$COMMANDS_TOTAL" \
        --argjson agents_total "$AGENTS_TOTAL" \
        --argjson brain_total "$BRAIN_TOTAL" \
        --argjson grand_total "$GRAND_TOTAL" \
        --argjson details "$DETAILS_JSON" \
        --argjson regression "$reg_val" \
        --argjson safety_fail "$sf_val" \
        '{
            "commands_total": $commands_total,
            "agents_total": $agents_total,
            "brain_total": $brain_total,
            "grand_total": $grand_total,
            "regression": $regression,
            "safety_fail": $safety_fail,
            "details": $details
        }'
fi

# Result
log ""
if $REGRESSION || $SAFETY_FAIL; then
    if $STRICT; then
        log "${RED}INSTRUCTION BUDGET EXCEEDED — strict mode, failing${NC}"
        exit 1
    else
        log "${YELLOW}INSTRUCTION BUDGET WARNING — budgets exceeded (non-strict, not blocking)${NC}"
        exit 0
    fi
else
    log "${GREEN}INSTRUCTION BUDGET CHECK PASSED — all within budget${NC}"
    exit 0
fi
