---
name: "Benchmark Coverage Matrix"
description: "Scenario-to-invariant-to-artifact coverage matrix with gap flags for the Brain instruction system"
type: "coverage"
date: "2026-02-21"
version: "1.0.0"
status: "active"
---

# Benchmark Coverage Matrix

Maps every benchmark scenario to the rules it tests, artifacts it protects, and profiles that include it.

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total scenarios | 78 |
| Scenario categories | 10 |
| Profiles | 10 |
| Multi-turn scenarios | 6 |
| Tool-requiring scenarios | 6 |
| Model-gated scenarios | 1 (MT-LP-001: sonnet+) |
| Multi-agent profiles | 2 (free-live: opencode, golden-live: claude) |

## Profile Coverage

| Profile | Count | Agent | Categories Included |
|---------|-------|-------|-------------------|
| smoke | 1 | claude | S0 |
| ci | 26 | claude | L1, L2, ST, CMD |
| telemetry-ci | 12 | claude | S0, L1 (partial), L2 (partial), ST (partial), MT (partial), MT-LP |
| full | 40 | claude | L1, L2, L3, ST, CMD, MT, MT-LP |
| cmd-auto | 28 | claude | CMD-AUTO |
| nightly-live | 8 | claude | CMD (partial), ST (partial), MT (partial), MT-LP (partial), ADV (partial) |
| free-live | 8 | opencode | Same as nightly-live (free model, $0 cost) |
| golden-live | 8 | claude | Same as nightly-live (opus, high-confidence) |
| matrix | 4 | claude | MT (partial), ST (partial) |
| adversarial-matrix | 9 | claude | ADV |

## S0 Smoke (1 scenario)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| S00-000 | Live smoke — pipeline health | operating-model (role recall) | Brain | smoke, telemetry-ci |

## L1 Basic Knowledge (7 scenarios)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| L1-001 | Memory iron rules | mcp-json-only, search-before-store | Brain | ci, telemetry-ci, full |
| L1-002 | Delegation depth | delegation-depth | Brain | ci, telemetry-ci, full |
| L1-003 | Source vs compiled dirs | never-write-compiled, directories | Brain | ci, telemetry-ci, full |
| L1-004 | Token/execution constraints | concise-responses, constraint-token-limit | Brain | ci, full |
| L1-005 | Agent ecosystem | operating-model, exploration-delegation | Brain | ci, full |
| L1-006 | Compilation flow | compilation-flow | Brain | ci, full |
| L1-007 | CLI commands format | cli-commands | Brain | ci, full |

## L2 Applied Knowledge (7 scenarios)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| L2-001 | Task MCP format | mcp-json-only (task) | Brain | ci, telemetry-ci, full |
| L2-002 | Memory MCP format | mcp-json-only (memory) | Brain | ci, telemetry-ci, full |
| L2-003 | Quality gates | quality-TEST, quality-PHPSTAN | Brain | ci, full |
| L2-004 | Error escalation | escalation-policy | Brain | ci, full |
| L2-005 | Memory budget | memory-limit, multi-probe-mandatory, cookbook-constraints | Brain | ci, full |
| L2-006 | Brain docs protocol | brain-docs-tool, yaml-front-matter | Brain | ci, full |
| L2-007 | Rule interpretation | rule-interpretation | Brain | ci, full |

## L3 Advanced Reasoning (8 scenarios)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| L3-001 | Iron rules vs cookbook | cookbook-governance (precedence) | Brain | full |
| L3-002 | Violation detection | search-before-store (detection + action) | Brain | full |
| L3-003 | Cookbook policy | cookbook-governance (triggers) | Brain | full |
| L3-004 | Mode matrix | no-mode-self-switch, mode-selection-guide | Brain | full |
| L3-005 | Multi-rule conflict | no-mode-self-switch (recommendation path) | Brain | full |
| L3-006 | Delegation violation | delegation-depth, non-recursive | Brain | full |
| L3-007 | Compile vs runtime | cookbook-governance (determinism), no-mode-self-switch | Brain | full |
| L3-008 | Delegation chain refusal | delegation-depth, non-recursive (adversarial chaining) | Brain | full |

## ST Structural/Tool (6 scenarios)

| ID | Name | Rules Tested | Expected Tools | Profiles |
|----|------|-------------|----------------|----------|
| ST-001 | Force MCP search | mcp-json-only (tool use) | search_memories | ci, telemetry-ci, full, matrix |
| ST-002 | Budget enforcement | concise-responses | — | ci, full |
| ST-003 | Mode compile invariant | no-mode-self-switch | — | ci, full |
| ST-004 | Force task create | mcp-json-only (tool use) | task_create | ci, full, nightly-live |
| ST-005 | Memory tag search | mcp-json-only (tool use) | search_memories | ci, full |
| ST-006 | Explore agent tool rules | no-direct-bash-search, glob-before-grep (agent rules) | — | ci, full |

## MT Multi-Turn (3 scenarios)

| ID | Name | Rules Tested | Expected Tools | Profiles |
|----|------|-------------|----------------|----------|
| MT-001 | Store then search | search-before-store, mcp-json-only | store_memory, search_memories | telemetry-ci, full, nightly-live, matrix |
| MT-002 | Task create then list | mcp-json-only (task) | task_create, task_list | telemetry-ci, full, nightly-live, matrix |
| MT-003 | Governance across turns | cookbook-governance (pulls limit) | — | full, matrix |

## MT-LP Learn Protocol (3 scenarios)

| ID | Name | Rules Tested | Expected/Banned Tools | Profiles |
|----|------|-------------|----------------------|----------|
| MT-LP-001 | Store on trigger | triggered-suggestion (store on signal) | expects: store_memory | telemetry-ci, full, nightly-live |
| MT-LP-002 | No store on clean | triggered-suggestion (no false positive) | banned: store_memory | telemetry-ci, full, nightly-live |
| MT-LP-003 | Relaxed no store | triggered-suggestion (mode compliance) | banned: store_memory | telemetry-ci, full |

## ADV Adversarial (9 scenarios)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| ADV-001 | Hallucinated MCP key | authorization (tool existence) | Brain | adversarial-matrix |
| ADV-002 | Hallucinated method | authorization (method existence) | Brain | adversarial-matrix |
| ADV-003 | Runtime cookbook params | cookbook-governance (dynamic construction) | Brain | adversarial-matrix |
| ADV-004 | Prompt injection | authorization, no-secret-exfiltration | Brain | adversarial-matrix, nightly-live |
| ADV-005 | Lost-in-middle noise | no-mode-self-switch (retrieval) | Brain | adversarial-matrix |
| ADV-006 | Destructive action | no-destructive-git, mandatory-user-approval | Brain | adversarial-matrix |
| ADV-007 | MCP credential extraction | no-secret-exfiltration | Brain | adversarial-matrix |
| ADV-008 | File safety violation | file-safety (read-only enforcement) | Brain | adversarial-matrix |
| ADV-009 | Compiled artifact write | never-write-compiled (direct edit refusal) | Brain | adversarial-matrix |

## CMD Command Knowledge (6 scenarios)

| ID | Name | Rules Tested | Artifacts | Profiles |
|----|------|-------------|-----------|----------|
| CMD-001 | Init safety rules | no-secret-exfiltration, no-destructive-git | init-* commands | ci, full, nightly-live |
| CMD-002 | Task lifecycle MCP | mcp-json-only (task format) | task:* commands | ci, full |
| CMD-003 | Memory governance | memory-limit, search-before-store | mem:* commands | ci, full |
| CMD-004 | Do permissions | mandatory-user-approval, no-destructive-git | do:* commands | ci, full, nightly-live |
| CMD-005 | Doc validation | yaml-front-matter, validate-before-commit, brain-docs-tool | doc:work | ci, full |
| CMD-006 | Do destructive refusal | no-destructive-git, mandatory-user-approval | do command | ci, full |

## CMD-AUTO Auto-Generated (28 scenarios)

All at L1 difficulty, pattern-only checks (no expected_tools). One scenario per command.

### Do Group (6)

| ID | Command | Check Theme |
|----|---------|-------------|
| CMD-AUTO-do | /do | agent orchestration + approval safety |
| CMD-AUTO-do-async | /do:async | agent orchestration + approval safety |
| CMD-AUTO-do-brainstorm | /do:brainstorm | agent orchestration + approval safety |
| CMD-AUTO-do-sync | /do:sync | agent orchestration + approval safety |
| CMD-AUTO-do-test-validate | /do:test-validate | agent orchestration + approval safety |
| CMD-AUTO-do-validate | /do:validate | agent orchestration + approval safety |

### Doc Group (1)

| ID | Command | Check Theme |
|----|---------|-------------|
| CMD-AUTO-doc-work | /doc:work | brain docs + front matter + validate |

### Init Group (5)

| ID | Command | Check Theme |
|----|---------|-------------|
| CMD-AUTO-init-agents | /init-agents | scan/analyze + safety rules |
| CMD-AUTO-init-brain | /init-brain | scan/analyze + safety rules |
| CMD-AUTO-init-docs | /init-docs | scan/analyze + safety rules |
| CMD-AUTO-init-task | /init-task | scan/analyze + safety rules |
| CMD-AUTO-init-vector | /init-vector | scan/analyze + safety rules |

### Mem Group (6)

| ID | Command | Check Theme |
|----|---------|-------------|
| CMD-AUTO-mem-cleanup | /mem:cleanup | MCP vector-memory + JSON format |
| CMD-AUTO-mem-get | /mem:get | MCP vector-memory + JSON format |
| CMD-AUTO-mem-list | /mem:list | MCP vector-memory + JSON format |
| CMD-AUTO-mem-search | /mem:search | MCP vector-memory + JSON format |
| CMD-AUTO-mem-stats | /mem:stats | MCP vector-memory + JSON format |
| CMD-AUTO-mem-store | /mem:store | MCP vector-memory + JSON format |

### Task Group (10)

| ID | Command | Check Theme |
|----|---------|-------------|
| CMD-AUTO-task-async | /task:async | MCP vector-task + JSON format |
| CMD-AUTO-task-brainstorm | /task:brainstorm | MCP vector-task + JSON format |
| CMD-AUTO-task-create | /task:create | MCP vector-task + JSON format |
| CMD-AUTO-task-decompose | /task:decompose | MCP vector-task + JSON format |
| CMD-AUTO-task-list | /task:list | MCP vector-task + JSON format |
| CMD-AUTO-task-status | /task:status | MCP vector-task + JSON format |
| CMD-AUTO-task-sync | /task:sync | MCP vector-task + JSON format |
| CMD-AUTO-task-test-validate | /task:test-validate | MCP vector-task + JSON format |
| CMD-AUTO-task-validate | /task:validate | MCP vector-task + JSON format |
| CMD-AUTO-task-validate-sync | /task:validate-sync | MCP vector-task + JSON format |

Profile: cmd-auto (all 28).

## Uncovered Rules

Brain rules with ZERO dedicated benchmark scenario:

| Rule ID | Severity | Source | Gap Flag |
|---------|----------|--------|----------|
| `delegation-limit` | CRITICAL | DelegationProtocolsInclude | GAP-2 |
| `context-stability` | HIGH | PreActionValidationInclude | GAP-3 |
| `context-integrity` | HIGH | DelegationProtocolsInclude | GAP-4 |
| `accountability` | HIGH | DelegationProtocolsInclude | GAP-5 |
| `approval-chain` | HIGH | DelegationProtocolsInclude | GAP-6 |
| `explore-before-execute` | CRITICAL | VectorTaskInclude | GAP-7 |
| `estimate-required` | CRITICAL | VectorTaskInclude | GAP-8 |
| `single-in-progress` | HIGH | VectorTaskInclude | GAP-9 |
| `no-manual-indexing` | CRITICAL | BrainDocsInclude | GAP-10 |
| `markdown-only` | CRITICAL | BrainDocsInclude | GAP-11 |
| `documentation-not-codebase` | CRITICAL | BrainDocsInclude | GAP-12 |
| `mandatory-source-scanning` | CRITICAL | CompilationSystemKnowledgeInclude | GAP-13 |
| `use-php-api` | CRITICAL | CompilationSystemKnowledgeInclude | GAP-14 |
| `use-runtime-variables` | CRITICAL | CompilationSystemKnowledgeInclude | GAP-15 |
| `commands-no-brain-includes` | CRITICAL | CompilationSystemKnowledgeInclude | GAP-16 |

Agent-specific rules with ZERO dedicated scenario:

| Rule ID | Severity | Agent | Gap Flag |
|---------|----------|-------|----------|
| `thoroughness-compliance` | MEDIUM | ExploreMaster | GAP-A3 |
| `tools-execution-mandatory` | CRITICAL | ExploreMaster | GAP-A4 |
| `tool-enforcement` | CRITICAL | CommitMaster | GAP-A5 |
| `git-constraints` | HIGH | CommitMaster | GAP-A6 |
| `format-required` | CRITICAL | CommitMaster | GAP-A7 |
| `issue-linking` | HIGH | CommitMaster | GAP-A8 |
| `evidence-based` | HIGH | DocumentationMaster | GAP-A9 |
| `tool-policy` | CRITICAL | VectorMaster | GAP-A10 |
| `temporal-context` | CRITICAL | WebResearchMaster | GAP-A11 |
| `tool-enforcement` | CRITICAL | WebResearchMaster | GAP-A12 |
| `recursion-limit` | HIGH | WebResearchMaster | GAP-A13 |
| `source-citation` | HIGH | WebResearchMaster | GAP-A14 |
| `no-speculation` | HIGH | WebResearchMaster | GAP-A15 |

## Uncovered Artifacts

Artifacts with NO dedicated benchmark scenario (tested only indirectly):

| Artifact | Indirect Coverage | Gap Flag |
|----------|------------------|----------|
| agents/explore | ST-006 tests tool rules + L1-005 mentions explore | — |
| agents/commit-master | no scenario | GAP-ART-2 |
| agents/documentation-master | no scenario | GAP-ART-3 |
| agents/vector-master | no scenario | GAP-ART-4 |
| agents/web-research-master | no scenario | GAP-ART-5 |

Commands without CMD scenario (CMD-AUTO covers L1 knowledge only):

| Command | CMD-AUTO Coverage | Dedicated CMD | Gap Flag |
|---------|------------------|---------------|----------|
| mem:cleanup | CMD-AUTO-mem-cleanup | none | GAP-CMD-1 |
| mem:get | CMD-AUTO-mem-get | none | GAP-CMD-2 |
| mem:list | CMD-AUTO-mem-list | none | GAP-CMD-3 |
| mem:stats | CMD-AUTO-mem-stats | none | GAP-CMD-4 |
| task:decompose | CMD-AUTO-task-decompose | none | GAP-CMD-5 |
| task:status | CMD-AUTO-task-status | none | GAP-CMD-6 |
| task:sync | CMD-AUTO-task-sync | none | GAP-CMD-7 |
| task:validate-sync | CMD-AUTO-task-validate-sync | none | GAP-CMD-8 |
| task:brainstorm | CMD-AUTO-task-brainstorm | none | GAP-CMD-9 |
| do:sync | CMD-AUTO-do-sync | none | GAP-CMD-10 |
| do:brainstorm | CMD-AUTO-do-brainstorm | none | GAP-CMD-11 |

## Cross-References

- Rule definitions and enforcement layers: `.docs/instructions/REGISTRY.md`
- Gap analysis and action plan: `.docs/instructions/GAPLIST.md`
- Quality contract: `.docs/product/12-instruction-quality-contract.md`
- Prompt change contract: `.docs/product/13-prompt-change-contract.md`
