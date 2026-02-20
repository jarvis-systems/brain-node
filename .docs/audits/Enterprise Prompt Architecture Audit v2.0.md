---
name:  Enterprise Prompt Architecture Audit v2.0
description:  Comprehensive review of our prompt architecture against deep research findings. Identifies gaps, validates
---
# Enterprise Prompt Architecture Audit v2.0
                                                                                         
---                                                                                  

1. EXEC SUMMARY

3 нових ризиків, що реально стосуються нашої архітектури:

1. Cognitive overload як jailbreak-вектор (NAACL 2024) — наш exhaustive mode = 731
   рядків. Чим більше always-on тексту, тим ширша поверхня атаки через перевантаження.
2. "Lost in the middle" деградація — критичні правила посеред 731 рядків можуть бути
   депріоритизовані моделлю. Позиція в документі має значення.
3. Gate 5 "Cookbook-First" з brain-integration-guide конфліктує з ContextLengthProblem
   — "Check cookbook before assuming" = вагний runtime тригер, що провокує зайві pulls.
   Потребує переформулювання.

3 підтвердження ("ми вже це робимо правильно"):

1. callValidatedJson + ksortRecursive = schema-enforced + deterministic JSON. Deep
   research називає це "один з небагатьох жорстких важелів".
2. Single-mode compile-time resolution. Deep research каже "text-only obedience =
   security theater". Ми не вчимо — ми бейкаємо.
3. Method whitelist + lint gate + CI diff-guard = least privilege + tool validation.
   OWASP LLM08 закрито.

3 actionable opportunities (high ROI, low risk):

1. Загейтити DelegationProtocols + ErrorHandling + ResponseValidation через
   isDeepCognitive() → ~170 рядків економії в standard CLAUDE.md (489 → ~320).
2. Формалізувати Cookbook Policy з negative triggers ("коли НЕ тягнути") — захист
   context budget.
3. Верифікувати позиціонування critical rules у compiled output (мають бути на початку,
   не в середині).

  ---

2. CLAIMS TRIAGE TABLE
   #: 1
   Claim: "Untrusted by default" trust model
   Verdict: KEEP
   Reason: Already implicit: compile-time instructions = trusted, runtime input =
   untrusted
   Sec: 5
   Ctx: 3
   Cpx: 1
   Reg: 0
   Fit: 5
   Total: 14
   ────────────────────────────────────────
   #: 2
   Claim: Schema-enforced structured outputs
   Verdict: KEEP
   Reason: Done: callValidatedJson + McpSchemaValidator + 338/372 coverage
   Sec: 5
   Ctx: 2
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 12
   ────────────────────────────────────────
   #: 3
   Claim: "Teaching obedience by text = theater"
   Verdict: KEEP
   Reason: Validates our compile-time approach. No text-only enforcement in production
   Sec: 5
   Ctx: 4
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 14
   ────────────────────────────────────────
   #: 4
   Claim: Evals as CI gates
   Verdict: ADAPT
   Reason: Our eval = compile both modes + wc -l + lint + grep + schema test. Formalize as

   script
   Sec: 3
   Ctx: 2
   Cpx: 2
   Reg: 1
   Fit: 4
   Total: 12
   ────────────────────────────────────────
   #: 5
   Claim: Cookbook as "managed artifact (like code)"
   Verdict: KEEP
   Reason: Already true: MCP-side, versioned, MCP-JSON-ONLY gate, write restricted to
   Brain
   Sec: 4
   Ctx: 3
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 12
   ────────────────────────────────────────
   #: 6
   Claim: Full YAML recipe structure (tests/evals/guardrails/observability)
   Verdict: REJECT
   Reason: Over-engineering. Brain is compiler, not runtime service. Recipes = MCP cases,
   already structured
   Sec: 2
   Ctx: 0
   Cpx: 5
   Reg: 3
   Fit: 1
   Total: 11
   ────────────────────────────────────────
   #: 7
   Claim: Deterministic triggers for cookbook
   Verdict: KEEP
   Reason: Already done: compile-time presets, not model-chosen
   Sec: 4
   Ctx: 4
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 13
   ────────────────────────────────────────
   #: 8
   Claim: Negative triggers ("when NOT to retrieve")
   Verdict: ADAPT
   Reason: Missing. Add to cookbook policy as explicit "do not pull" conditions
   Sec: 3
   Ctx: 5
   Cpx: 1
   Reg: 1
   Fit: 4
   Total: 14
   ────────────────────────────────────────
   #: 9
   Claim: RAG poisoning as first-class risk
   Verdict: ADAPT
   Reason: Document in enterprise-readiness.md as residual risk. Cookbook = read-only for
   agents, Brain = exclusive writer
   Sec: 4
   Ctx: 1
   Cpx: 1
   Reg: 0
   Fit: 4
   Total: 10
   ────────────────────────────────────────
   #: 10
   Claim: Runtime monitoring/observability
   Verdict: REJECT
   Reason: Architecture mismatch. Brain = compiler, not runtime service. CLI clients own
   observability
   Sec: 1
   Ctx: 0
   Cpx: 4
   Reg: 2
   Fit: 1
   Total: 8
   ────────────────────────────────────────
   #: 11
   Claim: External red teaming
   Verdict: REJECT
   Reason: No runtime to red-team. Our "red team" = compile both modes + diff + grep +
   adversarial lint patterns
   Sec: 2
   Ctx: 0
   Cpx: 4
   Reg: 1
   Fit: 1
   Total: 8
   ────────────────────────────────────────
   #: 12
   Claim: "Long prompts ≠ quality" / lost-in-middle
   Verdict: KEEP
   Reason: Validates aggressive isDeepCognitive() gating. Reduce standard mode ruthlessly
   Sec: 3
   Ctx: 5
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 13
   ────────────────────────────────────────
   #: 13
   Claim: Tool allowlist + param validation
   Verdict: KEEP
   Reason: Done: method whitelist in strict/paranoid + required key validation in all
   modes
   Sec: 5
   Ctx: 1
   Cpx: 0
   Reg: 0
   Fit: 5
   Total: 11
   ────────────────────────────────────────
   #: 14
   Claim: "Instruction Budget" concept
   Verdict: ADAPT
   Reason: No hard limit today. Add as benchmark metric (lines per include per mode)
   tracked in CI
   Sec: 2
   Ctx: 4
   Cpx: 2
   Reg: 1
   Fit: 3
   Total: 12
   ────────────────────────────────────────
   #: 15
   Claim: Canary/A-B rollout for recipes
   Verdict: REJECT
   Reason: No runtime. Recipes = compiled. A-B = compile with different .env + compare.
   Already possible
   Sec: 1
   Ctx: 0
   Cpx: 4
   Reg: 2
   Fit: 1
   Total: 8
   ────────────────────────────────────────
   #: 16
   Claim: Supply chain risk for MCP
   Verdict: KEEP
   Reason: Awareness only. MCP servers are our own repos. CI diff-guard covers compiled
   artifacts
   Sec: 3
   Ctx: 0
   Cpx: 0
   Reg: 0
   Fit: 4
   Total: 7
   ────────────────────────────────────────
   #: 17
   Claim: "Sub-agent quarantine for large files"
   Verdict: REJECT
   Reason: Runtime pattern from ContextLengthProblem. Belongs in agent instructions, not
   compile-time architecture
   Sec: 1
   Ctx: 2
   Cpx: 3
   Reg: 2
   Fit: 1
   Total: 9
   Scoring key: Security (0-5), Context impact (0-5), Complexity cost (0-5, lower=better),
   Regression risk (0-5, lower=better), Fit to architecture (0-5). Total = sum, higher =
   better fit.

  ---

3. HOLIVAR LIST (Top 5)

H1: Gate 5 "Cookbook-First" vs ContextLengthProblem "controlled pull only"

Pro: brain-integration-guide Gate 5 says "Check cookbook before assuming" — prevents
hallucination when model doesn't know the procedure.
Contra: "Before assuming" is a vague trigger. ContextLengthProblem warns this becomes
"protocol for protocol's sake" — model pulls cookbook every conversation "just in
case".
Recommendation: REDEFINE. Gate 5 is already correctly implemented as compile-time
preset (fires once at start, deterministically). The text "Uncertainty" as trigger must
be removed from Gate 5 description. Compile-time preset = the "check before assuming".
What would change my mind: Evidence that standard-mode agents frequently hallucinate
MCP patterns that a runtime cookbook pull would have prevented.

H2: DelegationProtocols 14 guidelines: always-on vs deep-only

Pro: Brain needs to understand authority levels and workflow phases to delegate
correctly. Removing them may cause incorrect delegation patterns.
Contra: 5 CRITICAL/HIGH rules already enforce delegation constraints. The 14 guidelines
are reference encyclopedia — model uses them when writing reports, not when
delegating. CoreInclude's workflow guideline already provides the summary.
Recommendation: Gate 9 of 14 guidelines behind isDeepCognitive(). Keep 5 rules +
exploration-delegation always-on. CoreInclude's workflow summary serves as always-on
placeholder.
What would change my mind: A/B test showing standard-mode agents make delegation errors
without level/type descriptions.

H3: ResponseValidation cosine thresholds — meaningful or aspirational?

Pro: Clear pass/fail criteria (≥0.9 / 0.75 / <0.75) provide decision framework for
quality assessment.
Contra: Brain cannot compute cosine similarity at runtime. Trust-index arithmetic
(±0.01/0.1) is pure fiction — no state persists. These are aspirational specs that
consume tokens but deliver no enforceable behavior.
Recommendation: Gate entirely behind isDeepCognitive(). In standard mode, CoreInclude's
quality-gate rule already says "semantic alignment ≥0.75" — sufficient.
What would change my mind: If Brain somehow gained persistent state + numeric scoring
capability.

H4: SequentialReasoningInclude: universal always-on vs deep-only

Pro: Structured reasoning framework works for ALL modes — even standard benefits from
disciplined analysis→inference→evaluation→decision flow.
Contra: 66 lines × every compiled artifact (CLAUDE.md + 8 agents).
SequentialThinkingMcp provides this at runtime with adaptive depth. The 20-phase model
(4 phases × 5 sub-steps) is cognitive overhead for standard tasks.
Recommendation: Keep phase-flow guideline always-on (4 compiled lines, describes the
model). Gate 4 detailed phase guidelines behind isDeepCognitive().
What would change my mind: Evidence that standard-mode agents produce structurally
worse reasoning without the detailed phases.

H5: LaravelBoost includes — universal vs project-conditional

Pro: For Laravel projects, these 196 lines are essential for effective use of boost MCP
tools.
Contra: For non-Laravel projects, 196 lines × every artifact = pure waste. This is a
DIFFERENT type of gating (project-conditional, not mode-conditional).
Recommendation: DEFER to iteration 2. Introduce HAS_LARAVEL_BOOST env var if/when
non-Laravel project compilation becomes reality. Current: all projects use Laravel, so
saving = 0. This is future-proofing, not current pain.
What would change my mind: A concrete non-Laravel project compiling with Brain.

  ---

4. NEXT ITERATION PLAN

Current baseline: standard/standard = 489 compiled lines, paranoid/exhaustive = 731
lines.

Target #1: DelegationProtocolsInclude.php
Category: ALWAYS-ON
Content: 5 rules: delegation-limit, approval-chain, context-integrity, non-recursive,
accountability
Lines (est. compiled): ~30
────────────────────────────────────────
Category: ALWAYS-ON
Content: exploration-delegation guideline
Lines (est. compiled): ~6
────────────────────────────────────────
Category: DEEP-ONLY
Content: 4 level guidelines (brain/architect/specialist/tool)
Lines (est. compiled): ~24
────────────────────────────────────────
Category: DEEP-ONLY
Content: 3 type guidelines (task/analysis/validation)
Lines (est. compiled): ~15
────────────────────────────────────────
Category: DEEP-ONLY
Content: validation-delegation + fallback-delegation
Lines (est. compiled): ~10
────────────────────────────────────────
Category: DEEP-ONLY
Content: 5 workflow phase guidelines
Lines (est. compiled): ~35
────────────────────────────────────────
Category: Savings
Content:
Lines (est. compiled): ~84 lines
Change: Add use ModeResolverTrait, wrap 14 guidelines in if ($this->isDeepCognitive()).
Verification:

- STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile → 0 matches for
  level-brain|type-task|workflow-request
- STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile → all present
- bash scripts/lint-mcp-syntax.sh → PASS
- All 5 rules present in BOTH modes

Target #2: ErrorHandlingInclude.php + ResponseValidationInclude.php
Category: ALWAYS-ON
Content: Compact 1-guideline summary: "On failure: retry → escalate → restore context"
Lines (est.): ~4
────────────────────────────────────────
Category: DEEP-ONLY
Content: 6 error scenario guidelines (ErrorHandling)
Lines (est.): ~36
────────────────────────────────────────
Category: DEEP-ONLY
Content: 4 validation detail guidelines (ResponseValidation)
Lines (est.): ~20
────────────────────────────────────────
Category: Savings
Content:
Lines (est.): ~52 lines
Change: Add use ModeResolverTrait to both. Wrap all guidelines in if
($this->isDeepCognitive()). Add 1 compact always-on summary guideline in
ErrorHandlingInclude.
Verification:

- grep "error-delegation\|error-agent-timeout\|validation-semantic\|validation-policy"
  → 0 in standard
- Purpose/provides text still present in both modes

Target #3: SequentialReasoningInclude.php
Category: ALWAYS-ON
Content: phase-flow guideline (sequential model overview)
Lines (est.): ~6
────────────────────────────────────────
Category: DEEP-ONLY
Content: 4 detailed phase guidelines (analysis/inference/evaluation/decision), 5
sub-steps each
Lines (est.): ~32
────────────────────────────────────────
Category: Savings
Content:
Lines (est.): ~32 lines
Change: Add use ModeResolverTrait. Wrap 4 detailed phases in if
($this->isDeepCognitive()).
Note: This is Universal include — savings multiply across CLAUDE.md AND agent
artifacts.
Verification:

- grep "phase-analysis\|phase-inference\|phase-evaluation\|phase-decision" → 0 in
  standard
- phase-flow present in both modes

Combined Impact
┌───────────────────────────┬──────────┬───────────────┬──────────────────────────────┐
│ Metric │ Before │ After │ Delta │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ standard CLAUDE.md │ 489 │ ~321 lines │ -168 lines (-34%)            │
│ │ lines │ │ │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ exhaustive CLAUDE.md │ 731 │ 731 lines │ unchanged │
│ │ lines │ │ │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ Agent artifacts │ ~varies │ -32 lines │ SequentialReasoning │
│ (standard)                │ │ each │ universal │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ Files changed │ 0 │ 4 │ minimal blast radius │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ New files │ 0 │ 0 │ — │
├───────────────────────────┼──────────┼───────────────┼──────────────────────────────┤
│ New abstractions │ 0 │ 0 │ — │
└───────────────────────────┴──────────┴───────────────┴──────────────────────────────┘
  ---

5. SECURITY MODEL ALIGNMENT
   Threat (from deep research): Direct prompt injection
   Our Control: Single-mode compilation. Model sees 1 fixed config, no conditional
   branching. Cannot self-switch mode.
   Residual Risk: Model still processes untrusted user input at runtime
   Minimal Mitigation: No action needed — compile-time defense is correct layer. Runtime
   defense = CLI responsibility
   ────────────────────────────────────────
   Threat (from deep research): Instruction hierarchy violation
   Our Control: All instructions compiled + baked. No trust levels to confuse within the
   prompt itself. Iron rules at critical priority.
   Residual Risk: In 731-line exhaustive mode, reference sections may dilute rule priority
   Minimal Mitigation: Verify critical rules compile at document top (before
   guidelines/reference). Low effort check.
   ────────────────────────────────────────
   Threat (from deep research): RAG/Cookbook poisoning
   Our Control: Cookbook data in SQLite, MCP-only access. Brain = exclusive writer. Agents

   = read-only. CASES are versioned in MCP repo code
   Residual Risk: If MCP SQLite compromised, cookbook cases inject false patterns
   Minimal Mitigation: Document as residual risk in enterprise-readiness.md. Add
   invariant:
   "Cookbook = read-only for agents". No code change.
   ────────────────────────────────────────
   Threat (from deep research): "Lost in the middle"
   Our Control: Standard = 489 lines (planned ~321). Exhaustive = 731 lines.
   isDeepCognitive() gating reduces standard aggressively
   Residual Risk: Exhaustive mode still long. Reference sections in middle.
   Minimal Mitigation: Iteration 1 gating reduces standard by 34%. For exhaustive: verify
   rule ordering in compiled output.
   ────────────────────────────────────────
   Threat (from deep research): Cognitive overload → jailbreak
   Our Control: Mode matrix: minimal(least)→exhaustive(most). Compile-time resolution.
   Standard ships ~489 lines.
   Residual Risk: Deep/exhaustive modes = higher instruction density = wider attack
   surface
   Minimal Mitigation: Same as gating plan. Less text = less attack surface. 321 lines
   standard is significantly safer than 489.
   ────────────────────────────────────────
   Threat (from deep research): Excessive agency (OWASP LLM08)
   Our Control: Schema validation on all VectorTask/VectorMemory calls. Method whitelist
   in
   strict/paranoid. Lint gate on 67 files.
   Residual Risk: Context7Mcp + SequentialThinkingMcp have no schema (by design —
   read-only, single-method)
   Minimal Mitigation: No action needed. Residual is acceptable per
   enterprise-readiness.md
   §Known Limitations

  ---

6. COOKBOOK POLICY (proposed final wording)

Cookbook Retrieval Governance — 8 Rules

1. Compile-time presets ONLY. Cookbook retrieval parameters (case_category, priority,
   limit, strict, cognitive) are resolved from .env at compile time and baked into
   artifacts. The model does not choose retrieval parameters.
2. onViolation triggers ONLY. Additional cookbook retrieval fires ONLY when a specific
   iron rule is violated AND the onViolation clause contains an explicit cookbook call.
   The violation must be detectable by the model (not speculative).
3. BANNED: "Pull when uncertain." Any directive that says "check cookbook before
   assuming", "read more to be sure", or "pull cookbook when unclear" is forbidden. These
   are model-chosen runtime decisions that bypass compile-time control.
4. Gate 5 reinterpretation. brain-integration-guide "Cookbook-First" gate means:
   "compiled preset replaces manual assumption." It does NOT mean "runtime pull on
   uncertainty." The preset fires once at conversation start. That IS the "first check."
5. Negative triggers (when NOT to pull):
    - Task is routine/standard path with no iron rule violation
    - Instructions for the operation are already in compiled context
    - Model "wants to verify" without a specific, nameable rule being violated
    - Context budget is at yellow/red (>80% tokens consumed)
6. Budget cap. Maximum 2 cookbook pulls per conversation: 1 compile-time preset at
   start + 1 onViolation if triggered. Third pull requires explicit user request.
7. Precedence. Compiled iron rules always override cookbook case recommendations. If
   cookbook case contradicts a compiled rule, the compiled rule wins.
8. No recursive cookbook. A cookbook case MUST NOT trigger another cookbook pull. Each
   pull is terminal — model reads, applies, continues. No "cookbook recommended reading
   more cookbook."

Conflict note: Rule 3 directly contradicts brain-integration-guide Gate 5 text
"Trigger: Uncertainty". This must be resolved in the integration guide.
ContextLengthProblem.md supports Rule 3: "контекст — це дорога оренда RAM" + "protocol
for protocol's sake" risk.
