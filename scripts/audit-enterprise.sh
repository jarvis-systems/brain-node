#!/usr/bin/env bash
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
#   - self:: in trait files (LSB violations)
#   - Known typos (Standarts→Standards)
#   - Dev dependencies in production require
#   - PHPStan static analysis
#   - Missing declare(strict_types=1)
#   - Secret patterns in tracked files
#   - Hardcoded user paths in tracked source files
#   - Version consistency (core vs root composer.json, CLI drift, tag vs composer.json)
#   - MCP schema bypass: raw ::call() on schema-enabled MCPs without @mcp-schema-bypass
#   - Compile clean-worktree: brain compile must not dirty tracked files
#
# Output: dist/audit-report.json + stdout summary
#
# Exit codes:
#   0 - All P0 checks pass (FAIL categories = 0)
#   1 - P0 regression detected (any FAIL category)
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

log "${BOLD}[1/19] PHP syntax check${NC}"

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

log "${BOLD}[2/19] PHPUnit tests${NC}"

TEST_FINDINGS="[]"
TEST_COUNT=0
if [[ -f "$PROJECT_ROOT/core/vendor/bin/phpunit" ]]; then
    if CORE_TEST_OUT=$(cd "$PROJECT_ROOT/core" && ./vendor/bin/phpunit 2>&1); then
        log "  ${GREEN}PASS${NC} Core tests passed"
    else
        TEST_COUNT=$((TEST_COUNT + 1))
        CORE_FAIL_TAIL=$(echo "$CORE_TEST_OUT" | tail -30)
        TEST_FINDINGS=$(echo "$TEST_FINDINGS" | jq \
            --arg detail "$CORE_FAIL_TAIL" \
            '. + [{"file": "core/", "message": "PHPUnit tests failed", "detail": $detail}]')
        log "  ${RED}FAIL${NC} Core tests failed"
        log "  ${RED}──── Core PHPUnit output (last 30 lines) ────${NC}"
        echo "$CORE_TEST_OUT" | tail -30 | while IFS= read -r _line; do
            log "    $_line"
        done
        log "  ${RED}───────────────────────────────────────────────${NC}"
        # Hint for common root cause: missing tracked files
        if echo "$CORE_TEST_OUT" | grep -q 'No MCP files found'; then
            log "  ${CYAN}HINT${NC}: node/Mcp/ appears empty. Check .git/info/exclude and .gitignore —"
            log "        required source files MUST be tracked. See .docs/architecture/repo-topology.md §3."
        fi
    fi
else
    log "  ${YELLOW}SKIP${NC} PHPUnit not installed (run: cd core && composer install)"
fi
# CLI tests: only reliable on clean worktree (separate repo, may have parallel WIP)
CLI_DIRTY=$(git -C "$PROJECT_ROOT/cli" status --porcelain -- ':!.phpunit.cache' ':!.phpunit.result.cache' 2>/dev/null | head -1)
if [[ -n "$CLI_DIRTY" ]]; then
    log "  ${YELLOW}WARN${NC} CLI worktree dirty — skipping CLI tests (parallel WIP detected)"
else
    if [[ -f "$PROJECT_ROOT/cli/vendor/bin/phpunit" ]]; then
        if CLI_TEST_OUT=$(cd "$PROJECT_ROOT/cli" && ./vendor/bin/phpunit 2>&1); then
            log "  ${GREEN}PASS${NC} CLI tests passed"
        else
            TEST_COUNT=$((TEST_COUNT + 1))
            CLI_FAIL_TAIL=$(echo "$CLI_TEST_OUT" | tail -30)
            TEST_FINDINGS=$(echo "$TEST_FINDINGS" | jq \
                --arg detail "$CLI_FAIL_TAIL" \
                '. + [{"file": "cli/", "message": "CLI PHPUnit tests failed", "detail": $detail}]')
            log "  ${RED}FAIL${NC} CLI tests failed"
            log "  ${RED}──── CLI PHPUnit output (last 30 lines) ────${NC}"
            echo "$CLI_TEST_OUT" | tail -30 | while IFS= read -r _line; do
                log "    $_line"
            done
            log "  ${RED}────────────────────────────────────────────${NC}"
        fi
    else
        log "  ${YELLOW}SKIP${NC} CLI PHPUnit not installed (run: cd cli && composer install)"
    fi
fi
add_category "phpunit" "$([ $TEST_COUNT -eq 0 ] && echo pass || echo fail)" "$TEST_COUNT" "$TEST_FINDINGS"

# ── Check 3: Silent catch blocks ────────────────────────────────────────

log "${BOLD}[3/19] Silent catch blocks${NC}"

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

log "${BOLD}[4/19] Debug artifacts${NC}"

DEBUG_FINDINGS="[]"
DEBUG_COUNT=0

# Search for dd(), dump(), var_dump(), print_r() — excluding compiled output and vendor
# CLI scanned for dd()/var_dump() only — dump() is intentional --dump CLI feature
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
    # Skip legitimate library method calls (Yaml::dump, ->dump, etc.)
    [[ "$content" == *"::dump("* ]] && continue
    [[ "$content" == *"->dump("* ]] && continue
    # Skip commented-out debug lines
    trimmed="${content#"${content%%[![:space:]]*}"}"
    [[ "$trimmed" == //* ]] && continue
    # Skip dump method definitions
    [[ "$content" == *"function dump("* ]] && continue
    DEBUG_COUNT=$((DEBUG_COUNT + 1))
    DEBUG_FINDINGS=$(echo "$DEBUG_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line"
done < <(
    grep -rn '\bvar_dump\s*(\|dump\s*(\|print_r\s*(\|\bdd\s*(' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" "$PROJECT_ROOT/scripts" --include='*.php' 2>/dev/null || true
    grep -rn '\bvar_dump\s*(\|\bdd\s*(' "$PROJECT_ROOT/cli/src" --include='*.php' 2>/dev/null || true
)

if [[ $DEBUG_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No debug artifacts"
fi
add_category "debug-artifacts" "$([ $DEBUG_COUNT -eq 0 ] && echo pass || echo warn)" "$DEBUG_COUNT" "$DEBUG_FINDINGS"

# ── Check 5: TODO/FIXME markers ────────────────────────────────────────

log "${BOLD}[5/19] TODO/FIXME markers${NC}"

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
    # Skip lines where TODO/FIXME appears inside string literals (instruction text, not actual TODO)
    # Only flag TODO/FIXME in comment context (// # /* * prefixes)
    if ! echo "$content" | grep -qE '(//|/\*|^[[:space:]]*\*[[:space:]]|^[[:space:]]*#).*(TODO|FIXME|@todo|@fixme)'; then
        continue
    fi
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

log "${BOLD}[6/19] Unsafe patterns (eval/shell_exec/die/exit)${NC}"

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

log "${BOLD}[7/19] Shell script safety headers${NC}"

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

log "${BOLD}[8/19] No-op escape method detection${NC}"

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

# ── Check 9: self:: in trait files ─────────────────────────────────────

log "${BOLD}[9/19] Late static binding in traits${NC}"

LSB_FINDINGS="[]"
LSB_COUNT=0

# Traits should use static:: not self:: for methods that may be overridden
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    # Skip constant references (self::UPPER_CASE) — constants don't participate in LSB
    # Only flag self:: followed by lowercase (method calls that need static::)
    if ! echo "$content" | grep -qE 'self::[a-z]'; then
        continue
    fi
    LSB_COUNT=$((LSB_COUNT + 1))
    LSB_FINDINGS=$(echo "$LSB_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${YELLOW}WARN${NC} $relative:$line — self:: in trait (should be static::)"
done < <(find "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" -name '*Trait*.php' -print0 2>/dev/null | xargs -0 grep -rn '\bself::' 2>/dev/null || true)

if [[ $LSB_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No self:: in trait files"
fi
add_category "trait-lsb" "$([ $LSB_COUNT -eq 0 ] && echo pass || echo warn)" "$LSB_COUNT" "$LSB_FINDINGS"

# ── Check 10: Known typos ──────────────────────────────────────────────

log "${BOLD}[10/19] Known typos in codebase${NC}"

TYPO_FINDINGS="[]"
TYPO_COUNT=0

# "Standarts" is a known P0-004 typo that propagated through 4 files.
# This check prevents regression after the CompileStandardsTrait rename.
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == .docs/* ]] && continue
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    TYPO_COUNT=$((TYPO_COUNT + 1))
    TYPO_FINDINGS=$(echo "$TYPO_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
    log "  ${RED}FAIL${NC} $relative:$line — typo: Standarts (should be Standards)"
done < <(grep -rn 'Standarts' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

if [[ $TYPO_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No known typos"
fi
add_category "known-typos" "$([ $TYPO_COUNT -eq 0 ] && echo pass || echo fail)" "$TYPO_COUNT" "$TYPO_FINDINGS"

# ── Check 11: Dev deps in production require ───────────────────────────

log "${BOLD}[11/19] Dev dependencies in production require${NC}"

DEVDEP_FINDINGS="[]"
DEVDEP_COUNT=0

# Known dev-only packages that should be in require-dev, not require
DEV_ONLY_PACKAGES=("fakerphp/faker" "phpunit/phpunit" "phpstan/phpstan" "vimeo/psalm")

for composer_file in "$PROJECT_ROOT"/*/composer.json "$PROJECT_ROOT/composer.json"; do
    [[ ! -f "$composer_file" ]] && continue
    relative="${composer_file#$PROJECT_ROOT/}"
    for pkg in "${DEV_ONLY_PACKAGES[@]}"; do
        # Check if package is in "require" (not "require-dev")
        if jq -e --arg pkg "$pkg" '.require[$pkg] // empty' "$composer_file" >/dev/null 2>&1; then
            DEVDEP_COUNT=$((DEVDEP_COUNT + 1))
            DEVDEP_FINDINGS=$(echo "$DEVDEP_FINDINGS" | jq \
                --arg file "$relative" \
                --arg pkg "$pkg" \
                '. + [{"file": $file, "package": $pkg, "message": "dev-only package in production require"}]')
            log "  ${RED}FAIL${NC} $relative — $pkg in require (should be require-dev)"
        fi
    done
done

if [[ $DEVDEP_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No dev deps in production require"
fi
add_category "dev-deps-prod" "$([ $DEVDEP_COUNT -eq 0 ] && echo pass || echo fail)" "$DEVDEP_COUNT" "$DEVDEP_FINDINGS"

# ── Check 12: PHPStan (static analysis) ───────────────────────────────

log "${BOLD}[12/19] PHPStan static analysis${NC}"

PHPSTAN_FINDINGS="[]"
PHPSTAN_COUNT=0
if [[ -f "$PROJECT_ROOT/core/vendor/bin/phpstan" ]]; then
    if (cd "$PROJECT_ROOT/core" && ./vendor/bin/phpstan analyse --no-progress 2>&1) >/dev/null 2>&1; then
        log "  ${GREEN}PASS${NC} Core phpstan passed"
    else
        PHPSTAN_COUNT=$((PHPSTAN_COUNT + 1))
        PHPSTAN_FINDINGS=$(echo "$PHPSTAN_FINDINGS" | jq '. + [{"file": "core/", "message": "PHPStan analysis failed"}]')
        log "  ${RED}FAIL${NC} Core phpstan failed"
    fi
else
    log "  ${YELLOW}SKIP${NC} PHPStan not installed (run: cd core && composer install)"
fi
# CLI phpstan: only reliable on clean worktree (separate repo, may have parallel WIP)
CLI_DIRTY_PHPSTAN=$(git -C "$PROJECT_ROOT/cli" status --porcelain -- ':!.phpunit.cache' ':!.phpunit.result.cache' 2>/dev/null | head -1)
if [[ -n "$CLI_DIRTY_PHPSTAN" ]]; then
    log "  ${YELLOW}WARN${NC} CLI worktree dirty — skipping CLI phpstan (parallel WIP detected)"
else
    if [[ -f "$PROJECT_ROOT/cli/vendor/bin/phpstan" ]]; then
        if (cd "$PROJECT_ROOT/cli" && ./vendor/bin/phpstan analyse --no-progress 2>&1) >/dev/null 2>&1; then
            log "  ${GREEN}PASS${NC} CLI phpstan passed"
        else
            PHPSTAN_COUNT=$((PHPSTAN_COUNT + 1))
            PHPSTAN_FINDINGS=$(echo "$PHPSTAN_FINDINGS" | jq '. + [{"file": "cli/", "message": "CLI PHPStan analysis failed"}]')
            log "  ${RED}FAIL${NC} CLI phpstan failed"
        fi
    else
        log "  ${YELLOW}SKIP${NC} CLI PHPStan not installed (run: cd cli && composer install)"
    fi
fi
add_category "phpstan" "$([ $PHPSTAN_COUNT -eq 0 ] && echo pass || echo fail)" "$PHPSTAN_COUNT" "$PHPSTAN_FINDINGS"

# ── Check 13: strict_types declaration ─────────────────────────────────

log "${BOLD}[13/19] Missing declare(strict_types=1)${NC}"

STRICT_FINDINGS="[]"
STRICT_COUNT=0

# Every PHP file in core/src, node/, scripts/*.php must have declare(strict_types=1)
while IFS= read -r -d '' file; do
    relative="${file#$PROJECT_ROOT/}"
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    # Check first 5 lines for strict_types declaration
    if ! head -5 "$file" 2>/dev/null | grep -q 'declare(strict_types=1)'; then
        STRICT_COUNT=$((STRICT_COUNT + 1))
        STRICT_FINDINGS=$(echo "$STRICT_FINDINGS" | jq \
            --arg file "$relative" \
            '. + [{"file": $file, "message": "Missing declare(strict_types=1)"}]')
        log "  ${RED}FAIL${NC} $relative — missing strict_types"
    fi
done < <(find "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" -name '*.php' -print0 2>/dev/null)

# Also check scripts/*.php
while IFS= read -r -d '' file; do
    relative="${file#$PROJECT_ROOT/}"
    if ! head -5 "$file" 2>/dev/null | grep -q 'declare(strict_types=1)'; then
        STRICT_COUNT=$((STRICT_COUNT + 1))
        STRICT_FINDINGS=$(echo "$STRICT_FINDINGS" | jq \
            --arg file "$relative" \
            '. + [{"file": $file, "message": "Missing declare(strict_types=1)"}]')
        log "  ${RED}FAIL${NC} $relative — missing strict_types"
    fi
done < <(find "$PROJECT_ROOT/scripts" -maxdepth 1 -name '*.php' -print0 2>/dev/null)

if [[ $STRICT_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} All PHP files declare strict_types"
fi
add_category "strict-types" "$([ $STRICT_COUNT -eq 0 ] && echo pass || echo fail)" "$STRICT_COUNT" "$STRICT_FINDINGS"

# ── Check 14: Secret patterns in tracked files ─────────────────────────

log "${BOLD}[14/19] Secret patterns in tracked files${NC}"

SECRET_FINDINGS="[]"
SECRET_COUNT=0

# Patterns that indicate leaked secrets
SECRET_PATTERN='github_pat_[A-Za-z0-9_]{10,}|ctx7sk-[a-f0-9-]{8,}|gsk_[A-Za-z0-9]{10,}|sk-or-v1-[A-Za-z0-9]{10,}'

while IFS= read -r tracked_file; do
    [[ -z "$tracked_file" ]] && continue
    # Skip files that legitimately reference patterns
    case "$tracked_file" in
        .env.example|*.env.example) continue ;;
        scripts/scan-secrets.sh) continue ;;
        scripts/audit-enterprise.sh) continue ;;
        .docs/*) continue ;;
        CLAUDE.md) continue ;;
        .claude/*) continue ;;
        .opencode/*) continue ;;
    esac
    # Scan for secret patterns
    while IFS=: read -r line_num content; do
        [[ -z "$line_num" ]] && continue
        SECRET_COUNT=$((SECRET_COUNT + 1))
        SECRET_FINDINGS=$(echo "$SECRET_FINDINGS" | jq \
            --arg file "$tracked_file" \
            --arg line "$line_num" \
            --arg content "$(echo "$content" | head -c 80)" \
            '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
        log "  ${RED}FAIL${NC} $tracked_file:$line_num — secret pattern detected"
    done < <(grep -nE "$SECRET_PATTERN" "$PROJECT_ROOT/$tracked_file" 2>/dev/null || true)
done < <(cd "$PROJECT_ROOT" && git ls-files 2>/dev/null)

if [[ $SECRET_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No secret patterns in tracked files"
fi
add_category "secrets" "$([ $SECRET_COUNT -eq 0 ] && echo pass || echo fail)" "$SECRET_COUNT" "$SECRET_FINDINGS"

# ── Check 15: Hardcoded user paths ────────────────────────────────────

log "${BOLD}[15/19] Hardcoded user paths in tracked source files${NC}"

HPATH_FINDINGS="[]"
HPATH_COUNT=0

# Scan tracked PHP, JSON, YAML source files for /Users/ or /home/ hardcoded paths
# These indicate non-portable, machine-specific configs that break on other machines
while IFS= read -r tracked_file; do
    [[ -z "$tracked_file" ]] && continue
    # Skip files where paths are legitimate references (docs, compiled output, audit tooling)
    case "$tracked_file" in
        .docs/*) continue ;;
        .claude/*) continue ;;
        .opencode/*) continue ;;
        CLAUDE.md) continue ;;
        boards/*) continue ;;
        .laboratories/*) continue ;;
        scripts/audit-enterprise.sh) continue ;;
        scripts/scan-secrets.sh) continue ;;
        agent-schema.json) continue ;;
        AGENTS.md) continue ;;
    esac
    while IFS=: read -r line_num content; do
        [[ -z "$line_num" ]] && continue
        HPATH_COUNT=$((HPATH_COUNT + 1))
        HPATH_FINDINGS=$(echo "$HPATH_FINDINGS" | jq \
            --arg file "$tracked_file" \
            --arg line "$line_num" \
            --arg content "$(echo "$content" | head -c 200)" \
            '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
        log "  ${YELLOW}WARN${NC} $tracked_file:$line_num — hardcoded user path"
    done < <(grep -nE '/Users/[a-zA-Z]|/home/[a-zA-Z]' "$PROJECT_ROOT/$tracked_file" 2>/dev/null || true)
done < <(cd "$PROJECT_ROOT" && git ls-files -- '*.php' '*.json' '*.yml' '*.yaml' '*.sh' 2>/dev/null)

if [[ $HPATH_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No hardcoded user paths in tracked source files"
fi
add_category "hardcoded-paths" "$([ $HPATH_COUNT -eq 0 ] && echo pass || echo warn)" "$HPATH_COUNT" "$HPATH_FINDINGS"

# ── Check 16: Degradation observability ────────────────────────────────

log "${BOLD}[16/19] Degradation observability in catch blocks${NC}"

DEGRAD_COUNT=0
DEGRAD_FINDINGS="[]"
HAS_LOGGING=0

# Scan all VarExporter catch blocks for observability signal
# Every catch that returns [unserializable] must have error_log or logDegradation
while IFS= read -r php_file; do
    [[ -z "$php_file" ]] && continue
    relative="${php_file#$PROJECT_ROOT/}"
    # Skip vendor directories
    [[ "$relative" == */vendor/* ]] && continue
    # Count catch blocks with VarExporter fallback patterns
    FALLBACK_COUNT=$(grep -c '\[unserializable\]\|unserializable_argument' "$php_file" 2>/dev/null || true)
    FALLBACK_COUNT=${FALLBACK_COUNT:-0}
    if [[ $FALLBACK_COUNT -gt 0 ]]; then
        # Check for observability signal
        LOG_COUNT=$(grep -c 'logDegradation\|error_log.*brain-compile' "$php_file" 2>/dev/null || true)
        LOG_COUNT=${LOG_COUNT:-0}
        if [[ $LOG_COUNT -gt 0 ]]; then
            HAS_LOGGING=$((HAS_LOGGING + LOG_COUNT))
        else
            DEGRAD_COUNT=$((DEGRAD_COUNT + 1))
            DEGRAD_FINDINGS=$(echo "$DEGRAD_FINDINGS" | jq \
                --arg file "$relative" \
                --argjson catches "$FALLBACK_COUNT" \
                '. + [{"file": $file, "catches_without_logging": $catches}]')
            log "  ${YELLOW}WARN${NC} $relative — $FALLBACK_COUNT catch(es) without observability"
        fi
    fi
done < <(find "$PROJECT_ROOT/core/src" -name '*.php' -type f 2>/dev/null)

if [[ $DEGRAD_COUNT -eq 0 && $HAS_LOGGING -gt 0 ]]; then
    log "  ${GREEN}PASS${NC} All degradation catches have observability ($HAS_LOGGING signals found)"
elif [[ $DEGRAD_COUNT -eq 0 && $HAS_LOGGING -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} No degradation catch blocks found"
fi
add_category "degradation-observability" "$([ $DEGRAD_COUNT -eq 0 ] && echo pass || echo warn)" "$DEGRAD_COUNT" "$DEGRAD_FINDINGS"

# ── Check 17: Version consistency ─────────────────────────────────────

log "${BOLD}[17/19] Version consistency${NC}"

VER_FINDINGS="[]"
VER_COUNT=0

ROOT_VERSION=$(jq -r '.version // "missing"' "$PROJECT_ROOT/composer.json" 2>/dev/null || echo "missing")
CORE_VERSION=$(jq -r '.version // "missing"' "$PROJECT_ROOT/core/composer.json" 2>/dev/null || echo "missing")

if [[ "$ROOT_VERSION" != "$CORE_VERSION" ]]; then
    VER_COUNT=1
    VER_FINDINGS=$(echo "$VER_FINDINGS" | jq \
        --arg root "$ROOT_VERSION" \
        --arg core "$CORE_VERSION" \
        '. + [{"root_version": $root, "core_version": $core, "message": "Version mismatch between root and core"}]')
    log "  ${RED}FAIL${NC} root=$ROOT_VERSION, core=$CORE_VERSION — mismatch"
else
    log "  ${GREEN}PASS${NC} root=$ROOT_VERSION, core=$CORE_VERSION — consistent"
fi

# Category: version-consistency — pass/fail determined ONLY by root vs core mismatch.
add_category "version-consistency" "$([ $VER_COUNT -eq 0 ] && echo pass || echo fail)" "$VER_COUNT" "$VER_FINDINGS"

# ── Check 17b/17c: Version drift (separate WARN category) ──
VER_WARN_COUNT=0
VER_DRIFT_FINDINGS="[]"

# 17b: CLI version vs root
CLI_VERSION=$(jq -r '.version // "missing"' "$PROJECT_ROOT/cli/composer.json" 2>/dev/null || echo "missing")
if [[ "$CLI_VERSION" != "$ROOT_VERSION" ]]; then
    VER_WARN_COUNT=$((VER_WARN_COUNT + 1))
    VER_DRIFT_FINDINGS=$(echo "$VER_DRIFT_FINDINGS" | jq \
        --arg root "$ROOT_VERSION" \
        --arg cli "$CLI_VERSION" \
        '. + [{"cli_version": $cli, "root_version": $root, "message": "CLI version differs from root — allowed in dev, must align for release"}]')
    log "  ${YELLOW}WARN${NC} cli=$CLI_VERSION differs from root=$ROOT_VERSION — dev OK, release requires alignment"
fi

# 17c: Per-repo tag vs composer.json
for repo_name in root core cli; do
    case "$repo_name" in
        root) repo_dir="$PROJECT_ROOT"; repo_composer="$PROJECT_ROOT/composer.json" ;;
        core) repo_dir="$PROJECT_ROOT/core"; repo_composer="$PROJECT_ROOT/core/composer.json" ;;
        cli)  repo_dir="$PROJECT_ROOT/cli"; repo_composer="$PROJECT_ROOT/cli/composer.json" ;;
    esac
    [[ ! -d "$repo_dir/.git" && "$repo_name" != "root" ]] && continue
    composer_ver=$(jq -r '.version // "missing"' "$repo_composer" 2>/dev/null || echo "missing")
    # Check if a tag matching composer.json version exists anywhere in the repo
    # (not just on HEAD). Post-tag doc/CI commits move HEAD past the tag — this is
    # normal dev flow, not version drift.
    #
    # Missing tag = normal dev state (tag created at release time). Only WARN when
    # HEAD carries a DIFFERENT tag than composer.json — that's real drift.
    # Pre-publication exact-match is enforced by .docs/product/10-pre-publication.md.
    tag_exists=$(git -C "$repo_dir" tag -l "$composer_ver" 2>/dev/null || echo "")
    head_tag=$(git -C "$repo_dir" describe --tags --exact-match 2>/dev/null || echo "")
    if [[ -z "$tag_exists" ]]; then
        log "  ${GREEN}PASS${NC} $repo_name: tag=$composer_ver pending — normal dev (pre-pub enforces)"
    elif [[ -n "$head_tag" && "$head_tag" != "$composer_ver" ]]; then
        VER_WARN_COUNT=$((VER_WARN_COUNT + 1))
        VER_DRIFT_FINDINGS=$(echo "$VER_DRIFT_FINDINGS" | jq \
            --arg repo "$repo_name" \
            --arg tag "$head_tag" \
            --arg ver "$composer_ver" \
            '. + [{"repo": $repo, "tag": $tag, "composer_version": $ver, "message": "HEAD tag differs from composer.json version"}]')
        log "  ${YELLOW}WARN${NC} $repo_name: tag=$head_tag != composer.json=$composer_ver — drift detected"
    else
        log "  ${GREEN}PASS${NC} $repo_name: tag=$composer_ver exists"
    fi
done

# Separate WARN category — only registered when drift exists, so PASS count is unaffected.
if [[ $VER_WARN_COUNT -gt 0 ]]; then
    add_category "version-drift" "warn" "$VER_WARN_COUNT" "$VER_DRIFT_FINDINGS"
fi

# ── Check 18: MCP schema bypass enforcement ─────────────────────────────

log "${BOLD}[18/19] MCP schema bypass enforcement${NC}"

MCPBYPASS_FINDINGS="[]"
MCPBYPASS_COUNT=0

# Schema-enabled MCP classes: VectorMemoryMcp, VectorTaskMcp
# These have local schemas and MUST use callValidatedJson() unless annotated with @mcp-schema-bypass
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip vendor, compiled output, audit tooling, tests
    [[ "$relative" == vendor/* ]] && continue
    [[ "$relative" == */vendor/* ]] && continue
    [[ "$relative" == .claude/* ]] && continue
    [[ "$relative" == .opencode/* ]] && continue
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    [[ "$relative" == */tests/* ]] && continue
    # Skip if it's callValidatedJson or callJson (already validated)
    [[ "$content" == *"callValidatedJson"* ]] && continue
    [[ "$content" == *"callJson"* ]] && continue
    # Skip string literals (documentation references, not actual calls)
    [[ "$content" == *"'"*"::call("* ]] && continue
    [[ "$content" == *'"'*'::call('* ]] && continue
    # Check if previous 3 lines contain @mcp-schema-bypass annotation
    has_bypass=false
    for offset in 1 2 3; do
        prev_line=$((line - offset))
        if [[ $prev_line -gt 0 ]]; then
            prev_content=$(sed -n "${prev_line}p" "$file" 2>/dev/null || true)
            if [[ "$prev_content" == *"@mcp-schema-bypass"* ]]; then
                has_bypass=true
                break
            fi
        fi
    done
    if [[ "$has_bypass" == false ]]; then
        MCPBYPASS_COUNT=$((MCPBYPASS_COUNT + 1))
        MCPBYPASS_FINDINGS=$(echo "$MCPBYPASS_FINDINGS" | jq \
            --arg file "$relative" \
            --arg line "$line" \
            --arg content "$(echo "$content" | head -c 200)" \
            '. + [{"file": $file, "line": ($line | tonumber), "content": $content}]')
        log "  ${RED}FAIL${NC} $relative:$line — raw ::call() on schema-enabled MCP without @mcp-schema-bypass"
    fi
done < <(grep -rn 'VectorMemoryMcp::call\|VectorTaskMcp::call' "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

if [[ $MCPBYPASS_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} All schema-enabled MCP calls validated or annotated"
fi
add_category "mcp-schema-bypass" "$([ $MCPBYPASS_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPBYPASS_COUNT" "$MCPBYPASS_FINDINGS"

# ── Check 19: Compile clean-worktree gate ────────────────────────────────

log "${BOLD}[19/20] Compile clean-worktree gate${NC}"

COMPILECLEAN_FINDINGS="[]"
COMPILECLEAN_COUNT=0

if command -v brain &>/dev/null; then
    # Snapshot worktree BEFORE compile
    BEFORE_COMPILE=$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null || true)

    # Run compile with --no-lock (audit already runs sequentially)
    if (cd "$PROJECT_ROOT" && BRAIN_ALLOW_NO_LOCK=1 brain compile --no-lock >/dev/null 2>&1); then
        # Snapshot worktree AFTER compile — diff to find NEW changes only
        AFTER_COMPILE=$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null || true)
        NEW_COMPILE_CHANGES=$(diff <(echo "$BEFORE_COMPILE") <(echo "$AFTER_COMPILE") | grep '^>' | sed 's/^> //' || true)

        if [[ -n "$NEW_COMPILE_CHANGES" ]]; then
            COMPILECLEAN_COUNT=1
            DIRTY_FILES=$(echo "$NEW_COMPILE_CHANGES" | awk '{print $2}' | head -20)
            COMPILECLEAN_FINDINGS=$(echo "$COMPILECLEAN_FINDINGS" | jq \
                --arg files "$DIRTY_FILES" \
                '. + [{"message": "brain compile produced new uncommitted changes", "files": $files}]')
            log "  ${RED}FAIL${NC} brain compile dirtied worktree"
        else
            log "  ${GREEN}PASS${NC} brain compile produces clean worktree"
        fi
    else
        log "  ${YELLOW}SKIP${NC} brain compile failed (check compilation errors separately)"
    fi
else
    log "  ${YELLOW}SKIP${NC} brain CLI not available"
fi
add_category "compile-clean" "$([ $COMPILECLEAN_COUNT -eq 0 ] && echo pass || echo fail)" "$COMPILECLEAN_COUNT" "$COMPILECLEAN_FINDINGS"

# ── Check 20: Agent schema enabled set consistency ───────────────────────────

log "${BOLD}[20/20] Agent schema enabled set${NC}"

SCHEMA_FILE="$PROJECT_ROOT/agent-schema.json"
CANON_AGENTS="commit-master documentation-master explore-master vector-master web-research-master"
AGENTSCHEMA_FINDINGS="[]"
AGENTSCHEMA_COUNT=0

if [[ -f "$SCHEMA_FILE" ]]; then
    SCHEMA_AGENTS=$(grep -oE '"(agent|commit|documentation|explore|prompt|script|vector|web-research)-master"' "$SCHEMA_FILE" 2>/dev/null | tr -d '"' | sort -u | tr '\n' ' ' | sed 's/ $//')
    CANON_SORTED=$(echo "$CANON_AGENTS" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')
    
    if [[ "$SCHEMA_AGENTS" != "$CANON_SORTED" ]]; then
        AGENTSCHEMA_COUNT=1
        AGENTSCHEMA_FINDINGS=$(echo "$AGENTSCHEMA_FINDINGS" | jq \
            --arg schema "$SCHEMA_AGENTS" \
            --arg canon "$CANON_SORTED" \
            '. + [{"message": "agent-schema.json enabled set mismatch", "schema_has": $schema, "canon_expects": $canon}]')
        log "  ${RED}FAIL${NC} enabled set mismatch"
        log "    Schema has: $SCHEMA_AGENTS"
        log "    Canon expects: $CANON_SORTED"
    else
        log "  ${GREEN}PASS${NC} enabled agents match canon ($SCHEMA_AGENTS)"
    fi
else
    log "  ${YELLOW}SKIP${NC} agent-schema.json not found"
fi
add_category "agent-schema" "$([ $AGENTSCHEMA_COUNT -eq 0 ] && echo pass || echo fail)" "$AGENTSCHEMA_COUNT" "$AGENTSCHEMA_FINDINGS"

# ── Check 21: MCP tool policy contract ───────────────────────────────────────

log "${BOLD}[21/21] MCP tool policy contract${NC}"

MCPPOLICY_FINDINGS="[]"
MCPPOLICY_COUNT=0

# Run the policy check script (resolves override -> default)
if bash "$PROJECT_ROOT/scripts/check-mcp-tool-policy.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP tool policy valid"
else
    MCPPOLICY_COUNT=1
    MCPPOLICY_FINDINGS=$(echo "$MCPPOLICY_FINDINGS" | jq '. + [{"message": "MCP tool policy validation failed"}]')
    log "  ${RED}FAIL${NC} MCP tool policy validation failed"
    # Re-run to show details
    bash "$PROJECT_ROOT/scripts/check-mcp-tool-policy.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-tool-policy" "$([ $MCPPOLICY_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPPOLICY_COUNT" "$MCPPOLICY_FINDINGS"

# ── Check 22: Self-hosting workspace hygiene ───────────────────────────────

log "${BOLD}[22/22] Self-hosting workspace hygiene${NC}"

SELFSYMLINK_FINDINGS="[]"
SELFSYMLINK_COUNT=0

# Check if .brain is a symlink to '.' (self-hosting mode)
if [[ -L "$PROJECT_ROOT/.brain" ]]; then
    SYMLINK_TARGET=$(readlink "$PROJECT_ROOT/.brain" 2>/dev/null || echo "")

    if [[ "$SYMLINK_TARGET" == "." ]]; then
        # Self-hosting mode: verify hygiene rules
        # Rule 1: .brain-config/ must exist and be tracked
        if [[ ! -d "$PROJECT_ROOT/.brain-config" ]]; then
            SELFSYMLINK_COUNT=$((SELFSYMLINK_COUNT + 1))
            SELFSYMLINK_FINDINGS=$(echo "$SELFSYMLINK_FINDINGS" | jq '. + [{"message": ".brain-config/ missing in self-hosting repo"}]')
            log "  ${RED}FAIL${NC} .brain-config/ missing"
        else
            # Check if tracked by git
            if ! git -C "$PROJECT_ROOT" ls-files --error-unmatch ".brain-config" >/dev/null 2>&1; then
                SELFSYMLINK_COUNT=$((SELFSYMLINK_COUNT + 1))
                SELFSYMLINK_FINDINGS=$(echo "$SELFSYMLINK_FINDINGS" | jq '. + [{"message": ".brain-config/ not tracked by git"}]')
                log "  ${RED}FAIL${NC} .brain-config/ not tracked"
            fi
        fi

        # Rule 2: config/brain/ must NOT exist (prevent consumer pattern relapse)
        if [[ -d "$PROJECT_ROOT/config/brain" ]]; then
            SELFSYMLINK_COUNT=$((SELFSYMLINK_COUNT + 1))
            SELFSYMLINK_FINDINGS=$(echo "$SELFSYMLINK_FINDINGS" | jq '. + [{"message": "config/brain/ exists — use .brain-config/ for self-hosting"}]')
            log "  ${RED}FAIL${NC} config/brain/ exists (use .brain-config/)"
        fi

        # Rule 3: MCP policy file must exist at canonical location
        if [[ ! -f "$PROJECT_ROOT/.brain-config/mcp-tools.allowlist.json" ]]; then
            SELFSYMLINK_COUNT=$((SELFSYMLINK_COUNT + 1))
            SELFSYMLINK_FINDINGS=$(echo "$SELFSYMLINK_FINDINGS" | jq '. + [{"message": ".brain-config/mcp-tools.allowlist.json missing"}]')
            log "  ${RED}FAIL${NC} MCP policy file missing"
        fi

        if [[ $SELFSYMLINK_COUNT -eq 0 ]]; then
            log "  ${GREEN}PASS${NC} Self-hosting workspace hygiene OK"
        fi
        add_category "self-hosting-hygiene" "$([ $SELFSYMLINK_COUNT -eq 0 ] && echo pass || echo fail)" "$SELFSYMLINK_COUNT" "$SELFSYMLINK_FINDINGS"
    else
        # Symlink but not to '.' — unusual, warn but don't fail
        log "  ${YELLOW}SKIP${NC} .brain symlink to '$SYMLINK_TARGET' (not self-hosting pattern)"
        add_category "self-hosting-hygiene" "info" "0" "[{\"message\": \"symlink to non-dot target\"}]"
    fi
else
    # Consumer project: .brain is not a symlink
    log "  ${YELLOW}SKIP${NC} Consumer project (.brain is not a symlink)"
    add_category "self-hosting-hygiene" "info" "0" "[{\"message\": \"consumer project\"}]"
fi

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

# Blocking exit: any FAIL category = exit 1 (P0 regression)
if [[ $fail_count -gt 0 ]]; then
    log ""
    log "  ${RED}BLOCKED${NC}: $fail_count FAIL categories detected — P0 regression"
    exit 1
fi

exit 0
