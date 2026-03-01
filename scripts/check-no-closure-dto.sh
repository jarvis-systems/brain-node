#!/usr/bin/env bash
#
# Check No Closure in DTO Property Types
# Prevents BindingResolutionException when DI container tries to resolve Closure
#
# Usage: scripts/check-no-closure-dto.sh
#
# Exit codes:
#   0 - No Closure in DTO union types
#   1 - Closure found in DTO property types
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI_DTO_DIR="$PROJECT_ROOT/cli/src/Dto"

VIOLATIONS=()

if [[ -d "$CLI_DTO_DIR" ]]; then
    while IFS= read -r -d '' file; do
        relative="${file#$PROJECT_ROOT/}"
        
        # Check for Closure in union type property declarations
        # Pattern: (public|protected|private) ... |Closure ... $var
        if grep -Pn '(public|protected|private)\s+[^;]*\|Closure' "$file" 2>/dev/null; then
            VIOLATIONS+=("$relative")
        fi
        if grep -Pn '(public|protected|private)\s+[^;]*Closure\|' "$file" 2>/dev/null; then
            VIOLATIONS+=("$relative")
        fi
    done < <(find "$CLI_DTO_DIR" -name '*.php' -type f -print0 2>/dev/null)
fi

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
    echo "ERROR: Closure in DTO property union types detected" >&2
    echo "" >&2
    echo "Closure in union types causes BindingResolutionException when" >&2
    echo "DI container tries to auto-resolve the type." >&2
    echo "" >&2
    echo "Use 'mixed' or 'callable' instead of Closure in union types." >&2
    echo "" >&2
    echo "Violations:" >&2
    printf '  - %s\n' "${VIOLATIONS[@]}" >&2
    exit 1
fi

echo "OK: No Closure in DTO property union types"
exit 0
