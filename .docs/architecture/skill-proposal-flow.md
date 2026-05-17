---
name: "Skill Proposal Flow"
description: "Diff-review gate for skill changes. Brain authors proposals; user reviews and applies. Prevents self-poisoning drift on the skill surface."
type: architecture
date: 2026-05-16
version: "0.1.0"
status: active
---

# Skill Proposal Flow

## Rationale

Skills are load-bearing instructions consumed by every Brain run. If Brain were allowed to write directly to `node/Skills/{id}/SKILL.md`, three failure modes follow:

1. **Drift**: each "self-improvement" mutates the contract, slowly diverging from what the user actually wants.
2. **Garbage accumulation**: low-confidence patterns get burned into skills, then re-inforce themselves on subsequent runs.
3. **No audit trail**: there is no way to attribute a skill change to evidence or to roll it back.

The fix is a strict **diff-review gate**: Brain MAY draft a change, but the only mutation path into canonical `SKILL.md` is `/skill:apply` triggered by an explicit user decision. This is enforced at policy level by `SkillProposalPolicyInclude` and at command level by the read-only contract of the four authoring commands (`/skill:learn`, `/skill:new`, `/skill:edit`, `/skill:deprecate`).

## Lifecycle

```
learn | new | edit | deprecate  →  list  →  review  →  apply | reject
```

1. **author** — one of four intent-based commands writes a `proposal.json` plus a diff or full-content draft.
   - Output lands under `node/Skills/{target}/pending-proposals/{date}-{slug}/` (modify / append-reference / deprecate) or under `node/Skills/.new-proposals/{date}-{slug}/` (create-skill).
   - **No canonical SKILL.md is touched.**

2. **list** (`/skill:list`)
   - Globs both pending locations, prints a summary table sorted by `created_at DESC`.

3. **review** (`/skill:review {id}`)
   - Locates the candidate folder.
   - Prints `proposal.json` metadata plus the diff (`SKILL.md.patch`) or the full draft (`SKILL.md.new`).
   - Emits caveats, confidence commentary, and the apply/reject next-step commands.

4. **apply** (`/skill:apply {id}`)
   - Validates `proposal.json` against `cli/schema/skill-proposal.schema.json`.
   - Snapshots canonical `SKILL.md` for rollback safety.
   - Executes the action (`patch`, write new reference, create skill folder, deprecate frontmatter).
   - Lints resulting frontmatter (`name`, `description` required).
   - Records `history-references/{date}-applied-{slug}.md` with full metadata and a result summary.
   - Removes the pending folder.
   - Recommends `brain compile`.

5. **reject** (`/skill:reject {id} --reason "..."`)
   - Records `history-references/{date}-rejected-{slug}.md` with the explicit reason.
   - Removes the pending folder.
   - Never touches canonical `SKILL.md`.

## Command Intents

| Command | Args | Intent | Resulting action |
|---|---|---|---|
| `/skill:learn` | none | Brain analyzes current session signals (recent files, vector-task changes, vector-memory entries, conversation), identifies 1-5 candidate patterns, asks the user to pick. | `modify-skill` (when pick matches existing target) or `create-skill` (otherwise) |
| `/skill:new {kebab-name}` | 1 (skill name) | Brain interactively asks "purpose?", enriches body from session context, drafts `SKILL.md.new` with frontmatter (name, description, auto-suggested `docs_topics`). | `create-skill` |
| `/skill:edit {existing-name}` | 1 (skill name) | Brain reads current `SKILL.md` + session signals (git history, corrections, related tasks), suggests a unified diff for accept / edit / abort. | `modify-skill` |
| `/skill:deprecate {existing-name}` | 1 (skill name) | Brain asks for reason and optional replacement, builds a frontmatter patch (`deprecated: true`, `replacement: X`). | `deprecate-skill` |

`docs_topics` auto-suggestion happens inside `/skill:learn`, `/skill:new`, and `/skill:edit` whenever Step 0 docs_search produces hits — it is **not** a separate user-facing command. When Step 0 classifies a candidate as `DUPLICATE_IN_DOCS`, the same workflow inline-recommends `append-reference` action with a `docs_topics` keyword wiring instead of duplicating prose.

### Migration Note

The earlier `/skill:propose` god-command (Phase 1) — with its seven flags `--action`, `--target`, `--rationale`, `--confidence`, `--evidence`, `--caveats`, `--replacement` — has been replaced by these four intent-based commands for cleaner UX. The on-disk schema (`cli/schema/skill-proposal.schema.json`), storage layout, triage workflow, and apply/reject lifecycle are unchanged.

## Triage (Step 0)

Before any proposal is written to disk, every authoring command (`/skill:learn`, `/skill:new`, `/skill:edit`, `/skill:deprecate`) runs a classification pass against five data sources via the shared `SkillProposalSharedTrait`:

| Source | Tool | Purpose |
|---|---|---|
| Vector-memory | `mcp__vector-memory__search_memories` | Past observations of similar patterns |
| Vector-task | `mcp__vector-task__task_list` | Related tasks (in-flight or completed) |
| Existing skills | Glob `node/Skills/*/SKILL.md` | Current rule/guideline coverage |
| Rejected history | Glob `node/Skills/*/history-references/*-rejected-*.md` | Patterns already explicitly turned down |
| .docs/ | `mcp__brain-tools__docs_search` | Project documentation context |

The classifier emits one of nine outcomes:

| Outcome | Action |
|---|---|
| `DUPLICATE` | ABORT — knowledge already exists in `{skill}/{rule_id}` |
| `DUPLICATE_IN_DOCS` | ABORT — knowledge already at `{doc_path}` in `.docs/`; recommend linking the doc via `docs_topics` keywords (auto-suggested in `/skill:new` / `/skill:edit`) or an explicit `append-reference` proposal, instead of duplicating prose |
| `FITS_EXISTING` | CONFIRM — recommend `--target {other-skill}` and require user yes |
| `SPLIT` | CONFIRM — propose multiple sub-proposals, require user yes |
| `NOISE_OR_TRIVIAL` | ABORT — store as observation in vector-memory instead |
| `BELONGS_IN_DOCS` | ABORT — input is descriptive material (architectural / runbook), not action-guiding skill material; recommend `/doc:work --create {.docs/path/}` instead |
| `PREVIOUSLY_REJECTED` | CONFIRM — reference past rejection reason, require user override |
| `NEW_DOMAIN` | PROCEED — `create-skill` is justified |
| `OK_MODIFY` | PROCEED — pattern cleanly modifies the chosen target |

If a vector or brain-tools MCP server is unavailable, triage degrades gracefully: skip the affected probe, log a warning, continue with remaining sources.

The triage is enforced by iron rule `skill-triage-required` (critical) registered via `SkillProposalPolicyInclude`.

## Docs Topics (Optional Frontmatter)

`SKILL.md` may optionally declare a `docs_topics` field in frontmatter:

```yaml
---
name: foo
description: ...
docs_topics: [auth-flow, session-tokens, csrf]
---
```

`docs_topics` is an array of keyword strings (each 1–64 chars). It is **optional** — skills without relevant docs context omit the field entirely.

**Why keywords, not paths**: skills are portable across Brain installations. Each client project has its own `.docs/` with different content. Hardcoded paths would break across installs. Keywords let Brain runtime invoke `docs_search` against whichever `.docs/` is local.

**Population**: `/skill:learn`, `/skill:new`, and `/skill:edit` auto-suggest `docs_topics` based on triage `docs_search` hits (Step 5.5 inside `SkillProposalSharedTrait`). The proposer may accept, edit, or remove the suggestion before review.

**Validation**: `/skill:apply` lints the field when present — must be a non-empty array of strings, each 1–64 chars and free of slashes (paths-with-slashes are rejected). Absent field is always valid.

**Runtime usage**: when Brain works with a skill, it may invoke `mcp__brain-tools__docs_search({"keywords": skill.docs_topics})` to load relevant project context before applying the skill's guidance.

## Storage Layout

```
node/Skills/{skill-id}/
├── SKILL.md                                    # canonical (only skill:apply writes here)
├── references/                                 # canonical reference docs
├── history-references/                         # applied / rejected audit log
│   ├── {YYYY-MM-DD}-applied-{slug}.md
│   └── {YYYY-MM-DD}-rejected-{slug}.md
└── pending-proposals/                          # WIP candidates against an existing skill
    └── {YYYY-MM-DD}-{slug}/
        ├── proposal.json
        ├── SKILL.md.patch                      # modify | append-reference | deprecate
        └── (or) SKILL.md.new                   # (unused inside an existing skill)

node/Skills/.new-proposals/                     # staging for create-skill (target doesn't exist yet)
└── {YYYY-MM-DD}-{slug}/
    ├── proposal.json
    └── SKILL.md.new                            # full future SKILL.md draft
```

The dot-prefix on `.new-proposals/` is significant: `NativeSkillCollector` skips any `node/Skills/` entry whose name starts with a dot, so staging folders never leak into compiled output.

## Confidence Formula

`proposal.confidence` is a calibrated float `0.0..1.0`. Suggested anchors:

| Signal | Confidence |
|---|---|
| Single task observation, no repeats | 0.4 |
| 2-3 repeated observations across sessions | 0.7 |
| Explicit user request to record the skill | 0.9 |
| Post-correction validated pattern (user corrected Brain, the correction repeated, then was validated) | 1.0 |

Anchors are normative for Phase 1. The skillable miner (Phase 2+) will refine them with population stats.

## Brain Integration

`SkillProposalPolicyInclude` is registered in `BrainIncludesTrait` and emits three iron rules into every Brain runtime surface:

- **`skill-write-via-proposal` (critical)** — forbids direct writes to `node/Skills/{id}/SKILL.md`. All changes go through `/skill:learn` | `/skill:new` | `/skill:edit` | `/skill:deprecate` → user review → `/skill:apply`.
- **`skill-trigger-policy` (high)** — restricts when Brain may create a proposal at all: explicit user request, evidenced repeating pattern (>=2 sessions), or skill-bug signal after user correction. Otherwise: record an observation in vector-memory instead.
- **`skill-triage-required` (critical)** — forbids writing a proposal before running Step 0 triage against all five probe sources (vector-memory, vector-task, `.docs/` via `docs_search`, existing skills, rejected history). ABORT classifications: `DUPLICATE`, `NOISE_OR_TRIVIAL`, `DUPLICATE_IN_DOCS`, `BELONGS_IN_DOCS`.

Together these prevent both **direct surface mutation** and **proposal spam**.

## Out of Scope (Phase 1)

- **Auto-trigger heuristics**: Brain currently proposes only on explicit ask. Heuristic detection of "this pattern is worth a proposal" is Phase 2.
- **Skillable miner**: an offline process that scans vector-memory + vector-task signals and authors proposals in batch is Phase 2+.
- **Schema-driven diff generation**: today the diff is hand-built by the proposer. Future iterations may generate diffs from a structured `changeset` block inside `proposal.json`.
- **Multi-skill atomic proposals**: one proposal touches one skill. Cross-skill refactors require multiple proposals coordinated externally.
- **Proposal mutation after creation**: today reviewers cannot edit a proposal — they apply or reject. Edit-in-place is deferred to Phase 2 when conflict semantics are clearer.

## Phase 2 Hooks (forward-looking)

- `skillable` agent class (already enumerated in `proposal.json.created_by`) — autonomous miner.
- `replacement` field on `deprecate-skill` proposals — pointer used by Brain to redirect mentions of the deprecated skill.
- Rejected-history mining: failed proposals teach the miner what NOT to propose again.