---
name: "Enterprise Prompt Architecture — Changed Files"
description: "Detailed diff of files changed during enterprise prompt architecture audit"
date: "2026-02-20"
---

# Enterprise Prompt Architecture — Changed Files

## Phase 1: Deep-Cognitive Gating (3 files in `core/`)

### core/src/Includes/Brain/DelegationProtocolsInclude.php
- Added `use ModeResolverTrait;`
- Wrapped 14 guidelines in `if ($this->isDeepCognitive()) { ... }`
- Always-on: 5 iron rules + `exploration-delegation` guideline
- Deep-only: `level-*`, `type-*`, `workflow-*`, `validation-delegation`, `fallback-delegation`

### core/src/Includes/Brain/ResponseValidationInclude.php
- Added `use ModeResolverTrait;`
- Early return: `if (!$this->isDeepCognitive()) { return; }`
- Always-on: nothing (CoreInclude quality-gate covers compact version)
- Deep-only: all 4 validation guidelines

### core/src/Includes/Brain/ErrorHandlingInclude.php
- Added `use ModeResolverTrait;`
- Wrapped 5 error guidelines in `if ($this->isDeepCognitive()) { ... }`
- Always-on: `escalation-policy` guideline
- Deep-only: 5 error playbooks

## Phase 1b: Sequential Reasoning Gating (1 file in `core/`)

### core/src/Includes/Universal/SequentialReasoningInclude.php
- Added `use ModeResolverTrait;`
- Reordered: `phase-flow` moved first (always-on)
- Wrapped `phase-analysis`, `phase-inference`, `phase-evaluation`, `phase-decision` in `if ($this->isDeepCognitive()) { ... }`
- Impact: active agents × 32 lines saved in standard

## Cookbook Governance Policy (2 files in `core/`)

### core/src/Includes/Universal/VectorTaskInclude.php
- Added `cookbook-governance` CRITICAL rule (presets + onViolation only)
- Added `cookbook-constraints` guideline (precedence, no-recursion, budget-cap, negative triggers)
- Added `gate5-satisfied` guideline (Gate 5 reinterpretation)

### core/src/Includes/Universal/VectorMemoryInclude.php
- Identical policy to VectorTaskInclude

## Infrastructure (main repo)

### scripts/verify-compile-metrics.sh
- Created: 9 checks (line counts + gating + always-on) for both modes
- Extended: +6 cookbook governance checks (uncertainty triggers, governance rule, gate5)

### .github/workflows/brain-lint.yml
- Added `AGENTS.md` + `agent-schema.json` to path triggers and compile discipline check

### .docs/migration/enterprise-readiness.md
- Added cookbook poisoning residual risk
- Added cookbook governance invariant (#13)
- Added speculative pulls mitigated vector
- Updated benchmark metrics
