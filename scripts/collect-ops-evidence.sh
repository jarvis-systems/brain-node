#!/usr/bin/env bash
# collect-ops-evidence.sh — Collect operational evidence for support/audit
# Output: dist/ops-evidence.json + human summary (10 lines max)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

DIST_DIR="dist"
OUTPUT="${DIST_DIR}/ops-evidence.json"
MANIFEST_FILE=".docs/releases/manifest.json"
PINS_FILE="pins.json"
BRAIN_ENV=".brain/.env"
DEMO_REPORT="${DIST_DIR}/demo-report.json"

mkdir -p "$DIST_DIR"

# --- Helpers ---
file_sha256() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "not-found"
        return
    fi
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        echo "no-sha256-tool"
    fi
}

# --- Collect ---

# Manifest
MANIFEST_JSON='null'
if [[ -f "$MANIFEST_FILE" ]]; then
    MANIFEST_JSON=$(jq '.' "$MANIFEST_FILE" 2>/dev/null || echo 'null')
fi

# Pins
PINS_JSON='null'
if [[ -f "$PINS_FILE" ]]; then
    PINS_JSON=$(jq 'del(._meta)' "$PINS_FILE" 2>/dev/null || echo 'null')
fi

# Mode env
STRICT_MODE="unknown"
COGNITIVE_LEVEL="unknown"
if [[ -f "$BRAIN_ENV" ]]; then
    STRICT_MODE=$(grep -E '^STRICT_MODE=' "$BRAIN_ENV" 2>/dev/null | cut -d= -f2 | tr -d '"' || true)
    COGNITIVE_LEVEL=$(grep -E '^COGNITIVE_LEVEL=' "$BRAIN_ENV" 2>/dev/null | cut -d= -f2 | tr -d '"' || true)
    [[ -z "$STRICT_MODE" ]] && STRICT_MODE="unknown"
    [[ -z "$COGNITIVE_LEVEL" ]] && COGNITIVE_LEVEL="unknown"
fi
PIN_STRICT="${PIN_STRICT:-0}"

# Hashes
MANIFEST_HASH=$(file_sha256 "$MANIFEST_FILE")
DEMO_REPORT_HASH=$(file_sha256 "$DEMO_REPORT")

# Find last benchmark report (any JSON in runs/)
LAST_BENCHMARK_HASH="not-found"
LAST_BENCHMARK_FILE="none"
if [[ -d ".docs/benchmarks/runs" ]]; then
    FOUND=$(find .docs/benchmarks/runs -name "*.json" -type f 2>/dev/null | sort -r | head -1 || true)
    if [[ -n "$FOUND" && -f "$FOUND" ]]; then
        LAST_BENCHMARK_FILE="$FOUND"
        LAST_BENCHMARK_HASH=$(file_sha256 "$FOUND")
    fi
fi

# Demo report aggregates (tool_use counts)
DEMO_AGGREGATES='null'
if [[ -f "$DEMO_REPORT" ]]; then
    DEMO_AGGREGATES=$(jq '{
        total_scenarios: (.scenarios | length),
        passed: [.scenarios[] | select(.status == "pass")] | length,
        failed: [.scenarios[] | select(.status == "fail")] | length,
        total_mcp_calls: [.scenarios[].mcp_calls_count // 0] | add,
        total_input_tokens: [.scenarios[].input_tokens // 0] | add,
        total_output_tokens: [.scenarios[].output_tokens // 0] | add
    }' "$DEMO_REPORT" 2>/dev/null || echo 'null')
fi

# Timestamp
GENERATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Build JSON ---
jq -n \
    --arg generated "$GENERATED" \
    --argjson manifest "$MANIFEST_JSON" \
    --argjson pins "$PINS_JSON" \
    --arg strict_mode "$STRICT_MODE" \
    --arg cognitive_level "$COGNITIVE_LEVEL" \
    --arg pin_strict "$PIN_STRICT" \
    --arg manifest_hash "$MANIFEST_HASH" \
    --arg demo_report_hash "$DEMO_REPORT_HASH" \
    --arg last_benchmark_hash "$LAST_BENCHMARK_HASH" \
    --arg last_benchmark_file "$LAST_BENCHMARK_FILE" \
    --argjson demo_aggregates "$DEMO_AGGREGATES" \
    '{
        generated: $generated,
        manifest: $manifest,
        pins: $pins,
        environment: {
            strict_mode: $strict_mode,
            cognitive_level: $cognitive_level,
            pin_strict: $pin_strict
        },
        hashes: {
            manifest: $manifest_hash,
            demo_report: $demo_report_hash,
            last_benchmark: $last_benchmark_hash
        },
        demo_aggregates: $demo_aggregates,
        last_benchmark_file: $last_benchmark_file
    }' > "$OUTPUT"

# Validate
if ! jq empty "$OUTPUT" 2>/dev/null; then
    echo "ERROR: Generated invalid JSON"
    exit 1
fi

# --- Human Summary (10 lines) ---
VERSION=$(jq -r '.node.version // "unknown"' "$MANIFEST_FILE" 2>/dev/null || echo 'unknown')
PINS_SUMMARY=$(jq -r 'del(._meta) | to_entries | map(.key + "==" + .value) | join(", ")' "$PINS_FILE" 2>/dev/null || echo 'none')
DEMO_PASS="N/A"
if [[ "$DEMO_AGGREGATES" != "null" ]]; then
    DEMO_PASS=$(echo "$DEMO_AGGREGATES" | jq -r '"\(.passed)/\(.total_scenarios)"' 2>/dev/null || echo 'N/A')
fi

echo "=== Ops Evidence ==="
echo "Generated:  ${GENERATED}"
echo "Version:    ${VERSION}"
echo "Mode:       ${STRICT_MODE} / ${COGNITIVE_LEVEL}"
echo "PIN_STRICT: ${PIN_STRICT}"
echo "Pins:       ${PINS_SUMMARY}"
echo "Manifest:   ${MANIFEST_HASH:0:12}..."
echo "Demo:       ${DEMO_REPORT_HASH:0:12}... (pass: ${DEMO_PASS})"
echo "Benchmark:  ${LAST_BENCHMARK_HASH:0:12}..."
echo "Output:     ${OUTPUT}"
echo "===================="
