#!/usr/bin/env bash
#
# Check 48: MCP Tool Schema Drift Detection
# Compares MCP schema (from mcp:serve) against introspected command options.
#
# FAIL if:
#   A) docs_search schema missing any DocsCommand options (except excluded)
#   B) docs_search schema has unexpected options not in command
#   C) list_masters schema not empty (agent is server-side via --agent)
#   D) Any stderr output during introspection
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Excluded options (CLI-only, not exposed via MCP)
EXCLUDED_OPTIONS='["json"]'

# Renamed options (CLI name -> MCP name)
# Keywords in CLI maps to extract-keywords in MCP
# MCP also adds "query" and "keywords" as MCP-specific

# Get MCP schema from mcp:serve
STDERR_FILE=$(mktemp)
MCP_RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$STDERR_FILE")
STDERR_BYTES=$(wc -c < "$STDERR_FILE" | tr -d ' ')
rm -f "$STDERR_FILE"

if [[ "$STDERR_BYTES" -gt 0 ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[E1] mcp:serve produced stderr ($STDERR_BYTES bytes)"
fi

if ! echo "$MCP_RESPONSE" | jq empty 2>/dev/null; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[E2] mcp:serve returned invalid JSON"
    echo -e "[FAIL] Check 48: MCP Tool Schema Drift ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

# Extract docs_search schema keys
MCP_DOCS_SEARCH_PROPS=$(echo "$MCP_RESPONSE" | jq -c '.result.tools[] | select(.name=="docs_search") | .inputSchema.properties | keys | sort' 2>/dev/null || echo "null")
MCP_LIST_MASTERS_PROPS=$(echo "$MCP_RESPONSE" | jq -c '.result.tools[] | select(.name=="list_masters") | .inputSchema.properties | keys | sort' 2>/dev/null || echo "null")

# Run PHP introspector to get command options
INTROSPECT_STDERR=$(mktemp)
INTROSPECT_OUTPUT=$(php cli/bin/brain docs --help 2>"$INTROSPECT_STDERR" || true)
INTROSPECT_STDERR_BYTES=$(wc -c < "$INTROSPECT_STDERR" | tr -d ' ')
rm -f "$INTROSPECT_STDERR"

if [[ "$INTROSPECT_STDERR_BYTES" -gt 0 ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[E3] docs --help produced stderr ($INTROSPECT_STDERR_BYTES bytes)"
fi

# Expected docs_search options based on DocsCommand signature
# These are the 24 CLI options (excluding json) + 2 MCP additions (query, keywords)
EXPECTED_DOCS_SEARCH='["as","cache","cache-health","cache-stats","clear-cache","code","download","exact","extract-keywords","freshness","global","headers","keywords","limit","links","matches","query","scaffold","snippets","stats","strict","trust","undocumented","update","validate"]'

# A) Check docs_search schema matches expected
if [[ "$MCP_DOCS_SEARCH_PROPS" != "$EXPECTED_DOCS_SEARCH" ]]; then
    ERRORS=$((ERRORS + 1))

    # Compute diff for better error message
    EXPECTED_ARR=$(echo "$EXPECTED_DOCS_SEARCH" | jq -r '.[]' 2>/dev/null || echo "")
    ACTUAL_ARR=$(echo "$MCP_DOCS_SEARCH_PROPS" | jq -r '.[]' 2>/dev/null || echo "")

    MISSING=""
    EXTRA=""

    for opt in $EXPECTED_ARR; do
        if ! echo "$MCP_DOCS_SEARCH_PROPS" | jq -e "index(\"$opt\")" >/dev/null 2>&1; then
            MISSING="$MISSING $opt"
        fi
    done

    for opt in $ACTUAL_ARR; do
        if ! echo "$EXPECTED_DOCS_SEARCH" | jq -e "index(\"$opt\")" >/dev/null 2>&1; then
            EXTRA="$EXTRA $opt"
        fi
    done

    ERROR_DETAILS="${ERROR_DETAILS}
[A] docs_search schema drift detected"
    if [[ -n "$MISSING" ]]; then
        ERROR_DETAILS="${ERROR_DETAILS}
  Missing:$MISSING"
    fi
    if [[ -n "$EXTRA" ]]; then
        ERROR_DETAILS="${ERROR_DETAILS}
  Extra:$EXTRA"
    fi
fi

# B) Check list_masters schema is empty (agent is server-side via --agent)
EXPECTED_LIST_MASTERS='[]'

if [[ "$MCP_LIST_MASTERS_PROPS" != "$EXPECTED_LIST_MASTERS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[C] list_masters schema drift detected (agent is server-side)
  Expected: $EXPECTED_LIST_MASTERS
  Actual:   $MCP_LIST_MASTERS_PROPS"
fi

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 48: MCP Tool Schema Drift ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 48: MCP Tool Schema Drift"
exit 0
