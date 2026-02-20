#!/usr/bin/env bash
# generate-manifest.sh — Generate reproducible build manifest
# Output: .docs/releases/manifest.json

set -euo pipefail

MANIFEST_FILE=".docs/releases/manifest.json"
COMPOSER_FILE="composer.json"
CORE_COMPOSER_FILE="core/composer.json"
PINS_FILE="pins.json"
BASELINES_FILE=".docs/benchmarks/baselines/baselines.json"
BRAIN_ENV=".brain/.env"

# Helpers
json_value() {
    local file="$1" key="$2"
    jq -r ".$key // \"unknown\"" "$file" 2>/dev/null || echo "unknown"
}

# Collect data
GENERATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NODE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
NODE_VERSION=$(json_value "$COMPOSER_FILE" "version")
CORE_VERSION=$(json_value "$CORE_COMPOSER_FILE" "version")
CLI_VERSION=$(brain --version 2>/dev/null || echo "unknown")

# Pins
if [[ -f "$PINS_FILE" ]]; then
    PINS_JSON=$(jq 'del(._meta)' "$PINS_FILE" 2>/dev/null || echo '{}')
else
    PINS_JSON='{}'
fi

PIN_STRICT="${PIN_STRICT:-0}"

# Compilation env
STRICT_MODE="standard"
COGNITIVE_LEVEL="standard"
if [[ -f "$BRAIN_ENV" ]]; then
    STRICT_MODE=$(grep -E '^STRICT_MODE=' "$BRAIN_ENV" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "standard")
    COGNITIVE_LEVEL=$(grep -E '^COGNITIVE_LEVEL=' "$BRAIN_ENV" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "standard")
    [[ -z "$STRICT_MODE" ]] && STRICT_MODE="standard"
    [[ -z "$COGNITIVE_LEVEL" ]] && COGNITIVE_LEVEL="standard"
fi

# Benchmarks
BASELINES_DATE="unknown"
TOTAL_SCENARIOS=0
if [[ -f "$BASELINES_FILE" ]]; then
    BASELINES_DATE=$(jq -r '.generated // "unknown"' "$BASELINES_FILE" 2>/dev/null || echo "unknown")
    TOTAL_SCENARIOS=$(jq 'del(.generated, .version) | length' "$BASELINES_FILE" 2>/dev/null || echo "0")
fi

# Build manifest JSON
cat > "$MANIFEST_FILE" <<EOF
{
  "generated": "${GENERATED}",
  "node": {
    "commit": "${NODE_COMMIT}",
    "version": "${NODE_VERSION}"
  },
  "core": {
    "version": "${CORE_VERSION}"
  },
  "cli": {
    "version": "${CLI_VERSION}"
  },
  "pins": ${PINS_JSON},
  "pin_strict": "${PIN_STRICT}",
  "compilation": {
    "strict_mode": "${STRICT_MODE}",
    "cognitive_level": "${COGNITIVE_LEVEL}"
  },
  "benchmarks": {
    "baselines_date": "${BASELINES_DATE}",
    "total_scenarios": ${TOTAL_SCENARIOS}
  }
}
EOF

echo "Manifest generated: ${MANIFEST_FILE}"
jq . "$MANIFEST_FILE"
