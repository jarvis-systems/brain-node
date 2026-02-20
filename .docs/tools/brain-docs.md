---
name: "Brain Docs CLI"
description: "Complete reference for brain docs — project documentation discovery, search, download, validation, and gap analysis tool"
type: "tool"
date: "2026-02-20"
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

### Common Patterns

    brain docs query --limit=3                                   # quick search
    brain docs query --headers=2 --stats --code --keywords       # deep analysis
    brain docs query --matches --limit=1                         # find exact location
    brain docs --headers=2 --limit=0                             # full index with structure

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
