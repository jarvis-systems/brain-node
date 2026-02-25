#!/bin/bash

# Enterprise Secret Reference Guard
# Prevents hardcoded secret values and unmasked prefixes.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FOUND_VIOLATIONS=0

echo "Checking for risky secret references..."

# 1. Check for real Anthropic key prefix (sk-ant-)
# We allow mentions in documentation and this script itself if they are just the prefix.
# We fail if we see sk-ant- followed by characters that look like a key (e.g. sk-ant-v1-...)
if grep -rn "sk-ant-[a-zA-Z0-9]\{10,\}" . --exclude-dir=vendor --exclude-dir=memory --exclude-dir=dist --exclude-dir=.brain; then
    echo -e "${RED}FAIL:${NC} Potential real Anthropic API key detected (sk-ant- with suffix)"
    FOUND_VIOLATIONS=$((FOUND_VIOLATIONS + 1))
fi

# 2. Check for ANTHROPIC_API_KEY assignments with non-placeholder values
# Allowed: empty string, placeholders like ${{ secrets.* }}, [REDACTED], FOUND, NOT FOUND
# We use a safer grep approach to avoid syntax errors in the script itself.
RISKY_ASSIGNMENTS=$(grep -rn "ANTHROPIC_API_KEY=" . --exclude-dir=vendor --exclude-dir=memory --exclude-dir=dist --exclude-dir=.brain | \
   grep -vE "ANTHROPIC_API_KEY=\"?(\\\$\{\{ secrets\.ANTHROPIC_API_KEY \}\}|\[REDACTED\]|FOUND|NOT FOUND)?\"?|ANTHROPIC_API_KEY=,|ANTHROPIC_API_KEY\s*=>" || true)

if [ -n "$RISKY_ASSIGNMENTS" ]; then
    echo "$RISKY_ASSIGNMENTS"
    echo -e "${RED}FAIL:${NC} Potentially hardcoded ANTHROPIC_API_KEY assignment detected"
    FOUND_VIOLATIONS=$((FOUND_VIOLATIONS + 1))
fi

if [ "$FOUND_VIOLATIONS" -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}PASS:${NC} No risky secret references found."
exit 0
