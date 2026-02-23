---
name: "M2 Docs Global Search — Design Spike"
description: "Design spike for brain docs global search with trust/freshness indicators — current state, target UX, data model, risk analysis, and go/no-go recommendation"
type: spike
date: 2026-02-23
version: "1.0.0"
status: active
---

# M2 Docs Global Search — Design Spike

## 1. Current-State Map

### What `brain docs` supports today

**Command shape:** `brain docs {keywords?*} [options]`

**Search options:**

| Flag | Type | Default | Behavior |
|------|------|---------|----------|
| `--limit=` | int | 5 | Max results (0 = unlimited) |
| `--exact=` | string | null | Exact phrase match |
| `--strict` | bool | false | Case-sensitive exact match |
| `--global` | bool | false | Search all `.docs/` dirs at depth 1-3 |
| `--headers=` | int | 0 | Extract headers (1=H1, 2=+H2, 3=+H3) |
| `--stats` | bool | false | File stats: lines, words, size, hash, modified |
| `--code` | bool | false | Extract fenced code blocks |
| `--snippets` | bool | false | Header section previews (max 200 chars) |
| `--links` | bool | false | Internal/external link extraction |
| `--keywords` | bool | false | Top 10 frequent terms |
| `--matches` | bool | false | Keyword match locations with context |

**Non-search modes:** `--validate`, `--undocumented`, `--scaffold=`, `--download=`, `--update`

**Output:** Always JSON. No human-readable mode for search results.

### Index/cache storage

**None.** Every invocation does a full filesystem scan via `File::allFiles()`. Documents are scored in-memory. No persistent index, no cache files, no `.work/` artifacts. This is both a simplicity win and a scaling concern for M2.

### Where trust/freshness currently live

| Signal | Exists? | Where | Used for |
|--------|---------|-------|----------|
| YAML `date` | Yes | Front matter | Written on `--download`/`--update`, never queried |
| YAML `url` | Yes | Front matter | `--update` re-downloads from URL, never used for trust |
| `modified` timestamp | Yes | `--stats` output | Display only, never used for filtering/sorting |
| Git history | No | — | Not queried at all |
| Trust score | No | — | Does not exist |
| Freshness bucket | No | — | Does not exist |
| Source badge | No | — | Not exposed (local vs downloaded not distinguished) |

**Conclusion:** All the raw data needed for trust/freshness is present (YAML fields, filesystem metadata, git). Zero logic consumes it.

## 2. Target UX (v1)

### Command shape (no breaking changes)

```bash
# Existing behavior — unchanged
brain docs <keywords>                          # local search, JSON
brain docs <keywords> --global                 # multi-root search, JSON

# New flags (additive, optional)
brain docs <keywords> --freshness=30           # filter: only docs modified within 30 days
brain docs <keywords> --trust=high             # filter: only high-trust docs
brain docs <keywords> --global --freshness=90 --trust=med  # combined

# Badges always present in output when --global or new flags used
brain docs <keywords> --global --limit=10
```

### New flags

| Flag | Type | Default | Behavior |
|------|------|---------|----------|
| `--freshness=` | int (days) | null (no filter) | Show only docs modified within N days. 0 = no filter. |
| `--trust=` | string | null (no filter) | Filter by minimum trust: `low` (all), `med` (local+downloaded), `high` (local only) |

Both flags are filters, not sort modifiers. Sort order remains score DESC (existing behavior).

### Per-result output schema (additive fields)

```json
{
  "path": ".docs/operations/release-prepare.md",
  "name": "Release Prepare",
  "description": "Release pack generator...",
  "score": 15,
  "source": "local",
  "freshness": {
    "days_ago": 0,
    "bucket": "fresh",
    "modified_at": "2026-02-23T12:00:00Z"
  },
  "trust": {
    "level": "high",
    "reason": "Local project documentation"
  }
}
```

New fields appear in every search result. Existing fields unchanged.

### Source badge values

| Badge | Meaning | Example path |
|-------|---------|--------------|
| `local` | Written by project authors, in `.docs/` (not `sources/`) | `.docs/product/roadmap.md` |
| `downloaded` | Fetched via `--download`, has `url` in YAML | `.docs/sources/laravel-11.md` |
| `external` | Found via `--global` in a different project root | `core/.docs/architecture.md` |

### Freshness bucket values

| Bucket | Criteria |
|--------|----------|
| `fresh` | Modified within 7 days |
| `recent` | Modified within 30 days |
| `aging` | Modified within 90 days |
| `stale` | Modified 90+ days ago |

Thresholds are hardcoded constants, not configurable in v1. Bucket is informational — filtering uses exact `--freshness=N` days.

### Trust level values

| Level | Criteria |
|-------|----------|
| `high` | Local project doc (no `url` in YAML, path in project `.docs/`) |
| `medium` | Downloaded doc with known URL (`url` in YAML) OR external project doc via `--global` |
| `low` | Downloaded doc without URL, or docs failing validation |

## 3. Data Model

### Freshness computation

**Local docs (no `url` in YAML):**
1. Primary: `git log -1 --format=%cI -- {file_path}` — last commit date touching this file
2. Fallback: `filemtime()` — filesystem modified time (if not in git or git fails)
3. Output: ISO 8601 timestamp + `days_ago` integer + bucket string

**Downloaded docs (`url` in YAML):**
1. Primary: YAML `date` field — set on download/update, represents last refresh
2. Fallback: `filemtime()` — filesystem modified time
3. No HTTP headers — v1 avoids network entirely

**External docs (via `--global`):**
Same as local docs logic, but executed in the subdirectory's git context.

**Performance note:** `git log` per file is O(n) subprocess calls. For a typical `.docs/` of 50-100 files, this is 1-3 seconds. Acceptable for v1 but may need caching if doc sets grow past 500 files.

### Trust computation

```
if (path starts with ".docs/sources/" AND has YAML "url") → "medium"  (downloaded, known source)
if (path starts with ".docs/sources/" AND no YAML "url")  → "low"     (downloaded, unknown source)
if (path found via --global, different root)               → "medium"  (external project)
if (path in project .docs/, not sources/)                  → "high"    (local project doc)
```

No validation-based trust degradation in v1 (would require running `--validate` per file, too expensive).

### Defaults (no surprises)

| Scenario | Behavior |
|----------|----------|
| No `--freshness` | All docs returned regardless of age |
| No `--trust` | All docs returned regardless of trust |
| `--freshness=0` | Same as omitting — no filter |
| `--trust=low` | All docs (low is minimum) |
| `--global` without new flags | Existing behavior + source/freshness/trust badges in output |
| No `--global` | New badges still appear (source=local for all results) |

### What changes in which files

| File | Change | Scope |
|------|--------|-------|
| `DocsCommand.php` | Add `--freshness=` and `--trust=` options to signature, add filtering logic, add badge fields to output | Medium |
| New: `FreshnessResolver.php` | Git log + filemtime fallback, bucket computation | Small |
| New: `TrustResolver.php` | Trust level computation from YAML + path analysis | Small |
| `ContentScorer.php` | No changes (scoring unchanged) | None |
| `MarkdownParser.php` | No changes | None |
| `DocsDirectoryResolver.php` | No changes (already supports --global) | None |

**Estimated new code:** ~150 lines across 2 new services + ~40 lines in command. No existing logic modified.

## 4. Risk & Test Plan

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `git log` per-file is slow for large doc sets | Medium | v1 accepts O(n) git calls; cache layer deferred to v2 |
| `git log` fails in non-git directories | Low | Fallback to `filemtime()` already planned |
| Trust heuristics produce false confidence | Medium | Conservative defaults: downloaded=medium, not high. User sees reason string |
| New flags break existing scripts consuming JSON | None | Additive fields only. No existing field removed or renamed |
| Network calls for freshness | None | Explicitly avoided. Local git + filesystem only |

### Determinism guarantees

1. **Sort order:** Score DESC (existing), then path ASC (tiebreaker, already in place). Trust/freshness do not affect sort.
2. **Freshness computation:** `git log` is deterministic for committed files. Uncommitted files fall back to `filemtime()` which is stable within a test run.
3. **Trust computation:** Pure function of YAML fields and path prefix. Deterministic by construction.
4. **Bucket boundaries:** Hardcoded constants, not configurable. Same input always produces same bucket.

### Golden test plan

| Test | Type | Validates |
|------|------|-----------|
| `test_search_result_has_source_badge` | Golden | `source` field present in every result |
| `test_search_result_has_freshness_object` | Golden | `freshness.days_ago`, `freshness.bucket`, `freshness.modified_at` structure |
| `test_search_result_has_trust_object` | Golden | `trust.level`, `trust.reason` structure |
| `test_freshness_filter_excludes_old_docs` | Runner | `--freshness=1` excludes docs older than 1 day |
| `test_trust_filter_excludes_low_trust` | Runner | `--trust=med` excludes low-trust docs |
| `test_badges_deterministic_across_runs` | Golden | Two identical runs produce identical badge values |
| `test_source_badge_local_vs_downloaded` | Runner | `.docs/sources/` → downloaded, `.docs/ops/` → local |
| `test_freshness_bucket_boundaries` | Unit | 0d=fresh, 8d=recent, 31d=aging, 91d=stale |
| `test_trust_resolver_all_levels` | Unit | Each path/YAML combo → expected level |
| `test_freshness_git_fallback_to_filemtime` | Unit | Non-git dir → filemtime used |

### Test pattern

- `FreshnessResolverTest.php` — unit tests with temp dirs and mocked git
- `TrustResolverTest.php` — pure unit tests (path + YAML → level)
- `DocsCommandGoldenTest.php` — extend existing with badge schema assertions
- `DocsGlobalSearchGoldenTest.php` — new file for `--global` + badges integration

## 5. Scope Assessment

### What M2 v1 actually requires

| Component | Lines (est.) | Complexity |
|-----------|-------------|------------|
| `FreshnessResolver.php` | ~80 | Low — git log + filemtime + bucket math |
| `TrustResolver.php` | ~50 | Low — path prefix + YAML field check |
| `DocsCommand.php` changes | ~40 | Low — 2 new options, filter + badge injection |
| Tests | ~200 | Medium — 10 test methods across 3-4 files |
| Runbook | ~60 | Low — document new flags |
| **Total** | ~430 | **Low-Medium** |

### What M2 v1 explicitly excludes

- No index/cache layer (deferred to v2 if perf becomes issue)
- No TNTSearch integration (mentioned in roadmap risk, not needed for v1)
- No network calls (no HTTP headers for downloaded doc freshness)
- No human-readable output mode (JSON only, consistent with existing)
- No trust degradation from validation failures
- No automatic re-download prompt for stale docs

## 6. Recommendation

**Proceed with M2 v1 implementation now.**

Reasons:

1. **Scope is small.** ~430 lines total, 2 new services + minor command changes. No existing behavior modified. Estimated 6-8h, well under the 16h roadmap budget.

2. **Zero architectural risk.** No persistence layer needed. No new dependencies. Two pure resolver services following existing patterns (ContentScorer, SecurityValidator).

3. **All raw data already exists.** YAML `url`/`date` fields, filesystem timestamps, git history — we just need to read and classify them.

4. **Additive only.** New JSON fields in output, new optional flags. Zero breaking changes. Existing tests remain untouched.

5. **Clear test strategy.** Same patterns as release:prepare (golden tests, unit tests, source inspection). No mocking complexity.

**Suggested implementation order:**

1. `FreshnessResolver` + unit tests
2. `TrustResolver` + unit tests
3. `DocsCommand` integration (flags, filtering, badge injection)
4. Golden tests for output schema
5. Runbook documentation
6. Quality gates
