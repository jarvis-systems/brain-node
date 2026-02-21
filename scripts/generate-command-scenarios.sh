#!/bin/bash
#
# Generate CMD-AUTO benchmark scenarios for all compiled commands
#
# Usage: scripts/generate-command-scenarios.sh [--force] [--update-baselines]
#
# Enumerates compiled .claude/commands/*.md files and generates
# text-only benchmark scenarios (no MCP execution required).
# All scenarios go under the "cmd-auto" profile.
#
# Options:
#   --force            Overwrite existing CMD-AUTO-* scenarios
#   --update-baselines Update baselines.json with cmd-auto profile
#
# Exit codes:
#   0 - Success
#   2 - Configuration error
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMMANDS_DIR="$PROJECT_ROOT/.claude/commands"
SCENARIOS_DIR="$PROJECT_ROOT/.docs/benchmarks/scenarios"
BASELINES_FILE="$PROJECT_ROOT/.docs/benchmarks/baselines/baselines.json"

FORCE=false
UPDATE_BASELINES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        --update-baselines) UPDATE_BASELINES=true; shift ;;
        -h|--help) head -18 "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ ! -d "$COMMANDS_DIR" ]]; then
    echo "ERROR: Commands directory not found: $COMMANDS_DIR" >&2
    echo "Run 'brain compile' first." >&2
    exit 2
fi

# ── Pattern sets by command group ──────────────────────────────────────────

get_patterns() {
    local group="$1"
    case "$group" in
        do)
            echo '["agent|делегу|orchestrat|оркестр|execution|виконан","approval|gate|підтвердж|дозвіл|permission|safety"]'
            ;;
        init)
            echo '["scan|analyz|аналіз|дослідж|initialization|ініціалі","safety|безпек|No-hallucin|No-secret|iron.rule|правил"]'
            ;;
        mem)
            echo '["MCP|mcp|vector.memory|векторн|memory|пам","JSON|json|store|search|категорі|category"]'
            ;;
        task)
            echo '["MCP|mcp|vector.task|векторн|task|задач","JSON|json|create|list|update|status|estimate|оцінк"]'
            ;;
        doc)
            echo '["brain docs|документац|documentation","markdown|md|front.matter|validate|валідац"]'
            ;;
        *)
            echo '["command|команд|instruction|інструкц"]'
            ;;
    esac
}

get_group() {
    local cmd_id="$1"
    case "$cmd_id" in
        do:*|do)     echo "do" ;;
        init-*)      echo "init" ;;
        mem:*)       echo "mem" ;;
        task:*)      echo "task" ;;
        doc:*)       echo "doc" ;;
        *)           echo "other" ;;
    esac
}

# ── Generate scenarios ─────────────────────────────────────────────────────

GENERATED=0
SKIPPED=0

echo "Generating CMD-AUTO scenarios from $COMMANDS_DIR"
echo ""

while IFS= read -r cmd_file; do
    # Derive command identifiers
    rel_path="${cmd_file#$COMMANDS_DIR/}"
    cmd_name="${rel_path%.md}"
    cmd_id="${cmd_name//\//:}"
    scenario_slug="${cmd_id//:/-}"
    scenario_file="$SCENARIOS_DIR/CMD-AUTO-${scenario_slug}.json"

    # Skip if exists and not forced
    if [[ -f "$scenario_file" ]] && ! $FORCE; then
        echo "  [SKIP] CMD-AUTO-${scenario_slug} (exists, use --force)"
        ((SKIPPED++))
        continue
    fi

    # Extract description from YAML front matter
    description=$(sed -n 's/^description: "\(.*\)"/\1/p' "$cmd_file" | head -1)
    [[ -z "$description" ]] && description="Command $cmd_id"

    # Determine group and patterns
    group=$(get_group "$cmd_id")
    patterns_json=$(get_patterns "$group")

    # Generate scenario JSON
    jq -n \
        --arg id "CMD-AUTO-${scenario_slug}" \
        --arg title "Auto: /${cmd_id} — ${description}" \
        --arg prompt "Опиши команду /${cmd_id}: що вона робить, які iron rules має, які safety gates застосовуються. Коротко, по суті." \
        --argjson patterns "$patterns_json" \
        '{
            id: $id,
            title: $title,
            difficulty: "L1",
            prompt: $prompt,
            timeout_s: 60,
            max_output_tokens: 800,
            checks: {
                required_patterns: $patterns,
                banned_patterns: ["when uncertain", "I don.t know|не знаю"]
            }
        }' > "$scenario_file"

    echo "  [GEN]  CMD-AUTO-${scenario_slug}"
    ((GENERATED++))

done < <(find "$COMMANDS_DIR" -name "*.md" -type f | sort)

TOTAL_AUTO=$(find "$SCENARIOS_DIR" -name "CMD-AUTO-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "Generated: $GENERATED, Skipped: $SKIPPED, Total CMD-AUTO: $TOTAL_AUTO"

# ── Update baselines ───────────────────────────────────────────────────────

if $UPDATE_BASELINES && [[ -f "$BASELINES_FILE" ]]; then
    # Budget: 800 tokens * N * 1.5 headroom
    max_tokens=$((TOTAL_AUTO * 800 * 3 / 2))
    # Duration: 60s * N * 1.5 headroom
    max_duration=$((TOTAL_AUTO * 60000 * 3 / 2))

    jq --argjson scenarios "$TOTAL_AUTO" \
       --argjson tokens "$max_tokens" \
       --argjson duration "$max_duration" \
       '.profiles["cmd-auto"] = {
            scenarios: $scenarios,
            max_total_output_tokens: $tokens,
            max_total_duration_ms: $duration,
            max_total_mcp_calls: 0
        }' "$BASELINES_FILE" > "${BASELINES_FILE}.tmp" && mv "${BASELINES_FILE}.tmp" "$BASELINES_FILE"

    echo ""
    echo "Updated baselines: cmd-auto profile ($TOTAL_AUTO scenarios, ${max_tokens} tokens, ${max_duration}ms)"
fi
