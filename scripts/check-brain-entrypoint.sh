#!/usr/bin/env bash
#
# Brain Entrypoint Guard — Verifies cli/bin/brain exists and is executable
# Usage: scripts/check-brain-entrypoint.sh
#
# Exit codes:
#   0 - Entrypoint valid
#   1 - Entrypoint missing or not executable
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENTRYPOINT="$PROJECT_ROOT/cli/bin/brain"

# Check file exists
if [[ ! -f "$ENTRYPOINT" ]]; then
    echo "FAIL: cli/bin/brain missing"
    exit 1
fi

# Check executable bit
if [[ ! -x "$ENTRYPOINT" ]]; then
    echo "FAIL: cli/bin/brain not executable"
    exit 1
fi

# Check it runs
if ! php "$ENTRYPOINT" --help >/dev/null 2>&1; then
    echo "FAIL: cli/bin/brain --help failed"
    exit 1
fi

echo "PASS: cli/bin/brain entrypoint valid"
exit 0
