---
name: "Brain Docs CLI"
description: "Complete reference for brain docs — project documentation discovery, search, download, validation, and gap analysis tool"
type: "tool"
date: "2026-02-23"
---

# Brain Docs CLI

Primary tool for `.docs/` project documentation discovery and search. Self-documenting: `brain docs --help` for usage, `-v` for examples, `-vv` for best practices and use cases, `-vvv` for internal detection algorithms.

## Core Principle

**Always use brain docs BEFORE any project-related reasoning.** One check, zero overhead, prevents costly rework. If the answer exists in `.docs/`, reading it is cheaper than guessing.

## Search

### Keyword Search (default)

OR logic, case-insensitive. Score: name match = +10, description = +5, content = +1 per occurrence. Results ranked by score DESC, then by path.

    brain docs api                       # search for "api" (limit 5)
    brain docs api auth --limit=10       # "api" OR "auth", max 10 results
    brain docs api --limit=0             # unlimited results

### JSON Output (v2 schema)

Search returns a JSON object with two fields:

```json
{
  "total_matches": 49,
  "files": [
    {"path": ".docs/architecture/api.md", "name": "API Design", "score": 15, ...},
    {"path": ".docs/operations/api-gateway.md", "name": "API Gateway", "score": 12, ...}
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `total_matches` | int | Count of all matching documents (before limit) |
| `files` | array | Top-K results, limited by `--limit` (default: 5) |

**Breaking change (v0.5):** Previous versions returned a bare array `[...]`. Consumers expecting the old format should pin to v0.4 or adapt to the new schema.

### Cache Observability

| Flag | Description |
|------|-------------|
| `--cache-stats` | Show cache statistics: entries, hit rate, timing breakdown |
| `--cache-health` | Show health report with recommendations |
| `--clear-cache` | Clear the docs index cache |
| `--cache=off` | Disable cache for this run |

**Stats output (`--cache-stats`):**

```json
{
  "cache_hit": true,
  "entries_total": 49,
  "entries_changed": 0,
  "hit_rate": 1.0,
  "health": "healthy",
  "timing": {
    "scan_ms": 17,
    "enrich_ms": 0,
    "render_ms": 0,
    "git_calls_saved": 49
  }
}
```

| Timing field | Description |
|--------------|-------------|
| `scan_ms` | File scanning + scoring phase |
| `enrich_ms` | Enrichment phase (headers, code_blocks, etc.) — only for top-K |
| `render_ms` | JSON encoding + output |
| `git_calls_saved` | Git lookups avoided via cached freshness data |

### Exact Phrase Search

Matches entire phrase in document. Case-insensitive by default.

    brain docs --exact="class not found"            # case-insensitive
    brain docs --exact="Error" --strict              # case-sensitive
    brain docs --exact="iron rules" api              # AND: phrase + keyword

### Output Enrichment

Each flag adds a layer of metadata to the JSON output:

| Flag | Adds | Use when |
|------|------|----------|
| `--headers=N` | Headers with line ranges (1=H1, 2=H1+H2, 3=all) | Need document structure |
| `--stats` | Lines, words, size, hash, modified date | Compare versions |
| `--code` | Code blocks with language and line ranges | Looking for examples |
| `--snippets` | Preview text under each header (max 200 chars) | Quick overview |
| `--links` | Internal and external links | Trace references |
| `--keywords` | Top 10 frequent terms | Understand document focus |
| `--matches` | Keyword locations with 50-char context | Find WHERE in doc |

### Global Search

Discovers all `.docs/` directories at depth 1-3 from project root. Useful for mono-repo projects with multiple subprojects.

    brain docs api --global              # search across all subproject .docs/
    brain docs --validate --global       # validate all docs in project tree

Works with: search, `--validate`, `--update`. Does NOT affect: `--download`, `--undocumented`, `--scaffold` (always use root `.docs/`). Results merged, deduplicated by path, re-sorted by score.

### Trust and Freshness Filters

Filter results by document age or trustworthiness. Additive — both can be combined.

| Flag | Description | Example |
|------|-------------|---------|
| `--freshness=N` | Include only docs modified within N days | `--freshness=7` (last week) |
| `--trust=LEVEL` | Minimum trust level: `low`, `med`, `high` | `--trust=high` (local only) |

    brain docs api --freshness=30         # docs about "api" modified in last 30 days
    brain docs --trust=high --limit=0     # all local project docs, skip downloads

### Per-Result Fields

Every search result includes three additional fields — `source`, `freshness`, and `trust`:

**source** — origin classification:
- `local` — authored in root `.docs/`, no external URL
- `downloaded` — in `sources/` subdirectory or has `url` in YAML front matter
- `external` — from a non-root `.docs/` directory (mono-repo subproject)

**freshness** — document age based on git log (batch per directory, ~38ms), filemtime fallback:
- `modified_at` — ISO 8601 timestamp of last modification
- `days_ago` — integer days since last change
- `bucket` — `fresh` (0-7d), `recent` (8-30d), `aging` (31-90d), `stale` (91+d)

**trust** — reliability indicator derived from source and URL presence:
- `high` — local project documentation
- `med` — downloaded from known URL, or external subproject docs
- `low` — downloaded without source URL

Example result:

    {
      "path": ".docs/operations/release-prepare.md",
      "name": "Release Prepare",
      "score": 15,
      "source": "local",
      "freshness": {"modified_at": "2026-02-23T10:00:00Z", "days_ago": 0, "bucket": "fresh"},
      "trust": {"level": "high", "reason": "Local project documentation"}
    }

Example downloaded doc result:

    {
      "path": ".docs/sources/laravel-11.md",
      "name": "Laravel 11 Docs",
      "score": 8,
      "source": "downloaded",
      "freshness": {"modified_at": "2026-01-15T08:30:00Z", "days_ago": 39, "bucket": "aging"},
      "trust": {"level": "med", "reason": "Downloaded from known URL"}
    }

### Common Patterns

    brain docs query --limit=3                                   # quick search
    brain docs query --headers=2 --stats --code --keywords       # deep analysis
    brain docs query --matches --limit=1                         # find exact location
    brain docs --headers=2 --limit=0                             # full index with structure
    brain docs api --freshness=7                                 # fresh docs about "api"
    brain docs --trust=high --global                             # high-trust docs across project

## Download and Update

### Download External Docs

Persists external documentation locally. Lossless — full content preserved, zero tokens lost compared to vector memory summaries.

    brain docs --download=https://raw.githubusercontent.com/owner/repo/README.md
    brain docs --download=https://example.com/docs/api.md --as=api-reference.md

Files saved to `.docs/sources/`. YAML front matter auto-generated with `url` field for future `--update`.

### Update Downloaded Docs

Scans ALL `.md` files in `.docs/` (not just `sources/`), finds those with valid `url` in YAML, downloads fresh content, preserves existing YAML fields, updates date.

    brain docs --update

### Security

Downloaded content is validated before saving:
- Max size: 5MB
- URL scheme: http/https only (no `file://`, `ftp://`)
- Blocked patterns: prompt injection attempts, script injection, event handlers
- Unusual AI-related terms flagged for review

## Validation

Checks all `.md` files in `.docs/` for quality. Returns only documents with errors or warnings — valid docs omitted for token efficiency.

    brain docs --validate

### Rules

**Critical errors** (document marked invalid):
- Missing YAML front matter (must start with `---`)
- Missing required field: `name`

**Warnings** (quality issues):
- Missing recommended field: `description`
- Description too short (< 10 characters)
- Empty content after YAML
- No H1 header in document
- Duplicate `name` across documents

Output: `{documents: [{path, valid, errors[], warnings[]}], summary: {total, valid, invalid, warnings}}`

## Gap Analysis

Scans `src/`, `app/`, `lib/`, `classes/` for PHP classes without documentation in `.docs/`.

    brain docs --undocumented

Returns classes sorted by `method_count` DESC (most complex first). Each entry includes class name, FQN, file path, public methods list, and method count.

## YAML Front Matter

Required for proper search ranking and validation.

    ---
    name: "Document Title"
    description: "Brief description (>= 10 chars)"
    ---

**Required:** `name` (unique across all docs)
**Recommended:** `description` (>= 10 chars)
**Optional:** `type`, `date`, `version`, `status`, `url` (required for `--update`)

## Detection Algorithms

### Code Language Detection (--code)

Priority order:
1. Declared language in fenced block (` ```json `, ` ```php `)
2. JSON: starts with `{` or `[`
3. PHP: `<?php` or `namespace` keyword
4. Python: `def`/`class`/`import`/`from`
5. JavaScript: `function`/`const`/`let` or `=>`
6. Bash: common CLI commands (`git`, `npm`, `composer`)
7. Unknown: excluded from output

### Header Detection (--headers)

Regex: `/^(#{1,6})\s*(.+)$/m`. `end_line` = line before next header of same or higher level. Snippets skip code blocks, empty lines, tables, YAML delimiters.

### Keyword Extraction (--keywords)

Filters 100+ English stop words, minimum 3-character length. Returns top 10 by frequency.

### Match Context (--matches)

25 chars before + keyword + 25 chars after. Max 20 unique (keyword, line) pairs per document. Line numbers are 1-indexed.

## Cognitive Triggers

| Situation | Action |
|-----------|--------|
| Before writing code | `brain docs <topic>` — read first if found |
| After code changes | Document what changed; create doc if none exists |
| During research | Download interesting docs, index, store insights to memory |
| Found interesting URL | `brain docs --download=<url>` |
| Task mentions feature | `brain docs feature --headers=2 --code` |
| Before commit | `brain docs --validate` — fix critical errors |
| No search results | Split CamelCase, strip suffixes (Test, Controller), try parent context |
| Task completion | `brain docs --undocumented` — log gaps in task comment |

## Environment

- `BRAIN_CLI_DEBUG=1` — enable debug output with full stack traces
- Help verbosity: `-v` usage examples, `-vv` best practices and use cases, `-vvv` detection algorithms and internals
