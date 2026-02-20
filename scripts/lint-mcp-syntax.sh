#!/bin/bash
#
# MCP Syntax Lint — Detects legacy pseudo-JSON syntax in MCP calls
# Usage: scripts/lint-mcp-syntax.sh [--strict]
#
# Exit codes:
#   0 - No legacy syntax found
#   1 - Legacy syntax detected (fail)
#   2 - Configuration error
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Directories to scan (relative to project root)
# Auto-detect: scan all compiled output directories that exist
SCAN_DIRS=()
for candidate in ".opencode/agent" ".opencode/command" ".claude/agents" ".claude/commands" ".claude/skills"; do
    if [[ -d "$PROJECT_ROOT/$candidate" ]]; then
        SCAN_DIRS+=("$candidate")
    fi
done
# Also scan top-level brain files
for candidate in ".claude/CLAUDE.md" ".opencode/OPENCODE.md"; do
    if [[ -f "$PROJECT_ROOT/$candidate" ]]; then
        SCAN_DIRS+=("$candidate")
    fi
done

# Directories to exclude (within scan dirs)
EXCLUDE_PATTERNS=(
    "node_modules"
    ".git"
    "vendor"
)

# Legacy patterns (these trigger failure in strict mode)
# Pattern 1: String pseudo-object - mcp__*__*('{...}')
LEGACY_PATTERN_1="mcp__[a-z-]+__[a-z_]+\s*\(\s*'{"

# Pattern 2: Named arguments without braces - mcp__*__*(query: ...)
LEGACY_PATTERN_2="mcp__[a-z-]+__[a-z_]+\s*\(\s*[a-z_]+\s*:"

# Pattern 3: Double-quoted pseudo-object - mcp__*__*("{...}")
LEGACY_PATTERN_3='mcp__[a-z-]+__[a-z_]+\s*\(\s*"{'

# Build exclude args for grep
EXCLUDE_GREP=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_GREP="$EXCLUDE_GREP --exclude-dir=$pattern"
done

# Function to check for legacy patterns
check_legacy_patterns() {
    local file="$1"
    local errors=0
    
    # Pattern 1: String pseudo-object with single quotes
    if grep -qE "$LEGACY_PATTERN_1" "$file" 2>/dev/null; then
        echo -e "${RED}ERROR: Legacy pseudo-object syntax (single quotes)${NC}"
        echo "  File: $file"
        grep -nE "$LEGACY_PATTERN_1" "$file" | head -3 | while read line; do
            echo "  → $line"
        done
        ((errors++))
    fi
    
    # Pattern 2: Named arguments without braces
    if grep -qE "$LEGACY_PATTERN_2" "$file" 2>/dev/null; then
        echo -e "${RED}ERROR: Legacy named arguments syntax (no braces)${NC}"
        echo "  File: $file"
        grep -nE "$LEGACY_PATTERN_2" "$file" | head -3 | while read line; do
            echo "  → $line"
        done
        ((errors++))
    fi
    
    # Pattern 3: String pseudo-object with double quotes
    if grep -qE "$LEGACY_PATTERN_3" "$file" 2>/dev/null; then
        echo -e "${RED}ERROR: Legacy pseudo-object syntax (double quotes)${NC}"
        echo "  File: $file"
        grep -nE "$LEGACY_PATTERN_3" "$file" | head -3 | while read line; do
            echo "  → $line"
        done
        ((errors++))
    fi
    
    return $errors
}

# Main
echo "=========================================="
echo "MCP Syntax Lint"
echo "=========================================="
echo ""

# Default: STRICT (fail on legacy). Use --warn to downgrade.
STRICT_MODE="${STRICT_MCP_LINT:-1}"
if [[ "$1" == "--warn" ]] || [[ "$1" == "-w" ]]; then
    STRICT_MODE=0
fi
# Legacy flag support
if [[ "$1" == "--strict" ]] || [[ "$1" == "-s" ]]; then
    STRICT_MODE=1
fi

if [[ "$STRICT_MODE" == "1" ]]; then
    echo -e "${YELLOW}Running in STRICT mode - legacy syntax will fail${NC}"
else
    echo -e "${YELLOW}Running in WARN mode - legacy syntax will warn only${NC}"
fi
echo ""

# Collect files to check
FILES=()
for entry in "${SCAN_DIRS[@]}"; do
    full_path="$PROJECT_ROOT/$entry"
    if [[ -d "$full_path" ]]; then
        while IFS= read -r -d '' file; do
            FILES+=("$file")
        done < <(find "$full_path" -name "*.md" -type f -print0 2>/dev/null)
    elif [[ -f "$full_path" ]]; then
        FILES+=("$full_path")
    fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No files found to scan${NC}"
    echo "Scanned directories: ${SCAN_DIRS[*]}"
    exit 0
fi

echo "Scanning ${#FILES[@]} files..."
echo "Targets: ${SCAN_DIRS[*]}"
echo ""

# Check each file
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

for file in "${FILES[@]}"; do
    REL_PATH="${file#$PROJECT_ROOT/}"
    
    # Skip if file is empty
    if [[ ! -s "$file" ]]; then
        continue
    fi
    
    # Check for legacy patterns
    ERROR_COUNT=0
    
    if grep -qE "$LEGACY_PATTERN_1" "$file" 2>/dev/null; then
        if [[ "$STRICT_MODE" == "1" ]]; then
            echo -e "${RED}[FAIL]${NC} $REL_PATH"
            echo -e "       ${RED}Found: pseudo-object with single quotes${NC}"
            grep -nE "$LEGACY_PATTERN_1" "$file" | head -2 | while read line; do
                echo "       $line"
            done
            ((ERROR_COUNT++))
        else
            echo -e "${YELLOW}[WARN]${NC} $REL_PATH"
            echo -e "       ${YELLOW}Found: pseudo-object with single quotes${NC}"
            ((TOTAL_WARNINGS++))
        fi
    fi
    
    if grep -qE "$LEGACY_PATTERN_2" "$file" 2>/dev/null; then
        if [[ "$STRICT_MODE" == "1" ]]; then
            echo -e "${RED}[FAIL]${NC} $REL_PATH"
            echo -e "       ${RED}Found: named arguments without braces${NC}"
            grep -nE "$LEGACY_PATTERN_2" "$file" | head -2 | while read line; do
                echo "       $line"
            done
            ((ERROR_COUNT++))
        else
            echo -e "${YELLOW}[WARN]${NC} $REL_PATH"
            echo -e "       ${YELLOW}Found: named arguments without braces${NC}"
            ((TOTAL_WARNINGS++))
        fi
    fi
    
    if grep -qE "$LEGACY_PATTERN_3" "$file" 2>/dev/null; then
        if [[ "$STRICT_MODE" == "1" ]]; then
            echo -e "${RED}[FAIL]${NC} $REL_PATH"
            echo -e "       ${RED}Found: pseudo-object with double quotes${NC}"
            grep -nE "$LEGACY_PATTERN_3" "$file" | head -2 | while read line; do
                echo "       $line"
            done
            ((ERROR_COUNT++))
        else
            echo -e "${YELLOW}[WARN]${NC} $REL_PATH"
            echo -e "       ${YELLOW}Found: pseudo-object with double quotes${NC}"
            ((TOTAL_WARNINGS++))
        fi
    fi
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        ((TOTAL_ERRORS+=ERROR_COUNT))
    fi
done

echo ""
echo "=========================================="

if [[ "$STRICT_MODE" == "1" ]]; then
    if [[ $TOTAL_ERRORS -gt 0 ]]; then
        echo -e "${RED}FAILED: $TOTAL_ERRORS legacy syntax error(s) found${NC}"
        echo ""
        echo "To fix: Use JSON object syntax instead:"
        echo "  mcp__tool__method({\"key\":\"value\"})"
        echo ""
        echo "Forbidden patterns:"
        echo "  mcp__tool__method('{key: \"value\"}')  ← string pseudo-object"
        echo "  mcp__tool__method(key: \"value\")      ← named args without braces"
        exit 1
    else
        echo -e "${GREEN}PASSED: No legacy syntax found${NC}"
        exit 0
    fi
else
    if [[ $TOTAL_WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}WARNING: $TOTAL_WARNINGS legacy syntax pattern(s) found${NC}"
        echo "Run with --strict or STRICT_MCP_LINT=1 to fail on these"
        exit 0
    else
        echo -e "${GREEN}PASSED: No legacy syntax found${NC}"
        exit 0
    fi
fi
