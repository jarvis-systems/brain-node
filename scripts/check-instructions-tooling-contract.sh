#!/usr/bin/env bash
# Check 60: Instructions Tooling Contract (FINAL MCP tooling model)
# Ensures instruction surfaces use mcp__brain-tools__* tool IDs, not legacy CLI patterns
# Verifies BOTH vendor surface (consumer-relevant) AND compiled surface (authoritative)
#
# FINAL MODEL:
# - Source: BrainCLI::MCP__DOCS_SEARCH(), BrainCLI::MCP__DIAGNOSE(), BrainCLI::MCP__LIST_MASTERS()
# - Compiled: mcp__brain-tools__docs_search({}), mcp__brain-tools__diagnose({}), mcp__brain-tools__list-masters({})
# - FORBIDDEN: "brain docs", "brain diagnose", "brain list:masters", "brain tools:*", "mcp:*" (old CLI namespace)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ERRORS=0
FINDINGS=""
COMPILED_DIRS=""

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: Run brain compile --contract and extract compiled surfaces
# ═══════════════════════════════════════════════════════════════════════════

COMPILE_LOG=$(mktemp)
trap "rm -f '$COMPILE_LOG'" EXIT

if ! php cli/bin/brain compile --contract --no-interaction > "$COMPILE_LOG" 2>&1; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[ERROR] brain compile --contract failed'
    cat "$COMPILE_LOG" >&2
fi

# Verify JSON is valid before parsing
if ! jq empty "$COMPILE_LOG" 2>/dev/null; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[ERROR] compile --contract output is not valid JSON'
    COMPILED_DIRS=""
else
    # Extract compiled_surfaces from JSON (directories only, starting with ., not files)
    COMPILED_DIRS=$(jq -r '.compiled_surfaces[] | select(startswith(".")) | select(test("^\\.[a-zA-Z]+$"))' "$COMPILE_LOG" 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || true)
fi

if [[ -z "$COMPILED_DIRS" ]]; then
    FINDINGS+=$'\n[WARN] No compiled surface directories detected'
fi

FINDINGS+=$'\n[INFO] Compiled surfaces: '"${COMPILED_DIRS:-none}"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Vendor surface detection (strictly scoped)
# ═══════════════════════════════════════════════════════════════════════════

BRAIN_VENDOR_ROOT=""
if [[ -d ".brain/vendor" ]]; then
    BRAIN_VENDOR_ROOT=".brain/vendor"
elif [[ -d "vendor" ]]; then
    BRAIN_VENDOR_ROOT="vendor"
fi

CORE_INCLUDES_PATH=""
if [[ -n "$BRAIN_VENDOR_ROOT" ]]; then
    for p in "$BRAIN_VENDOR_ROOT/jarvis-brain/core/src/Includes" "$BRAIN_VENDOR_ROOT/brain/core/src/Includes"; do
        if [[ -d "$p" ]]; then
            CORE_INCLUDES_PATH="$p"
            break
        fi
    done
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 60.2: Vendor surface - BrainCLI::MCP__* methods present
# ═══════════════════════════════════════════════════════════════════════════
if [[ -n "$CORE_INCLUDES_PATH" ]]; then
    mcp_methods_in_vendor=$(grep -rE "BrainCLI::MCP__DOCS_SEARCH|BrainCLI::MCP__DIAGNOSE|BrainCLI::MCP__LIST_MASTERS" "$CORE_INCLUDES_PATH/" --include="*.php" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$mcp_methods_in_vendor" -lt 3 ]]; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+=$'\n[60.2 FAIL] Expected 3+ BrainCLI::MCP__* methods in vendor includes, found: '"$mcp_methods_in_vendor"
    else
        FINDINGS+=$'\n[60.2 PASS] Found '"$mcp_methods_in_vendor"' BrainCLI::MCP__* methods in vendor includes'
    fi
else
    FINDINGS+=$'\n[60.2 SKIP] Core includes path not found'
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 60.4: Compiled surface - mcp__brain-tools__* tool IDs present
# ═══════════════════════════════════════════════════════════════════════════
if [[ -n "$COMPILED_DIRS" ]]; then
    total_mcp_tools=0
    for dir in $COMPILED_DIRS; do
        if [[ -d "$dir" ]]; then
            set +e
            count=$(grep -rE "mcp__brain-tools__(docs_search|diagnose|list_masters)" "$dir/" --include="*.md" --include="*.toml" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
            set -e
            total_mcp_tools=$((total_mcp_tools + count))
        fi
    done

    if [[ "$total_mcp_tools" -lt 1 ]]; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+=$'\n[60.4 FAIL] Expected 1+ mcp__brain-tools__* tool IDs in compiled output, found: '"$total_mcp_tools"
    else
        FINDINGS+=$'\n[60.4 PASS] Found '"$total_mcp_tools"' mcp__brain-tools__* tool IDs in compiled output'
    fi
else
    FINDINGS+=$'\n[60.4 SKIP] No compiled directories detected'
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 60.5: Vendor surface - No forbidden CLI patterns
# ═══════════════════════════════════════════════════════════════════════════
if [[ -n "$CORE_INCLUDES_PATH" ]]; then
    forbidden_cli=$(grep -rE '\bbrain\s+docs\b|\bbrain\s+diagnose\b|\bbrain\s+list:masters\b|\bbrain\s+tools:' "$CORE_INCLUDES_PATH/" --include="*.php" 2>/dev/null | grep -v 'BrainCLI::' | head -10 || true)
    if [[ -n "$forbidden_cli" ]]; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+=$'\n[60.5 FAIL] Forbidden CLI patterns found in vendor includes:\n'"$forbidden_cli"
    else
        FINDINGS+=$'\n[60.5 PASS] No forbidden CLI patterns in vendor includes'
    fi
else
    FINDINGS+=$'\n[60.5 SKIP] Core includes path not found'
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 60.6: Product docs - No mcp:* commands (user-facing)
# ═══════════════════════════════════════════════════════════════════════════
if [[ -d ".docs/product" ]]; then
    mcp_in_product=$(grep -rE "brain mcp:docs_search|brain mcp:diagnose" .docs/product/ --include="*.md" 2>/dev/null | head -5 || true)
    if [[ -n "$mcp_in_product" ]]; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+=$'\n[60.6 FAIL] mcp:* commands found in product docs:\n'"$mcp_in_product"
    else
        FINDINGS+=$'\n[60.6 PASS] No mcp:* commands in product docs'
    fi
else
    FINDINGS+=$'\n[60.6 SKIP] No .docs/product directory'
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
echo -e "$FINDINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "[FAIL] Check 60: $ERRORS sub-check(s) failed"
    exit 1
else
    echo ""
    echo "[PASS] Check 60: Instructions tooling contract (6/6)"
    exit 0
fi
