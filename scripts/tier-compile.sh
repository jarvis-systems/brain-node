#!/usr/bin/env bash
#
# Model-Tier Preset Compiler — Translates MODEL_TIER to STRICT_MODE + COGNITIVE_LEVEL
# Usage: MODEL_TIER=economy scripts/tier-compile.sh
#        MODEL_TIER=premium scripts/tier-compile.sh
#        scripts/tier-compile.sh                     (defaults to standard)
#
# Tier always sets both STRICT_MODE and COGNITIVE_LEVEL deterministically.
# For manual override, use brain compile directly:
#   STRICT_MODE=paranoid COGNITIVE_LEVEL=deep brain compile
#
# Exit codes mirror brain compile.
#

set -euo pipefail

MODEL_TIER="${MODEL_TIER:-standard}"

case "$MODEL_TIER" in
    economy)
        export STRICT_MODE=strict
        export COGNITIVE_LEVEL=minimal
        ;;
    standard)
        export STRICT_MODE=strict
        export COGNITIVE_LEVEL=standard
        ;;
    premium)
        export STRICT_MODE=paranoid
        export COGNITIVE_LEVEL=exhaustive
        ;;
    *)
        echo "ERROR: Unknown MODEL_TIER: $MODEL_TIER"
        echo "Valid values: economy | standard | premium"
        exit 1
        ;;
esac

echo "Compiling: MODEL_TIER=$MODEL_TIER → STRICT_MODE=$STRICT_MODE, COGNITIVE_LEVEL=$COGNITIVE_LEVEL"
brain compile "$@"
