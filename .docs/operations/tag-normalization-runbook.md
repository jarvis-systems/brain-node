---
name: "Tag Normalization Runbook"
description: "Non-destructive tag normalization procedure for vector memory hygiene"
type: runbook
date: 2026-02-22
version: "2.0.0"
status: active
---

# Tag Normalization Runbook

## Principle

Tags are the secondary retrieval axis after semantic embeddings. Tag fragmentation (plurals, case variants, semantic overlaps) degrades filter-based searches and inflates the canonical tag registry. Normalization merges equivalent tags without touching memory content or deleting records.

**Safety guarantee**: This procedure modifies ONLY tag arrays on existing memories. Zero memories are created, deleted, or content-modified.

## Scope

| In Scope | Out of Scope |
|----------|-------------|
| Rename tags on existing memories | Memory deletion |
| Merge semantic duplicates | Content modification |
| Establish canonical tag set | Embedding re-generation |
| Entropy reduction | Category changes |

## Current State (2026-02-22)

| Metric | Value |
|--------|-------|
| Total memories | 207 |
| Unique tags | 548 |
| Canonical tags | 47 |
| Tags with freq > 1 | 5 (`brain`:8, `invariant`:4, `canonical`:4, `compile-safety`:2, `security`:2, `customruncommand`:2) |
| Tags with freq = 1 | 42 canonical, ~543 unique |
| Health status | Healthy |
| Smoke test pass rate | 12/15 (80%) |
| Tag entropy | See Step 2 |

## Step 0: Snapshot / Export Plan

### Pre-Action State Capture

Before ANY tag modifications, capture a complete snapshot of current state.

**File locations**:

| Artifact | Path |
|----------|------|
| Ledger snapshot | `.work/memory-hygiene/ledger.json` |
| Pre-normalize snapshot | `.work/memory-hygiene/pre-normalize-snapshot-2026-02-22.json` |
| Normalization plan | `.work/memory-hygiene/tag-normalize-plan.json` |
| Post-normalize snapshot | `.work/memory-hygiene/post-normalize-snapshot-2026-02-22.json` |

**Capture commands** (execute in Claude Code session):

```
# 1. Memory stats
mcp__vector-memory__get_memory_stats()

# 2. Full tag inventory
mcp__vector-memory__get_unique_tags()
mcp__vector-memory__get_canonical_tags()
mcp__vector-memory__get_tag_frequencies()
mcp__vector-memory__get_tag_weights()

# 3. Recent memories (for diff verification)
mcp__vector-memory__list_recent_memories({"limit": 50})
```

**Save to snapshot file** `.work/memory-hygiene/pre-normalize-snapshot-2026-02-22.json`:

```json
{
  "snapshot_date": "2026-02-22T...",
  "type": "pre-normalize",
  "total_memories": 207,
  "unique_tags_count": 548,
  "canonical_tags_count": 47,
  "unique_tags": ["<full list from get_unique_tags>"],
  "canonical_tags": ["<full list from get_canonical_tags>"],
  "tag_frequencies": {"<full map from get_tag_frequencies>"},
  "tag_weights": {"<full map from get_tag_weights>"},
  "smoke_test_pass_rate": "12/15"
}
```

**Verification**: After saving, re-read the snapshot file to confirm it contains all 548 unique tags and 47 canonical tags.

## Step 1: Tag Normalization Ruleset

### Current Canonical Tags (47)

```
archetype-registry    benchmark-system     benchmark-test
brain                 brain-cli            brain-compilation
brain-includes        brain-node           brain-traits
canonical             ci-gates             command-includes
compilation-system    compile-safety       composer
conditional-syntax    customruncommand     dependabot
documentation         domain:auth          dual-repo
elvis-operator        flock                formats
invariant             jsonl-telemetry      lab-docblock
lab-ui                navigation           no-secret-output
null-coalescing       phpstan              phpunit
project-structure     quality-gates        scenario-format
security              single-writer        tab-bar
task-13               task-6               ternary
threat-model          tooluse-dto          topology
type:lesson           validation
```

### Normalization Categories

#### Category A: Plural to Singular

No plural canonical tags detected. However, in the 548 unique tags:

| Old Tag | New Tag | Frequency | Rationale |
|---------|---------|-----------|-----------|
| `assertions` | `assertion` | unique | Singular convention |
| `commands` | `command` | unique | Singular convention |
| `constants` | `constant` | unique | Singular convention |
| `directions` | `direction` | unique | Singular convention |
| `dto-patterns` | `dto-pattern` | unique | Singular convention |
| `handlers` | `handler` | unique | Singular convention |
| `hooks` | `hook` | unique | Singular convention |
| `imports` | `import` | unique | Singular convention |
| `modifiers` | `modifier` | unique | Singular convention |
| `patterns` | `pattern` | unique | Singular convention |
| `prompts` | `prompt` | unique | Singular convention |
| `regex-patterns` | `regex-pattern` | unique | Singular convention |
| `transforms` | `transform` | unique | Singular convention |
| `variables` | `variable` | unique | Singular convention |
| `keyboard-shortcuts` | `keyboard-shortcut` | unique | Singular convention |
| `keyboard-events` | `keyboard-event` | unique | Singular convention |
| `conditional-schemas` | `conditional-schema` | unique | Singular convention |
| `ternary-operators` | `ternary-operator` | unique | Singular convention |

#### Category B: CamelCase / Mixed Case to kebab-case

| Old Tag | New Tag | Frequency | Rationale |
|---------|---------|-----------|-----------|
| `customruncommand` | `custom-run-command` | canonical(2) | Kebab-case convention; `custom-run-command` already exists as unique tag |
| `drawasync` | `draw-async` | unique | Kebab-case convention |
| `tooluse-dto` | `tool-use-dto` | canonical(1) | Consistent kebab-case |
| `evaluatecondition` | `evaluate-condition` | unique | Kebab-case convention |
| `flattenarray` | `flatten-array` | unique | Kebab-case convention |
| `parseternary` | `parse-ternary` | unique | Kebab-case convention |
| `variablesdetectarray` | `variables-detect-array` | unique | Kebab-case convention |
| `variablesdetectstring` | `variables-detect-string` | unique | Kebab-case convention |
| `tabnavigation` | `tab-navigation` | unique | Kebab-case convention; related tag `navigation` exists |
| `commandlineprompt` | `command-line-prompt` | unique | `command-line-prompt` already exists as unique tag |
| `labcommand` | `lab-command` | unique | `lab-command` already exists as unique tag |
| `braincommandregexp` | `brain-command-regexp` | unique | Kebab-case convention |
| `brainsystem` | `brain-system` | unique | Kebab-case convention |
| `reactphp` | `react-php` | unique | `react-php` already exists as unique tag |

#### Category C: Semantic Overlaps (merge into canonical)

| Old Tag | New Tag (Canonical) | Frequency | Rationale |
|---------|---------------------|-----------|-----------|
| `brain-compile` | `brain-compilation` | unique → canonical(1) | Same concept |
| `brain-core` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `brain-system` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `brain-ecosystem` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `brain-optimization` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `brain-archetype` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `brain-principles` | `brain` | unique → canonical(8) | Sub-concept rolls up |
| `compilation` | `brain-compilation` | unique → canonical(1) | Same concept |
| `compilation-knowledge` | `brain-compilation` | unique → canonical(1) | Sub-concept |
| `compilation-system-knowledge` | `compilation-system` | unique → canonical(1) | Sub-concept |
| `compile-command` | `brain-compilation` | unique → canonical(1) | Same domain |
| `compile-orchestrator` | `brain-compilation` | unique → canonical(1) | Same domain |
| `flock` | `single-writer` | canonical(1) → canonical(1) | flock IS single-writer mechanism |
| `ci-gates` | `quality-gates` | canonical(1) → canonical(1) | Merge candidate — review needed |
| `security` | `no-secret-output` | canonical(2) → canonical(1) | DO NOT MERGE — security is broader |
| `tab-bar` | `lab-ui` | canonical(1) → canonical(1) | Sub-concept of lab-ui |
| `tab-navigation` | `lab-ui` | unique → canonical(1) | Sub-concept of lab-ui |
| `tab-switching` | `lab-ui` | unique → canonical(1) | Sub-concept of lab-ui |
| `tab-state` | `lab-ui` | unique → canonical(1) | Sub-concept of lab-ui |
| `tabbar` | `lab-ui` | unique → canonical(1) | Duplicate of tab-bar |
| `tabbar-php` | `lab-ui` | unique → canonical(1) | Implementation detail |
| `lab-component` | `lab-ui` | unique → canonical(1) | Sub-concept |
| `lab-components` | `lab-ui` | unique → canonical(1) | Sub-concept (plural) |
| `lab-screen` | `lab-ui` | unique → canonical(1) | Sub-concept |
| `navigation` | `lab-ui` | canonical(1) → canonical(1) | Context is always lab navigation |
| `elvis-syntax` | `elvis-operator` | unique → canonical(1) | Same concept |
| `ternary-operator` | `ternary` | unique → canonical(1) | Same concept |
| `ternary-parser` | `ternary` | unique → canonical(1) | Sub-concept |
| `ternary-implementation` | `ternary` | unique → canonical(1) | Sub-concept |
| `nested-ternary` | `ternary` | unique → canonical(1) | Sub-concept |
| `conditional-syntax` | `ternary` | canonical(1) → canonical(1) | Review — may be broader |
| `null-coalescing` | Keep separate | canonical(1) | Distinct from ternary |
| `yaml-front-matter` | `documentation` | unique → canonical(1) | Sub-concept |
| `documentation-standards` | `documentation` | unique → canonical(1) | Sub-concept |
| `markdown-format` | `documentation` | unique → canonical(1) | Sub-concept |
| `brain-docs` | `documentation` | unique → canonical(1) | Sub-concept |

#### Category D: Task-Reference Tags (consider removal)

| Old Tag | Action | Rationale |
|---------|--------|-----------|
| `task-6` | Keep but review | Canonical; may reference specific task context |
| `task-13` | Keep but review | Canonical; may reference specific task context |
| `task-2`, `task-3`, ... `task-28` | Normalize to pattern `task-N` | 20+ task-reference tags in unique set |
| `task-2-completed`, `task-3-completed`, etc. | Remove status suffix | Status is not a tag concern |
| `task-2-validation`, `task-3-validation`, etc. | Remove validation suffix | Validation is a separate concern |
| `step-1`, `step-2`, ... `step-6` | Remove | Workflow position, not knowledge tag |
| `step-1-complete`, `step-2-completed`, etc. | Remove | Status + workflow position |
| `in_progress`, `completed`, `passed` | Remove | Status tags pollute knowledge taxonomy |

#### Category E: High-Frequency Tags (Priority)

These have the highest canonical frequency and must be handled first:

| Canonical Tag | Frequency | Weight (IDF) | Action |
|---------------|-----------|-------------|--------|
| `brain` | 8 | 0.434 | Keep — top-level domain tag |
| `invariant` | 4 | 0.621 | Keep — semantic precision |
| `canonical` | 4 | 0.558 | Keep — refers to canonical tag system |
| `compile-safety` | 2 | 0.910 | Keep — critical domain |
| `security` | 2 | 0.910 | Keep — critical domain (do NOT merge with no-secret-output) |
| `customruncommand` | 2 | 0.721 | Rename to `custom-run-command` |

### Proposed Canonical Tag Set (Post-Normalization)

Target: reduce from 47 canonical tags to ~34 by merging overlaps.

```
archetype-registry    benchmark-system     benchmark-test
brain                 brain-cli            brain-compilation
brain-includes        brain-node           brain-traits
canonical             compilation-system   compile-safety
composer              custom-run-command   dependabot
documentation         domain:auth          dual-repo
elvis-operator        formats              invariant
jsonl-telemetry       lab-docblock         lab-ui
no-secret-output      null-coalescing      phpstan
phpunit               project-structure    quality-gates
scenario-format       security             single-writer
ternary               threat-model         tool-use-dto
topology              type:lesson          validation
```

**Changes from current**: removed `command-includes` (merged to `brain-includes`), `conditional-syntax` (merged to `ternary`), `customruncommand` (renamed to `custom-run-command`), `flock` (merged to `single-writer`), `navigation` (merged to `lab-ui`), `tab-bar` (merged to `lab-ui`), `task-6` (demoted from canonical), `task-13` (demoted from canonical), `tooluse-dto` (renamed to `tool-use-dto`).

## Step 2: Dry-Run Mode Specification

### Report-Only Analysis

Before applying any changes, produce a tag entropy analysis to quantify current fragmentation.

### Tag Entropy Formula

```
H = -SUM(p_i * log2(p_i))
```

Where:
- `p_i = freq_i / total_freq`
- `freq_i` = frequency of canonical tag `i`
- `total_freq` = sum of all canonical tag frequencies

### Current Entropy Calculation

From `get_tag_frequencies` data (47 canonical tags, total frequency = 55):

| Tag | freq | p_i | -p_i * log2(p_i) |
|-----|------|-----|-------------------|
| brain | 8 | 0.1455 | 0.3986 |
| invariant | 4 | 0.0727 | 0.2627 |
| canonical | 4 | 0.0727 | 0.2627 |
| compile-safety | 2 | 0.0364 | 0.1688 |
| security | 2 | 0.0364 | 0.1688 |
| customruncommand | 2 | 0.0364 | 0.1688 |
| (41 tags with freq=1) | 1 each | 0.0182 each | 0.1021 each |
| **Total** | **55** | **1.0** | **H = 5.38 bits** |

**Maximum entropy** for 47 tags: H_max = log2(47) = 5.55 bits.

**Normalized entropy**: H/H_max = 5.38/5.55 = **0.969** (extremely high fragmentation; near-uniform distribution).

### Expected Post-Normalization Entropy

After merging ~13 canonical tags into existing ones (47 -> ~34):

- `brain` absorbs ~5 sub-tags: freq rises from 8 to ~13
- `lab-ui` absorbs `navigation`, `tab-bar`: freq rises from 1 to ~3
- `ternary` absorbs `conditional-syntax`: freq rises from 1 to ~2
- `single-writer` absorbs `flock`: freq rises from 1 to ~2

Estimated H_post ~ 4.6 bits, H_max_post = log2(34) = 5.09 bits.
Normalized entropy: 4.6/5.09 = **0.904** (measurable improvement).

### Dry-Run Verification Commands

For each proposed canonical tag, verify memory count using tag filters:

```
# Verify brain-related tag consolidation
mcp__vector-memory__search_memories({"query": "brain system", "tags": ["brain"], "limit": 50})
mcp__vector-memory__search_memories({"query": "brain system", "tags": ["brain-core"], "limit": 50})
mcp__vector-memory__search_memories({"query": "brain system", "tags": ["brain-system"], "limit": 50})

# Verify lab-ui consolidation
mcp__vector-memory__search_memories({"query": "lab screen tab bar", "tags": ["tab-bar"], "limit": 50})
mcp__vector-memory__search_memories({"query": "lab screen tab bar", "tags": ["lab-ui"], "limit": 50})
mcp__vector-memory__search_memories({"query": "lab screen tab bar", "tags": ["navigation"], "limit": 50})

# Verify ternary consolidation
mcp__vector-memory__search_memories({"query": "ternary conditional", "tags": ["ternary"], "limit": 50})
mcp__vector-memory__search_memories({"query": "ternary conditional", "tags": ["conditional-syntax"], "limit": 50})

# Verify custom-run-command rename
mcp__vector-memory__search_memories({"query": "custom run command", "tags": ["customruncommand"], "limit": 50})
```

### Expected Dry-Run Output Format

```
+------------------------+-------+--------+
| Canonical Tag          | Count | % Total|
+------------------------+-------+--------+
| brain                  |   13  | 23.6%  |
| invariant              |    4  |  7.3%  |
| canonical              |    4  |  7.3%  |
| lab-ui                 |    3  |  5.5%  |
| compile-safety         |    2  |  3.6%  |
| security               |    2  |  3.6%  |
| custom-run-command     |    2  |  3.6%  |
| ...                    |  ...  |  ...   |
+------------------------+-------+--------+
| TOTAL                  |   55  | 100.0% |
+------------------------+-------+--------+
| Entropy (H)            | ~4.6 bits       |
| Max Entropy (H_max)    | 5.09 bits       |
| Normalized (H/H_max)   | 0.904           |
+------------------------+-------+--------+
```

## Step 3: Apply Mode (Tags-Only)

### Tool Availability

Implemented in `vector-memory-mcp >= v1.10.0` (shipped 2026-02-22).

| Tool | MCP Server | Available | Since |
|------|-----------|-----------|-------|
| `tag_normalize_preview` | vector-memory | YES | v1.10.0 |
| `tag_normalize_apply` | vector-memory | YES | v1.10.0 |
| `snapshot_create` | vector-memory | YES | v1.10.0 |
| `snapshot_restore` | vector-memory | YES | v1.10.0 |
| `tag_normalize_preview` | vector-task | YES | v1.x |
| `tag_normalize_apply` | vector-task | YES | v1.x |

### Upgrade Checklist

Before using these tools, ensure the MCP server is at v1.10.0+:

1. Check current version: `uvx --version vector-memory-mcp` or check `pyproject.toml`
2. Upgrade: `uvx upgrade vector-memory-mcp` (or `pip install --upgrade vector-memory-mcp`)
3. Restart Claude Desktop / MCP client to reload tools
4. Verify: call `mcp__vector-memory__snapshot_create({"description": "version check"})` — should return `{"success": true, ...}`

### Exact MCP Commands (Full Workflow)

**Phase 1: Create rollback snapshot**

```
mcp__vector-memory__snapshot_create({"description": "pre-normalize baseline 2026-02-22"})
# Returns: { "success": true, "snapshot_id": "<16-char hex>", "memory_count": 207 }
# SAVE the snapshot_id — required for apply step
```

**Phase 2: Preview normalization (non-destructive)**

```
mcp__vector-memory__tag_normalize_preview({"threshold": 0.90, "max_changes": 200})
# Returns: {
#   "success": true,
#   "preview_id": "<64-char hex>",
#   "total_memories_scanned": 207,
#   "unique_tags_before": 548,
#   "unique_tags_after": <lower>,
#   "planned_updates_count": <N>,
#   "affected_memories_count": <N>,
#   "changes": [ { "memory_id": ..., "old_tags": [...], "new_tags": [...] }, ... ],
#   "threshold": 0.90
# }
# VERIFY: review changes list. SAVE preview_id.
```

**Phase 3: Apply normalization (requires both IDs)**

```
mcp__vector-memory__tag_normalize_apply({
  "preview_id": "<preview_id from Phase 2>",
  "snapshot_id": "<snapshot_id from Phase 1>",
  "threshold": 0.90,
  "max_changes": 200
})
# Returns: { "success": true, "applied_count": <N>, "memories_updated": <N> }
# Apply re-computes the mapping internally and VERIFIES preview_id matches.
# If state drifted between preview and apply → rejected.
```

**Phase 4: Post-apply verification**

Run the 15-probe smoke test (see Evidence section below). If pass rate drops below 12/15:

```
mcp__vector-memory__snapshot_restore({"snapshot_id": "<snapshot_id from Phase 1>"})
# Returns: { "success": true, "restored_count": 207 }
# Restores EXACT pre-normalization tag state. Content/embeddings untouched.
```

### Safety Guarantees

- **Tags-only**: content and embeddings are NEVER modified by normalize or snapshot tools
- **Deterministic preview_id**: same state produces same preview_id (SHA256 of sorted mapping JSON)
- **Deterministic snapshot_id**: same tag state produces same snapshot_id
- **Atomic apply**: all tag updates in a single transaction; rollback on any failure
- **Snapshot survives apply**: snapshot data persists in `tag_snapshots` table, reusable for rollback
- **Guards**: version tags, colon-prefixed tags, numeric suffix tags, and prefix-overlap tags are protected from merging
- **Apply rejects invalid snapshot**: fake/missing snapshot_id returns `{"success": false, "error": "Snapshot not found"}`

### Verified On

Runtime verification completed 2026-02-22. PyPI v1.10.0. All 4 tools discoverable via MCP ToolSearch.

| Step | Result |
|------|--------|
| snapshot_create | memory_count=207, snapshot_id=16-char hex |
| tag_normalize_preview (max_changes=10) | 2 mappings, 4 affected memories, tags 546→544 |
| tag_normalize_apply | 4 memories updated, tags_replaced=4 |
| snapshot_restore | restored_count=207, tags reverted 544→546 |
| apply with fake snapshot_id | Rejected: "Snapshot not found" |

### Rollback Instructions

**Primary method (snapshot restore)**:

```
mcp__vector-memory__snapshot_restore({"snapshot_id": "<snapshot_id>"})
```

This is a LOSSLESS rollback — restores the exact per-memory tag arrays captured at snapshot time. No inverse mapping ambiguity.

**Important**: Always create a snapshot BEFORE applying. Without a snapshot, rollback requires manual reconstruction from `.work/memory-hygiene/pre-normalize-snapshot-*.json` artifacts.

### Post-Apply Safety Checks

```
# 1. Verify memory count unchanged
mcp__vector-memory__get_memory_stats()
# ASSERT: total_memories == 207

# 2. Verify unique tag count reduced
mcp__vector-memory__get_unique_tags()
# ASSERT: count < 548

# 3. Verify canonical tag count reduced
mcp__vector-memory__get_canonical_tags()
# ASSERT: count <= 34

# 4. Verify no data loss — compare with pre-normalize snapshot
# total_memories MUST be identical
# categories distribution MUST be identical
# Only tags array should differ
```

## Evidence: Retrieval Verification

### 15-Probe Smoke Test

Execute the full smoke test from `.work/memory-hygiene/probe-set.json` before and after normalization.

**Baseline**: 12/15 PASS (80%) as of 2026-02-22.
**Target**: 14/15 PASS (93%) — tag normalization should improve filter-based retrieval by +2.

### Probe Queries

| ID | Domain | Query | Expected Concept | Critical |
|----|--------|-------|-----------------|----------|
| P01 | compile-safety | `brain compile single-writer lock mutex flock concurrent compilation forbidden` | Single-writer lock for brain compile, flock() mutex | Yes |
| P02 | ci-gates | `composer test composer analyse quality gates PHPStan PHPUnit` | Quality gates: composer test + composer analyse mandatory | Yes |
| P03 | project-structure | `project root directory brain-node cli core dual repository structure` | Dual-repo: brain-node (root) + brain-cli (cli/) + brain-core | Yes |
| P04 | static-analysis | `PHPStan level analysis zero errors 170 files 124 files static analysis` | PHPStan L2 zero errors across core (170 files) and CLI (124 files) | No |
| P05 | release-ritual | `roadmap release closure phases batch testing coverage assertions` | Roadmap closure with phases, evidence, next candidates | No |
| P06 | memory-rules | `vector memory search before store iron rules MCP json payload mandatory` | search-before-store, mcp-json-only, multi-probe-mandatory | Yes |
| P07 | delegation | `Brain delegation protocol agent orchestration workflow request analysis synthesis` | Brain as delegation orchestrator, not executor | Yes |
| P08 | bridge-pattern | `CommandBridgeAbstract handle bridge autoupdate checkWorkingDir abstract command` | CommandBridgeAbstract handle() -> handleBridge() pattern | No |
| P09 | lab-architecture | `Lab Screen REPL interactive CLI TUI keyboard event loop ReactPHP` | Lab REPL with ReactPHP async event loop, drawAsync() | No |
| P10 | semantic-tags | `semantic tags purpose execute mission provides XML compilation archetype` | Context-specific tags: execute (Command), mission (Agent), provides (Include) | No |
| P11 | pseudo-syntax | `Operator.php pseudo-syntax IF FOREACH END-IF standardization format` | Pseudo-syntax standardization with END markers, 60-char threshold | Yes |
| P12 | benchmark | `benchmark JSONL tool_use DTO scenario validation runner suite` | Benchmark system with JSONL output, tool_use DTOs, scenario runner | No |
| P13 | delegation-rules | `async sync delegation threshold 30 seconds checklist when to use agent` | Async >30s, sync <5s, gray zone decision framework | No |
| P14 | security | `security model compile safety secret output prevention no-secret-output` | No-secret-output policy, compile safety contract | Yes |
| P15 | bug-fix-recall | `flattenArray Array to string conversion warning CompileStandartsTrait fix` | flattenArray() fix for nested arrays in compilation | No |

### Execution Protocol

```
# For each probe P01-P15:
mcp__vector-memory__search_memories({"query": "<probe query>", "limit": 3})

# Evaluate:
# 1. Top result semantically relevant to expected concept?
# 2. similarity >= 0.40?
# 3. Mark PASS or FAIL
```

### Before / After Comparison

| Metric | Pre-Normalize | Post-Normalize | Delta | Pass? |
|--------|--------------|----------------|-------|-------|
| Total memories | 207 | MUST = 207 | 0 | Required |
| Pass rate | 12/15 | >= 12/15 | >= 0 | Required |
| Critical probes | 7/7 | 7/7 | 0 | Required |
| Unique tags | 548 | < 548 | negative | Expected |
| Canonical tags | 47 | ~34 | -13 | Expected |
| Tag entropy (norm) | 0.969 | < 0.969 | negative | Expected |

### Acceptance Criteria

1. **HARD REQUIREMENT**: `total_memories` unchanged (207)
2. **HARD REQUIREMENT**: `pass_rate >= 12/15` (no regression from baseline)
3. **TARGET**: `pass_rate >= 14/15` (+2 improvement)
4. **EXPECTED**: `unique_tags < 548` (tag reduction)
5. **EXPECTED**: `normalized_entropy < 0.969` (fragmentation reduction)

### Failure Protocol

If post-normalize pass rate drops below 12/15:
1. Identify which probes regressed
2. Check if tag filter changes affected retrieval
3. Apply inverse mapping for the specific tags causing regression
4. Re-run smoke test to confirm recovery

## Anti-Patterns

| Do NOT | Why |
|--------|-----|
| Apply without snapshot | No rollback baseline |
| Merge `security` into `no-secret-output` | Security is a broader domain than secret prevention |
| Merge `ci-gates` into `quality-gates` without review | May be distinct concepts in some memories |
| Remove task-reference tags wholesale | Some encode meaningful context about feature origin |
| Use `clear_old_memories` for "cleanup" | Destructive; violates this runbook's safety guarantee |
| Normalize tags without smoke test baseline | Cannot measure impact |
| Apply via Option C (re-store) | Creates duplicates without deletion capability |

## Appendix A: Tag Weight Analysis

IDF weights reveal tag discriminative power. Lower weight = more common = less discriminative.

| Weight | Tags | Interpretation |
|--------|------|---------------|
| 0.434 | `brain` | Lowest weight; appears in 8 canonical entries. Low discriminative value. |
| 0.558 | `canonical` | Low weight; 4 entries. |
| 0.621 | `invariant` | Medium-low; 4 entries. |
| 0.721 | `customruncommand` | Medium; 2 entries. |
| 0.910 | `compile-safety`, `security`, `null-coalescing` | Medium-high; 2 entries each. |
| 1.443 | All freq=1 tags (41 tags) | Maximum weight; highest discriminative power. |

**Insight**: The two "ghost" tags in weights but NOT in canonical (`elvis-syntax`, `yaml-expressions`) confirm that the canonical tag registry and unique tag set are not fully synchronized. Normalization should address this.

## Appendix B: Unique Tags NOT in Canonical (Sample of High-Value Candidates)

From the 548 unique tags, these appear frequently across memories but lack canonical status:

| Tag | Estimated Usage | Recommended Canonical |
|-----|----------------|----------------------|
| `architecture` | High (57 memories in category) | `architecture` |
| `lab` | High (many lab memories) | `lab-ui` (merge) |
| `cli` | Medium | `brain-cli` (merge) |
| `php` | Medium | `php` (new canonical) |
| `refactoring` | Medium | `refactoring` (new canonical) |
| `testing` | Medium | `testing` (new canonical) |
| `error-handling` | Medium | `error-handling` (new canonical) |
| `delegation` | Medium | `delegation` (new canonical) |

## Appendix C: Implementation Priority

| Priority | Action | Impact | Effort |
|----------|--------|--------|--------|
| ~~P0~~ | ~~Request `tag_normalize_preview/apply` for vector-memory MCP~~ | DONE — shipped in v1.10.0 | Completed 2026-02-22 |
| P1 | Rename `customruncommand` -> `custom-run-command` | Fixes worst kebab-case violation (freq=2) | 2 memories |
| P2 | Merge `flock` -> `single-writer` | Reduces semantic overlap | 1 memory |
| P3 | Merge tab/navigation tags -> `lab-ui` | Consolidates UI tags | ~10 memories |
| P4 | Merge brain sub-tags -> `brain` | Reduces `brain-*` fragmentation | ~5 memories |
| P5 | Clean up task-reference and status tags | Removes noise tags | ~20 memories |
| P6 | Establish canonical set for uncovered domains | Improves coverage | New canonical entries |
