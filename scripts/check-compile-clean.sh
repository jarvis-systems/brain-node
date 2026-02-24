#!/usr/bin/env bash
#
# Compile Clean-Worktree Gate
# Verifies: brain compile produces no NEW uncommitted changes.
# Captures worktree state before compile, then diffs after.
# Only flags changes INTRODUCED by compilation, not pre-existing work.
#
# Usage: scripts/check-compile-clean.sh
#
# Exit codes:
#   0 - Clean (compile is deterministic, no new changes)
#   1 - Dirty (compile modified or created tracked files)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ISOLATED_DIR="$PROJECT_ROOT/dist/tmp"

cd "$PROJECT_ROOT"

# Colors (disabled when not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

# Verify we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}ERROR${NC}: Not a git repository"
    exit 1
fi

# Ensure isolated directory exists with marker
mkdir -p "$ISOLATED_DIR"
touch "$ISOLATED_DIR/.brain-testmode.marker"

# Snapshot worktree state BEFORE compile
BEFORE=$(git status --porcelain 2>/dev/null || true)

# Run brain compile from isolated directory
echo -e "${YELLOW}Running brain compile...${NC}"
if ! (cd "$ISOLATED_DIR" && BRAIN_TEST_MODE=1 BRAIN_TEST_MODE_SOURCE=ci BRAIN_ALLOW_NO_LOCK=1 brain compile --no-lock >/dev/null 2>&1); then
    echo -e "${RED}FAIL${NC}: brain compile exited with error"
    exit 1
fi

# Snapshot worktree state AFTER compile
AFTER=$(git status --porcelain 2>/dev/null || true)

# Diff: only NEW changes introduced by compile
NEW_CHANGES=$(diff <(echo "$BEFORE") <(echo "$AFTER") | grep '^>' | sed 's/^> //' || true)

if [[ -n "$NEW_CHANGES" ]]; then
    echo -e "${RED}FAIL${NC}: brain compile produced new uncommitted changes:"
    echo "$NEW_CHANGES" | while IFS= read -r line; do
        echo "  $line"
    done
    exit 1
fi

echo -e "${GREEN}PASS${NC}: brain compile produces clean worktree"
exit 0
