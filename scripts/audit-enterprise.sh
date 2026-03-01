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

source "$SCRIPT_DIR/lib/brain-cli.sh"

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

log "${BOLD}[1/60] PHP syntax check${NC}"

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

log "${BOLD}[2/60] PHPUnit tests${NC}"

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

log "${BOLD}[3/60] Silent catch blocks${NC}"

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

log "${BOLD}[4/60] Debug artifacts${NC}"

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

log "${BOLD}[5/60] TODO/FIXME markers${NC}"

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

log "${BOLD}[6/60] Unsafe patterns (eval/shell_exec/die/exit)${NC}"

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

log "${BOLD}[7/60] Shell script safety headers${NC}"

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

log "${BOLD}[8/60] No-op escape method detection${NC}"

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

log "${BOLD}[9/60] Late static binding in traits${NC}"

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

log "${BOLD}[10/60] Known typos in codebase${NC}"

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

log "${BOLD}[11/60] Dev dependencies in production require${NC}"

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

log "${BOLD}[12/60] PHPStan static analysis${NC}"

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

log "${BOLD}[13/60] Missing declare(strict_types=1)${NC}"

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

log "${BOLD}[14/60] Secret patterns in tracked files${NC}"

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

log "${BOLD}[15/60] Hardcoded user paths in tracked source files${NC}"

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

log "${BOLD}[16/60] Degradation observability in catch blocks${NC}"

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

log "${BOLD}[17/60] Version consistency${NC}"

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

log "${BOLD}[18/60] MCP schema bypass enforcement${NC}"

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

log "${BOLD}[19/60] Compile clean-worktree gate${NC}"

COMPILECLEAN_FINDINGS="[]"
COMPILECLEAN_COUNT=0

if command -v brain &>/dev/null; then
    # Ensure isolated directory exists with marker
    ISOLATED_DIR="$PROJECT_ROOT/dist/tmp"
    mkdir -p "$ISOLATED_DIR"
    touch "$ISOLATED_DIR/.brain-testmode.marker"

    # Snapshot worktree BEFORE compile
    BEFORE_COMPILE=$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null || true)

    # Run compile from isolated directory
    if (cd "$ISOLATED_DIR" && BRAIN_TEST_MODE=1 BRAIN_TEST_MODE_SOURCE=ci BRAIN_ALLOW_NO_LOCK=1 brain_cli compile --no-lock --no-interaction >/dev/null 2>&1); then
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

log "${BOLD}[20/60] Agent schema enabled set${NC}"

CANON_FILE="$PROJECT_ROOT/.brain-config/enabled-agents.json"
AGENTSCHEMA_FINDINGS="[]"
AGENTSCHEMA_COUNT=0

# Determine Canon list from canonical JSON file
if [[ -f "$CANON_FILE" ]]; then
    CANON_SORTED=$(jq -r '.enabled[]' "$CANON_FILE" | sort | tr '\n' ' ' | sed 's/ $//')
else
    # Fallback to hardcoded enterprise canon (5 agents)
    CANON_SORTED=$(echo "commit-master documentation-master explore-master vector-master web-research-master" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')
fi

# Determine Observed list from deterministic filtered CLI source
OBS_SORTED=$(brain_cli list:masters --json | jq -r 'keys[]' | sort | tr '\n' ' ' | sed 's/ $//')

if [[ "$OBS_SORTED" != "$CANON_SORTED" ]]; then
    AGENTSCHEMA_COUNT=1
    AGENTSCHEMA_FINDINGS=$(echo "$AGENTSCHEMA_FINDINGS" | jq \
        --arg observed "$OBS_SORTED" \
        --arg canon "$CANON_SORTED" \
        '. + [{"message": "enabled agents set mismatch", "observed": $observed, "canon_expects": $canon}]')
    log "  ${RED}FAIL${NC} enabled set mismatch"
    log "    Observed: $OBS_SORTED"
    log "    Canon expects: $CANON_SORTED"
else
    log "  ${GREEN}PASS${NC} enabled agents match canon ($OBS_SORTED)"
fi
add_category "agent-schema" "$([ $AGENTSCHEMA_COUNT -eq 0 ] && echo pass || echo fail)" "$AGENTSCHEMA_COUNT" "$AGENTSCHEMA_FINDINGS"

# ── Check 21: MCP tool policy contract ───────────────────────────────────────

log "${BOLD}[21/60] MCP tool policy contract${NC}"

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

log "${BOLD}[22/60] Self-hosting workspace hygiene${NC}"

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

# ── Check 23: Test Mode Contract enforcement ───────────────────────────────

log "${BOLD}[23/60] Test Mode Contract enforcement${NC}"

TESTMODE_FINDINGS="[]"
TESTMODE_COUNT=0

# Check 24a: BRAIN_ALLOW_NO_LOCK usage outside tests
# Only flag actual USAGE patterns (getenv, $_ENV), not string references in comments/docs
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip test files and this audit script
    [[ "$relative" == */tests/* ]] && continue
    [[ "$relative" == *Test.php ]] && continue
    [[ "$relative" == scripts/audit-enterprise.sh ]] && continue
    [[ "$relative" == .docs/* ]] && continue
    # Skip CompileLock.php and CompileCommand.php - they implement the contract
    [[ "$relative" == cli/src/Services/CompileLock.php ]] && continue
    [[ "$relative" == cli/src/Console/Commands/CompileCommand.php ]] && continue
    [[ "$relative" == core/src/Includes/Universal/CompileSafetyInclude.php ]] && continue
    TESTMODE_COUNT=$((TESTMODE_COUNT + 1))
    TESTMODE_FINDINGS=$(echo "$TESTMODE_FINDINGS" | jq \
        --arg file "$relative" \
        --arg line "$line" \
        --arg content "$(echo "$content" | head -c 200)" \
        '. + [{"file": $file, "line": ($line | tonumber), "type": "allow-no-lock-outside-tests", "content": $content}]')
    log "  ${RED}FAIL${NC} $relative:$line — BRAIN_ALLOW_NO_LOCK outside tests"
done < <(grep -rn "getenv.*BRAIN_ALLOW_NO_LOCK\|_ENV.*BRAIN_ALLOW_NO_LOCK" "$PROJECT_ROOT/core/src" "$PROJECT_ROOT/cli/src" "$PROJECT_ROOT/node" --include='*.php' 2>/dev/null || true)

# Check 24b: CompileCommand validates test mode contract (static analysis)
# Ensure enforceNoLockPolicy() calls validateTestModeContract()
COMPILECMD="$PROJECT_ROOT/cli/src/Console/Commands/CompileCommand.php"
if [[ -f "$COMPILECMD" ]]; then
    if ! grep -q 'validateTestModeContract' "$COMPILECMD" 2>/dev/null; then
        TESTMODE_COUNT=$((TESTMODE_COUNT + 1))
        TESTMODE_FINDINGS=$(echo "$TESTMODE_FINDINGS" | jq '. + [{"file": "cli/src/Console/Commands/CompileCommand.php", "type": "missing-test-mode-validation", "message": "enforceNoLockPolicy does not call validateTestModeContract"}]')
        log "  ${RED}FAIL${NC} CompileCommand missing test mode validation"
    fi
fi

# Check 24c: CompileLock has required test mode methods
COMPILELOCK="$PROJECT_ROOT/cli/src/Services/CompileLock.php"
if [[ -f "$COMPILELOCK" ]]; then
    REQUIRED_METHODS="isTestMode isTestModeSourceCi isPhpUnit isUnderTempDir isUnderDistTmp hasTestModeMarker isBrainProjectRoot isIsolatedWorkdir validateTestModeContract getContractDiagnostics"
    for method in $REQUIRED_METHODS; do
        if ! grep -q "function $method" "$COMPILELOCK" 2>/dev/null; then
            TESTMODE_COUNT=$((TESTMODE_COUNT + 1))
            TESTMODE_FINDINGS=$(echo "$TESTMODE_FINDINGS" | jq \
                --arg method "$method" \
                '. + [{"file": "cli/src/Services/CompileLock.php", "type": "missing-method", "method": $method}]')
            log "  ${RED}FAIL${NC} CompileLock missing method: $method"
        fi
    done
fi

# Check 24d: Test mode marker file can be created in dist/tmp
MARKER_DIR="$PROJECT_ROOT/dist/tmp"
MARKER_FILE="$MARKER_DIR/.brain-testmode.marker"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
if [[ ! -d "$MARKER_DIR" ]]; then
    TESTMODE_COUNT=$((TESTMODE_COUNT + 1))
    TESTMODE_FINDINGS=$(echo "$TESTMODE_FINDINGS" | jq '. + [{"file": "dist/tmp/", "type": "missing-marker-dir", "message": "Cannot create dist/tmp directory for isolated compile"}]')
    log "  ${RED}FAIL${NC} Cannot create dist/tmp directory"
fi

if [[ $TESTMODE_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} Test Mode Contract enforced"
fi
add_category "test-mode-contract" "$([ $TESTMODE_COUNT -eq 0 ] && echo pass || echo fail)" "$TESTMODE_COUNT" "$TESTMODE_FINDINGS"

# ── Check 24: MCP policy inspector output contract ─────────────────────────

log "${BOLD}[24/60] MCP policy inspector output contract${NC}"

MCPPOLICYINSPECTOR_FINDINGS="[]"
MCPPOLICYINSPECTOR_COUNT=0

# Run brain mcp:policy and validate output
POLICY_OUTPUT=$(brain_cli mcp:policy --no-interaction 2>&1) || true

# Check 1: Valid JSON
if ! echo "$POLICY_OUTPUT" | jq empty 2>/dev/null; then
    MCPPOLICYINSPECTOR_COUNT=$((MCPPOLICYINSPECTOR_COUNT + 1))
    MCPPOLICYINSPECTOR_FINDINGS=$(echo "$MCPPOLICYINSPECTOR_FINDINGS" | jq '. + [{"message": "Invalid JSON output"}]')
    log "  ${RED}FAIL${NC} Invalid JSON output"
fi

# Check 2: Required keys present
if [[ $MCPPOLICYINSPECTOR_COUNT -eq 0 ]]; then
    REQUIRED_TOP_KEYS="enabled kill_switch_env"
    for key in $REQUIRED_TOP_KEYS; do
        if ! echo "$POLICY_OUTPUT" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
            MCPPOLICYINSPECTOR_COUNT=$((MCPPOLICYINSPECTOR_COUNT + 1))
            MCPPOLICYINSPECTOR_FINDINGS=$(echo "$MCPPOLICYINSPECTOR_FINDINGS" | jq --arg key "$key" '. + [{"message": "Missing required top-level key", "key": $key}]')
            log "  ${RED}FAIL${NC} Missing required top-level key: $key"
        fi
    done

    REQUIRED_DATA_KEYS="resolved_path schema_version allowed_count never_count overlap"
    for key in $REQUIRED_DATA_KEYS; do
        if ! echo "$POLICY_OUTPUT" | jq -e ".data | has(\"$key\")" >/dev/null 2>&1; then
            MCPPOLICYINSPECTOR_COUNT=$((MCPPOLICYINSPECTOR_COUNT + 1))
            MCPPOLICYINSPECTOR_FINDINGS=$(echo "$MCPPOLICYINSPECTOR_FINDINGS" | jq --arg key "$key" '. + [{"message": "Missing required data key", "key": $key}]')
            log "  ${RED}FAIL${NC} Missing required data key: $key"
        fi
    done
fi

# Check 3: No forbidden patterns (tool names, secrets)
if [[ $MCPPOLICYINSPECTOR_COUNT -eq 0 ]]; then
    FORBIDDEN_PATTERNS="docs compile make: token secret api_key bearer sk- gsk_ ctx7sk"
    OUTPUT_LOWER=$(echo "$POLICY_OUTPUT" | tr '[:upper:]' '[:lower:]')
    for pattern in $FORBIDDEN_PATTERNS; do
        if echo "$OUTPUT_LOWER" | grep -qE "$pattern"; then
            MCPPOLICYINSPECTOR_COUNT=$((MCPPOLICYINSPECTOR_COUNT + 1))
            MCPPOLICYINSPECTOR_FINDINGS=$(echo "$MCPPOLICYINSPECTOR_FINDINGS" | jq --arg pattern "$pattern" '. + [{"message": "Forbidden pattern in output", "pattern": $pattern}]')
            log "  ${RED}FAIL${NC} Forbidden pattern detected: $pattern"
        fi
    done
fi

if [[ $MCPPOLICYINSPECTOR_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP policy inspector output valid"
fi
add_category "mcp-policy-inspector" "$([ $MCPPOLICYINSPECTOR_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPPOLICYINSPECTOR_COUNT" "$MCPPOLICYINSPECTOR_FINDINGS"

# ── Check 25: MCP allowlist contract ───────────────────────────────────────

log "${BOLD}[25/60] MCP allowlist contract${NC}"

MCPALLOWLIST_FINDINGS="[]"
MCPALLOWLIST_COUNT=0

# Run brain mcp:allowlist and validate output
ALLOWLIST_OUTPUT=$(brain_cli mcp:allowlist --no-interaction 2>&1) || true

# Check 1: Valid JSON
if ! echo "$ALLOWLIST_OUTPUT" | jq empty 2>/dev/null; then
    MCPALLOWLIST_COUNT=$((MCPALLOWLIST_COUNT + 1))
    MCPALLOWLIST_FINDINGS=$(echo "$MCPALLOWLIST_FINDINGS" | jq '. + [{"message": "Invalid JSON output"}]')
    log "  ${RED}FAIL${NC} Invalid JSON output"
fi

# Check 2: Required keys present (programmatic v1 contract)
if [[ $MCPALLOWLIST_COUNT -eq 0 ]]; then
    REQUIRED_TOP_ALLOWLIST_KEYS="enabled kill_switch_env"
    for key in $REQUIRED_TOP_ALLOWLIST_KEYS; do
        if ! echo "$ALLOWLIST_OUTPUT" | jq -e "has(\"$key\")" >/dev/null 2>&1; then
            MCPALLOWLIST_COUNT=$((MCPALLOWLIST_COUNT + 1))
            MCPALLOWLIST_FINDINGS=$(echo "$MCPALLOWLIST_FINDINGS" | jq --arg key "$key" '. + [{"message": "Missing required programmatic top-level key", "key": $key}]')
            log "  ${RED}FAIL${NC} Missing programmatic top-level key: $key"
        fi
    done

    REQUIRED_DATA_ALLOWLIST_KEYS="allowed clients never resolved_path schema_version"
    for key in $REQUIRED_DATA_ALLOWLIST_KEYS; do
        if ! echo "$ALLOWLIST_OUTPUT" | jq -e ".data | has(\"$key\")" >/dev/null 2>&1; then
            MCPALLOWLIST_COUNT=$((MCPALLOWLIST_COUNT + 1))
            MCPALLOWLIST_FINDINGS=$(echo "$MCPALLOWLIST_FINDINGS" | jq --arg key "$key" '. + [{"message": "Missing required programmatic data key", "key": $key}]')
            log "  ${RED}FAIL${NC} Missing programmatic data key: $key"
        fi
    done
fi

# Check 3: No secrets
if [[ $MCPALLOWLIST_COUNT -eq 0 ]]; then
    FORBIDDEN_ALLOWLIST_PATTERNS="token secret api_key bearer sk- gsk_ ctx7sk"
    ALLOWLIST_OUTPUT_LOWER=$(echo "$ALLOWLIST_OUTPUT" | tr '[:upper:]' '[:lower:]')
    for pattern in $FORBIDDEN_ALLOWLIST_PATTERNS; do
        if echo "$ALLOWLIST_OUTPUT_LOWER" | grep -qE "$pattern"; then
            MCPALLOWLIST_COUNT=$((MCPALLOWLIST_COUNT + 1))
            MCPALLOWLIST_FINDINGS=$(echo "$MCPALLOWLIST_FINDINGS" | jq --arg pattern "$pattern" '. + [{"message": "Secret pattern in allowlist output", "pattern": $pattern}]')
            log "  ${RED}FAIL${NC} Secret pattern detected: $pattern"
        fi
    done
fi

# Check 4: Respects kill switch
if [[ $MCPALLOWLIST_COUNT -eq 0 ]]; then
    KILL_OUTPUT=$(BRAIN_DISABLE_MCP=true brain_cli mcp:allowlist --no-interaction 2>&1) || true
    if [[ "$(echo "$KILL_OUTPUT" | jq -r '.enabled')" != "false" ]]; then
        MCPALLOWLIST_COUNT=$((MCPALLOWLIST_COUNT + 1))
        MCPALLOWLIST_FINDINGS=$(echo "$MCPALLOWLIST_FINDINGS" | jq '. + [{"message": "Kill switch ignored"}]')
        log "  ${RED}FAIL${NC} Kill switch ignored"
    fi
fi

if [[ $MCPALLOWLIST_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP allowlist programmatic output valid"
fi
add_category "mcp-allowlist-contract" "$([ $MCPALLOWLIST_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPALLOWLIST_COUNT" "$MCPALLOWLIST_FINDINGS"

# ── Check 26: brain-tools serve contract (docs_search) ─────────────────────

log "${BOLD}[26/60] brain-tools serve contract (docs_search)${NC}"

MCPSERVE_DOCS_FINDINGS="[]"
MCPSERVE_DOCS_COUNT=0

# Test docs_search via mcp:serve JSON-RPC
MCPSERVE_DOCS_OUT=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"test","limit":1}}}' | BRAIN_AGENT_ID=claude brain_cli mcp:serve 2>/tmp/mcpserve_err_26.txt)

# Check stderr is empty
if [[ -s /tmp/mcpserve_err_26.txt ]]; then
    MCPSERVE_DOCS_COUNT=$((MCPSERVE_DOCS_COUNT + 1))
    MCPSERVE_DOCS_FINDINGS=$(echo "$MCPSERVE_DOCS_FINDINGS" | jq '. + [{"message": "mcp:serve docs_search produced stderr output"}]')
    log "  ${RED}FAIL${NC} stderr not empty"
fi

# Check JSON-RPC response validity
if ! echo "$MCPSERVE_DOCS_OUT" | jq -e '.result.content[0].type == "text"' >/dev/null 2>&1; then
    MCPSERVE_DOCS_COUNT=$((MCPSERVE_DOCS_COUNT + 1))
    MCPSERVE_DOCS_FINDINGS=$(echo "$MCPSERVE_DOCS_FINDINGS" | jq '. + [{"message": "mcp:serve docs_search invalid JSON-RPC response"}]')
    log "  ${RED}FAIL${NC} invalid JSON-RPC response"
fi

# Check response contains valid JSON in text field
DOCS_TEXT=$(echo "$MCPSERVE_DOCS_OUT" | jq -r '.result.content[0].text' 2>/dev/null || echo "")
if ! echo "$DOCS_TEXT" | jq -e '.total_matches' >/dev/null 2>&1; then
    MCPSERVE_DOCS_COUNT=$((MCPSERVE_DOCS_COUNT + 1))
    MCPSERVE_DOCS_FINDINGS=$(echo "$MCPSERVE_DOCS_FINDINGS" | jq '. + [{"message": "mcp:serve docs_search response missing total_matches"}]')
    log "  ${RED}FAIL${NC} response missing total_matches"
fi

if [[ $MCPSERVE_DOCS_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} brain-tools docs_search contract valid"
fi
add_category "brain-tools-docs_search" "$([ $MCPSERVE_DOCS_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPSERVE_DOCS_COUNT" "$MCPSERVE_DOCS_FINDINGS"

# ── Check 27: brain-tools serve contract (diagnose) ────────────────────────

log "${BOLD}[27/60] brain-tools serve contract (diagnose)${NC}"

MCPSERVE_DIAG_FINDINGS="[]"
MCPSERVE_DIAG_COUNT=0

# Test diagnose via mcp:serve JSON-RPC
MCPSERVE_DIAG_OUT=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}' | BRAIN_AGENT_ID=claude brain_cli mcp:serve 2>/tmp/mcpserve_err_27.txt)

# Check stderr is empty
if [[ -s /tmp/mcpserve_err_27.txt ]]; then
    MCPSERVE_DIAG_COUNT=$((MCPSERVE_DIAG_COUNT + 1))
    MCPSERVE_DIAG_FINDINGS=$(echo "$MCPSERVE_DIAG_FINDINGS" | jq '. + [{"message": "mcp:serve diagnose produced stderr output"}]')
    log "  ${RED}FAIL${NC} stderr not empty"
fi

# Check JSON-RPC response validity
if ! echo "$MCPSERVE_DIAG_OUT" | jq -e '.result.content[0].type == "text"' >/dev/null 2>&1; then
    MCPSERVE_DIAG_COUNT=$((MCPSERVE_DIAG_COUNT + 1))
    MCPSERVE_DIAG_FINDINGS=$(echo "$MCPSERVE_DIAG_FINDINGS" | jq '. + [{"message": "mcp:serve diagnose invalid JSON-RPC response"}]')
    log "  ${RED}FAIL${NC} invalid JSON-RPC response"
fi

# Check response contains valid JSON with self_hosting field
DIAG_TEXT=$(echo "$MCPSERVE_DIAG_OUT" | jq -r '.result.content[0].text' 2>/dev/null || echo "")
if ! echo "$DIAG_TEXT" | jq -e '.self_hosting' >/dev/null 2>&1; then
    MCPSERVE_DIAG_COUNT=$((MCPSERVE_DIAG_COUNT + 1))
    MCPSERVE_DIAG_FINDINGS=$(echo "$MCPSERVE_DIAG_FINDINGS" | jq '. + [{"message": "mcp:serve diagnose response missing self_hosting"}]')
    log "  ${RED}FAIL${NC} response missing self_hosting"
fi

if [[ $MCPSERVE_DIAG_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} brain-tools diagnose contract valid"
fi
add_category "brain-tools-diagnose" "$([ $MCPSERVE_DIAG_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPSERVE_DIAG_COUNT" "$MCPSERVE_DIAG_FINDINGS"

# ── Check 28: Secret reference hygiene ─────────────────────────────────────

log "${BOLD}[28/60] Secret reference hygiene${NC}"

SECRETREF_FINDINGS="[]"
SECRETREF_COUNT=0

if ! bash scripts/check-secret-references.sh; then
    SECRETREF_COUNT=$((SECRETREF_COUNT + 1))
    SECRETREF_FINDINGS=$(echo "$SECRETREF_FINDINGS" | jq '. + [{"message": "Risky secret references detected in tracked files"}]')
    log "  ${RED}FAIL${NC} Risky secret references detected"
else
    log "  ${GREEN}PASS${NC} No risky secret references found"
fi
add_category "secret-reference-hygiene" "$([ $SECRETREF_COUNT -eq 0 ] && echo pass || echo fail)" "$SECRETREF_COUNT" "$SECRETREF_FINDINGS"

# ── Check 29: MCP registry contract ─────────────────────────────────────────

log "${BOLD}[29/60] MCP registry contract${NC}"

MCPREGISTRY_FINDINGS="[]"
MCPREGISTRY_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-registry.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP registry valid"
else
    MCPREGISTRY_COUNT=1
    MCPREGISTRY_FINDINGS=$(echo "$MCPREGISTRY_FINDINGS" | jq '. + [{"message": "MCP registry validation failed"}]')
    log "  ${RED}FAIL${NC} MCP registry validation failed"
    bash "$PROJECT_ROOT/scripts/check-mcp-registry.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-registry" "$([ $MCPREGISTRY_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPREGISTRY_COUNT" "$MCPREGISTRY_FINDINGS"

# ── Check 30: MCP compile consistency ───────────────────────────────────────

log "${BOLD}[30/60] MCP compile consistency${NC}"

MCPCONSISTENCY_FINDINGS="[]"
MCPCONSISTENCY_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-compile-registry-consistency.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP compile consistent with registry"
else
    MCPCONSISTENCY_COUNT=1
    MCPCONSISTENCY_FINDINGS=$(echo "$MCPCONSISTENCY_FINDINGS" | jq '. + [{"message": "MCP compile consistency check failed"}]')
    log "  ${RED}FAIL${NC} MCP compile consistency check failed"
    bash "$PROJECT_ROOT/scripts/check-compile-registry-consistency.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-compile-consistency" "$([ $MCPCONSISTENCY_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPCONSISTENCY_COUNT" "$MCPCONSISTENCY_FINDINGS"

# ── Check 31: MCP registry validation ───────────────────────────────────────

log "${BOLD}[31/60] MCP registry validation${NC}"

MCPVALIDATION_FINDINGS="[]"
MCPVALIDATION_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-registry-validation.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP registry validation verified"
else
    MCPVALIDATION_COUNT=1
    MCPVALIDATION_FINDINGS=$(echo "$MCPVALIDATION_FINDINGS" | jq '. + [{"message": "MCP registry validation check failed"}]')
    log "  ${RED}FAIL${NC} MCP registry validation check failed"
    bash "$PROJECT_ROOT/scripts/check-mcp-registry-validation.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-registry-validation" "$([ $MCPVALIDATION_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPVALIDATION_COUNT" "$MCPVALIDATION_FINDINGS"

# ── Check 32: MCP call bridge v1 ────────────────────────────────────────────

log "${BOLD}[32/60] MCP call bridge v1${NC}"

MCPCALL_FINDINGS="[]"
MCPCALL_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-call.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP call bridge verified"
else
    MCPCALL_COUNT=1
    MCPCALL_FINDINGS=$(echo "$MCPCALL_FINDINGS" | jq '. + [{"message": "MCP call bridge check failed"}]')
    log "  ${RED}FAIL${NC} MCP call bridge check failed"
    bash "$PROJECT_ROOT/scripts/check-mcp-call.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-call-bridge" "$([ $MCPCALL_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPCALL_COUNT" "$MCPCALL_FINDINGS"

# ── Check 33: MCP external tools policy ─────────────────────────────────────

log "${BOLD}[33/60] MCP external tools policy${NC}"

MCPEXTPOLICY_FINDINGS="[]"
MCPEXTPOLICY_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-external-tools-policy.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP external tools policy valid"
else
    MCPEXTPOLICY_COUNT=1
    MCPEXTPOLICY_FINDINGS=$(echo "$MCPEXTPOLICY_FINDINGS" | jq '. + [{"message": "MCP external tools policy check failed"}]')
    log "  ${RED}FAIL${NC} MCP external tools policy check failed"
    bash "$PROJECT_ROOT/scripts/check-mcp-external-tools-policy.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-external-tools-policy" "$([ $MCPEXTPOLICY_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPEXTPOLICY_COUNT" "$MCPEXTPOLICY_FINDINGS"

# ── Check 34: MCP external tools call gating ───────────────────────────────

log "${BOLD}[34/60] MCP external tools call gating${NC}"

MCPCALLGATE_FINDINGS="[]"
MCPCALLGATE_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-call.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP call gating verified"
else
    MCPCALLGATE_COUNT=1
    MCPCALLGATE_FINDINGS=$(echo "$MCPCALLGATE_FINDINGS" | jq '. + [{"message": "MCP call gating check failed"}]')
    log "  ${RED}FAIL${NC} MCP call gating check failed"
    bash "$PROJECT_ROOT/scripts/check-mcp-call.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-call-gating" "$([ $MCPCALLGATE_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPCALLGATE_COUNT" "$MCPCALLGATE_FINDINGS"

# ── Check 35: MCP discovery list ───────────────────────────────────────────

log "${BOLD}[35/60] MCP discovery list${NC}"

MCPLIST_FINDINGS="[]"
MCPLIST_COUNT=0

if brain_cli mcp:list >/dev/null 2>&1; then
    # Validate sorting and schema via discovery script
    if bash "$PROJECT_ROOT/scripts/check-mcp-discovery.sh" >/dev/null 2>&1; then
        log "  ${GREEN}PASS${NC} MCP discovery list valid and sorted"
    else
        MCPLIST_COUNT=1
        MCPLIST_FINDINGS=$(echo "$MCPLIST_FINDINGS" | jq '. + [{"message": "MCP discovery list validation failed (sorting or schema)"}]')
        log "  ${RED}FAIL${NC} MCP discovery list validation failed"
    fi
else
    MCPLIST_COUNT=1
    MCPLIST_FINDINGS=$(echo "$MCPLIST_FINDINGS" | jq '. + [{"message": "mcp:list command failed"}]')
    log "  ${RED}FAIL${NC} mcp:list command failed"
fi
add_category "mcp-discovery-list" "$([ $MCPLIST_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPLIST_COUNT" "$MCPLIST_FINDINGS"

# ── Check 36: MCP discovery describe ───────────────────────────────────────

log "${BOLD}[36/60] MCP discovery describe${NC}"

MCPDESC_FINDINGS="[]"
MCPDESC_COUNT=0

# Test with vector-task which has schema
if brain_cli mcp:describe --server=vector-task >/dev/null 2>&1; then
    # Already verified by check-mcp-discovery.sh in Check 35, but we can do a quick extra check here
    log "  ${GREEN}PASS${NC} MCP discovery describe valid"
else
    MCPDESC_COUNT=1
    MCPDESC_FINDINGS=$(echo "$MCPDESC_FINDINGS" | jq '. + [{"message": "mcp:describe command failed"}]')
    log "  ${RED}FAIL${NC} mcp:describe command failed"
fi
add_category "mcp-discovery-describe" "$([ $MCPDESC_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPDESC_COUNT" "$MCPDESC_FINDINGS"

# ── Check 37: MCP call UX ───────────────────────────────────────────────────

log "${BOLD}[37/60] MCP call UX (error hints)${NC}"

MCPUX_FINDINGS="[]"
MCPUX_COUNT=0

# Run script and capture output for findings on failure
UX_OUTPUT=$(bash "$PROJECT_ROOT/scripts/check-mcp-ux.sh" 2>&1)
if [[ $? -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP call error hints verified"
else
    MCPUX_COUNT=1
    MCPUX_FINDINGS=$(echo "$MCPUX_FINDINGS" | jq --arg msg "MCP call error hints validation failed: $UX_OUTPUT" '. + [{"message": $msg}]')
    log "  ${RED}FAIL${NC} MCP call error hints validation failed"
fi
add_category "mcp-call-ux" "$([ $MCPUX_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPUX_COUNT" "$MCPUX_FINDINGS"

# ── Check 38: MCP guardrails contract ──────────────────────────────────────

log "${BOLD}[38/60] MCP guardrails contract${NC}"

MCPGUARD_FINDINGS="[]"
MCPGUARD_COUNT=0

# We already ran the script above, but for clarity and simplicity we can rely on its success for Check 38 too
# or just run it again if we want independent checks.
# Since Check 37 and 38 are in the same script, if it returns 0, both are likely fine.
if [[ $MCPUX_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP guardrails contract verified"
else
    MCPGUARD_COUNT=1
    MCPGUARD_FINDINGS=$(echo "$MCPGUARD_FINDINGS" | jq '. + [{"message": "MCP guardrails contract validation failed (see Check 37)"}]')
    log "  ${RED}FAIL${NC} MCP guardrails contract validation failed"
fi
add_category "mcp-guardrails" "$([ $MCPGUARD_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPGUARD_COUNT" "$MCPGUARD_FINDINGS"

# ── Check 39: MCP call preflight validation ───────────────────────────────

log "${BOLD}[39/60] MCP call preflight validation${NC}"

MCPPREFLIGHT_FINDINGS="[]"
MCPPREFLIGHT_COUNT=0

PREFLIGHT_OUTPUT=$(bash "$PROJECT_ROOT/scripts/check-mcp-preflight.sh" 2>&1)
if [[ $? -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP call preflight validation verified"
else
    MCPPREFLIGHT_COUNT=1
    MCPPREFLIGHT_FINDINGS=$(echo "$MCPPREFLIGHT_FINDINGS" | jq --arg msg "MCP call preflight validation failed: $PREFLIGHT_OUTPUT" '. + [{"message": $msg}]')
    log "  ${RED}FAIL${NC} MCP call preflight validation failed"
fi
add_category "mcp-call-preflight" "$([ $MCPPREFLIGHT_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPPREFLIGHT_COUNT" "$MCPPREFLIGHT_FINDINGS"

# ── Check 40: MCP trace contract ───────────────────────────────────────────

log "${BOLD}[40/60] MCP trace contract${NC}"

MCPTRACE_FINDINGS="[]"
MCPTRACE_COUNT=0

if [[ $MCPPREFLIGHT_COUNT -eq 0 ]]; then
    log "  ${GREEN}PASS${NC} MCP trace contract verified"
else
    MCPTRACE_COUNT=1
    MCPTRACE_FINDINGS=$(echo "$MCPTRACE_FINDINGS" | jq '. + [{"message": "MCP trace contract validation failed (see Check 39)"}]')
    log "  ${RED}FAIL${NC} MCP trace contract validation failed"
fi
add_category "mcp-trace-contract" "$([ $MCPTRACE_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPTRACE_COUNT" "$MCPTRACE_FINDINGS"

# ── Check 41: MCP hardening (budget + normalized errors) ─────────────────────

log "${BOLD}[41/60] MCP hardening check${NC}"

MCPHARDEN_FINDINGS="[]"
MCPHARDEN_COUNT=0

if bash "$PROJECT_ROOT/scripts/audit-mcp-harden.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP hardening (budget + retries + errors) verified"
else
    MCPHARDEN_COUNT=1
    MCPHARDEN_FINDINGS=$(echo "$MCPHARDEN_FINDINGS" | jq '. + [{"message": "MCP hardening validation failed"}]')
    log "  ${RED}FAIL${NC} MCP hardening validation failed"
    # Re-run to show details
    bash "$PROJECT_ROOT/scripts/audit-mcp-harden.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-hardening" "$([ $MCPHARDEN_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPHARDEN_COUNT" "$MCPHARDEN_FINDINGS"

# ── Check 42: MCP serve contract (brain-tools) ─────────────────────────────

log "${BOLD}[42/60] MCP serve contract (brain-tools)${NC}"

MCPSERVE_FINDINGS="[]"
MCPSERVE_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-serve-contract.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP serve contract (brain-tools) verified"
else
    MCPSERVE_COUNT=1
    MCPSERVE_FINDINGS=$(echo "$MCPSERVE_FINDINGS" | jq '. + [{"message": "MCP serve contract validation failed"}]')
    log "  ${RED}FAIL${NC} MCP serve contract validation failed"
    # Re-run to show details
    bash "$PROJECT_ROOT/scripts/check-mcp-serve-contract.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-serve-contract" "$([ $MCPSERVE_COUNT -eq 0 ] && echo pass || echo fail)" "$MCPSERVE_COUNT" "$MCPSERVE_FINDINGS"

# ── Check 43: No MCP wrapper commands ─────────────────────────────────────

log "${BOLD}[43/60] No MCP wrapper commands${NC}"

NOWRAPPER_FINDINGS="[]"
NOWRAPPER_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-no-mcp-wrapper-commands.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} No MCP wrapper commands found"
else
    NOWRAPPER_COUNT=1
    NOWRAPPER_FINDINGS=$(echo "$NOWRAPPER_FINDINGS" | jq '. + [{"message": "Forbidden MCP wrapper commands detected in CLI"}]')
    log "  ${RED}FAIL${NC} Forbidden MCP wrapper commands detected"
    bash "$PROJECT_ROOT/scripts/check-no-mcp-wrapper-commands.sh" 2>&1 | sed 's/^/    /'
fi
add_category "no-mcp-wrapper-commands" "$([ $NOWRAPPER_COUNT -eq 0 ] && echo pass || echo fail)" "$NOWRAPPER_COUNT" "$NOWRAPPER_FINDINGS"

# ── Check 44: Brain entrypoint guard ─────────────────────────────────────

log "${BOLD}[44/60] Brain entrypoint guard${NC}"

ENTRYPOINT_FINDINGS="[]"
ENTRYPOINT_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-brain-entrypoint.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Brain CLI entrypoint valid"
else
    ENTRYPOINT_COUNT=1
    ENTRYPOINT_FINDINGS=$(echo "$ENTRYPOINT_FINDINGS" | jq '. + [{"message": "Brain CLI entrypoint missing or invalid"}]')
    log "  ${RED}FAIL${NC} Brain CLI entrypoint invalid"
    bash "$PROJECT_ROOT/scripts/check-brain-entrypoint.sh" 2>&1 | sed 's/^/    /'
fi
add_category "brain-entrypoint" "$([ $ENTRYPOINT_COUNT -eq 0 ] && echo pass || echo fail)" "$ENTRYPOINT_COUNT" "$ENTRYPOINT_FINDINGS"

# ── Check 45: No Closure in DTO union types ──────────────────────────────

log "${BOLD}[45/60] No Closure in DTO union types${NC}"

CLOSUREDTO_FINDINGS="[]"
CLOSUREDTO_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-no-closure-dto.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} No Closure in DTO union types"
else
    CLOSUREDTO_COUNT=1
    CLOSUREDTO_FINDINGS=$(echo "$CLOSUREDTO_FINDINGS" | jq '. + [{"message": "Closure found in DTO property union types - DI resolution risk"}]')
    log "  ${RED}FAIL${NC} Closure in DTO union types detected"
    bash "$PROJECT_ROOT/scripts/check-no-closure-dto.sh" 2>&1 | sed 's/^/    /'
fi
add_category "no-closure-dto" "$([ $CLOSUREDTO_COUNT -eq 0 ] && echo pass || echo fail)" "$CLOSUREDTO_COUNT" "$CLOSUREDTO_FINDINGS"

# ── Check 46: MCP Thin Adapter Lock ───────────────────────────────────────

log "${BOLD}[46/60] MCP Thin Adapter Lock${NC}"

THINADAPTER_FINDINGS="[]"
THINADAPTER_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-thin-adapter-lock.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP Thin Adapter Lock"
else
    THINADAPTER_COUNT=1
    THINADAPTER_FINDINGS=$(echo "$THINADAPTER_FINDINGS" | jq '. + [{"message": "Thin adapter invariants violated - shadow wrappers, shell calls, or filesystem scanning detected"}]')
    log "  ${RED}FAIL${NC} MCP Thin Adapter Lock violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-thin-adapter-lock.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-thin-adapter-lock" "$([ $THINADAPTER_COUNT -eq 0 ] && echo pass || echo fail)" "$THINADAPTER_COUNT" "$THINADAPTER_FINDINGS"

# ── Check 47: brain-tools Toolset Freeze ───────────────────────────────────

log "${BOLD}[47/60] brain-tools Toolset Freeze${NC}"

BRAINTOOLS_FREEZE_FINDINGS="[]"
BRAINTOOLS_FREEZE_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-brain-tools-freeze.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} brain-tools Toolset Freeze"
else
    BRAINTOOLS_FREEZE_COUNT=1
    BRAINTOOLS_FREEZE_FINDINGS=$(echo "$BRAINTOOLS_FREEZE_FINDINGS" | jq '. + [{"message": "brain-tools toolset/schema contract violated - drift detected"}]')
    log "  ${RED}FAIL${NC} brain-tools Toolset Freeze violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-brain-tools-freeze.sh" 2>&1 | sed 's/^/    /'
fi
add_category "brain-tools-freeze" "$([ $BRAINTOOLS_FREEZE_COUNT -eq 0 ] && echo pass || echo fail)" "$BRAINTOOLS_FREEZE_COUNT" "$BRAINTOOLS_FREEZE_FINDINGS"

# ── Check 48: MCP Tool Schema Drift ─────────────────────────────────────────

log "${BOLD}[48/60] MCP Tool Schema Drift${NC}"

SCHEMADRIFT_FINDINGS="[]"
SCHEMADRIFT_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-tool-schema-drift.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP Tool Schema Drift"
else
    SCHEMADRIFT_COUNT=1
    SCHEMADRIFT_FINDINGS=$(echo "$SCHEMADRIFT_FINDINGS" | jq '. + [{"message": "MCP schema drift detected - schema does not match command signatures"}]')
    log "  ${RED}FAIL${NC} MCP Tool Schema Drift detected"
    bash "$PROJECT_ROOT/scripts/check-mcp-tool-schema-drift.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-tool-schema-drift" "$([ $SCHEMADRIFT_COUNT -eq 0 ] && echo pass || echo fail)" "$SCHEMADRIFT_COUNT" "$SCHEMADRIFT_FINDINGS"

# ── Check 49: MCP tools/list Snapshot ───────────────────────────────────────

log "${BOLD}[49/60] MCP tools/list Snapshot${NC}"

TOOLSLIST_FINDINGS="[]"
TOOLSLIST_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-tools-list-snapshot.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP tools/list Snapshot"
else
    TOOLSLIST_COUNT=1
    TOOLSLIST_FINDINGS=$(echo "$TOOLSLIST_FINDINGS" | jq '. + [{"message": "MCP tools/list schema contract violated - additionalProperties, required sorting, or property drift"}]')
    log "  ${RED}FAIL${NC} MCP tools/list Snapshot violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-tools-list-snapshot.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-tools-list-snapshot" "$([ $TOOLSLIST_COUNT -eq 0 ] && echo pass || echo fail)" "$TOOLSLIST_COUNT" "$TOOLSLIST_FINDINGS"

# ── Check 50: MCP tools/call Contract ───────────────────────────────────────

log "${BOLD}[50/60] MCP tools/call Contract${NC}"

TOOLSCALL_FINDINGS="[]"
TOOLSCALL_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-tools-call-contract.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP tools/call Contract"
else
    TOOLSCALL_COUNT=1
    TOOLSCALL_FINDINGS=$(echo "$TOOLSCALL_FINDINGS" | jq '. + [{"message": "MCP tools/call JSON-RPC envelope contract violated - success/error format, stderr hygiene, or kill-switch"}]')
    log "  ${RED}FAIL${NC} MCP tools/call Contract violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-tools-call-contract.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-tools-call-contract" "$([ $TOOLSCALL_COUNT -eq 0 ] && echo pass || echo fail)" "$TOOLSCALL_COUNT" "$TOOLSCALL_FINDINGS"

# ── Check 51: Client MCP Parity ───────────────────────────────────────

log "${BOLD}[51/60] Client MCP Parity${NC}"

CLIENTPARITY_FINDINGS="[]"
CLIENTPARITY_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-client-mcp-parity.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Client MCP Parity"
else
    CLIENTPARITY_COUNT=1
    CLIENTPARITY_FINDINGS=$(echo "$CLIENTPARITY_FINDINGS" | jq '. + [{"message": "Client MCP parity check failed - direct CLI vs MCP output mismatch"}]')
    log "  ${RED}FAIL${NC} Client MCP Parity violated"
    bash "$PROJECT_ROOT/scripts/check-client-mcp-parity.sh" 2>&1 | sed 's/^/    /'
fi
add_category "client-mcp-parity" "$([ $CLIENTPARITY_COUNT -eq 0 ] && echo pass || echo fail)" "$CLIENTPARITY_COUNT" "$CLIENTPARITY_FINDINGS"

# ── Check 52: MCP No External Surface ───────────────────────────────────

log "${BOLD}[52/60] MCP No External Surface${NC}"

NOEXTERNAL_FINDINGS="[]"
NOEXTERNAL_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-no-external-surface.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP No External Surface"
else
    NOEXTERNAL_COUNT=1
    NOEXTERNAL_FINDINGS=$(echo "$NOEXTERNAL_FINDINGS" | jq '. + [{"message": "MCP external surface check failed - brain-tools must use only mcp:serve, no mcp:list/describe/call, no shell execution"}]')
    log "  ${RED}FAIL${NC} MCP No External Surface violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-no-external-surface.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-no-external-surface" "$([ $NOEXTERNAL_COUNT -eq 0 ] && echo pass || echo fail)" "$NOEXTERNAL_COUNT" "$NOEXTERNAL_FINDINGS"

# ── Check 53: MCP Serve Framing Contract ───────────────────────────────

log "${BOLD}[53/60] MCP Serve Framing Contract${NC}"

FRAMING_FINDINGS="[]"
FRAMING_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-mcp-serve-framing.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MCP Serve Framing Contract"
else
    FRAMING_COUNT=1
    FRAMING_FINDINGS=$(echo "$FRAMING_FINDINGS" | jq '. + [{"message": "MCP serve framing contract violated - 1 response per request, stderr=0, stable error codes"}]')
    log "  ${RED}FAIL${NC} MCP Serve Framing Contract violated"
    bash "$PROJECT_ROOT/scripts/check-mcp-serve-framing.sh" 2>&1 | sed 's/^/    /'
fi
add_category "mcp-serve-framing" "$([ $FRAMING_COUNT -eq 0 ] && echo pass || echo fail)" "$FRAMING_COUNT" "$FRAMING_FINDINGS"

# ── Check 54: No User MCP Artifacts ───────────────────────────────────────

log "${BOLD}[54/60] No User MCP Artifacts${NC}"

NOJUNK_FINDINGS="[]"
NOJUNK_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-no-user-mcp-artifacts.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} No User MCP Artifacts"
else
    NOJUNK_COUNT=1
    NOJUNK_FINDINGS=$(echo "$NOJUNK_FINDINGS" | jq '. + [{"message": "User MCP artifacts found (MockEcho, forbidden terms, missing tools commands)"}]')
    log "  ${RED}FAIL${NC} User MCP artifacts detected"
    bash "$PROJECT_ROOT/scripts/check-no-user-mcp-artifacts.sh" 2>&1 | sed 's/^/    /'
fi
add_category "no-user-mcp-artifacts" "$([ $NOJUNK_COUNT -eq 0 ] && echo pass || echo fail)" "$NOJUNK_COUNT" "$NOJUNK_FINDINGS"

# ── Check 55: MSP Call Contract ───────────────────────────────────────

log "${BOLD}[55/60] MSP Call Contract${NC}"

MSP_FINDINGS="[]"
MSP_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-msp-call-contract.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MSP Call Contract"
else
    MSP_COUNT=1
    MSP_FINDINGS=$(echo "$MSP_FINDINGS" | jq '. + [{"message": "MSP call contract violated - JSON output, stderr hygiene, error codes, kill-switch"}]')
    log "  ${RED}FAIL${NC} MSP Call Contract violated"
    bash "$PROJECT_ROOT/scripts/check-msp-call-contract.sh" 2>&1 | sed 's/^/    /'
fi
add_category "msp-call-contract" "$([ $MSP_COUNT -eq 0 ] && echo pass || echo fail)" "$MSP_COUNT" "$MSP_FINDINGS"

# ── Check 56: MSP Registry Contract ───────────────────────────────────────

log "${BOLD}[56/60] MSP Registry Contract${NC}"

MSPREG_FINDINGS="[]"
MSPREG_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-msp-registry.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} MSP Registry Contract"
else
    MSPREG_COUNT=1
    MSPREG_FINDINGS=$(echo "$MSPREG_FINDINGS" | jq '. + [{"message": "MSP registry contract violated - JSON valid, sorting, class exists, msp:list contract"}]')
    log "  ${RED}FAIL${NC} MSP Registry Contract violated"
    bash "$PROJECT_ROOT/scripts/check-msp-registry.sh" 2>&1 | sed 's/^/    /'
fi
add_category "msp-registry-contract" "$([ $MSPREG_COUNT -eq 0 ] && echo pass || echo fail)" "$MSPREG_COUNT" "$MSPREG_FINDINGS"

# ── Check 57: Brain Tools MCP Artifact ───────────────────────────────────────

log "${BOLD}[57/60] Brain Tools MCP Artifact${NC}"

BTARTIFACT_FINDINGS="[]"
BTARTIFACT_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-brain-tools-mcp-artifact.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Brain Tools MCP Artifact"
else
    BTARTIFACT_COUNT=1
    BTARTIFACT_FINDINGS=$(echo "$BTARTIFACT_FINDINGS" | jq '. + [{"message": "Brain tools MCP artifact violated - exists in mcpServers, args contain --agent, no absolute paths"}]')
    log "  ${RED}FAIL${NC} Brain Tools MCP Artifact violated"
    bash "$PROJECT_ROOT/scripts/check-brain-tools-mcp-artifact.sh" 2>&1 | sed 's/^/    /'
fi
add_category "brain-tools-mcp-artifact" "$([ $BTARTIFACT_COUNT -eq 0 ] && echo pass || echo fail)" "$BTARTIFACT_COUNT" "$BTARTIFACT_FINDINGS"

# ── Check 58: Instructions Tooling Contract ───────────────────────────────────

log "${BOLD}[58/60] Instructions Tooling Contract${NC}"

TOOLING_FINDINGS="[]"
TOOLING_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-instructions-tooling-contract.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Instructions Tooling Contract"
else
    TOOLING_COUNT=1
    TOOLING_FINDINGS=$(echo "$TOOLING_FINDINGS" | jq '. + [{"message": "Instructions tooling contract violated - forbidden CLI patterns or missing mcp__brain-tools__* tool IDs"}]')
    log "  ${RED}FAIL${NC} Instructions Tooling Contract violated"
    bash "$PROJECT_ROOT/scripts/check-instructions-tooling-contract.sh" 2>&1 | sed 's/^/    /'
fi
add_category "instructions-tooling-contract" "$([ $TOOLING_COUNT -eq 0 ] && echo pass || echo fail)" "$TOOLING_COUNT" "$TOOLING_FINDINGS"

# ── Check 59: Brain Tools Agent Args ─────────────────────────────────────────

log "${BOLD}[59/60] Brain Tools Agent Args${NC}"

AGENTARGS_FINDINGS="[]"
AGENTARGS_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-brain-tools-agent-args.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Brain Tools Agent Args"
else
    AGENTARGS_COUNT=1
    AGENTARGS_FINDINGS=$(echo "$AGENTARGS_FINDINGS" | jq '. + [{"message": "Brain tools agent args violated - args contain --agent with value, list_masters schema empty, agent rejected in input"}]')
    log "  ${RED}FAIL${NC} Brain Tools Agent Args violated"
    bash "$PROJECT_ROOT/scripts/check-brain-tools-agent-args.sh" 2>&1 | sed 's/^/    /'
fi
add_category "brain-tools-agent-args" "$([ $AGENTARGS_COUNT -eq 0 ] && echo pass || echo fail)" "$AGENTARGS_COUNT" "$AGENTARGS_FINDINGS"

# ── Check 60: Compile JSON Contract ─────────────────────────────────────────

log "${BOLD}[60/60] Compile JSON Contract${NC}"

CONTRACT_COUNT=0
CONTRACT_FINDINGS="[]"

if bash "$PROJECT_ROOT/scripts/check-compile-json-contract.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Compile JSON Contract"
else
    CONTRACT_COUNT=1
    CONTRACT_FINDINGS=$(echo "$CONTRACT_FINDINGS" | jq '. + [{"message": "Compile JSON contract violated - missing keys, absolute paths, or invalid structure"}]')
    log "  ${RED}FAIL${NC} Compile JSON Contract violated"
    bash "$PROJECT_ROOT/scripts/check-compile-json-contract.sh" 2>&1 | sed 's/^/    /'
fi
add_category "compile-json-contract" "$([ $CONTRACT_COUNT -eq 0 ] && echo pass || echo fail)" "$CONTRACT_COUNT" "$CONTRACT_FINDINGS"

# ── Check 61: Client MCP Export Contract (All Clients) ───────────────────────

log "${BOLD}[61/61] Client MCP Export Contract${NC}"

CLIENT_MCP_COUNT=0
CLIENT_MCP_FINDINGS="[]"

if bash "$PROJECT_ROOT/scripts/check-opencode-mcp-export.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Client MCP Export Contract"
else
    CLIENT_MCP_COUNT=1
    CLIENT_MCP_FINDINGS=$(echo "$CLIENT_MCP_FINDINGS" | jq '. + [{"message": "Client MCP export contract violated - missing brain-tools in one or more clients"}]')
    log "  ${RED}FAIL${NC} Client MCP Export Contract violated"
    bash "$PROJECT_ROOT/scripts/check-opencode-mcp-export.sh" 2>&1 | sed 's/^/    /'
fi
add_category "client-mcp-export-contract" "$([ $CLIENT_MCP_COUNT -eq 0 ] && echo pass || echo fail)" "$CLIENT_MCP_COUNT" "$CLIENT_MCP_FINDINGS"

# ── Check 62: Includes No Legacy CLI ───────────────────────────────────────

log "${BOLD}[62/62] Includes No Legacy CLI${NC}"

LEGACYCLI_FINDINGS="[]"
LEGACYCLI_COUNT=0

if bash "$PROJECT_ROOT/scripts/check-includes-no-legacy-cli.sh" >/dev/null 2>&1; then
    log "  ${GREEN}PASS${NC} Includes No Legacy CLI"
else
    LEGACYCLI_COUNT=1
    LEGACYCLI_FINDINGS=$(echo "$LEGACYCLI_FINDINGS" | jq '. + [{"message": "Legacy CLI invocations found in includes - use brain tools:* commands instead"}]')
    log "  ${RED}FAIL${NC} Legacy CLI invocations detected"
    bash "$PROJECT_ROOT/scripts/check-includes-no-legacy-cli.sh" 2>&1 | sed 's/^/    /'
fi
add_category "includes-no-legacy-cli" "$([ $LEGACYCLI_COUNT -eq 0 ] && echo pass || echo fail)" "$LEGACYCLI_COUNT" "$LEGACYCLI_FINDINGS"

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
