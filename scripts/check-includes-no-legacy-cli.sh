#!/usr/bin/env bash
#
# Check: Legacy CLI invocations in instruction includes
# Usage: scripts/check-includes-no-legacy-cli.sh
#
# FORBID patterns inside core/src/Includes/**/*.php:
#   - brain docs (must use BrainCLI::MCP__DOCS_SEARCH)
#   - brain diagnose (must use BrainCLI::MCP__DIAGNOSE)
#   - brain list:masters (must use BrainCLI::MCP__LIST_MASTERS)
#   - brain tools:* (must use BrainCLI::MCP__*)
#
# REQUIRE: at least one occurrence of "BrainCLI::MCP__DOCS_SEARCH" in includes (sanity)
#
# Exit codes:
#   0 - No legacy CLI invocations found
#   1 - Legacy CLI invocations detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INCLUDES_DIR="$PROJECT_ROOT/.brain/vendor/jarvis-brain/core/src/Includes"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

LEGACY_COUNT=0
LEGACY_FINDINGS=""

# FORBID patterns - legacy CLI commands
FORBID_PATTERNS=(
    '\bbrain\s+docs\b'
    '\bbrain\s+diagnose\b'
    '\bbrain\s+list:masters\b'
    '\bbrain\s+tools:'
)

# Check for legacy patterns
for pattern in "${FORBID_PATTERNS[@]}"; do
    while IFS=: read -r file line content; do
        [[ -z "$file" ]] && continue
        relative="${file#$PROJECT_ROOT/}"
        LEGACY_COUNT=$((LEGACY_COUNT + 1))
        LEGACY_FINDINGS="$LEGACY_FINDINGS$relative:$line: $content\n"
        echo -e "${RED}FAIL${NC} $relative:$line — legacy CLI: $content"
    done < <(grep -rnE "$pattern" "$INCLUDES_DIR" --include='*.php' 2>/dev/null || true)
done

# REQUIRE: at least one "BrainCLI::MCP__DOCS_SEARCH" (sanity check)
CANONICAL_COUNT=$(grep -rnE 'BrainCLI::MCP__DOCS_SEARCH' "$INCLUDES_DIR" --include='*.php' 2>/dev/null | wc -l | tr -d ' ')

if [[ $LEGACY_COUNT -gt 0 ]]; then
    echo ""
    echo -e "${RED}FAIL${NC}: Found $LEGACY_COUNT legacy CLI invocation(s) in includes"
    echo "  Replace: brain docs → BrainCLI::MCP__DOCS_SEARCH(['query' => '...'])"
    echo "  Replace: brain diagnose → BrainCLI::MCP__DIAGNOSE([...])"
    echo "  Replace: brain list:masters → BrainCLI::MCP__LIST_MASTERS([...])"
    echo "  Replace: brain tools:docs_search → BrainCLI::MCP__DOCS_SEARCH(['query' => '...'])"
    exit 1
fi

if [[ $CANONICAL_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}WARN${NC}: No 'BrainCLI::MCP__DOCS_SEARCH' found in includes (sanity check failed)"
    exit 1
fi

echo -e "${GREEN}PASS${NC}: No legacy CLI invocations in includes (canonical: $CANONICAL_COUNT)"
exit 0
