#!/usr/bin/env bash
#
# Check 47: brain-tools Toolset Freeze
# Verifies toolset + schema contracts via live JSON-RPC
#
# FAIL if:
#   A) tools/list not exactly ["diagnose","docs_search","list_masters"] (sorted)
#   B) docs_search schema missing required options or has unknown extras
#   C) diagnose schema not empty
#   D) list_masters schema not empty (agent is server-side via --agent)
#   E) Any stderr output
#   F) Invalid JSON output

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Expected toolset (sorted)
EXPECTED_TOOLS='["diagnose","docs_search","list_masters"]'

# Expected docs_search options (25 options, alphabetically sorted)
EXPECTED_DOCS_SEARCH_OPTIONS='["as","cache","cache-health","cache-stats","clear-cache","code","download","exact","extract-keywords","freshness","global","headers","keywords","limit","links","matches","query","scaffold","snippets","stats","strict","trust","undocumented","update","validate"]'

# Get tools/list response
STDERR_FILE=$(mktemp)
TOOLS_RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$STDERR_FILE")
STDERR_BYTES=$(wc -c < "$STDERR_FILE" | tr -d ' ')
rm -f "$STDERR_FILE"

# E) Check stderr is empty
if [[ "$STDERR_BYTES" -gt 0 ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[E] stderr not empty ($STDERR_BYTES bytes)"
fi

# F) Check valid JSON
if ! echo "$TOOLS_RESPONSE" | jq empty 2>/dev/null; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[F] Invalid JSON output"
    echo -e "[FAIL] Check 47: brain-tools Toolset Freeze ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

# A) Check tools list exact and sorted
ACTUAL_TOOLS=$(echo "$TOOLS_RESPONSE" | jq -c '.result.tools | sort_by(.name) | [.[] | .name]')
if [[ "$ACTUAL_TOOLS" != "$EXPECTED_TOOLS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[A] tools/list mismatch:"
    ERROR_DETAILS+="\n  Expected: $EXPECTED_TOOLS"
    ERROR_DETAILS+="\n  Actual:   $ACTUAL_TOOLS"
fi

# B) Check docs_search schema
DOCS_SEARCH_PROPS=$(echo "$TOOLS_RESPONSE" | jq -c '.result.tools[] | select(.name=="docs_search") | .inputSchema.properties | keys | sort' 2>/dev/null || echo "null")
if [[ "$DOCS_SEARCH_PROPS" != "$EXPECTED_DOCS_SEARCH_OPTIONS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[B] docs_search schema mismatch:"
    ERROR_DETAILS+="\n  Expected: $EXPECTED_DOCS_SEARCH_OPTIONS"
    ERROR_DETAILS+="\n  Actual:   $DOCS_SEARCH_PROPS"
fi

# C) Check diagnose schema empty
DIAGNOSE_PROPS=$(echo "$TOOLS_RESPONSE" | jq -c '.result.tools[] | select(.name=="diagnose") | .inputSchema.properties' 2>/dev/null || echo "null")
if [[ "$DIAGNOSE_PROPS" != "[]" ]] && [[ "$DIAGNOSE_PROPS" != "{}" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[C] diagnose schema not empty: $DIAGNOSE_PROPS"
fi

# D) Check list_masters schema is empty (agent is server-side via --agent)
LIST_MASTERS_PROPS=$(echo "$TOOLS_RESPONSE" | jq -c '.result.tools[] | select(.name=="list_masters") | .inputSchema.properties' 2>/dev/null || echo "null")

if [[ "$LIST_MASTERS_PROPS" != '[]' ]] && [[ "$LIST_MASTERS_PROPS" != '{}' ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[D] list_masters schema not empty (agent is server-side): $LIST_MASTERS_PROPS"
fi

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 47: brain-tools Toolset Freeze ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 47: brain-tools Toolset Freeze"
exit 0
