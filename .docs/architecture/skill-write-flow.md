---
name: "Skill Write Flow"
description: "Triage-gated direct write for skill changes. Brain analyzes session signals, user picks, write goes straight to canonical SKILL.md with audit trail."
type: architecture
date: 2026-05-18
version: "0.2.0"
status: active
---

# Skill Write Flow

## Rationale

Skills are load-bearing instructions consumed by every Brain run. If Brain were allowed to write to `node/Skills/{id}/SKILL.md` without any safeguard, three failure modes follow:

1. **Drift**: each "self-improvement" mutates the contract, slowly diverging from what the user actually wants.
2. **Garbage accumulation**: low-confidence patterns get burned into skills, then reinforce themselves on subsequent runs.
3. **No audit trail**: there is no way to attribute a skill change to evidence or to roll it back.

The historical fix was a two-stage pipeline: Brain authored a proposal under `pending-proposals/`, the user ran `/skill:apply` or `/skill:reject` later to materialize or discard. That intermediate stage carried real cost — extra commands, extra disk artifacts, extra schema validation — without proportional safety benefit. The four authoring commands (`/skill:learn`, `/skill:new`, `/skill:edit`, `/skill:deprecate`) are all user-initiated and each one already contains an explicit pick/confirm step inside its workflow.

The new fix is a **triage-gated direct write**:

- The user invocation IS the explicit consent.
- The Step 0 triage IS the safety gate (5 probes, 9 classifications, ABORT routes, CONFIRM routes, PROCEED routes).
- `git revert` IS the rollback path.

Brain writes directly to `node/Skills/{id}/SKILL.md` only after triage passes plus the user has picked/confirmed inside the command. The pending stage no longer exists.

## Lifecycle

```
/skill:{learn|new|edit|deprecate}
        →  Step 0 triage  →  user pick/confirm
        →  direct write to node/Skills/{name}/
        →  history-references/{date}-{action}-{slug}.md
        →  vector-memory positive signal
```

1. **invocation** — user runs one of the four intent-based commands. The command collects intent (skill name, purpose, candidate pick, deprecation reason, etc.).

2. **Step 0 triage** — every command runs the shared 5-probe triage via `SkillProposalSharedTrait`. ABORT routes stop the flow with no write. CONFIRM routes require an explicit user YES before proceeding. PROCEED routes go straight through.

3. **direct write** — `SkillProposalSharedTrait::defineDirectWriteWorkflow()` dispatches on `$ACTION` and applies the change directly to canonical `node/Skills/{TARGET_SKILL}/`:
   - `create-skill` — `mkdir` plus `WriteTool` for the new `SKILL.md`.
   - `modify-skill` — `patch -p0` against the canonical `SKILL.md`.
   - `append-reference` — `WriteTool` for the new `references/{ref}.md` plus optional `patch` for SKILL.md link.
   - `deprecate-skill` — `patch -p0` adds `deprecated: true` (and optional `replacement: X`) to frontmatter.

4. **history record** — every successful write logs `node/Skills/{name}/history-references/{YYYY-MM-DD}-{action}-{slug}.md` with YAML frontmatter (status=written, action, decided_at, decided_by, confidence), rationale, evidence bullets, and a one-line result summary.

5. **vector-memory signals** — positive signal stored on success (`category=skill-written`); negative signal stored on decline (`category=skill-declined`) via the shared `recordDeclineSignal()` helper invoked from each command's abort branches.

6. **report** — final report shows the canonical path, the history record path, the rollback command (`git checkout` / `git revert`), and the `brain compile` recommendation.

## Command Intents

| Command | Args | Intent | Resulting action |
|---|---|---|---|
| `/skill:learn` | none | Brain analyzes current session signals (recent files, vector-task changes, vector-memory entries, conversation), identifies 1-5 candidate patterns, asks the user to pick. | `modify-skill` (when pick matches existing target) or `create-skill` (otherwise) |
| `/skill:new {kebab-name}` | 1 (skill name) | Brain interactively asks "purpose?", enriches body from session context, drafts `SKILL.md` content with frontmatter (name, description, auto-suggested `docs_topics`). | `create-skill` |
| `/skill:edit {existing-name}` | 1 (skill name) | Brain reads current `SKILL.md` + session signals (git history, corrections, related tasks), suggests a unified diff for accept / edit / abort. | `modify-skill` |
| `/skill:deprecate {existing-name}` | 1 (skill name) | Brain asks for reason and optional replacement, builds a frontmatter patch (`deprecated: true`, `replacement: X`). | `deprecate-skill` |

`docs_topics` auto-suggestion happens inside `/skill:learn`, `/skill:new`, and `/skill:edit` whenever Step 0 docs_search produces hits — it is **not** a separate user-facing command. When Step 0 classifies a candidate as `DUPLICATE_IN_DOCS`, the same workflow inline-recommends `append-reference` action with a `docs_topics` keyword wiring instead of duplicating prose.

## Triage (Step 0)

Before any direct write lands, every authoring command runs a classification pass against five data sources via the shared `SkillProposalSharedTrait`:

| Source | Tool | Purpose |
|---|---|---|
| Vector-memory | `mcp__vector-memory__search_memories` | Past observations of similar patterns |
| Vector-task | `mcp__vector-task__task_list` | Related tasks (in-flight or completed) |
| Existing skills | Glob `node/Skills/*/SKILL.md` | Current rule/guideline coverage |
| Declined history | Glob `node/Skills/*/history-references/*-declined-*.md` | Patterns already explicitly turned down |
| .docs/ | `mcp__brain-tools__docs_search` | Project documentation context |

The classifier emits one of nine outcomes:

| Outcome | Branch |
|---|---|
| `DUPLICATE` | ABORT — knowledge already exists in `{skill}/{rule_id}` |
| `DUPLICATE_IN_DOCS` | ABORT — knowledge already at `{doc_path}` in `.docs/`; recommend linking the doc via `docs_topics` keywords (auto-suggested in `/skill:new` / `/skill:edit`) or an explicit `append-reference` change, instead of duplicating prose |
| `FITS_EXISTING` | CONFIRM — recommend `--target {other-skill}` and require user yes before direct write |
| `SPLIT` | CONFIRM — propose multiple sub-changes, require user yes before any direct write |
| `NOISE_OR_TRIVIAL` | ABORT — store as observation in vector-memory instead |
| `BELONGS_IN_DOCS` | ABORT — input is descriptive material (architectural / runbook), not action-guiding skill material; recommend `/doc:work --create {.docs/path/}` instead |
| `PREVIOUSLY_REJECTED` | CONFIRM — reference past decline reason, require user override before direct write |
| `NEW_DOMAIN` | PROCEED — `create-skill` is justified, go straight to direct write |
| `OK_MODIFY` | PROCEED — pattern cleanly modifies the chosen target, go straight to direct write |

If a vector or brain-tools MCP server is unavailable, triage degrades gracefully: skip the affected probe, log a warning, continue with remaining sources.

Triage is enforced by iron rule `skill-triage-required` (critical) registered via `SkillProposalPolicyInclude`.

## Docs Topics (Optional Frontmatter)

`SKILL.md` may optionally declare a `docs_topics` field in frontmatter:

```yaml
---
name: foo
description: ...
docs_topics: [auth-flow, session-tokens, csrf]
---
```

`docs_topics` is an array of keyword strings (each 1-64 chars). It is **optional** — skills without relevant docs context omit the field entirely.

**Why keywords, not paths**: skills are portable across Brain installations. Each client project has its own `.docs/` with different content. Hardcoded paths would break across installs. Keywords let Brain runtime invoke `docs_search` against whichever `.docs/` is local.

**Population**: `/skill:learn`, `/skill:new`, and `/skill:edit` auto-suggest `docs_topics` based on triage `docs_search` hits (Step 5.5 inside `SkillProposalSharedTrait`). The user may accept, edit, or remove the suggestion during the accept/edit/abort prompt before the canonical write.

**Validation**: `frontmatter-required` (critical iron rule) lints the canonical write — `name` and `description` must be non-empty strings. `docs_topics`, when present, must be a non-empty array of strings, each 1-64 chars and free of slashes (paths-with-slashes are rejected). Absent field is always valid.

**Runtime usage**: when Brain works with a skill, it may invoke `mcp__brain-tools__docs_search({"keywords": skill.docs_topics})` to load relevant project context before applying the skill's guidance.

## Storage Layout

```
node/Skills/{skill-id}/
├── SKILL.md                                # canonical (written directly by the four /skill:* commands)
├── references/                             # canonical reference docs (append-reference action)
│   └── {ref-name}.md
└── history-references/                     # per-skill audit log
    ├── {YYYY-MM-DD}-create-skill-{slug}.md
    ├── {YYYY-MM-DD}-modify-skill-{slug}.md
    ├── {YYYY-MM-DD}-append-reference-{slug}.md
    ├── {YYYY-MM-DD}-deprecate-skill-{slug}.md
    └── {YYYY-MM-DD}-declined-{slug}.md     # (optional) decline pattern for triage history
```

There is no `pending-proposals/` folder, no `.new-proposals/` staging folder, and no `proposal.json` artifact. The intermediate stage was eliminated in Phase 3.0 of the skill flow refactor.

`NativeSkillCollector` still skips any `node/Skills/` entry whose name starts with a dot — that guard is preserved as defensive coding even though no staging folder is written under `node/Skills/.*` anymore.

## Confidence Formula

`CONFIDENCE` is a calibrated float `0.0..1.0` carried in the history record frontmatter and in the vector-memory tags. Suggested anchors:

| Signal | Confidence |
|---|---|
| Single task observation, no repeats | 0.4 |
| 2-3 repeated observations across sessions | 0.7 |
| Explicit user request to record the skill | 0.9 |
| Post-correction validated pattern (user corrected Brain, the correction repeated, then was validated) | 1.0 |

Anchors are normative for Phase 1. The skillable miner (Phase 2+) will refine them with population stats.

## Brain Integration

`SkillProposalPolicyInclude` is registered in `BrainIncludesTrait` and emits three iron rules into every Brain runtime surface:

- **`skill-write-after-triage` (critical)** — Brain MUST run Step 0 triage AND obtain an explicit user pick/confirmation before writing to `node/Skills/{name}/SKILL.md`. All skill changes flow through `/skill:learn` | `/skill:new` | `/skill:edit` | `/skill:deprecate`.
- **`skill-trigger-policy` (high)** — restricts when Brain may attempt a skill change at all: explicit user request, evidenced repeating pattern (>=2 sessions), or skill-bug signal after user correction. Otherwise: record an observation in vector-memory instead.
- **`skill-triage-required` (critical)** — forbids writing a skill change before running Step 0 triage against all five probe sources (vector-memory, vector-task, `.docs/` via `docs_search`, existing skills, declined history). ABORT classifications: `DUPLICATE`, `NOISE_OR_TRIVIAL`, `DUPLICATE_IN_DOCS`, `BELONGS_IN_DOCS`.

Together these prevent both **direct surface mutation without a safety gate** and **change spam**.

## Why Direct Write

The legacy two-stage proposal flow added overhead without proportional safety:

- **User invocation IS the consent.** The four `/skill:*` commands are all user-initiated and each contains an explicit pick step (`learn` asks "which to record?", `new` shows the draft and asks accept/edit/abort, `edit` shows the diff and asks accept/edit/abort, `deprecate` asks for an explicit reason). There is no path through the flow that bypasses the user.
- **Triage IS the safety gate.** Step 0 runs the same 5-probe, 9-classification logic as before. ABORT outcomes terminate the flow with no write. CONFIRM outcomes pause for an explicit user YES.
- **Rollback IS trivial.** `git checkout -- node/Skills/{name}/SKILL.md` undoes an uncommitted change; `git revert HEAD` undoes a committed change; `rm -rf node/Skills/{name}/` undoes a freshly-created skill.
- **History-references/ replaces proposal.json.** The audit trail still exists, but per skill instead of per pending folder. Every successful write logs `{date}-{action}-{slug}.md`; every decline records a vector-memory negative signal under `category=skill-declined`.

What was lost: the explicit two-pause review window. What was gained: removal of an extra command surface (`/skill:list`, `/skill:review`, `/skill:apply`, `/skill:reject`), removal of an extra disk artifact (`proposal.json`), removal of an extra schema (`cli/schema/skill-proposal.schema.json`), removal of an extra storage layout (`pending-proposals/`, `.new-proposals/`).

## Out of Scope (Phase 1)

- **Auto-trigger heuristics**: Brain currently writes only on explicit user invocation. Heuristic detection of "this pattern is worth a skill change" is Phase 2.
- **Skillable miner**: an offline process that scans vector-memory + vector-task signals and authors skill changes in batch is Phase 2+.
- **Multi-skill atomic writes**: one invocation touches one skill. Cross-skill refactors require multiple invocations coordinated externally.

## Phase 2 Hooks (forward-looking)

- `skillable` agent class (already enumerated as a valid `decided_by` value in history-references frontmatter) — autonomous miner.
- `replacement` field on `deprecate-skill` history records — pointer used by Brain to redirect mentions of the deprecated skill.
- Declined-history mining: vector-memory `skill-declined` entries teach the miner what NOT to attempt again.
