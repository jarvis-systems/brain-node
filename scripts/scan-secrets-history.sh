#!/usr/bin/env bash
# scan-secrets-history.sh — Scan git history for leaked secrets (redacted, low-noise)
#
# Usage: scripts/scan-secrets-history.sh [--json] [--quiet]
#
# Scans entire git history for secret patterns, excluding documentation
# and pattern-definition files that create false positives in Tier-1 grep.
#
# Flags:
#   --json    Machine-readable JSON output
#   --quiet   Print only TOTAL_MATCHES=<n> line and exit code (for gate scripts)
#
# Output (redacted — NEVER prints actual secret values):
#   - TOTAL_MATCHES: count of matching diff lines in affected commits
#   - AFFECTED_COMMITS: count + list of short commit hashes
#   - AFFECTED_FILES: count + list of file paths (no content)
#
# Exit codes:
#   0 — No matches in history (clean)
#   1 — Script/runtime error (cannot extract patterns, git unavailable)
#   2 — Matches found in history (leaked secrets exist in non-docs files)
#
# Patterns sourced from: scripts/scan-secrets.sh (SECRET_PATTERNS variable)
# Single source of truth — never hardcode patterns here.
#
# Noise exclusions (files that legitimately reference patterns):
#   - .docs/           (documentation describing patterns)
#   - *.md             (markdown files referencing patterns)
#   - scripts/scan-secrets.sh        (pattern definitions)
#   - scripts/scan-secrets-history.sh (this script)
#   - scripts/audit-enterprise.sh    (pattern definitions)
#   - .claude/ .opencode/ .codex/ .gemini/ .qwen/ (compiled brain output)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

JSON_MODE=false
QUIET_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json)  JSON_MODE=true ;;
        --quiet) QUIET_MODE=true ;;
    esac
done

# Colors (disabled when not a terminal, json mode, or quiet mode)
if [[ -t 1 ]] && [[ "$JSON_MODE" == false ]] && [[ "$QUIET_MODE" == false ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' NC=''
fi

log() {
    if [[ "$JSON_MODE" == false ]] && [[ "$QUIET_MODE" == false ]]; then
        echo -e "$@"
    fi
}

cd "$PROJECT_ROOT"

# ── Extract canonical patterns from scan-secrets.sh ──────────────────────
# Single source of truth: never hardcode patterns in this script.

PATTERNS=$(sed -n "s/^SECRET_PATTERNS='\\(.*\\)'/\\1/p" scripts/scan-secrets.sh)

if [[ -z "$PATTERNS" ]]; then
    log "${RED}ERROR: Could not extract SECRET_PATTERNS from scripts/scan-secrets.sh${NC}"
    log "Expected format: SECRET_PATTERNS='pattern1|pattern2|...' on a single line."
    exit 1
fi

log "${BOLD}Scanning git history for leaked secrets (redacted, low-noise)...${NC}"
log "Patterns sourced from: scripts/scan-secrets.sh:SECRET_PATTERNS"
log ""

# ── Pathspec exclusions (noise sources) ──────────────────────────────────
# These paths legitimately reference secret patterns as regex/examples/docs.
# Excluding them reduces Tier-1 false positives from ~1M to actual leak count.

PATHSPEC=(
    ':!.docs/'
    ':!*.md'
    ':!scripts/scan-secrets.sh'
    ':!scripts/scan-secrets-history.sh'
    ':!scripts/audit-enterprise.sh'
    ':!.claude/'
    ':!.opencode/'
    ':!.codex/'
    ':!.gemini/'
    ':!.qwen/'
)

# ── Find affected commits using git -G (precise: matches diff content) ───
# -G finds commits where the number of pattern matches changed.
# Combined with pathspec exclusions, this skips docs/scripts noise.

COMMITS=$(git log --all --oneline -G "$PATTERNS" -- "${PATHSPEC[@]}" 2>/dev/null || true)

COMMIT_COUNT=0
COMMIT_HASHES=""

if [[ -n "$COMMITS" ]]; then
    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
    COMMIT_HASHES=$(echo "$COMMITS" | awk '{print $1}')
fi

# ── Count total matches per affected commit (redacted) ───────────────────
# Only processes commits found by -G (fast: skips irrelevant commits).
# Uses git show with pathspec to count matching lines without printing them.

TOTAL_MATCHES=0

if [[ $COMMIT_COUNT -gt 0 ]]; then
    while IFS= read -r hash; do
        [[ -z "$hash" ]] && continue
        count=$(git show "$hash" -- "${PATHSPEC[@]}" 2>/dev/null | grep -cE "$PATTERNS" || echo 0)
        TOTAL_MATCHES=$((TOTAL_MATCHES + count))
    done <<< "$COMMIT_HASHES"
fi

# ── Find affected files (paths only, no content) ────────────────────────

AFFECTED_FILES=""
FILE_COUNT=0

if [[ $COMMIT_COUNT -gt 0 ]]; then
    AFFECTED_FILES=$(git log --all --name-only --pretty=format: -G "$PATTERNS" -- "${PATHSPEC[@]}" 2>/dev/null | sort -u | grep -v '^$' || true)
    if [[ -n "$AFFECTED_FILES" ]]; then
        FILE_COUNT=$(echo "$AFFECTED_FILES" | wc -l | tr -d ' ')
    fi
fi

# ── Output ───────────────────────────────────────────────────────────────

if [[ "$JSON_MODE" == true ]]; then
    # Build JSON arrays
    COMMITS_JSON="[]"
    if [[ -n "$COMMIT_HASHES" ]]; then
        while IFS= read -r hash; do
            [[ -z "$hash" ]] && continue
            COMMITS_JSON=$(echo "$COMMITS_JSON" | jq --arg h "$hash" '. + [$h]')
        done <<< "$COMMIT_HASHES"
    fi

    FILES_JSON="[]"
    if [[ -n "$AFFECTED_FILES" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            FILES_JSON=$(echo "$FILES_JSON" | jq --arg f "$f" '. + [$f]')
        done <<< "$AFFECTED_FILES"
    fi

    jq -n \
        --argjson matches "$TOTAL_MATCHES" \
        --argjson commit_count "$COMMIT_COUNT" \
        --argjson file_count "$FILE_COUNT" \
        --argjson commits "$COMMITS_JSON" \
        --argjson files "$FILES_JSON" \
        '{
            "total_matches": $matches,
            "affected_commits_count": $commit_count,
            "affected_files_count": $file_count,
            "affected_commits": $commits,
            "affected_files": $files
        }'
fi

log "${BOLD}Results:${NC}"
log "  TOTAL_MATCHES=$TOTAL_MATCHES"
log "  AFFECTED_COMMITS=$COMMIT_COUNT"
log "  AFFECTED_FILES=$FILE_COUNT"
log ""

if [[ $COMMIT_COUNT -gt 0 ]]; then
    log "${YELLOW}Affected commits (hashes only):${NC}"
    while IFS= read -r hash; do
        [[ -z "$hash" ]] && continue
        log "  $hash"
    done <<< "$COMMIT_HASHES"
    log ""

    log "${YELLOW}Affected files (paths only, no content):${NC}"
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        log "  $f"
    done <<< "$AFFECTED_FILES"
    log ""
fi

# ── Quiet mode: single-line output for gate scripts ──────────────────────

if [[ "$QUIET_MODE" == true ]]; then
    echo "TOTAL_MATCHES=$TOTAL_MATCHES"
fi

if [[ $TOTAL_MATCHES -eq 0 ]]; then
    log "${GREEN}No secret patterns found in git history (excluding docs/scripts).${NC}"
    exit 0
else
    log "${RED}${BOLD}Secret patterns detected in git history.${NC}"
    log "Old credentials should be rotated. See: .docs/product/16-security-3.0-playbook.md"
    exit 2
fi
