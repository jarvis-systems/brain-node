#!/usr/bin/env bash
#
# run-enterprise-gates.sh — One-command enterprise quality verification
# Runs all gates and produces evidence bundle in dist/evidence/
#
# Usage:
#   bash scripts/run-enterprise-gates.sh
#
# Exit codes:
#   0 - All gates PASS
#   1 - One or more gates FAIL
#
# No external network calls. No secrets in output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
EVIDENCE_DIR="${DIST_DIR}/evidence"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Create timestamped evidence folder
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUNDLE_DIR="${EVIDENCE_DIR}/enterprise-gates-${TIMESTAMP}"
mkdir -p "$BUNDLE_DIR"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
GATES_LOG=""

log_gate() {
    local name="$1"
    local status="$2"
    local detail="$3"
    
    if [[ "$status" == "PASS" ]]; then
        printf "  ${GREEN}[PASS]${NC} %s %s\n" "$name" "$detail"
        PASS_COUNT=$((PASS_COUNT + 1))
        GATES_LOG="${GATES_LOG}PASS\t${name}\t${detail}\n"
    else
        printf "  ${RED}[FAIL]${NC} %s %s\n" "$name" "$detail"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        GATES_LOG="${GATES_LOG}FAIL\t${name}\t${detail}\n"
    fi
}

echo -e "${BOLD}=== Enterprise Gates Runner ===${NC}"
echo "Evidence bundle: ${BUNDLE_DIR}"
echo ""

cd "$PROJECT_ROOT"

# ── Gate 1: Secret Scan ──────────────────────────────────────────────────

echo -e "${YELLOW}[1/7] Secret Scan${NC}"
if bash scripts/scan-secrets.sh >/dev/null 2>&1; then
    log_gate "secret-scan" "PASS" "0 secrets found"
else
    log_gate "secret-scan" "FAIL" "secrets detected"
fi

# ── Gate 2: Enterprise Audit ─────────────────────────────────────────────

echo -e "${YELLOW}[2/7] Enterprise Audit${NC}"
AUDIT_OUTPUT=$(bash scripts/audit-enterprise.sh 2>&1) || true
AUDIT_PASS=$(echo "$AUDIT_OUTPUT" | grep -E 'PASS:.*categories' | grep -oE '[0-9]+' | head -1 || echo "0")
AUDIT_FAIL=$(echo "$AUDIT_OUTPUT" | grep -E 'FAIL:.*categories' | grep -oE '[0-9]+' | head -1 || echo "0")

if [[ "$AUDIT_FAIL" == "0" && "$AUDIT_PASS" -gt 0 ]]; then
    log_gate "enterprise-audit" "PASS" "${AUDIT_PASS}/22 checks"
else
    log_gate "enterprise-audit" "FAIL" "${AUDIT_FAIL} failures"
fi

# Save audit report
echo "$AUDIT_OUTPUT" > "$BUNDLE_DIR/audit-output.txt"

# ── Gate 3: Compile Clean ────────────────────────────────────────────────

echo -e "${YELLOW}[3/7] Compile Clean${NC}"
if bash scripts/check-compile-clean.sh >/dev/null 2>&1; then
    log_gate "compile-clean" "PASS" "worktree clean"
else
    log_gate "compile-clean" "FAIL" "worktree dirty"
fi

# ── Gate 4: Compile Metrics ──────────────────────────────────────────────

echo -e "${YELLOW}[4/7] Compile Metrics${NC}"
METRICS_OUTPUT=$(bash scripts/verify-compile-metrics.sh 2>&1) || true
if echo "$METRICS_OUTPUT" | grep -q "PASSED: All checks passed"; then
    STD_LINES=$(echo "$METRICS_OUTPUT" | grep -oE 'standard=[0-9]+' | grep -oE '[0-9]+' || echo "?")
    EXH_LINES=$(echo "$METRICS_OUTPUT" | grep -oE 'exhaustive=[0-9]+' | grep -oE '[0-9]+' || echo "?")
    log_gate "compile-metrics" "PASS" "std=${STD_LINES}, exh=${EXH_LINES}"
    echo "$METRICS_OUTPUT" > "$BUNDLE_DIR/compile-metrics.txt"
else
    log_gate "compile-metrics" "FAIL" "metrics check failed"
    echo "$METRICS_OUTPUT" > "$BUNDLE_DIR/compile-metrics.txt"
fi

# ── Gate 5: Docs Validation ──────────────────────────────────────────────

echo -e "${YELLOW}[5/7] Docs Validation${NC}"
DOCS_OUTPUT=$(brain docs --validate 2>&1) || true
VALID_COUNT=$(echo "$DOCS_OUTPUT" | grep -oE '"valid":[0-9]+' | grep -oE '[0-9]+' || echo "0")
INVALID_COUNT=$(echo "$DOCS_OUTPUT" | grep -oE '"invalid":[0-9]+' | grep -oE '[0-9]+' || echo "0")

if [[ "$INVALID_COUNT" == "0" && "$VALID_COUNT" -gt 0 ]]; then
    log_gate "docs-validate" "PASS" "valid=${VALID_COUNT}, invalid=0"
else
    log_gate "docs-validate" "FAIL" "invalid=${INVALID_COUNT}"
fi

# ── Gate 6: Core Tests ───────────────────────────────────────────────────

echo -e "${YELLOW}[6/7] Core Tests${NC}"
TEST_OUTPUT=$(cd core && composer test 2>&1) || true
if echo "$TEST_OUTPUT" | grep -q "OK"; then
    TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oE '[0-9]+ tests' | grep -oE '[0-9]+' | head -1 || echo "?")
    ASSERT_COUNT=$(echo "$TEST_OUTPUT" | grep -oE '[0-9]+ assertions' | grep -oE '[0-9]+' | head -1 || echo "?")
    log_gate "core-tests" "PASS" "${TEST_COUNT} tests, ${ASSERT_COUNT} assertions"
else
    log_gate "core-tests" "FAIL" "tests failed"
fi

# ── Gate 7: Static Analysis ──────────────────────────────────────────────

echo -e "${YELLOW}[7/7] Static Analysis${NC}"
PHPSTAN_OUTPUT=$(composer analyse 2>&1) || true
if echo "$PHPSTAN_OUTPUT" | grep -q "No errors"; then
    log_gate "phpstan" "PASS" "0 errors"
else
    log_gate "phpstan" "FAIL" "errors found"
fi

# ── Versions ─────────────────────────────────────────────────────────────

{
    echo "=== Version Snapshot ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "Root: $(git describe --tags --always 2>/dev/null || echo 'unknown')"
    echo "Core: $(cd core && git describe --tags --always 2>/dev/null || echo 'unknown')"
    echo "CLI:  $(cd cli && git describe --tags --always 2>/dev/null || echo 'unknown')"
} > "$BUNDLE_DIR/versions.txt"

# ── Gates Summary ────────────────────────────────────────────────────────

{
    echo "=== Enterprise Gates Summary ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo -e "Status\tGate\tDetail"
    echo -e "------\t----\t------"
    echo -e "$GATES_LOG"
    echo ""
    echo "TOTAL: ${PASS_COUNT}/7 PASS"
    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        echo "RESULT: FAIL (${FAIL_COUNT} gates failed)"
    else
        echo "RESULT: PASS (all gates green)"
    fi
} > "$BUNDLE_DIR/gates-summary.txt"

# ── Evidence Manifest ─────────────────────────────────────────────────────

MANIFEST_JSON="$BUNDLE_DIR/manifest.json"
MANIFEST_TXT="$BUNDLE_DIR/manifest.txt"
GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build file list with hashes (sorted by filename)
FILES_JSON="[]"
FILES_TXT=""

for f in $(ls "$BUNDLE_DIR"/*.txt 2>/dev/null | sort); do
    fname=$(basename "$f")
    fsize=$(wc -c < "$f" | tr -d ' ')
    fhash=$(shasum -a 256 "$f" | cut -d' ' -f1)
    
    FILES_JSON=$(echo "$FILES_JSON" | jq \
        --arg path "$fname" \
        --argjson bytes "$fsize" \
        --arg sha256 "$fhash" \
        '. + [{"path": $path, "bytes": $bytes, "sha256": $sha256}]')
    
    FILES_TXT="${FILES_TXT}${fname}\t${fsize}\t${fhash}\n"
done

# Write manifest.json
jq -n \
    --arg generated_at "$GENERATED_AT" \
    --arg bundle "$(basename "$BUNDLE_DIR")" \
    --argjson pass "$PASS_COUNT" \
    --argjson fail "$FAIL_COUNT" \
    --argjson files "$FILES_JSON" \
    '{
        "generated_at": $generated_at,
        "bundle": $bundle,
        "gates": {"pass": $pass, "fail": $fail},
        "files": $files
    }' > "$MANIFEST_JSON"

# Write manifest.txt (human-readable)
{
    echo "=== Evidence Bundle Manifest ==="
    echo "Generated: $GENERATED_AT"
    echo "Bundle: $(basename "$BUNDLE_DIR")"
    echo "Gates: ${PASS_COUNT}/7 PASS"
    echo ""
    echo -e "File\tBytes\tSHA256"
    echo -e "----\t-----\t------"
    echo -e "$FILES_TXT"
} > "$MANIFEST_TXT"

# ── Final Output ─────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}=== Summary ===${NC}"
cat "$BUNDLE_DIR/gates-summary.txt" | tail -3
echo ""
echo "Evidence bundle: ${BUNDLE_DIR}/"
echo "Manifest: ${BUNDLE_DIR}/manifest.json"
ls -la "$BUNDLE_DIR" | tail -7

# Exit code
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo ""
    echo -e "${RED}BLOCKED: ${FAIL_COUNT} gates failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}READY: All gates PASS${NC}"
exit 0
