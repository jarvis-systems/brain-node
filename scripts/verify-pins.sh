#!/usr/bin/env bash
# verify-pins.sh — Verify compiled .mcp.json against pins.json
# Exit 0 = all pins verified (or PIN_STRICT != 1)
# Exit 1 = pin mismatch detected

set -euo pipefail

PIN_STRICT="${PIN_STRICT:-0}"
PINS_FILE="pins.json"
MCP_FILE=".mcp.json"

if [[ "$PIN_STRICT" != "1" ]]; then
    echo "PIN_STRICT != 1, skipping pin verification."
    exit 0
fi

if [[ ! -f "$PINS_FILE" ]]; then
    echo "ERROR: $PINS_FILE not found."
    exit 1
fi

if [[ ! -f "$MCP_FILE" ]]; then
    echo "ERROR: $MCP_FILE not found."
    exit 1
fi

FAILED=0

while IFS='=' read -r PACKAGE VERSION; do
    [[ -z "$PACKAGE" || -z "$VERSION" ]] && continue

    # uvx uses == separator
    EXPECTED="${PACKAGE}==${VERSION}"

    if grep -q "\"${EXPECTED}\"" "$MCP_FILE"; then
        echo "PASS: ${PACKAGE} pinned to ${VERSION}"
    else
        echo "FAIL: ${PACKAGE} expected ${EXPECTED} in ${MCP_FILE}"
        FAILED=1
    fi
done < <(jq -r 'to_entries | map(select(.key != "_meta")) | .[] | "\(.key)=\(.value)"' "$PINS_FILE")

if [[ "$FAILED" -eq 1 ]]; then
    echo ""
    echo "Pin verification FAILED. Recompile with PIN_STRICT=1:"
    echo "  PIN_STRICT=1 brain compile"
    exit 1
fi

echo ""
echo "All pins verified."
exit 0
