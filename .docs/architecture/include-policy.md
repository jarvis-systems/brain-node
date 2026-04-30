---
name: "Include Policy"
description: "Taxonomy and design rules for Brain/Agent/Command includes"
type: architecture
date: 2026-03-05
version: "1.0.0"
status: active
---

# Include Policy

Defines the semantic boundaries and valid inclusion chains to prevent duplication, "God-includes", and output bloat.

## Taxonomy Layers

1. **Brain / Universal Includes** (`core/src/Includes/Universal/*`)
   - **Scope:** True globals. Apply to the entire ecosystem (Brain orchestration, ALL agents, safety).
   - **Examples:** `SecretOutputPolicyInclude`, `CompileSafetyInclude`.
   - **Rule:** Commands MUST NOT dynamically include these via traits or manual method calls. They are already injected via Brain Context. Duplicating them bloats command prompts.

2. **Shared-but-not-Universal** (`core/src/Includes/Commands/Shared/*`)
   - **Scope:** Logic shared by multiple agents or commands, but NOT automatically global.
   - **Mechanism:** Must be implemented as explicit `IncludeArchetype` classes, NEVER as PHP Traits executing procedure calls.
   - **Benefit:** Allows compiler deduplication (`#[Includes]`) and maintains readable, deterministic include chains.
   - **Rule:** Includes exist solely in `core/` and `core/src/Variations/`. `node/` contains command and agent gluing only, and must never contain actual include definitions or their abstractions.

3. **Command/Agent Specific** (`node/Commands/*`, `node/Agents/*` -> `core/src/Includes/.../*Include`)
   - **Scope:** Unique logic mapping 1:1 to a specific CLI workflow or Agent capability.
   - **Examples:** `TaskAsyncInclude`, `DocumentationMasterInclude`.
   - **Rule:** May compositionally include Shared includes via `#[Includes(SharedTaskInclude::class)]`.

## Anti-Patterns Addressed
- **No God-Traits:** Replaced `SharedCommandTrait` with explicit `SharedCommandInclude`.
- **No Brain-Leaking in Commands:** Removed manual calls to `$this->defineSecretsPiiProtectionRules()` in command traits because Brain/Universal includes already handle ecosystem-wide security. If commands need specific rules, they must be part of `SharedCommandInclude`.
