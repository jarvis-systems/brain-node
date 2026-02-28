#!/usr/bin/env bash
# Check 60: Compile JSON Contract
# Validates brain compile --contract output for stability and portability
#
# Requirements:
#   - stderr is byte-empty
#   - stdout is valid JSON
#   - required keys: ok, compiled_surfaces, project_root, agents_compiled
#   - compiled_surfaces contains EXACTLY the 5 client surface dirs (sorted)
#   - .mcp.json is NOT in compiled_surfaces (must be in mcp_artifact_path if present)
#   - no absolute paths leaked (no /Users/, /home/, C:\, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

ERRORS=0
FINDINGS=""

# ── Run compile --contract ───────────────────────────────────────────────────

COMPILE_OUTPUT=$(mktemp)
COMPILE_STDERR=$(mktemp)
trap "rm -f '$COMPILE_OUTPUT' '$COMPILE_STDERR'" EXIT

php cli/bin/brain compile --contract --no-interaction > "$COMPILE_OUTPUT" 2> "$COMPILE_STDERR" || true

# ── Sub-check 61.1: stderr is byte-empty ─────────────────────────────────────

STDERR_CONTENT=$(cat "$COMPILE_STDERR")
if [[ -n "$STDERR_CONTENT" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.1 FAIL] stderr is not empty: '"$STDERR_CONTENT"
else
    FINDINGS+=$'\n[60.1 PASS] stderr is byte-empty'
fi

# ── Sub-check 61.2: stdout is valid JSON ─────────────────────────────────────

if ! jq empty "$COMPILE_OUTPUT" 2>/dev/null; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.2 FAIL] stdout is not valid JSON'
else
    FINDINGS+=$'\n[60.2 PASS] stdout is valid JSON'
fi

# ── Sub-check 61.3: Required keys present ────────────────────────────────────

if jq -e '.ok' "$COMPILE_OUTPUT" >/dev/null 2>&1 && \
   jq -e '.compiled_surfaces' "$COMPILE_OUTPUT" >/dev/null 2>&1 && \
   jq -e '.project_root' "$COMPILE_OUTPUT" >/dev/null 2>&1 && \
   jq -e '.agents_compiled' "$COMPILE_OUTPUT" >/dev/null 2>&1; then
    FINDINGS+=$'\n[60.3 PASS] Required keys present (ok, compiled_surfaces, project_root, agents_compiled)'
else
    ERRORS=$((ERRORS + 1))
    MISSING=""
    jq -e '.ok' "$COMPILE_OUTPUT" >/dev/null 2>&1 || MISSING+="ok "
    jq -e '.compiled_surfaces' "$COMPILE_OUTPUT" >/dev/null 2>&1 || MISSING+="compiled_surfaces "
    jq -e '.project_root' "$COMPILE_OUTPUT" >/dev/null 2>&1 || MISSING+="project_root "
    jq -e '.agents_compiled' "$COMPILE_OUTPUT" >/dev/null 2>&1 || MISSING+="agents_compiled "
    FINDINGS+=$'\n[60.3 FAIL] Missing required keys: '"$MISSING"
fi

# ── Sub-check 61.4: compiled_surfaces contains EXACTLY 5 client surfaces ─────

EXPECTED_SURFACES='[".claude",".codex",".gemini",".opencode",".qwen"]'
ACTUAL_SURFACES=$(jq -c '.compiled_surfaces | sort' "$COMPILE_OUTPUT" 2>/dev/null || echo '[]')

if [[ "$ACTUAL_SURFACES" == "$EXPECTED_SURFACES" ]]; then
    SURFACE_COUNT=$(jq '.compiled_surfaces | length' "$COMPILE_OUTPUT")
    FINDINGS+=$'\n[60.4 PASS] compiled_surfaces contains exactly 5 client surfaces (sorted)'
else
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.4 FAIL] compiled_surfaces mismatch'
    FINDINGS+=$'\n  Expected: '"$EXPECTED_SURFACES"
    FINDINGS+=$'\n  Actual:   '"$ACTUAL_SURFACES"
fi

# ── Sub-check 61.5: .mcp.json NOT in compiled_surfaces ────────────────────────

set +e
MCP_IN_SURFACES=$(jq -e '.compiled_surfaces | index(".mcp.json")' "$COMPILE_OUTPUT" 2>/dev/null)
JQ_EXIT=$?
set -e

if [[ $JQ_EXIT -eq 0 ]] && [[ "$MCP_IN_SURFACES" != "null" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.5 FAIL] .mcp.json found in compiled_surfaces (should be in mcp_artifact_path)'
else
    FINDINGS+=$'\n[60.5 PASS] .mcp.json not in compiled_surfaces'
fi

# ── Sub-check 61.6: No absolute paths leaked ─────────────────────────────────

ABSOLUTE_PATHS=$(grep -oE '/(Users|home|tmp|var|etc)/[^"]*|[A-Z]:\\[^"]*' "$COMPILE_OUTPUT" 2>/dev/null || true)

if [[ -n "$ABSOLUTE_PATHS" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.6 FAIL] Absolute paths leaked in JSON: '"$ABSOLUTE_PATHS"
else
    FINDINGS+=$'\n[60.6 PASS] No absolute paths leaked'
fi

# ── Sub-check 61.7: ok is boolean ────────────────────────────────────────────

OK_TYPE=$(jq -r '.ok | type' "$COMPILE_OUTPUT" 2>/dev/null || echo "null")
if [[ "$OK_TYPE" == "boolean" ]]; then
    FINDINGS+=$'\n[60.7 PASS] ok is boolean'
else
    ERRORS=$((ERRORS + 1))
    FINDINGS+=$'\n[60.7 FAIL] ok is not boolean (type: '"$OK_TYPE"')'
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo -e "$FINDINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "[FAIL] Check 60: Compile JSON contract ($ERRORS sub-check(s) failed)"
    exit 1
else
    echo ""
    echo "[PASS] Check 60: Compile JSON contract (7/7)"
    exit 0
fi
