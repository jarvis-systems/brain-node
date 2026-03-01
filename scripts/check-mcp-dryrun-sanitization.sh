#!/usr/bin/env bash
#
# check-mcp-dryrun-sanitization.sh
# Verifies mcp:call --dry-run does not leak sensitive key names
#
# Exit codes:
#   0 - PASS: No sensitive keys found
#   1 - FAIL: Sensitive keys detected in output
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/brain-cli.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Forbidden words (case-insensitive)
FORBIDDEN_WORDS="api-key|apikey|token|authorization|bearer"
FORBIDDEN_FLAGS="--api-key|--token|--secret|--password|--auth|--bearer|--authorization"

echo "=== MCP Dry-Run Sanitization Check ==="

# Run dry-run for context7/search
OUTPUT=$(brain_cli mcp:call --server=context7 --tool=search --input='{"query":"test"}' --dry-run 2>/dev/null) || {
    echo -e "${RED}FAIL: dry-run command failed${NC}"
    exit 1
}

# Check 1: Output is valid JSON
echo "$OUTPUT" | jq empty 2>/dev/null || {
    echo -e "${RED}FAIL: output is not valid JSON${NC}"
    echo "$OUTPUT"
    exit 1
}

# Check 2: stderr is empty
STDERR_BYTES=$(brain_cli mcp:call --server=context7 --tool=search --input='{"query":"test"}' --dry-run 2>&1 >/dev/null | wc -c | tr -d ' ')
if [[ "$STDERR_BYTES" -gt 0 ]]; then
    echo -e "${RED}FAIL: stderr is not empty ($STDERR_BYTES bytes)${NC}"
    exit 1
fi
echo "✓ stderr is empty"

# Check 3: No forbidden words in output (case-insensitive)
LOWER_OUTPUT=$(echo "$OUTPUT" | tr '[:upper:]' '[:lower:]')
if echo "$LOWER_OUTPUT" | grep -qE "($FORBIDDEN_WORDS)"; then
    MATCHED=$(echo "$LOWER_OUTPUT" | grep -oE "($FORBIDDEN_WORDS)" | head -1)
    echo -e "${RED}FAIL: forbidden word detected: $MATCHED${NC}"
    exit 1
fi
echo "✓ no sensitive key names in output"

# Check 4: No forbidden flags in command/args
COMMAND=$(echo "$OUTPUT" | jq -r '.data.command // ""' 2>/dev/null || echo "")
ARGS=$(echo "$OUTPUT" | jq -r '.data.args | join(" ") // ""' 2>/dev/null || echo "")
COMBINED=$(echo "$COMMAND $ARGS" | tr '[:upper:]' '[:lower:]')

if echo "$COMBINED" | grep -qE "($FORBIDDEN_FLAGS)"; then
    MATCHED=$(echo "$COMBINED" | grep -oE "($FORBIDDEN_FLAGS)" | head -1)
    echo -e "${RED}FAIL: forbidden flag detected: $MATCHED${NC}"
    exit 1
fi
echo "✓ no sensitive flags in command/args"

# Check 5: ok=true
OK=$(echo "$OUTPUT" | jq -r '.ok // false' 2>/dev/null)
if [[ "$OK" != "true" ]]; then
    echo -e "${RED}FAIL: ok is not true${NC}"
    exit 1
fi
echo "✓ ok=true"

echo -e "${GREEN}PASS: MCP dry-run sanitization verified${NC}"
exit 0
