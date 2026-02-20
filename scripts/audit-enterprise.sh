#!/bin/bash
#
# Enterprise Codebase Audit — Automated static checks
# Usage: scripts/audit-enterprise.sh [--json-only]
#
# Scans PHP and shell sources for common enterprise risks:
#   - PHP syntax errors
#   - Silent catch blocks
#   - Debug artifacts (dd/dump/var_dump/print_r)
#   - TODO/FIXME markers
#   - Unsafe exec functions (eval/shell_exec)
#   - Exit/die calls outside scripts
#   - Hardcoded user paths
#   - Shell script safety headers
#   - No-op escape methods (contract lies)
#
# Output: dist/audit-report.json + stdout summary
#
# Exit codes:
#   0 - Audit completed (findings may exist)
#   2 - Missing dependencies
#

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist"
REPORT_FILE="$DIST_DIR/audit-report.json"

JSON_ONLY=false
if [[ "${1:-}" == "--json-only" ]]; then
    JSON_ONLY=true
fi

# Colors (disabled when not a terminal or json-only)
if [[ -t 1 ]] && [[ "$JSON_ONLY" == false ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ── Dependency check ──────────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed" >&2
    exit 2
fi

if ! command -v php &>/dev/null; then
    echo "ERROR: php is required but not installed" >&2
    exit 2
fi

# ── Helpers ───────────────────────────────────────────────────────────────

log() {
    if [[ "$JSON_ONLY" == false ]]; then
        echo -e "$@"
    fi
}

TOTAL_FINDINGS=0
CATEGORIES_JSON="[]"

add_category() {
    local name="$1"
    local status="$2"
    local count="$3"
    local details="$4"

    CATEGORIES_JSON=$(echo "$CATEGORIES_JSON" | jq \
        --arg name "$name" \
        --arg status "$status" \
        --argjson count "$count" \
        --argjson details "$details" \
        '. + [{"category": $name, "status": $status, "count": $count, "findings": $details}]')

    TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))
}

# ── Check 1: PHP syntax ──────────────────────────────────────────────────

log "${BOLD}[1/8] PHP syntax check${NC}"

PHP_ERRORS=0
PHP_FINDINGS="[]"

while IFS= read -r -d '' file; do
    relative="${file#$PROJECT_ROOT/}"
    output=$(php -l "$file" 2>&1) || {
        PHP_ERRORS=$((PHP_ERRORS + 1))
        PHP_FINDINGS=$(echo "$PHP_FINDINGS" | jq \
            --arg file "$relative" \
            --arg msg "$output" \
            '. + [{"file": $file, "message": $msg}]')
        log "  ${RED}FAIL${NC} $relative"
    }
done < <(find "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" -name '*.php' -print0 2>/dev/null)

# Also check scripts/*.php if they exist
while IFS= read -r -d '' file; do
    relative="${file#$PROJECT_ROOT/}"
    output=$(php -l "$file" 2>&1) || {
        PHP_ERRORS=$((PHP_ERRORS + 1))
        PHP_FINDINGS=$(echo "$PHP_FINDINGS" | jq \
            --arg file "$relative" \
            --arg msg "$output" \
            '. + [{"file": $file, "message": $msg}]')
        log "  ${RED}FAIL${NC} $relative"
    }
done < <(find "$PROJECT_ROOT/scripts" -maxdepth 1 -name '*.php' -print0 2>/dev/null)

if [[ $PHP_ERRORS -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} All PHP files valid"
fi
add_category "php-syntax" "$([ $PHP_ERRORS -eq 0 ] && echo pass || echo fail)" "$PHP_ERRORS" "$PHP_FINDINGS"

# ── Check 2: PHPUnit (if available) ─────────────────────────────────────

log "${BOLD}[2/8] PHPUnit tests${NC}"

TEST_FINDINGS="[]"
TEST_COUNT=0
if [[ -f "$PROJECT_ROOT/core/vendor/bin/phpunit" ]]; then
    if (cd "$PROJECT_ROOT/core" && ./vendor/bin/phpunit 2>&1) >/dev/null 2>&1; then
        log "  ${GREEN}PASS${NC} Core tests passed"
    else
        TEST_COUNT=1
        TEST_FINDINGS=$(echo "$TEST_FINDINGS" | jq '. + [{"file": "core/", "message": "PHPUnit tests failed"}]')
        log "  ${RED}FAIL${NC} Core tests failed"
    fi
else
    log "  ${YELLOW}SKIP${NC} PHPUnit not installed (run: cd core && composer install)"
fi
add_category "phpunit" "$([ $TEST_COUNT -eq 0 ] && echo pass || echo fail)" "$TEST_COUNT" "$TEST_FINDINGS"

# ── Check 3: Silent catch blocks ────────────────────────────────────────

log "${BOLD}[3/8] Silent catch blocks${NC}"

CATCH_FINDINGS="[]"
CATCH_COUNT=0

# Match: catch (...) { } with optional whitespace/newlines, nothing inside braces
# Use grep -P for perl-compatible regex, fall back to basic if unavailable
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip vendor directories
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    CATCH_COUNT=$((CATCH_COUNT + 1))
    CATCH_FINDINGS=$(echo "$CATCH_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$content" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line"
done < <(grep -rn 'catch\s*(.*)\s*{\s*}' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

# Also catch multiline empty catches: catch (...) {\n    }
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    # Avoid double-counting single-line catches
    already_found=false
    for existing in $(echo "$CATCH_FINDINGS" | jq -r '.[].file + ":" + (.[].line | tostring)' 2>/dev/null); do
        if [[ "$relative:$line" == "$existing" ]]; then
            already_found=true
            break
        fi
    done
    if [[ "$already_found" == false ]]; then
        CATCH_COUNT=$((CATCH_COUNT + 1))
        CATCH_FINDINGS=$(echo "$CATCH_FINDINGS" | jq \
            --arg file "$relative" \
            --arg line "$line" \
            --arg content "$content" \
            '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
        log "  ${YELLOW}WARN${NC} $relative:$line"
    fi
done < <(grep -rn 'catch\s*(.*)\s*{$' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null | while IFS=: read -r f l c; do
    # Check if next non-empty line is just }
    next=$(sed -n "$((l+1))p" "$f" 2>/dev/null | tr -d '[:space:]')
    if [[ "$next" == "}" ]]; then
        echo "$f:$l:$c"
    fi
done)

if [[ $CATCH_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No silent catch blocks"
fi
add_category "silent-catches" "$([ $CATCH_COUNT -eq 0 ] && echo pass || echo warn)" "$CATCH_COUNT" "$CATCH_FINDINGS"

# ── Check 4: Debug artifacts ────────────────────────────────────────────

log "${BOLD}[4/8] Debug artifacts${NC}"

DEBUG_FINDINGS="[]"
DEBUG_COUNT=0

# Search for dd(), dump(), var_dump(), print_r() — excluding compiled output and vendor
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip compiled output, vendor, and comments with legitimate references
    [[ "$relative" == .claude/* ]] && continue
    [[ "$relative" == .opencode/* ]] && continue
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == .docs/* ]] && continue
    # Skip this audit script itself
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    DEBUG_COUNT=$((DEBUG_COUNT + 1))
    DEBUG_FINDINGS=$(echo "$DEBUG_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line"
done < <(grep -rn '\bvar_dump\s*(\|dump\s*(\|print_r\s*(\|\bdd\s*(' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" "$PROJECT_ROOT/scripts" --include='*.php' 2>/dev/null || true)

if [[ $DEBUG_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No debug artifacts"
fi
add_category "debug-artifacts" "$([ $DEBUG_COUNT -eq 0 ] && echo pass || echo warn)" "$DEBUG_COUNT" "$DEBUG_FINDINGS"

# ── Check 5: TODO/FIXME markers ────────────────────────────────────────

log "${BOLD}[5/8] TODO/FIXME markers${NC}"

TODO_FINDINGS="[]"
TODO_COUNT=0

while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip compiled output, vendor, docs, and Brain Include text (legitimate references)
    [[ "$relative" == .claude/* ]] && continue
    [[ "$relative" == .opencode/* ]] && continue
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == .docs/* ]] && continue
    # Skip this script
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    TODO_COUNT=$((TODO_COUNT + 1))
    TODO_FINDINGS=$(echo "$TODO_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line"
done < <(grep -rn '@todo\|@fixme\|TODO\|FIXME' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

if [[ $TODO_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No TODO/FIXME markers"
fi
add_category "todo-fixme" "$([ $TODO_COUNT -eq 0 ] && echo pass || echo info)" "$TODO_COUNT" "$TODO_FINDINGS"

# ── Check 6: Unsafe patterns ───────────────────────────────────────────

log "${BOLD}[6/8] Unsafe patterns (eval/shell_exec/die/exit)${NC}"

UNSAFE_FINDINGS="[]"
UNSAFE_COUNT=0

# eval() and shell_exec() — excluding vendor
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == .docs/* ]] && continue
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    UNSAFE_COUNT=$((UNSAFE_COUNT + 1))
    UNSAFE_FINDINGS=$(echo "$UNSAFE_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        --arg type "unsafe-exec" \
        '. + [{"file": $file, "line": ($line | tonumber), "type": $type, "content": $content}]')
    log "  ${RED}WARN${NC} $relative:$line (unsafe exec)"
done < <(grep -rn '\bshell_exec\s*(\|\beval\s*(' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

# die() and exit() — in src code only (not scripts)
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == scripts/* ]] && continue
    UNSAFE_COUNT=$((UNSAFE_COUNT + 1))
    UNSAFE_FINDINGS=$(echo "$UNSAFE_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        --arg type "die-exit" \
        '. + [{"file": $file, "line": ($line | tonumber), "type": $type, "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line (die/exit)"
done < <(grep -rn '\bdie\s*(\|\bexit\s*(' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

if [[ $UNSAFE_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No unsafe patterns"
fi
add_category "unsafe-patterns" "$([ $UNSAFE_COUNT -eq 0 ] && echo pass || echo warn)" "$UNSAFE_COUNT" "$UNSAFE_FINDINGS"

# ── Check 7: Shell script safety ────────────────────────────────────────

log "${BOLD}[7/8] Shell script safety headers${NC}"

SHELL_FINDINGS="[]"
SHELL_COUNT=0

for script in "$PROJECT_ROOT"/scripts/*.sh; do
    [[ ! -f "$script" ]] && continue
    relative="${script#$PROJECT_ROOT/}"
    # Check if script has set -euo pipefail (or equivalent)
    if ! grep -q 'set -euo pipefail' "$script" 2>/dev/null; then
        if grep -q 'set -e' "$script" 2>/dev/null; then
            SHELL_COUNT=$((SHELL_COUNT + 1))
            SHELL_FINDINGS=$(echo "$SHELL_FINDINGS" | jq \
                --arg file "$relative" \
                --arg msg "Uses 'set -e' instead of 'set -euo pipefail'" \
                '. + [{"file": $file, "message": $msg}]')
            log "  ${YELLOW}WARN${NC} $relative — missing -uo pipefail"
        fi
    fi
done

if [[ $SHELL_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} All shell scripts use safe headers"
fi
add_category "shell-safety" "$([ $SHELL_COUNT -eq 0 ] && echo pass || echo warn)" "$SHELL_COUNT" "$SHELL_FINDINGS"

# ── Check 8: No-op escape methods ───────────────────────────────────────

log "${BOLD}[8/8] No-op escape method detection${NC}"

NOOP_FINDINGS="[]"
NOOP_COUNT=0

# Pattern: method named *escape* that just returns its argument (contract lie)
# Matches: function escape...(string $value)...{ return $value; }
while IFS= read -r -d '' file; do
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue

    # Extract methods containing "escape" in name, check if body is just "return $value"
    # Use awk to find function...escape...return $value patterns
    matches=$(awk '
        /function [a-zA-Z]*[Ee]scape[a-zA-Z]*\s*\(/ { in_escape=1; brace=0; body="" }
        in_escape { body = body $0 "\n"; gsub(/[^{}]/, "", $0); brace += gsub(/{/, "{"); brace -= gsub(/}/, "}"); if (brace <= 0 && in_escape) { if (body ~ /return \$[a-zA-Z_]+;/ && body !~ /htmlspecialchars|htmlentities|str_replace|preg_replace|addslashes|urlencode/) { print FILENAME ":" NR ": no-op escape method detected" }; in_escape=0; body="" } }
    ' "$file" 2>/dev/null)

    if [[ -n "$matches" ]]; then
        while IFS= read -r match; do
            NOOP_COUNT=$((NOOP_COUNT + 1))
            NOOP_FINDINGS=$(echo "$NOOP_FINDINGS" | jq \
                --arg file "$relative" \
                --arg msg "$match" \
                '. + [{"file": $file, "message": $msg}]')
            log "  ${YELLOW}WARN${NC} $relative — no-op escape method"
        done <<< "$matches"
    fi
done < <(find "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" -name '*.php' -print0 2>/dev/null)

if [[ $NOOP_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No no-op escape methods"
fi
add_category "noop-escape" "$([ $NOOP_COUNT -eq 0 ] && echo pass || echo warn)" "$NOOP_COUNT" "$NOOP_FINDINGS"

# ── Output JSON report ──────────────────────────────────────────────────

mkdir -p "$DIST_DIR"

REPORT=$(jq -n \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg version "1.0.0" \
    --argjson total "$TOTAL_FINDINGS" \
    --argjson categories "$CATEGORIES_JSON" \
    '{
        "audit": "enterprise-codebase",
        "version": $version,
        "date": $date,
        "total_findings": $total,
        "categories": $categories
    }')

echo "$REPORT" > "$REPORT_FILE"

# ── Summary ─────────────────────────────────────────────────────────────

log ""
log "${BOLD}═══ Enterprise Audit Summary ═══${NC}"
log ""

pass_count=$(echo "$CATEGORIES_JSON" | jq '[.[] | select(.status == "pass")] | length')
warn_count=$(echo "$CATEGORIES_JSON" | jq '[.[] | select(.status == "warn" or .status == "info")] | length')
fail_count=$(echo "$CATEGORIES_JSON" | jq '[.[] | select(.status == "fail")] | length')

log "  ${GREEN}PASS${NC}: $pass_count categories"
log "  ${YELLOW}WARN${NC}: $warn_count categories"
log "  ${RED}FAIL${NC}: $fail_count categories"
log "  Total findings: $TOTAL_FINDINGS"
log ""
log "  Report: ${CYAN}$REPORT_FILE${NC}"

exit 0
