#!/usr/bin/env bash
#
# Check 49: MCP tools/list Snapshot
# Validates exact schema contract at JSON-RPC boundary.
#
# FAIL if:
#   A) stderr not empty
#   B) Invalid JSON output
#   C) Tool names not exactly ["diagnose","docs_search","list_masters"] (sorted)
#   D) docs_search properties != expected set
#   E) list_masters properties != [] (agent is server-side)
#   F) diagnose properties != []
#   G) additionalProperties != false for any tool
#   H) required arrays not sorted
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# Expected tools (sorted)
EXPECTED_TOOLS='["diagnose","docs_search","list_masters"]'

# Expected docs_search properties (25 options, alphabetically sorted)
EXPECTED_DOCS_PROPS='["as","cache","cache-health","cache-stats","clear-cache","code","download","exact","extract-keywords","freshness","global","headers","keywords","limit","links","matches","query","scaffold","snippets","stats","strict","trust","undocumented","update","validate"]'

# Get tools/list response
STDERR_FILE=$(mktemp)
RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | BRAIN_AGENT_ID=claude php cli/bin/brain mcp:serve 2>"$STDERR_FILE")
STDERR_BYTES=$(wc -c < "$STDERR_FILE" | tr -d ' ')
rm -f "$STDERR_FILE"

# A) Check stderr is empty
if [[ "$STDERR_BYTES" -gt 0 ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[A] stderr not empty ($STDERR_BYTES bytes)"
fi

# B) Check valid JSON
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[B] Invalid JSON output"
    echo -e "[FAIL] Check 49: MCP tools/list Snapshot ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

# C) Check tool names exact and sorted
ACTUAL_TOOLS=$(echo "$RESPONSE" | jq -c '.result.tools | sort_by(.name) | [.[] | .name]')
if [[ "$ACTUAL_TOOLS" != "$EXPECTED_TOOLS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[C] Tool names mismatch:
  Expected: $EXPECTED_TOOLS
  Actual:   $ACTUAL_TOOLS"
fi

# D) Check docs_search properties
DOCS_PROPS=$(echo "$RESPONSE" | jq -c '.result.tools[] | select(.name=="docs_search") | .inputSchema.properties | keys | sort')
if [[ "$DOCS_PROPS" != "$EXPECTED_DOCS_PROPS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[D] docs_search properties mismatch:
  Expected: $EXPECTED_DOCS_PROPS
  Actual:   $DOCS_PROPS"
fi

# E) Check list_masters properties (empty - agent is server-side)
LIST_PROPS=$(echo "$RESPONSE" | jq -c '.result.tools[] | select(.name=="list_masters") | .inputSchema.properties | keys | sort')
EXPECTED_LIST_PROPS='[]'
if [[ "$LIST_PROPS" != "$EXPECTED_LIST_PROPS" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[E] list_masters properties mismatch (agent is server-side):
  Expected: $EXPECTED_LIST_PROPS
  Actual:   $LIST_PROPS"
fi

# F) Check diagnose properties empty
DIAG_PROPS=$(echo "$RESPONSE" | jq -c '.result.tools[] | select(.name=="diagnose") | .inputSchema.properties | keys | sort')
if [[ "$DIAG_PROPS" != "[]" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[F] diagnose properties not empty: $DIAG_PROPS"
fi

# G) Check additionalProperties == false for all tools
for tool in diagnose docs_search list_masters; do
    ADD_PROP=$(echo "$RESPONSE" | jq ".result.tools[] | select(.name==\"$tool\") | .inputSchema.additionalProperties")
    if [[ "$ADD_PROP" != "false" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[G] $tool additionalProperties != false (got: $ADD_PROP)"
    fi
done

# H) Check required arrays are sorted for all tools
for tool in diagnose docs_search list_masters; do
    REQUIRED=$(echo "$RESPONSE" | jq -c ".result.tools[] | select(.name==\"$tool\") | .inputSchema.required // []")
    REQUIRED_SORTED=$(echo "$REQUIRED" | jq -c 'sort')
    if [[ "$REQUIRED" != "$REQUIRED_SORTED" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[H] $tool required array not sorted:
  Got:      $REQUIRED
  Expected: $REQUIRED_SORTED"
    fi
done

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 49: MCP tools/list Snapshot ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 49: MCP tools/list Snapshot"
exit 0
