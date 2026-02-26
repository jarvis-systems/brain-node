#!/usr/bin/env bash
#
# Check MCP Output Contract: truly single-line JSON on stdout
# Usage: scripts/check-mcp-output-contract.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

function log_check() {
    echo "Checking: $1..."
}

function assert_strictly_single_line() {
    local cmd="$1"
    local name="$2"
    local tmp_file="out.tmp"
    
    # Run command and capture REAL stdout to file
    eval "$cmd" > "$tmp_file" 2>/dev/null || true
    
    local output=$(cat "$tmp_file")
    
    # 1. Must be valid JSON
    if ! jq empty "$tmp_file" 2>/dev/null; then
        echo "FAIL: $name output is not valid JSON"
        echo "Note: first 120 chars: ${output:0:120}..."
        rm -f "$tmp_file"
        exit 1
    fi
    
    # 2. Must be exactly one line (exactly one newline character at the end)
    # wc -l counts newline characters.
    local nl_count=$(wc -l < "$tmp_file" | tr -d ' ')
    
    if [[ "$nl_count" -ne 1 ]]; then
        echo "FAIL: $name output is not strictly single-line"
        echo "Byte-level newline count: $nl_count (expected 1)"
        echo "Note: first 120 chars: ${output:0:120}..."
        rm -f "$tmp_file"
        exit 1
    fi
    
    # 3. No internal newlines (captured bash variable should have NO newlines)
    # Bash $(cat file) removes trailing newlines. If any remain, they are internal.
    if [[ "$output" == *$'\n'* ]]; then
         echo "FAIL: $name output contains internal newlines"
         echo "Note: first 120 chars: ${output:0:120}..."
         rm -f "$tmp_file"
         exit 1
    fi
    
    rm -f "$tmp_file"
}

# 1. Test mcp:list
log_check "mcp:list output contract"
assert_strictly_single_line "php cli/bin/brain mcp:list --no-interaction" "mcp:list"
echo "  PASS: mcp:list is strictly single-line"

# 2. Test mcp:describe
log_check "mcp:describe output contract"
assert_strictly_single_line "BRAIN_TEST_MODE=1 php cli/bin/brain mcp:describe --server=mock-echo --no-interaction" "mcp:describe"
echo "  PASS: mcp:describe is strictly single-line"

# 3. Test mcp:call (blocked)
log_check "mcp:call (blocked) output contract"
assert_strictly_single_line "php cli/bin/brain mcp:call --server=vector-memory --tool=non-existent-epic-secret --input='{}' --no-interaction" "mcp:call (blocked)"
echo "  PASS: mcp:call (blocked) is strictly single-line"

# 4. Test mcp:diagnose
log_check "mcp:diagnose output contract"
assert_strictly_single_line "php cli/bin/brain mcp:diagnose --no-interaction" "mcp:diagnose"
echo "  PASS: mcp:diagnose is strictly single-line"

echo "PASS: MCP output contract verified"
