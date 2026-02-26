#!/bin/bash

# Enterprise Secret Reference Guard v3
# Prevents hardcoded secret values and unmasked key tails.
# Parametrized for future extensibility.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration table: "PREFIX:RULE"
# Rules:
#   ALNUM_TAIL - Fail if prefix is followed by [a-zA-Z0-9]
PREFIXES=(
    "sk-ant-:ALNUM_TAIL"
)

# Internal Self-Test Logic
if [[ "${SELF_TEST:-0}" == "1" ]]; then
    echo "Running guard self-test..."
    
    # Test case 1: Naked prefix (Allowed)
    if echo "prefix sk-ant- is fine" | grep -qE "sk-ant-[a-zA-Z0-9]"; then
        echo -e "${RED}SELF-TEST FAIL:${NC} Naked prefix matched erroneously"
        exit 1
    fi
    
    # Test case 2: Prefix with tail (Forbidden)
    TAIL="REALLYBAD"
    if ! echo "sk-ant-${TAIL}" | grep -qE "sk-ant-[a-zA-Z0-9]"; then
        echo -e "${RED}SELF-TEST FAIL:${NC} Prefix with tail not matched"
        exit 1
    fi
    
    echo -e "${GREEN}SELF-TEST PASS${NC}"
    exit 0
fi

FOUND_VIOLATIONS=0

echo "Checking for risky secret references (parametrized)..."

# 1. Check for real-looking key patterns based on prefix table
for entry in "${PREFIXES[@]}"; do
    PREFIX="${entry%%:*}"
    RULE="${entry#*:}"
    
    if [[ "$RULE" == "ALNUM_TAIL" ]]; then
        PATTERN="${PREFIX}[a-zA-Z0-9]"
        RISKY_KEYS=$(grep -rnE "$PATTERN" . --exclude-dir=vendor --exclude-dir=memory --exclude-dir=dist --exclude-dir=.brain || true)
        
        if [ -n "$RISKY_KEYS" ]; then
            echo -e "${RED}FAIL:${NC} Potential real key detected for prefix '$PREFIX' (unmasked tail):"
            echo "$RISKY_KEYS" | cut -d: -f1,2 | sed 's/$/: [REDACTED KEY TAIL]/'
            FOUND_VIOLATIONS=$((FOUND_VIOLATIONS + 1))
        fi
    fi
done

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
