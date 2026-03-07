#!/usr/bin/env bash
#
# Check for canonical SQLite storage roots
# Usage: scripts/check-storage-roots.sh
#
# Canonical location: memory/ (lowercase)
# Forbidden: ./Memory/, Memory/ (uppercase on case-sensitive FS)
#
# Exit codes:
#   0 - All checks pass
#   1 - Non-canonical roots detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

errors=0
warnings=0

# Check 1: No uppercase Memory directory at root (case-sensitive FS guard)
if [[ -d "Memory" ]] && [[ ! -d "memory" ]]; then
    echo -e "${RED}FAIL: Found ./Memory/ but not ./memory/${NC}"
    echo "  Canonical location is ./memory/ (lowercase)"
    ((errors++))
fi

# Check 2: No uppercase Memory directory under .brain
if [[ -d "Memory" ]] && [[ ! -d "memory" ]]; then
    echo -e "${RED}FAIL: Found Memory/ but not memory/${NC}"
    echo "  Canonical location is memory/ (lowercase)"
    ((errors++))
fi

# Check 3: Verify canonical DB files exist
canonical_files=(
    "memory/tasks.db"
    "memory/vector_memory.db"
)

for f in "${canonical_files[@]}"; do
    if [[ -f "$f" ]]; then
        echo -e "${GREEN}INFO: Found canonical: $f${NC}"
    fi
done

# Check 5: No stranded DB files in non-canonical locations
stranded=$(find . -name "*.db" -o -name "*.sqlite" 2>/dev/null | grep -v "^\./\memory/" | grep -v "^\./memory/" | grep -v vendor | grep -v node_modules | grep -v ".git" | grep -v "_quarantine" || true)

if [[ -n "$stranded" ]]; then
    echo -e "${YELLOW}WARN: Found DB files outside canonical location:${NC}"
    echo "$stranded" | while read -r f; do
        echo "  $f"
    done
    echo "  Canonical location: memory/ (or ./memory/ in self-hosting mode)"
    ((warnings++))
fi

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}FAIL: $errors storage root error(s)${NC}"
    exit 1
fi

if [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}PASS: Storage roots canonical ($warnings warning(s))${NC}"
else
    echo -e "${GREEN}PASS: Storage roots canonical${NC}"
fi
exit 0
