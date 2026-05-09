#!/usr/bin/env bash
#
# MCP Tool Policy Check
#
# Verifies compiled instruction surfaces keep the MCP JSON contract and do not
# leak legacy PHP helper syntax into client-facing prompts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ERRORS=0
SURFACES=(
    "$PROJECT_ROOT/.claude/CLAUDE.md"
    "$PROJECT_ROOT/AGENTS.md"
    "$PROJECT_ROOT/GEMINI.md"
    "$PROJECT_ROOT/QWEN.md"
)

for surface in "${SURFACES[@]}"; do
    if [[ ! -f "$surface" ]]; then
        echo "missing surface: ${surface#$PROJECT_ROOT/}"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    if ! grep -q 'Mcp-json-only' "$surface"; then
        echo "missing Mcp-json-only anchor: ${surface#$PROJECT_ROOT/}"
        ERRORS=$((ERRORS + 1))
    fi
done

LEGACY_COUNT=$(grep -R -cE 'Mcp[A-Z][A-Za-z]+::call\(' \
    "$PROJECT_ROOT/.claude" \
    "$PROJECT_ROOT/.codex" \
    "$PROJECT_ROOT/.gemini" \
    "$PROJECT_ROOT/.qwen" \
    "$PROJECT_ROOT/.opencode" \
    2>/dev/null | awk -F: '{sum += $2} END {print sum + 0}' || true)

if [[ "$LEGACY_COUNT" -ne 0 ]]; then
    echo "legacy MCP helper syntax found in compiled artifacts: $LEGACY_COUNT"
    ERRORS=$((ERRORS + 1))
fi

exit "$ERRORS"
