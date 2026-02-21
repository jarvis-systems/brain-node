---
name: "Instruction Registry"
description: "Complete artifact-to-includes-to-rules-to-enforcement map for the Brain instruction system"
type: "registry"
date: "2026-02-21"
version: "1.0.0"
status: "active"
---

# Instruction Registry

Single-source-of-truth map connecting compiled artifacts to their include chains, rule IDs, enforcement layers, and instruction budgets.

Re-generate after any include modification or artifact addition.

## Overview

| Metric | Value |
|--------|-------|
| Compiled artifacts | 34 (1 Brain + 5 agents + 28 commands) |
| Source agents | 8 (5 compiled + 3 system-only) |
| Brain rules (iron) | ~35 unique IDs |
| Agent-specific rules | ~25 unique IDs |
| Command trait rules | ~70+ unique IDs |
| Enforcement layers | 5 |
| Instruction budget | 4698 lines (max 5167) |

## Enforcement Layer Definitions

| Layer | ID | Definition | Verification |
|-------|----|-----------|-------------|
| CI-enforced | `CI` | Scripts block merge on violation | Deterministic, automated |
| Tool-enforced | `TOOL` | MCP server rejects invalid operations | Runtime, server-side |
| Compile-time | `COMP` | PHP compiler prunes/includes based on env/mode | Build-time, deterministic |
| Platform-enforced | `PLAT` | OS/filesystem/compile cycle prevents violation | Infrastructure-level |
| Prompt-only | `PROMPT` | LLM behavioral compliance | Probabilistic, benchmark-tested |

## Brain (CLAUDE.md)

### Include Chain

Via `Scrutinizer` variation using `BrainIncludesTrait`:

| # | Include | Namespace | Conditional |
|---|---------|-----------|-------------|
| 1 | `CoreConstraintsInclude` | Brain | always |
| 2 | `VectorMemoryInclude` | Universal | always |
| 3 | `VectorTaskInclude` | Universal | always |
| 4 | `BrainDocsInclude` | Universal | always |
| 5 | `CompilationSystemKnowledgeInclude` | Universal | `isSelfDev()` only |
| 6 | `CoreInclude` | Brain | always |
| 7 | `PreActionValidationInclude` | Brain | always |
| 8 | `DelegationProtocolsInclude` | Brain | claude/opencode only |
| 9 | `ResponseValidationInclude` | Brain | always |
| 10 | `ErrorHandlingInclude` | Brain | always |
| dyn | Quality gate rules | `.env` | per `QUALITY_COMMAND` group |

### Brain Rules

| Rule ID | Severity | Source Include | Enforcement |
|---------|----------|---------------|-------------|
| `quality-gates-mandatory` | CRITICAL | BrainIncludesTrait (dynamic) | `CI` |
| `quality-TEST` | CRITICAL | BrainIncludesTrait (dynamic) | `CI` |
| `quality-PHPSTAN` | CRITICAL | BrainIncludesTrait (dynamic) | `CI` |
| `cookbook-governance` | CRITICAL | VectorMemoryInclude | `PROMPT` |
| `mcp-json-only` | CRITICAL | VectorMemoryInclude + VectorTaskInclude | `TOOL` |
| `multi-probe-mandatory` | CRITICAL | VectorMemoryInclude | `PROMPT` |
| `search-before-store` | HIGH | VectorMemoryInclude | `PROMPT` |
| `triggered-suggestion` | HIGH | VectorMemoryInclude | `PROMPT` |
| `explore-before-execute` | CRITICAL | VectorTaskInclude | `PROMPT` |
| `estimate-required` | CRITICAL | VectorTaskInclude | `PROMPT` |
| `parent-readonly` | CRITICAL | VectorTaskInclude | `TOOL` |
| `timestamps-auto` | CRITICAL | VectorTaskInclude | `TOOL` |
| `single-in-progress` | HIGH | VectorTaskInclude | `PROMPT` |
| `no-mode-self-switch` | CRITICAL | VectorTaskInclude | `COMP` |
| `no-manual-indexing` | CRITICAL | BrainDocsInclude | `PROMPT` |
| `markdown-only` | CRITICAL | BrainDocsInclude | `PROMPT` |
| `documentation-not-codebase` | CRITICAL | BrainDocsInclude | `PROMPT` |
| `code-only-when-cheaper` | HIGH | BrainDocsInclude | `PROMPT` |
| `yaml-front-matter` | CRITICAL | BrainDocsInclude | `CI` |
| `validate-before-commit` | HIGH | BrainDocsInclude | `CI` |
| `mandatory-source-scanning` | CRITICAL | CompilationSystemKnowledgeInclude | `PROMPT` |
| `never-write-compiled` | CRITICAL | CompilationSystemKnowledgeInclude | `PLAT` |
| `use-php-api` | CRITICAL | CompilationSystemKnowledgeInclude | `PROMPT` |
| `use-runtime-variables` | CRITICAL | CompilationSystemKnowledgeInclude | `PROMPT` |
| `commands-no-brain-includes` | CRITICAL | CompilationSystemKnowledgeInclude | `PROMPT` |
| `memory-limit` | MEDIUM | CoreInclude (Brain) | `PROMPT` |
| `file-safety` | CRITICAL | CoreInclude (Brain) | `PROMPT` |
| `quality-gate` | HIGH | CoreInclude (Brain) | `PROMPT` |
| `concise-responses` | HIGH | CoreInclude (Brain) | `PROMPT` |
| `context-stability` | HIGH | PreActionValidationInclude | `PROMPT` |
| `authorization` | CRITICAL | PreActionValidationInclude | `PROMPT` |
| `delegation-depth` | HIGH | PreActionValidationInclude | `PROMPT` |
| `delegation-limit` | CRITICAL | DelegationProtocolsInclude | `PROMPT` |
| `approval-chain` | HIGH | DelegationProtocolsInclude | `PROMPT` |
| `context-integrity` | HIGH | DelegationProtocolsInclude | `PROMPT` |
| `non-recursive` | CRITICAL | DelegationProtocolsInclude | `PROMPT` |
| `accountability` | HIGH | DelegationProtocolsInclude | `PROMPT` |

### Brain Guidelines

| Guideline ID | Source Include |
|-------------|---------------|
| `constraint-token-limit` | CoreConstraintsInclude |
| `constraint-execution-time` | CoreConstraintsInclude |
| `cookbook-preset` | VectorMemoryInclude + VectorTaskInclude |
| `cookbook-first` | VectorMemoryInclude + VectorTaskInclude |
| `cookbook-constraints` | VectorMemoryInclude |
| `gate5-satisfied` | VectorMemoryInclude |
| `mode-selection-guide` | VectorTaskInclude |
| `brain-docs-tool` | BrainDocsInclude |
| `scanning-workflow` | CompilationSystemKnowledgeInclude |
| `compilation-flow` | CompilationSystemKnowledgeInclude |
| `directories` | CompilationSystemKnowledgeInclude |
| `directive` | CompilationSystemKnowledgeInclude + CoreInclude |
| `namespaces-*` (8 IDs) | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `var-*` (5 IDs) | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `api-*` (8 IDs) | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `structure-*` (4 IDs) | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `builder-*` (3 IDs) | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `cli-workflow` | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `cli-debug` | CompilationSystemKnowledgeInclude (deep/exhaustive) |
| `operating-model` | CoreInclude (Brain) |
| `workflow` | CoreInclude (Brain) |
| `rule-interpretation` | CoreInclude (Brain) |
| `cli-commands` | CoreInclude (Brain) |
| `validation-workflow` | PreActionValidationInclude |
| `exploration-delegation` | DelegationProtocolsInclude |
| `level-*` (4 IDs) | DelegationProtocolsInclude (deep/exhaustive) |
| `type-*` (3 IDs) | DelegationProtocolsInclude (deep/exhaustive) |
| `validation-delegation` | DelegationProtocolsInclude (deep/exhaustive) |
| `fallback-delegation` | DelegationProtocolsInclude (deep/exhaustive) |
| `workflow-*` (5 IDs) | DelegationProtocolsInclude (deep/exhaustive) |
| `validation-semantic` | ResponseValidationInclude (deep/exhaustive) |
| `escalation-policy` | ErrorHandlingInclude |
| `error-*` (5 IDs) | ErrorHandlingInclude (deep/exhaustive) |

## Agents

### Agent Base Include Chain

Via `Master` variation using `AgentIncludesTrait`:

| # | Include | Namespace | Conditional |
|---|---------|-----------|-------------|
| 1 | `VectorMemoryInclude` | Universal | always |
| 2 | `VectorTaskInclude` | Universal | `$taskUsage=true` (Master) / `false` (SystemMaster) |
| 3 | `BrainDocsInclude` | Universal | always |
| 4 | `SequentialReasoningInclude` | Universal | always |
| 5 | `CoreInclude` | Agent | always |
| 6 | `DocumentationFirstInclude` | Agent | always |
| 7 | `LaravelBoostGuidelinesInclude` | Universal | `HAS_LARAVEL` env |
| 8 | `LaravelBoostClassToolsInclude` | Universal | `HAS_LARAVEL` env |

SystemMaster adds (on top of Master, with `$taskUsage=false`):

| # | Include | Namespace |
|---|---------|-----------|
| 9 | `LifecycleInclude` | Agent |
| 10 | `CompilationSystemKnowledgeInclude` | Universal |
| 11 | `BrainScriptsInclude` | Universal |
| 12 | `WebBasicResearchInclude` | Agent |

### Agent Base Rules (all agents receive)

| Rule ID | Severity | Source Include |
|---------|----------|---------------|
| `identity-uniqueness` | HIGH | Agent CoreInclude |
| `temporal-check` | HIGH | Agent CoreInclude |
| `concise-agent-responses` | HIGH | Agent CoreInclude |
| `docs-is-canonical-source` | CRITICAL | DocumentationFirstInclude |
| `docs-before-action` | CRITICAL | DocumentationFirstInclude |
| `docs-before-web-research` | HIGH | DocumentationFirstInclude |

Plus all rules from VectorMemoryInclude, VectorTaskInclude (Master only), BrainDocsInclude.

### Per-Agent Specifics

#### ExploreMaster (compiled: `agents/explore`)

- **Base**: Master | **Model**: haiku | **Budget**: 347 lines
- **Specific include**: `ExploreMasterInclude`

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `glob-before-grep` | HIGH | `PROMPT` |
| `no-direct-bash-search` | CRITICAL | `PROMPT` |
| `thoroughness-compliance` | MEDIUM | `PROMPT` |
| `tools-execution-mandatory` | CRITICAL | `PROMPT` |

#### CommitMaster (compiled: `agents/commit-master`)

- **Base**: Master | **Model**: sonnet | **Budget**: 339 lines
- **Specific includes**: `CommitMasterInclude` (sub: `GitConventionalCommitsInclude`)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `tool-enforcement` | CRITICAL | `PROMPT` |
| `git-constraints` | HIGH | `PROMPT` |
| `format-required` | CRITICAL | `PROMPT` |
| `issue-linking` | HIGH | `PROMPT` |

#### DocumentationMaster (compiled: `agents/documentation-master`)

- **Base**: Master | **Model**: haiku | **Budget**: 306 lines
- **Specific includes**: `DocumentationMasterInclude` (sub: `WebBasicResearchInclude`)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `evidence-based` | HIGH | `PROMPT` |

#### WebResearchMaster (compiled: `agents/web-research-master`)

- **Base**: Master | **Model**: sonnet | **Budget**: 373 lines
- **Specific includes**: `WebResearchMasterInclude` (sub: `WebRecursiveResearchInclude`)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `temporal-context` | CRITICAL | `PROMPT` |
| `tool-enforcement` | CRITICAL | `PROMPT` |
| `recursion-limit` | HIGH | `PROMPT` |
| `source-citation` | HIGH | `PROMPT` |
| `no-speculation` | HIGH | `PROMPT` |

#### VectorMaster (compiled: `agents/vector-master`)

- **Base**: Master | **Model**: sonnet | **Budget**: 276 lines
- **Specific include**: `VectorMasterInclude`

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `tool-policy` | CRITICAL | `PROMPT` |

#### AgentMaster (not compiled — SystemMaster, no budget)

- **Base**: SystemMaster | **Model**: sonnet
- **Specific include**: `AgentMasterInclude`

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `temporal-context-first` | HIGH | `PROMPT` |
| `no-duplicate-domains` | HIGH | `PROMPT` |
| `include-chain-validation` | HIGH | `PROMPT` |

#### PromptMaster (not compiled — SystemMaster, no budget)

- **Base**: SystemMaster | **Model**: sonnet
- **Specific include**: `PromptMasterInclude`

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `no-placeholders` | CRITICAL | `PROMPT` |
| `token-efficiency` | HIGH | `PROMPT` |
| `compile-verify` | CRITICAL | `PROMPT` |
| `memory-storage` | HIGH | `PROMPT` |

#### ScriptMaster (not compiled — SystemMaster, no budget)

- **Base**: SystemMaster | **Model**: sonnet
- **Specific include**: `ScriptMasterInclude`

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `laravel-12-features` | HIGH | `PROMPT` |
| `memory-storage-mandatory` | HIGH | `PROMPT` |

## Commands

### Trait Hierarchy

```
InputCaptureTrait (3 base vars: RAW_INPUT, HAS_AUTO_APPROVE, CLEAN_ARGS)
    |
SharedCommandTrait (~30 rules, tag taxonomy, universal safety)
    |                    |
TaskCommandCommonTrait   DoCommandCommonTrait
(~40 rules, lifecycle)   (~18 rules, do workflow)
```

### Command Groups

#### Task Commands (10) — TaskCommandCommonTrait

| Command ID | Specific Include |
|------------|-----------------|
| `task:async` | TaskAsyncInclude |
| `task:sync` | TaskSyncInclude |
| `task:validate` | TaskValidateInclude |
| `task:validate-sync` | TaskValidateSyncInclude |
| `task:test-validate` | TaskTestValidateInclude |
| `task:create` | TaskCreateInclude |
| `task:decompose` | TaskDecomposeInclude |
| `task:list` | TaskListInclude |
| `task:status` | TaskStatusInclude |
| `task:brainstorm` | TaskBrainstormInclude |

#### Do Subcommands (5) — DoCommandCommonTrait

| Command ID | Specific Include |
|------------|-----------------|
| `do:async` | DoAsyncInclude |
| `do:sync` | DoSyncInclude |
| `do:validate` | DoValidateInclude |
| `do:test-validate` | DoTestValidateInclude |
| `do:brainstorm` | DoBrainstormInclude |

#### DoCommand Root (1) — standalone, ModeResolverTrait only

| Command ID | Specific Include |
|------------|-----------------|
| `do` | none (all rules inline) |

#### Mem Commands (6) — no traits

| Command ID | Specific Include |
|------------|-----------------|
| `mem:search` | MemSearchInclude |
| `mem:get` | MemGetInclude |
| `mem:list` | MemListInclude |
| `mem:store` | MemStoreInclude |
| `mem:stats` | MemStatsInclude |
| `mem:cleanup` | MemCleanupInclude |

#### Init Commands (4) — TaskCommandCommonTrait

| Command ID | Specific Include |
|------------|-----------------|
| `init-task` | InitTaskInclude |
| `init-agents` | InitAgentsInclude |
| `init-brain` | InitBrainInclude |
| `init-vector` | InitVectorInclude |

#### Doc Command (1) — TaskCommandCommonTrait

| Command ID | Specific Include |
|------------|-----------------|
| `doc:work` | DocWorkInclude |

#### Init Docs (1) — TaskCommandCommonTrait

| Command ID | Specific Include |
|------------|-----------------|
| `init-docs` | InitDocsInclude |

### SharedCommandTrait Rules (all commands except mem:* and standalone do)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `task-tags-predefined-only` | CRITICAL | `PROMPT` |
| `mandatory-level-tags` | CRITICAL | `PROMPT` |
| `batch-trivial-grouping` | HIGH | `PROMPT` |
| `docs-are-law` | CRITICAL | `PROMPT` |
| `no-phantom-options` | CRITICAL | `PROMPT` |
| `partial-work-continue` | CRITICAL | `PROMPT` |
| `docs-over-existing-code` | HIGH | `PROMPT` |
| `context-priority-chain` | HIGH | `PROMPT` |
| `aggressive-docs-search` | CRITICAL | `PROMPT` |
| `no-secret-exfiltration` | CRITICAL | `PROMPT` |
| `no-secrets-in-storage` | CRITICAL | `PROMPT` |
| `failure-history-mandatory` | CRITICAL | `PROMPT` |
| `sibling-task-check` | HIGH | `PROMPT` |
| `failure-policy-tool-error` | CRITICAL | `PROMPT` |
| `failure-policy-missing-docs` | HIGH | `PROMPT` |
| `failure-policy-ambiguous-spec` | HIGH | `PROMPT` |
| `no-destructive-git` | CRITICAL | `PROMPT` |
| `no-destructive-git-in-agents` | CRITICAL | `PROMPT` |
| `memory-folder-sacred` | CRITICAL | `PROMPT` |
| `auto-approve-mode` | CRITICAL | `PROMPT` |
| `interactive-mode` | HIGH | `PROMPT` |
| `workflow-atomicity` | CRITICAL | `PROMPT` |
| `mandatory-user-approval` | CRITICAL | `PROMPT` |
| `codebase-pattern-reuse` | CRITICAL | `PROMPT` |
| `impact-radius-analysis` | CRITICAL | `PROMPT` |
| `logic-edge-case-verification` | HIGH | `PROMPT` |
| `performance-awareness` | HIGH | `PROMPT` |
| `code-hallucination-prevention` | CRITICAL | `PROMPT` |
| `cleanup-after-changes` | MEDIUM | `PROMPT` |
| `test-coverage-during-execution` | CRITICAL | `PROMPT` |
| `docs-during-execution` | HIGH | `PROMPT` |
| `safety-escalation-non-overridable` | CRITICAL | `PROMPT` |

### TaskCommandCommonTrait Rules (task:*, init-*, doc:work, init-docs)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `status-semantics` | CRITICAL | `PROMPT` |
| `no-hallucination` | CRITICAL | `PROMPT` |
| `no-verbose` | CRITICAL | `PROMPT` |
| `guaranteed-finalization` | CRITICAL | `PROMPT` |
| `no-manual-agent-fallback` | CRITICAL | `PROMPT` |
| `stuck-pattern-detection` | HIGH | `PROMPT` |
| `stuck-research-escalation` | HIGH | `PROMPT` |
| `one-task-per-cycle` | CRITICAL | `PROMPT` |
| `machine-readable-progress` | HIGH | `PROMPT` |
| `next-step-lifecycle` | CRITICAL | `PROMPT` |
| `retry-circuit-breaker` | CRITICAL | `PROMPT` |
| `docs-are-complete-spec` | CRITICAL | `PROMPT` |
| `task-scope-only` | CRITICAL | `PROMPT` |
| `task-complete` | CRITICAL | `PROMPT` |
| `no-garbage` | CRITICAL | `PROMPT` |
| `cosmetic-inline` | CRITICAL | `PROMPT` |
| `functional-to-task` | CRITICAL | `PROMPT` |
| `test-coverage` | HIGH | `PROMPT` |
| `slow-test-detection` | HIGH | `PROMPT` |
| `no-repeat-failures` | CRITICAL | `PROMPT` |
| `fix-task-blocks-validated` | CRITICAL | `PROMPT` |
| `revalidation-mandatory` | CRITICAL | `PROMPT` |
| `aggregation-only-path` | HIGH | `PROMPT` |
| `collateral-failure-detection` | HIGH | `PROMPT` |
| `parent-id-mandatory` | CRITICAL | `PROMPT` |
| `vector-task-id-required` | CRITICAL | `PROMPT` |
| `comment-context-mandatory` | CRITICAL | `PROMPT` |
| `parallel-isolation-mandatory` | CRITICAL | `PROMPT` |
| `parallel-file-manifest` | CRITICAL | `PROMPT` |
| `parallel-conservative-default` | HIGH | `PROMPT` |
| `parallel-transitive-deps` | HIGH | `PROMPT` |
| `parallel-execution-awareness` | CRITICAL | `PROMPT` |
| `parallel-strict-scope` | CRITICAL | `PROMPT` |
| `parallel-shared-files-forbidden` | HIGH | `PROMPT` |
| `parallel-scope-in-comment` | CRITICAL | `PROMPT` |
| `parallel-status-interpretation` | HIGH | `PROMPT` |
| `validator-parallel-cosmetic-defer` | HIGH | `PROMPT` |
| `scoped-git-checkpoint` | CRITICAL | `PROMPT` |
| `test-scoping` | CRITICAL | `PROMPT` |

### DoCommandCommonTrait Rules (do:*, do subcommands)

| Rule ID | Severity | Enforcement |
|---------|----------|-------------|
| `entry-point-blocking` | CRITICAL | `PROMPT` |
| `zero-distractions` | CRITICAL | `PROMPT` |
| `vector-memory-mandatory` | HIGH | `PROMPT` |
| `scope-escalation` | CRITICAL | `PROMPT` |
| `do-circuit-breaker` | CRITICAL | `PROMPT` |
| `do-failure-awareness` | CRITICAL | `PROMPT` |
| `do-machine-readable-progress` | HIGH | `PROMPT` |
| `text-description-required` | CRITICAL | `PROMPT` |
| `parallel-agent-orchestration` | HIGH | `PROMPT` |
| `idempotent-validation` | HIGH | `PROMPT` |
| `validation-only-no-execution` | CRITICAL | `PROMPT` |
| `no-direct-fixes` | CRITICAL | `PROMPT` |
| `test-validation-only` | CRITICAL | `PROMPT` |
| `phase-sequence-strict` | CRITICAL | `PROMPT` |
| `no-phase-skip` | CRITICAL | `PROMPT` |
| `phase-completion-marker` | HIGH | `PROMPT` |
| `no-parallel-phases` | CRITICAL | `PROMPT` |
| `output-status-report` | HIGH | `PROMPT` |

### Init Command Safety Rules (CI-enforced)

The `check-instruction-budget.sh` script verifies that init-* command artifacts contain these safety rules:

| Rule | Applies To | Enforcement |
|------|-----------|-------------|
| `No-hallucination` | init-* | `CI` |
| `No-secret-exfiltration` | init-* | `CI` |
| `No-secrets-in-storage` | init-* | `CI` |
| `No-destructive-git` | init-* | `CI` |

## Budget Summary

From `instruction-budgets.json` (threshold: 10%):

| Category | Baseline | Max Lines |
|----------|----------|-----------|
| commands_total | 2362 | 2598 |
| agents_total | 1641 | 1805 |
| brain_total | 695 | 764 |
| **grand_total** | **4698** | **5167** |

Per-artifact breakdown:

| Artifact | Lines |
|----------|-------|
| brain/CLAUDE | 695 |
| agents/explore | 347 |
| agents/web-research-master | 373 |
| agents/commit-master | 339 |
| agents/documentation-master | 306 |
| agents/vector-master | 276 |
| commands/init-brain | 647 |
| commands/init-agents | 418 |
| commands/init-task | 413 |
| commands/do | 328 |
| commands/init-docs | 288 |
| commands/init-vector | 268 |

Note: Only 6 commands tracked individually (init-* + do). Other 22 commands contribute to `commands_total` aggregate but lack individual baselines. System agents (AgentMaster, PromptMaster, ScriptMaster) are not compiled and have no budget.

## Enforcement Summary

| Enforcement | Rule Count | Examples |
|-------------|-----------|---------|
| CI-enforced | 7 | quality-TEST, quality-PHPSTAN, yaml-front-matter, validate-before-commit, init safety rules |
| Tool-enforced | 3 | mcp-json-only, parent-readonly, timestamps-auto |
| Compile-time | 1 | no-mode-self-switch (mode gating) |
| Platform-enforced | 1 | never-write-compiled (overwritten on compile) |
| Prompt-only | ~120+ | All remaining behavioral rules |

## Cross-References

- Quality contract: `.docs/product/12-instruction-quality-contract.md`
- Prompt change contract: `.docs/product/13-prompt-change-contract.md`
- Instruction budgets: `.docs/benchmarks/baselines/instruction-budgets.json`
- Benchmark baselines: `.docs/benchmarks/baselines/baselines.json`
- Coverage matrix: `.docs/instructions/COVERAGE.md`
- Gap list: `.docs/instructions/GAPLIST.md`
