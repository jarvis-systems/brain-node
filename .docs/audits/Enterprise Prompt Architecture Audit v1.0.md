---
name: "Enterprise Prompt Architecture Audit v1.0"
description: "Comprehensive audit of Brain's prompt architecture against research findings and best practices in prompt engineering. Identifies actionable optimizations to reduce token bloat while maintaining safety and performance."
---
# Enterprise Prompt Architecture Audit v1.0

1. Deep Research Digest

deep-research-report.md — 409 рядків, незалежний enterprise-аудит prompt engineering та
cookbook-підходу. Ключові claims:

- Stable truths (підтверджені дослідженнями + інцидентами):
    - Prompt injection — системний ризик, не "баг у промпті". 1% ASR = meaningful risk
      (Anthropic)
    - "Trusted instructions vs untrusted tokens" — базова інваріанта будь-якої системи
    - Інженерні обмеження > великі промпти для керованості (OWASP, NIST)
    - Schema-enforced structured outputs — один з небагатьох "жорстких" важелів
    - "Lost in the middle" — довгий контекст деградує якість (Liu et al.)
    - Cognitive overload = шлях до jailbreak (NAACL 2024)
    - "Навчити слухняності тільки текстом" = security theater (Instruction Hierarchy
      paper)
    - Evals + regression testing — механізм виживання в production
- Context-dependent (залежать від архітектури):
    - Cookbook як "керований retrieval" — сенс є, АЛЕ стає attack surface (RAG poisoning)
    - Тригери мають бути детерміновані, модельна класифікація — лише допоміжний шар
    - Негативні тригери ("коли НЕ витягувати") — критично для context budget
    - Recipe structure з tests/evals/guardrails — повна YAML-структура
- Speculative (для Brain поки зайве):
    - Runtime monitoring/observability (Brain — compiler, не runtime service)
    - Canary rollout / A/B testing recipes
    - External red teaming як процес

ContextLengthProblem.md — діалог Doc↔GPT. Ключові принципи:
- Контекст = дорога оренда RAM, не безкоштовна пам'ять
- Sub-agent quarantine для великих файлів (runtime ідея)
- "Protocol for protocol's sake" ризик у deep/exhaustive
- Budget signals (green/yellow/red) — runtime, не compile-time
- Prefix stability для KV-cache — вже вирішено deterministic compilation

  ---
2. Fit Decision Table
   #: 1
   Claim/Recommendation: Schema-enforced outputs
   Verdict: KEEP
   Reason: Already done: callValidatedJson + McpSchemaValidator
   Risk if adopted: None — already shipped
   Benefit: 100% schema coverage on compiled calls
   ────────────────────────────────────────
   #: 2
   Claim/Recommendation: "Trusted vs untrusted" trust model
   Verdict: KEEP
   Reason: Brain's compile-time approach inherently separates trusted instructions from
   runtime data
   Risk if adopted: None
   Benefit: Core invariant already in place
   ────────────────────────────────────────
   #: 3
   Claim/Recommendation: Deterministic compilation (no mode leakage)
   Verdict: KEEP
   Reason: Single-mode policy + ksortRecursive() + zero leakage proven
   Risk if adopted: None
   Benefit: Prefix stability, no cognitive overload
   ────────────────────────────────────────
   #: 4
   Claim/Recommendation: Cookbook as compile-time preset
   Verdict: KEEP
   Reason: getCookbookPreset() baked at compile time, not model-chosen
   Risk if adopted: None
   Benefit: Controlled pull, no runtime drift
   ────────────────────────────────────────
   #: 5
   Claim/Recommendation: onViolation as retrieval trigger
   Verdict: KEEP
   Reason: Already implemented: specific MCP calls on rule violations
   Risk if adopted: None
   Benefit: Targeted adaptive retrieval
   ────────────────────────────────────────
   #: 6
   Claim/Recommendation: Mode-gating reference sections
   Verdict: ADAPT
   Reason: Only 3/35 includes use isDeepCognitive(). Extend to Brain includes
   Risk if adopted: Low (may lose context in standard mode)
   Benefit: ~150-200 lines savings in standard CLAUDE.md
   ────────────────────────────────────────
   #: 7
   Claim/Recommendation: Negative triggers ("when NOT to include")
   Verdict: ADAPT
   Reason: No explicit negative triggers in current includes. Add gating conditions
   Risk if adopted: Low
   Benefit: Prevents "protocol for protocol's sake"
   ────────────────────────────────────────
   #: 8
   Claim/Recommendation: Instruction Budget per include
   Verdict: ADAPT
   Reason: No hard limit today. Add as guideline + measure in benchmark
   Risk if adopted: Medium (arbitrary limit may cut useful content)
   Benefit: Prevents unbounded include growth
   ────────────────────────────────────────
   #: 9
   Claim/Recommendation: Full YAML recipe structure (tests/evals/guardrails)
   Verdict: REJECT
   Reason: Over-engineering for compile-time system. Brain generates instructions, doesn't

    serve runtime requests
Risk if adopted: High (massive complexity for no real gain)
Benefit: None for current scope
────────────────────────────────────────
#: 10
Claim/Recommendation: Runtime monitoring/observability
Verdict: REJECT
Reason: Brain is a compiler. Observability belongs to CLI clients, not instruction
compiler
Risk if adopted: Architecture mismatch
Benefit: None for current scope
────────────────────────────────────────
#: 11
Claim/Recommendation: "Move all references to BrainDocs"
Verdict: REJECT
Reason: Forces tool calls during code generation. isDeepCognitive() gating already
eliminates them in standard
Risk if adopted: Increased latency in deep mode
Benefit: Marginal at best (already gated)
────────────────────────────────────────
#: 12
Claim/Recommendation: Sub-agent quarantine for files
Verdict: REJECT (for includes)
Reason: Runtime pattern. Belongs in agent instructions, not compile-time architecture
Risk if adopted: Architecture confusion
Benefit: None for includes
────────────────────────────────────────
#: 13
Claim/Recommendation: Budget signals (green/yellow/red)
Verdict: REJECT
Reason: Runtime orchestration concern, not compile-time
Risk if adopted: Architecture confusion
Benefit: None for Brain compiler
────────────────────────────────────────
#: 14
Claim/Recommendation: Eval datasets as CI gate
Verdict: ADAPT
Reason: Lightweight: compile both modes + size comparison + lint + grep patterns
Risk if adopted: Medium (maintaining eval dataset)
Benefit: Regression control for prompt changes
────────────────────────────────────────
#: 15
Claim/Recommendation: Cookbook cases for Brain delegation patterns
Verdict: REJECT
Reason: Cookbook is MCP-side (vector-memory/task). Brain orchestration ≠ MCP tool usage
Risk if adopted: Architectural violation
Benefit: None (wrong abstraction layer)
  ---
3. Holivar Items + Verdicts

Holivar 1: "Cookbook as dynamic escalator" vs "Cookbook only via onViolation"

For dynamic escalator: Deep research says proactive cookbook pulls reduce
hallucinations. The compile-time preset pattern (cookbook-preset guideline) already
does a limited form of this. Some rules genuinely benefit from a "pull before act"
pattern.

Against: ContextLengthProblem explicitly warns about "protocol for protocol's sake".
Each cookbook pull adds tokens. If model can decide "I'm uncertain, let me pull more" —
that's the runtime-chosen pattern we forbid (invariant #5 from NON-NEGOTIABLE).

Verdict: KEEP CURRENT HYBRID. Compile-time presets (controlled) + onViolation
(targeted) = correct. Ban any "read more when uncertain" directives. Current
architecture already has the right balance. cookbook-first directive exists only in
strict/paranoid — це правильно.

Holivar 2: "Move reference sections to BrainDocs" vs "Gate in include"

For BrainDocs: 0 tokens unless explicitly requested. BrainDocs tool already exists.
Reference sections (namespaces, API, builders) are needed only during code generation.

Against: BrainDocs requires tool call (latency + tool-call tokens). In deep/exhaustive,
having reference in-context avoids round-trips during complex code generation.
CompilationSystemKnowledgeInclude already gates with isDeepCognitive() — standard mode
already pays 0 tokens.

Verdict: KEEP GATING IN INCLUDE. Standard/minimal = 0 reference tokens (already).
Deep/exhaustive = reference in-context (avoids tool call overhead during complex
generation). Moving to BrainDocs would save nothing in standard (already absent) and
add latency in deep. Current approach is optimal.

Holivar 3: "Unify SYNC/ASYNC flows" vs "Keep both but de-duplicate core"

For unification: Less surface area, fewer bugs, simpler maintenance.

Against: SYNC (Brain executes directly) and ASYNC (Brain delegates to sub-agent) are
genuinely different execution models with different constraints, validation, and error
handling. Forcing them together = artificial abstraction.

Verdict: KEEP BOTH. SharedCommandTrait (906 lines) is already the de-duplication layer.
SYNC and ASYNC commands share rules via trait, diverge in execution. The question is
not "merge them" but "is SharedCommandTrait itself too bloated?" — and that's a Phase 2
item, not a structural change.

  ---
4. Next 3 Includes to Audit (ranked by ROI)

Current state: CLAUDE.md standard/standard = 489 lines, paranoid/exhaustive = 731 lines

Only 3 of 35 includes use ModeResolverTrait. The remaining 32 compile identically
regardless of mode. This is the primary optimization opportunity.

  ---
#1: DelegationProtocolsInclude.php (Brain, ~154 lines)

1) Purpose: Framework governing task delegation, authority transfer, and responsibility
   flow among Brain and Agents.

2) Current risk signals:
- Token bloat: HIGH. 5 rules + 14 guidelines, many with verbose multi-step descriptions
- Redundancy: Workflow phases duplicate concepts already in CoreInclude (operating
  model + workflow)
- Mode leakage potential: ZERO (no mode references)
- Ambiguous directives: Level descriptions (brain/architect/specialist/tool) are
  reference material rarely needed at runtime

3) What can be moved to Cookbook cases:
- NOTHING. Delegation protocols are Brain-internal orchestration logic, not MCP tool
  patterns. Cookbook = vector-memory/vector-task MCP. Wrong abstraction layer.

4) What should be gated by isDeepCognitive():
- Level descriptions (4 guidelines: level-brain, level-architect, level-specialist,
  level-tool) — ~30 lines
- Type descriptions (3 guidelines: type-task, type-analysis, type-validation) — ~18
  lines
- Workflow phase details (5 guidelines: workflow-request-analysis through
  workflow-knowledge-storage) — ~40 lines
- Fallback/validation delegation details — ~15 lines
- Total gatable: ~103 lines (~67% of include)

5) What must remain always-on ("must-know"):
- CRITICAL rules: delegation-limit, non-recursive — model must ALWAYS know these
- HIGH rules: approval-chain, context-integrity, accountability
- exploration-delegation guideline (Brain must never execute Glob/Grep directly)
- ~51 lines

6) Proposed diff plan:
- Step 1: Add use ModeResolverTrait to class
- Step 2: Wrap level descriptions in if ($this->isDeepCognitive())
- Step 3: Wrap type descriptions in same gate
- Step 4: Wrap workflow phase details in same gate
- Step 5: Keep all 5 rules + exploration-delegation ungated

7) Verification:
- STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile → verify
  level/type/workflow absent
- STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile → verify all present
- wc -l .claude/CLAUDE.md both modes → expect ~100 line difference
- bash scripts/lint-mcp-syntax.sh → pass
- grep -c "level-brain\|level-architect\|type-task\|workflow-request" .claude/CLAUDE.md
  → 0 for standard

  ---
#2: ErrorHandlingInclude.php + ResponseValidationInclude.php (Brain, combined ~108
lines)

1) Purpose:
- ErrorHandling: Basic error handling for Brain delegation operations (6 error
  patterns)
- ResponseValidation: Agent response validation protocol (semantic, structural, policy
  checks)

2) Current risk signals:
- Token bloat: MEDIUM. 108 lines of procedural descriptions always in CLAUDE.md
- Redundancy: ErrorHandling duplicates general error recovery concepts.
  ResponseValidation describes thresholds (cosine similarity ≥ 0.9/0.75) that Brain
  cannot actually compute
- Mode leakage potential: ZERO
- Ambiguous directives: Cosine similarity thresholds are aspirational, not enforceable
  by prompt

3) What can be moved to Cookbook:
- NOTHING. Same reasoning as #1 — Brain orchestration ≠ MCP patterns.

4) What should be gated by isDeepCognitive():
- ErrorHandling: ALL 6 guidelines (error scenarios are reference, not always-needed) —
  ~55 lines
- ResponseValidation: Detailed thresholds and action tables — ~35 lines
- Total gatable: ~90 lines

5) What must remain always-on:
- ErrorHandling: ZERO rules, but add 1 summary guideline (3-4 lines): "On delegation
  failure: retry once → escalate to AgentMaster → restore context"
- ResponseValidation: Purpose description only (1-2 lines)
- ~18 lines total

6) Proposed diff plan:
- Step 1: Add use ModeResolverTrait to both classes
- Step 2: Wrap all ErrorHandling guidelines in if ($this->isDeepCognitive())
- Step 3: Add compact always-on summary guideline for ErrorHandling
- Step 4: Wrap ResponseValidation details in if ($this->isDeepCognitive())
- Step 5: Keep Purpose description as always-on

7) Verification:
- Same compile-both-modes pattern as #1
- grep -c "error-delegation\|error-agent-timeout\|validation-semantic"
  .claude/CLAUDE.md → 0 for standard
- wc -l comparison → expect ~90 line difference

  ---
#3: CoreInclude.php (Brain, ~87 lines)

1) Purpose: Brain ecosystem coordination — operating model, workflow, directive, rules,
   style/response/determinism.

2) Current risk signals:
- Token bloat: MEDIUM. style()/response()/determinism() builders generate verbose XML
  blocks
- Redundancy: workflow guideline has 5 phases that overlap with DelegationProtocols
  workflow phases
- Mode leakage potential: ZERO
- Ambiguous directives: rule-interpretation guideline is philosophical ("interpret by
  SPIRIT not LETTER")

3) What can be moved to Cookbook:
- NOTHING (Brain identity, wrong layer for cookbook).

4) What should be gated by isDeepCognitive():
- Workflow phase details (workflow guideline with step descriptions) — ~12 lines
- rule-interpretation guideline — ~6 lines
- Detailed constraint-* guidelines from CoreConstraintsInclude (if merged) — ~10 lines
- Total gatable: ~28 lines

5) What must remain always-on:
- ALL 4 rules (memory-limit, file-safety, quality-gate, concise-responses)
- operating-model guideline (Brain = strategic orchestrator)
- directive guideline ("Ultrathink. Delegate. Validate. Reflect.")
- cli-commands guideline
- style/response/determinism builders
- ~59 lines

6) Proposed diff plan:
- Step 1: Add use ModeResolverTrait
- Step 2: Wrap workflow step details in if ($this->isDeepCognitive())
- Step 3: Wrap rule-interpretation in same gate
- Step 4: Review if workflow phase overlap with DelegationProtocols can be deduplicated

7) Verification:
- Compile both modes
- Verify rule-interpretation absent in standard, present in exhaustive
- wc -l comparison → expect ~25-30 line difference

  ---
Summary: Expected Impact
┌────────────────────────────────┬─────────────────┬──────────────────────┬───────────┐
│            Include             │    Current      │    After gating      │  Savings  │
│                                │    always-on    │      (standard)      │           │
├────────────────────────────────┼─────────────────┼──────────────────────┼───────────┤
│ DelegationProtocols            │ ~154 lines      │ ~51 lines            │ ~103      │
│                                │                 │                      │ lines     │
├────────────────────────────────┼─────────────────┼──────────────────────┼───────────┤
│ ErrorHandling +                │ ~108 lines      │ ~18 lines            │ ~90 lines │
│ ResponseValidation             │                 │                      │           │
├────────────────────────────────┼─────────────────┼──────────────────────┼───────────┤
│ CoreInclude (Brain)            │ ~87 lines       │ ~59 lines            │ ~28 lines │
├────────────────────────────────┼─────────────────┼──────────────────────┼───────────┤
│ Total                          │ ~349 lines      │ ~128 lines           │ ~221      │
│                                │                 │                      │ lines     │
└────────────────────────────────┴─────────────────┴──────────────────────┴───────────┘
Projected CLAUDE.md standard/standard: 489 - 221 = ~268 lines (45% reduction from
current!)
Projected CLAUDE.md paranoid/exhaustive: 731 lines (unchanged)

  ---
5. Proposed Minimal Diffs (Summary)

Diff 1 — DelegationProtocolsInclude.php:
- Add use ModeResolverTrait
- Wrap 4 level guidelines, 3 type guidelines, 5 workflow guidelines, 2 delegation
  detail guidelines in if ($this->isDeepCognitive())
- Keep 5 rules + exploration-delegation guideline ungated

Diff 2 — ErrorHandlingInclude.php:
- Add use ModeResolverTrait
- Add 1 compact summary guideline (always-on, ~4 lines)
- Wrap 6 detailed error guidelines in if ($this->isDeepCognitive())

Diff 3 — ResponseValidationInclude.php:
- Add use ModeResolverTrait
- Wrap 4 validation detail guidelines in if ($this->isDeepCognitive())
- Keep Purpose description as always-on

Diff 4 — CoreInclude.php (Brain):
- Add use ModeResolverTrait
- Wrap workflow step details and rule-interpretation in if ($this->isDeepCognitive())

Total: 4 files, ~20-30 lines of PHP changes each, zero new files, zero new
abstractions.

  ---
6. Verification Checklist

[ ] STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
[ ] STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
[ ] wc -l .claude/CLAUDE.md (both modes) — expect standard ~268, exhaustive ~731
[ ] bash scripts/lint-mcp-syntax.sh — PASS
[ ] grep "level-brain\|level-architect\|type-task\|type-analysis" .claude/CLAUDE.md
(standard) — 0 matches
[ ] grep "level-brain\|level-architect\|type-task\|type-analysis" .claude/CLAUDE.md
(exhaustive) — N matches
[ ] grep
"error-delegation\|error-agent-timeout\|validation-semantic\|validation-structural"
.claude/CLAUDE.md (standard) — 0 matches
[ ] grep "rule-interpretation\|workflow-request-analysis\|workflow-agent-selection"
.claude/CLAUDE.md (standard) — 0 matches
[ ] cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php — PASS
[ ] diff .claude/CLAUDE.md between modes — verify zero mode leakage (no
"strict/paranoid:" text in standard)
[ ] Verify all CRITICAL rules present in BOTH modes
