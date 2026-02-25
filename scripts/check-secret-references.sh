#!/bin/bash

# Enterprise Secret Reference Guard v2
# Prevents hardcoded secret values and unmasked key tails.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FOUND_VIOLATIONS=0

echo "Checking for risky secret references (strict mode)..."

# 1. Check for real-looking Anthropic key patterns (sk-ant- followed by alphanumeric)
# Allowed: naked "sk-ant-" followed by space, quote, bracket, or EOL.
# Regex fails if "sk-ant-" is immediately followed by a-z, A-Z, or 0-9.
RISKY_KEYS=$(grep -rnE "sk-ant-[a-zA-Z0-9]" . --exclude-dir=vendor --exclude-dir=memory --exclude-dir=dist --exclude-dir=.brain || true)

if [ -n "$RISKY_KEYS" ]; then
    echo -e "${RED}FAIL:${NC} Potential real Anthropic API key detected (unmasked tail):"
    echo "$RISKY_KEYS" | cut -d: -f1,2 | sed 's/$/: [REDACTED KEY TAIL]/'
    FOUND_VIOLATIONS=$((FOUND_VIOLATIONS + 1))
fi

# 2. Check for ANTHROPIC_API_KEY assignments with non-placeholder values
RISKY_ASSIGNMENTS=$(grep -rn "ANTHROPIC_API_KEY=" . --exclude-dir=vendor --exclude-dir=memory --exclude-dir=dist --exclude-dir=.brain | \
   grep -vE "ANTHROPIC_API_KEY=\"?(\\\$\{\{ secrets\.ANTHROPIC_API_KEY \}\}|\[REDACTED\]|FOUND|NOT FOUND)?\"?|ANTHROPIC_API_KEY=,|ANTHROPIC_API_KEY\s*=>" || true)

if [ -n "$RISKY_ASSIGNMENTS" ]; then
    echo -e "${RED}FAIL:${NC} Potentially hardcoded ANTHROPIC_API_KEY assignment detected:"
    echo "$RISKY_ASSIGNMENTS" | cut -d: -f1,2 | sed 's/$/: [REDACTED ASSIGNMENT]/'
    FOUND_VIOLATIONS=$((FOUND_VIOLATIONS + 1))
fi

if [ "$FOUND_VIOLATIONS" -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}PASS:${NC} No risky secret references found."
exit 0
