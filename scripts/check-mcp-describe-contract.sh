#!/usr/bin/env bash
#
# Check MCP Describe Contract — Verifies mcp:describe output for all enabled servers
# Usage: scripts/check-mcp-describe-contract.sh
#
# Validates:
#   1. stderr is byte-empty for each enabled server
#   2. output is valid JSON
#   3. tools have non-empty descriptions
#   4. input_schema has canonical structure
#
# Exit codes:
#   0 - All servers pass
#   1 - One or more servers fail
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

ERRORS=0

# Get enabled servers from mcp:list
SERVERS=$(php cli/bin/brain mcp:list 2>/dev/null | jq -r '.data.servers[] | select(.enabled==true) | .id')

for server in $SERVERS; do
    echo "Checking: $server"
    
    # Run describe and capture stdout/stderr separately
    STDOUT=$(mktemp)
    STDERR=$(mktemp)
    
    php cli/bin/brain mcp:describe --server="$server" > "$STDOUT" 2> "$STDERR" || true
    
    # Check stderr is empty
    STDERR_BYTES=$(wc -c < "$STDERR" | tr -d ' ')
    if [[ "$STDERR_BYTES" != "0" ]]; then
        echo "  FAIL: stderr not empty ($STDERR_BYTES bytes)"
        cat "$STDERR"
        ERRORS=$((ERRORS + 1))
        rm -f "$STDOUT" "$STDERR"
        continue
    fi
    
    # Check valid JSON
    if ! jq empty < "$STDOUT" 2>/dev/null; then
        echo "  FAIL: output is not valid JSON"
        ERRORS=$((ERRORS + 1))
        rm -f "$STDOUT" "$STDERR"
        continue
    fi
    
    # Check ok==true
    OK=$(jq -r '.ok' < "$STDOUT")
    if [[ "$OK" != "true" ]]; then
        echo "  FAIL: .ok is not true (got: $OK)"
        ERRORS=$((ERRORS + 1))
        rm -f "$STDOUT" "$STDERR"
        continue
    fi
    
    # Check each tool has non-empty description
    TOOL_COUNT=$(jq '.data.tools | length' < "$STDOUT")
    DESC_EMPTY=$(jq '[.data.tools[] | select(.description == "" or .description == "No description available.")] | length' < "$STDOUT")
    
    if [[ "$DESC_EMPTY" -gt 0 ]]; then
        echo "  FAIL: $DESC_EMPTY tools have empty/placeholder descriptions"
        ERRORS=$((ERRORS + 1))
        rm -f "$STDOUT" "$STDERR"
        continue
    fi
    
    # Check input_schema structure
    SCHEMA_INVALID=$(jq '[.data.tools[] | select(.input_schema.type != "object" or (.input_schema.properties | type) != "object" or (.input_schema.required | type) != "array")] | length' < "$STDOUT")
    
    if [[ "$SCHEMA_INVALID" -gt 0 ]]; then
        echo "  FAIL: $SCHEMA_INVALID tools have invalid input_schema structure"
        ERRORS=$((ERRORS + 1))
        rm -f "$STDOUT" "$STDERR"
        continue
    fi
    
    echo "  PASS: $TOOL_COUNT tools, valid JSON, empty stderr, complete metadata"
    
    rm -f "$STDOUT" "$STDERR"
done

if [[ "$ERRORS" -gt 0 ]]; then
    echo ""
    echo "FAIL: $ERRORS server(s) failed contract check"
    exit 1
fi

echo ""
echo "PASS: All enabled servers pass mcp:describe contract"
exit 0
