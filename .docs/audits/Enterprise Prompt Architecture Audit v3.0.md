---
name: "Enterprise Prompt Architecture Audit v3.0"
description: "Deep research digest and actionable audit of Brain prompt architecture"
type: "audit"
version: "3.0"
date: "2026-02-20"
---

# Enterprise Prompt Architecture Audit v3.0

1) Deep Research Digest

Проаналізовано 409 рядків deep-research-report.md. Ось що реально стосується нашої     
compile-time архітектури:
#: 1
Теза з deep-research: Schema-enforced outputs = "жорсткий важіль"
Вердикт: KEEP
Чому: У нас вже є: callValidatedJson() + ksortRecursive() + McpSchemaValidator. Ми і є
gold standard
────────────────────────────────────────
#: 2
Теза з deep-research: "Text-only obedience = театр безпеки"
Вердикт: KEEP (awareness)
Чому: Наш захист НЕ лише текст — compile-time schema + lint + CI. Але iron rules в
compiled output = текстові інструкції для моделі. Факт: model compliance не
гарантована, але це residual risk, не actionable зараз
────────────────────────────────────────
#: 3
Теза з deep-research: Untrusted-by-default для tool outputs/RAG
Вердикт: KEEP
Чому: Brain memory вже має search-before-store. Cookbook retrieval через compile-time
presets
────────────────────────────────────────
#: 4
Теза з deep-research: Lost-in-middle: критичне губиться в середині
Вердикт: ADAPT
Чому: Наш compiled output: CRITICAL rules на lines 1-196 (перші 40%) — ОК. Але
guidelines (levels/types/workflows/validation/errors) на lines 294-458 — "death
zone". Саме їх треба гейтити
────────────────────────────────────────
#: 5
Теза з deep-research: Cognitive overload = jailbreak vector
Вердикт: ADAPT
Чому: Менше тексту = менша attack surface. Скорочення standard з 489→~330 рядків
прибирає ~160 рядків, які не давали пропорційної цінності
────────────────────────────────────────
#: 6
Теза з deep-research: Evals як CI gates
Вердикт: ADAPT (документувати gap)
Чому: У нас є schema tests + lint + compile discipline. Немає prompt-level evals
(regression suite для змін інструкцій). Прийнятний gap — задокументувати як
residual risk
────────────────────────────────────────
#: 7
Теза з deep-research: Cookbook = attack surface (RAG poisoning)
Вердикт: KEEP (з уточненням)
Чому: Наш cookbook — CASES.md в git, не user-writable vector DB. Poisoning = supply
chain attack (потрібен git access), NOT RAG poisoning. Різниця суттєва
────────────────────────────────────────
#: 8
Теза з deep-research: YAML recipe format для cookbook
Вердикт: REJECT
Чому: Наш cookbook — markdown в CASES.md. PHP builder API strictly typed. Нова
абстракція з нульовим ROI
────────────────────────────────────────
#: 9
Теза з deep-research: Runtime monitoring/observability
Вердикт: REJECT
Чому: Brain = compile-time система. Не маємо інфраструктури, не actionable
────────────────────────────────────────
#: 10
Теза з deep-research: External red teaming
Вердикт: REJECT
Чому: Dev tool, не user-facing application. Overkill для поточного scope
  ---
2) Holivar List (top 5)

Holivar 1: Gate 5 "Cookbook-First" — "Trigger: Uncertainty"

Обидва brain-integration-guide (task line 282-283, memory line 326-327) та CASES.md
(line 2388-2393) кажуть: TRIGGER: Uncertainty about tools, patterns, rules, or
procedures.

PRO: Integration guides — upstream docs для MCP repos. "Uncertainty" — валідний trigger
для агентів без compile-time presets.

CONTRA: Для Brain "When uncertain, CALL cookbook()" — runtime self-choice. Суперечить:
(a) compiled presets з фіксованими params, (b) ContextLengthProblem "expensive RAM
rent", (c) no-mode-self-switch invariant.

Вердикт: REDEFINE для Brain контексту. Gate 5 = "compile-time preset вже вирішив за
тебе." Не чіпаємо upstream docs, але Brain instructions мають перекривати цю
інтерпретацію.

Що змінить мою думку: Доказ, що модель ігнорує compiled preset і самовільно кличе
cookbook() з іншими params.

  ---
Holivar 2: DelegationProtocols — 14 guidelines always-on vs deep-only

Факти: DelegationProtocolsInclude.php = 155 рядків PHP → ~122 рядки compiled output
(lines 170-195 rules + lines 294-392 guidelines). Це 25% усього CLAUDE.md.

PRO: Brain має знати ієрархію levels, types, workflows.

CONTRA: CoreInclude вже має compact workflow summary (compiled line 267) + operating
model (line 263). 14 detailed guidelines дають reference depth для exhaustive analysis,
але standard Brain делегує нормально і без них.

Вердикт: Gate 9 of 14 guidelines. Always-on залишаються: 5 rules +
exploration-delegation (operational necessity). Deep-only: 4 levels, 3 types,
validation-delegation, fallback-delegation, 5 workflow phases. Savings: ~96 lines.

Що змінить мою думку: Доказ, що standard Brain робить неправильні delegation decisions
без level/type reference.

  ---
Holivar 3: ResponseValidation — aspirational чи реальні метрики?

Факти: ResponseValidationInclude.php = 46 рядків PHP → ~24 рядки compiled (lines
395-416). Містить: cosine similarity ≥0.9, quality-score ≥0.95, trust-index ≥0.75.

PRO: Дає Brain конкретні threshold для оцінки якості.

CONTRA: Brain фізично не може обчислити cosine similarity або trust-index. Це
aspirational числа. CoreInclude вже має quality-gate rule (line 131): "semantic
alignment ≥0.75, structural completeness, policy compliance."

Вердикт: Gate all 4 guidelines behind isDeepCognitive(). CoreInclude quality-gate =
always-on compact version.

Що змінить мою думку: Якщо Brain отримає реальну quality scoring capability.

  ---
Holivar 4: ErrorHandling — 6 guidelines always-on vs deep-only

Факти: ErrorHandlingInclude.php = 64 рядка PHP → ~42 рядки compiled (lines 419-458). 6
guidelines × 4 key-value pairs. Сидять у "death zone" (lines 419-458 з 489).

PRO: Brain потрібен error recovery playbook.

CONTRA: Кожен guideline описує специфічний failure mode (timeout, context loss, etc.),
який Brain зустрічає рідко. escalation-policy (3-tier: standard/critical/unrecoverable)
покриває 90% кейсів.

Вердикт: Gate 5 of 6 guidelines. Always-on: escalation-policy (3 рядки). Savings: ~35
lines.

Що змінить мою думку: Доказ, що standard Brain неправильно обробляє delegation errors
без детального playbook.

  ---
Holivar 5: SequentialReasoningInclude — Universal, blast radius

Факти: SequentialReasoningInclude.php = 67 рядків PHP. Universal include = впливає на
всі агенти. 4 detailed phases × 5 sub-steps + 1 phase-flow summary. НЕ присутній у
compiled CLAUDE.md (тільки в agents). Тому gating тут НЕ впливає на Brain.

PRO: Consistent reasoning framework для всіх агентів.

CONTRA: 4 phases × 5 sub-steps = ~48 рядків на кожен agent artifact. phase-flow summary
(4 рядки) покриває essential: "analysis → inference → evaluation → decision." Для
agents це ~48 lines × 8 agents = ~384 рядки total savings.

Вердикт: Gate 4 detailed phases, keep phase-flow always-on. Savings: ~48 lines per
agent.  Оскільки не впливає на CLAUDE.md, можна виконувати паралельно або як окремий
iteration 2.

Що змінить мою думку: Доказ, що agents produce гірше reasoning без detailed phase
breakdowns.

  ---
3) Iteration Plan (Phase 1 — High ROI, Low Risk)

Target 1: DelegationProtocolsInclude.php

- Файл: core/src/Includes/Brain/DelegationProtocolsInclude.php
- Дія: use ModeResolverTrait + if ($this->isDeepCognitive()) навколо 9 guidelines
- Always-on: 5 rules + exploration-delegation
- Deep-only: 4 levels, 3 types, validation-delegation, fallback-delegation, 5 workflow
  phases
- Savings: ~96 compiled lines
- Risk: LOW — CoreInclude compact workflow залишається як summary

Target 2: ResponseValidationInclude.php

- Файл: core/src/Includes/Brain/ResponseValidationInclude.php
- Дія: use ModeResolverTrait + if ($this->isDeepCognitive()) навколо всіх 4 guidelines
- Deep-only: validation-semantic, validation-structural, validation-policy,
  validation-actions
- Savings: ~22 compiled lines
- Risk: LOW — CoreInclude quality-gate rule = always-on compact version

Target 3: ErrorHandlingInclude.php

- Файл: core/src/Includes/Brain/ErrorHandlingInclude.php
- Дія: use ModeResolverTrait + if ($this->isDeepCognitive()) навколо 5 of 6 guidelines
- Always-on: escalation-policy
- Deep-only: error-delegation-failed, error-agent-timeout, error-invalid-response,
  error-context-loss, error-resource-exceeded
- Savings: ~35 compiled lines
- Risk: LOW — escalation-policy покриває 90% кейсів

Зведені числа:
┌─────────────────────┬───────────────┬───────────────────────┐
│       Target        │     PHP Δ     │ Compiled Δ (standard) │
├─────────────────────┼───────────────┼───────────────────────┤
│ DelegationProtocols │ +5 lines      │ -96 lines             │
├─────────────────────┼───────────────┼───────────────────────┤
│ ResponseValidation  │ +5 lines      │ -22 lines             │
├─────────────────────┼───────────────┼───────────────────────┤
│ ErrorHandling       │ +5 lines      │ -35 lines             │
├─────────────────────┼───────────────┼───────────────────────┤
│ Total               │ +15 lines PHP │ -153 lines compiled   │
└─────────────────────┴───────────────┴───────────────────────┘
CLAUDE.md: 489 → ~336 lines (-31%)

SequentialReasoning — iteration 2 (не впливає на Brain, тільки на agents).

  ---
4) Cookbook Governance Policy

1. Compile-time presets ONLY. Model отримує pre-baked cookbook() calls з фіксованими
   params. Model НІКОЛИ не конструює params самостійно.
2. onViolation triggers ONLY. Cookbook retrieval з'являється ТІЛЬКИ як onViolation на
   Iron Rules. Model кличе cookbook() тільки при порушенні конкретного правила.
3. BANNED: "Pull when uncertain." Integration guide Gate 5 "Cookbook-First:
   Trigger=Uncertainty" реінтерпретований: compile-time preset = відповідь на
   невизначеність. Model НЕ self-invoke cookbook() поза compiled onViolation triggers.
4. Budget cap: max 2 pulls/conversation (1 preset at start + max 1 onViolation).
   Paranoid/exhaustive: до 4.
5. Negative triggers (коли НЕ тягти):
   - Trivial task (< 5 min, 1 file) → НІКОЛИ
   - Відповідь вже в loaded rules → НІКОЛИ
   - Та сама query повторно → НІКОЛИ
   - Context budget_state = red → НІКОЛИ
6. Precedence: compiled Iron Rules > cookbook cases. Завжди.
7. Cookbook = git artifact. CASES.md version-controlled. Зміни потребують git commit.
   Це НЕ vector DB (RAG poisoning = supply chain attack, not retrieval attack).
8. No recursive cookbook. Cookbook cases НЕ тригерять подальші cookbook pulls.
   Single-level only.

  ---
5) Critical Rules Positioning Check

Провів позиційний аналіз 489 рядків compiled CLAUDE.md:

Lines 001-007  ████ System meta            → TOP (high attention)
Lines 008-058  ████████████ Iron Rules MCP  → TOP (EXCELLENT)
Lines 059-115  ██████████ Iron Rules Comp   → UPPER (GOOD)
Lines 117-163  ████████ Iron Rules Core     → UPPER-MID (acceptable)
Lines 165-196  █████ Iron Rules Delegation  → MIDDLE (borderline)
Lines 197-214  ███ Quality Gates CRITICAL   → MIDDLE (acceptable)
Lines 216-260  ████████ Cookbook+Compilation → LOWER-MID (degrading)
Lines 262-283  ████ CoreInclude guidelines  → LOWER-MID (degrading)
Lines 294-392  ████████████████████ Delegation guidelines → DEATH ZONE ⚠️
Lines 395-458  ██████████ Validation+Errors → DEATH ZONE ⚠️
Lines 462-470  ██ CoreConstraints           → NEAR-END (recovering)
Lines 473-489  ███ Style/formatting         → END (high attention)

Оцінка:
- CRITICAL Iron Rules на lines 1-196 (перші 40%) — ПРАВИЛЬНО
- Guidelines (levels/types/workflows/validation/errors) на lines 294-458 — DEATH ZONE
  (60-94% документа)
- Quality Gates CRITICAL (lines 206-213) — прийнятна позиція, але можна б піднести
  ближче до початку

Висновок: Переорганізація НЕ потрібна. Phase 1 gating природньо ВИДАЛЯЄ ~153 рядки з
death zone у standard mode. Після gating:
- Standard: ~336 lines, guidelines в death zone = 0
- Deep/exhaustive: 489 lines без змін

  ---
6) Concrete Diff Plan
   #: 1
   Файл: core/src/Includes/Brain/DelegationProtocolsInclude.php
   Дія: use ModeResolverTrait + wrap 9 guidelines в if ($this->isDeepCognitive()) { }
   Compiled Δ: -96 lines
   ────────────────────────────────────────
   #: 2
   Файл: core/src/Includes/Brain/ResponseValidationInclude.php
   Дія: use ModeResolverTrait + wrap 4 guidelines в if ($this->isDeepCognitive()) { }
   Compiled Δ: -22 lines
   ────────────────────────────────────────
   #: 3
   Файл: core/src/Includes/Brain/ErrorHandlingInclude.php
   Дія: use ModeResolverTrait + wrap 5 guidelines (keep escalation-policy) в if
   ($this->isDeepCognitive()) { }
   Compiled Δ: -35 lines
   ────────────────────────────────────────
   #: 4
   Файл: .docs/migration/enterprise-readiness.md
   Дія: Додати в Residual Risks: cookbook poisoning = supply chain, not RAG + Gate 5
   reinterpretation
   Compiled Δ: +5 lines
   Чого НЕ чіпаємо:
- Upstream brain-integration-guide (зовнішній repo)
- CASES.md / CASES_AGENTS.md (зовнішній repo)
- Brain.php, CoreInclude.php, VectorTaskInclude.php, VectorMemoryInclude.php (вже
  гейтяться або не потребують змін)
- Будь-які нові файли / абстракції / фреймворки

4 файли. ~20 рядків PHP. 0 нових абстракцій.

  ---
7) Verification Checklist

# 1. Baseline (before changes)
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
wc -l .claude/CLAUDE.md                    # Expected: 489

# 2. After changes — standard
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
wc -l .claude/CLAUDE.md                    # Expected: ~330-340

# 3. After changes — paranoid/exhaustive
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
wc -l .claude/CLAUDE.md                    # Expected: ~731 (unchanged)

# 4. Zero mode leakage (standard)
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
grep -c 'Level brain\|Level architect\|Level specialist\|Level tool' .claude/CLAUDE.md
# Expected: 0

grep -c 'Type task\|Type analysis\|Type validation' .claude/CLAUDE.md
# Expected: 0

grep -c 'Workflow request analysis\|Workflow agent selection' .claude/CLAUDE.md
# Expected: 0

grep -c 'Validation semantic\|Validation structural' .claude/CLAUDE.md
# Expected: 0

grep -c 'Error delegation failed\|Error agent timeout' .claude/CLAUDE.md
# Expected: 0

# 5. Always-on content present in BOTH modes
grep -c 'Exploration delegation' .claude/CLAUDE.md    # Expected: 1
grep -c 'Escalation policy' .claude/CLAUDE.md         # Expected: 1
grep -c 'Delegation-limit' .claude/CLAUDE.md          # Expected: 1 (CRITICAL rule)
grep -c 'Non-recursive' .claude/CLAUDE.md             # Expected: 1 (CRITICAL rule)

# 6. Gated content present in paranoid/exhaustive
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
grep -c 'Level brain' .claude/CLAUDE.md               # Expected: 1
grep -c 'Validation semantic' .claude/CLAUDE.md       # Expected: 1
grep -c 'Error delegation failed' .claude/CLAUDE.md   # Expected: 1

# 7. CRITICAL iron rules count (standard)
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
grep -c 'CRITICAL' .claude/CLAUDE.md                  # Expected: ≥12

# 8. Lint gate
bash scripts/lint-mcp-syntax.sh                       # Expected: 0 errors

# 9. Schema tests
cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
# Expected: all pass

# 10. No Gate 5 "uncertainty" in compiled output
grep -c 'When uncertain.*cookbook\|Trigger.*Uncertainty' .claude/CLAUDE.md
# Expected: 0
 
