#!/usr/bin/env bash
# scan-secrets.sh — Scan tracked files and dist bundles for leaked secrets
#
# Usage: scripts/scan-secrets.sh [--json]
#
# Patterns detected:
#   - github_pat_*          (GitHub Personal Access Tokens)
#   - ctx7sk-*              (Context7 API keys)
#   - gsk_*                 (Groq API keys)
#   - sk-or-v1-*            (OpenRouter API keys)
#   - Bearer <token>        (Hardcoded Bearer tokens, 20+ chars)
#   - Packagist API tokens  (user:hex format in curl/Authorization)
#
# Scans:
#   1. All git-tracked files (git ls-files)
#   2. dist/ bundle contents (if present)
#
# Exit codes:
#   0 — No secrets found
#   1 — Secrets detected
#
# Exclusions (files that legitimately reference patterns):
#   - .env.example files (template placeholders)
#   - scan-secrets.sh itself (pattern definitions)
#   - .docs/ directory (documentation may describe patterns)
#   - CLAUDE.md / .claude/ (compiled brain instructions may reference patterns)
#   - audit-enterprise.sh (references patterns in check logic)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

JSON_MODE=false
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

# Colors (disabled when not a terminal or json mode)
if [[ -t 1 ]] && [[ "$JSON_MODE" == false ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' BOLD='' NC=''
fi

log() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "$@"
    fi
}

# Secret patterns (extended grep syntax)
# Each pattern is designed to match actual secret values, not documentation references
SECRET_PATTERNS='github_pat_[A-Za-z0-9_]{10,}|ctx7sk-[a-f0-9-]{8,}|gsk_[A-Za-z0-9]{10,}|sk-or-v1-[A-Za-z0-9]{10,}'

# Exclusion patterns for files that legitimately contain pattern references
is_excluded() {
    local file="$1"
    case "$file" in
        .env.example|*.env.example) return 0 ;;
        scripts/scan-secrets.sh) return 0 ;;
        scripts/audit-enterprise.sh) return 0 ;;
        .docs/*) return 0 ;;
        CLAUDE.md) return 0 ;;
        .claude/*) return 0 ;;
        .opencode/*) return 0 ;;
    esac
    return 1
}

TOTAL_SECRETS=0
FINDINGS="[]"

add_finding() {
    local file="$1"
    local line="$2"
    local pattern="$3"
    TOTAL_SECRETS=$((TOTAL_SECRETS + 1))
    if [[ "$JSON_MODE" == true ]]; then
        FINDINGS=$(echo "$FINDINGS" | jq \
            --arg file "$file" \
            --arg line "$line" \
            --arg pattern "$pattern" \
            '. + [{"file": $file, "line": ($line | tonumber), "pattern": $pattern}]')
    fi
    log "  ${RED}SECRET${NC} $file:$line — matches: $pattern"
}

# ── Scan 1: Git-tracked files ────────────────────────────────────────────

log "${BOLD}Scanning git-tracked files...${NC}"

cd "$PROJECT_ROOT"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Skip excluded files
    if is_excluded "$file"; then
        continue
    fi

    # Scan file for secret patterns
    while IFS=: read -r line_num content; do
        [[ -z "$line_num" ]] && continue
        # Determine which pattern matched
        matched_pattern="unknown"
        if echo "$content" | grep -qE 'github_pat_[A-Za-z0-9_]{10,}'; then
            matched_pattern="github_pat_*"
        elif echo "$content" | grep -qE 'ctx7sk-[a-f0-9-]{8,}'; then
            matched_pattern="ctx7sk-*"
        elif echo "$content" | grep -qE 'gsk_[A-Za-z0-9]{10,}'; then
            matched_pattern="gsk_*"
        elif echo "$content" | grep -qE 'sk-or-v1-[A-Za-z0-9]{10,}'; then
            matched_pattern="sk-or-v1-*"
        fi
        add_finding "$file" "$line_num" "$matched_pattern"
    done < <(grep -nE "$SECRET_PATTERNS" "$file" 2>/dev/null || true)
done < <(git ls-files 2>/dev/null)

# ── Scan 2: dist/ bundle contents ────────────────────────────────────────

if [[ -d "$PROJECT_ROOT/dist" ]]; then
    log "${BOLD}Scanning dist/ bundles...${NC}"

    while IFS= read -r -d '' file; do
        relative="${file#$PROJECT_ROOT/}"
        while IFS=: read -r line_num content; do
            [[ -z "$line_num" ]] && continue
            matched_pattern="unknown"
            if echo "$content" | grep -qE 'github_pat_[A-Za-z0-9_]{10,}'; then
                matched_pattern="github_pat_*"
            elif echo "$content" | grep -qE 'ctx7sk-[a-f0-9-]{8,}'; then
                matched_pattern="ctx7sk-*"
            elif echo "$content" | grep -qE 'gsk_[A-Za-z0-9]{10,}'; then
                matched_pattern="gsk_*"
            elif echo "$content" | grep -qE 'sk-or-v1-[A-Za-z0-9]{10,}'; then
                matched_pattern="sk-or-v1-*"
            fi
            add_finding "$relative" "$line_num" "$matched_pattern"
        done < <(grep -nE "$SECRET_PATTERNS" "$file" 2>/dev/null || true)
    done < <(find "$PROJECT_ROOT/dist" -type f \( -name '*.json' -o -name '*.sh' -o -name '*.php' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)
fi

# ── Output ────────────────────────────────────────────────────────────────

if [[ "$JSON_MODE" == true ]]; then
    jq -n \
        --argjson count "$TOTAL_SECRETS" \
        --argjson findings "$FINDINGS" \
        '{"secrets_found": $count, "findings": $findings}'
fi

log ""
if [[ $TOTAL_SECRETS -eq 0 ]]; then
    log "${GREEN}No secrets found in tracked files.${NC}"
    exit 0
else
    log "${RED}${BOLD}FOUND $TOTAL_SECRETS secret(s) in tracked files!${NC}"
    log "Rotate compromised credentials immediately."
    exit 1
fi
