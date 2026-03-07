<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Compilation\BrainCLI;
use BrainCore\Compilation\Operator;
use BrainCore\Compilation\Runtime;
use BrainCore\Compilation\Store;
use BrainCore\Compilation\Tools\BashTool;
use BrainCore\Compilation\Tools\ReadTool;

#[Meta('id', 'prompt-php-dsl-generation')]
#[Meta('description', 'Generate high-quality prompts in Brain PHP DSL format for deterministic compile to client prompt artifacts')]
#[Purpose(<<<'PURPOSE'
Teaches how to author prompts in Brain PHP DSL so they compile into stable markdown prompt artifacts.
Focuses on architecture, rule design, workflow phases, and anti-pattern prevention.
Applies to any command/include prompt, not a specific command implementation.
PURPOSE
)]
class PromptGenerationSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('objective')
            ->text('Goal: generate instruction prompts via PHP source archetypes (Command/Include/Agent/Skill), then compile to target prompt files (for Codex: .codex/prompts/*.md).');

        $this->guideline('source-of-truth')
            ->text('Author ONLY source files in node/core PHP archetypes. Never edit compiled artifacts directly.')
            ->example()->do(
                'Edit: node/Commands/*, node/Includes/*, node/Agents/*, node/Skills/*',
                'Compile: brain compile',
                'Read output: .codex/prompts/*.md',
                'Forbidden: manual edits in .codex/prompts/',
            );

        $this->guideline('prompt-anatomy')
            ->text('Canonical prompt anatomy in PHP DSL for any artifact (Brain/Agent/Command/Include/Skill): Meta -> Purpose -> Iron Rules -> Guidelines/Workflow -> Structured Output contract.')
            ->example()->do(
                '#[Meta("id", "artifact-id")]',
                '#[Meta("description", "Short and concrete")]',
                '#[Purpose("Execution contract and scope")]',
                '$this->rule("rule-id")->critical()->text("Constraint")',
                '$this->guideline("workflow")->example()->phase(' . var_export(Operator::goal('Workflow contract'), true) . ')',
            );

        $this->guideline('rule-authoring-standard')
            ->text('Rule quality standard: each rule must be atomic, testable, and operational.')
            ->example()->do(
                'Rule id: kebab-case, semantic and stable',
                'Severity: critical/high/medium/low by impact and recoverability',
                'text(): precise behavior contract (what MUST/MUST NOT happen)',
                'why(): operational risk being prevented',
                'onViolation(): deterministic remediation action',
                'No vague policy-only prose without executable behavior',
            );

        $this->guideline('workflow-phase-standard')
            ->text('Workflow in prompts must be phase-driven and machine-readable.')
            ->example()
            ->phase('PHASE 0: input capture and normalization ($RAW_INPUT -> intent, flags, scope)')
            ->phase('PHASE 1: context discovery (docs, code, dependencies, prior decisions)')
            ->phase('PHASE 2: plan with explicit steps, touched files, risks, stop-conditions')
            ->phase('PHASE 3: execution with read-before-edit and atomic edits')
            ->phase('PHASE 4: validation (syntax/lint/tests/docs impact)')
            ->phase('PHASE 5: completion report (STATUS/RESULT/NEXT)');

        $this->guideline('prompt-style-contract')
            ->text('Prompt text style must be direct, deterministic, and non-ambiguous.')
            ->example()->do(
                'Use explicit MUST/FORBIDDEN language for hard constraints',
                'Avoid optional wording where behavior must be fixed',
                'Prefer short executable instructions over long narrative text',
                'Define exact stop conditions and retry limits',
                'Include security rules: no secret output, no destructive rollback',
            );

        $this->guideline('php-dsl-patterns')
            ->text('Use native PHP DSL helpers instead of pseudo-string instruction blocks where possible. Prefer Operator::* as first-class flow syntax.')
            ->example()->do(
                Operator::input('$RAW_INPUT'),
                Store::as('TASK', 'normalized input'),
                Operator::validate('task scope is clear', Operator::abort('Ambiguous task scope')),
                Operator::if('docs required', BrainCLI::MCP__DOCS_SEARCH(['keywords' => '{$TASK}']), Operator::skip('docs scan not needed')),
                Operator::forEach('file in $TARGET_FILES', [
                    ReadTool::call('{file}'),
                    Operator::check('file content loaded'),
                ]),
                Operator::task(
                    Operator::note('execute atomic steps only'),
                    BashTool::call(BrainCLI::COMPILE),
                    Operator::verify('compile success'),
                ),
                Operator::output('STATUS: [done] flow complete'),
            );

        $this->guideline('operator-full-catalog')
            ->text('Operator class capabilities (BrainCore\\Compilation\\Operator) that must be considered during prompt generation:')
            ->example()->do(
                'Control flow: if(), ifBlock(), forEach(), validate(), task()',
                'Guards/checks: verify(), check(), abort(), continue(), break(), return()',
                'Semantic markers: goal(), scenario(), report(), note(), context(), output(), input(), skip()',
                'Chaining/formatting: do(), chain()',
                'Delegation/orchestration: delegate(), parallel()',
                'Rule: do not limit Operator usage to only if/forEach/task/verify; choose method by semantics of the step.',
            );

        $this->guideline('compilation-helpers-namespaces')
            ->text('Always use explicit namespaces for core compilation helpers from core/src/Compilation and core/src/Compilation/Tools.')
            ->example()->do(
                'use BrainCore\\Compilation\\Operator;',
                'use BrainCore\\Compilation\\Store;',
                'use BrainCore\\Compilation\\Runtime;',
                'use BrainCore\\Compilation\\BrainCLI;',
                'use BrainCore\\Compilation\\Tools\\BashTool;',
                'use BrainCore\\Compilation\\Tools\\ReadTool;',
                'Path rule: prefer Runtime::* constants/methods over hardcoded paths.',
                'Command rule: prefer BrainCLI::* constants/methods over string literals.',
            );

        $this->guideline('operator-over-plain-do')
            ->text('Anti-pattern: building complex flow only with plain do(...) chains. Use semantic Operator methods for branching, loops, validation, and guard rails.')
            ->example()->do(
                'BAD: do("check", "maybe skip", "maybe abort", "loop files", "report")',
                'GOOD: Operator::validate(...) + Operator::if(...) + Operator::forEach(...) + Operator::report(...)',
                'Plain do(...) is acceptable for linear micro-sequences without branching logic.',
            );

        $this->guideline('anti-patterns')
            ->text('Anti-patterns when generating prompt PHP source:')
            ->example()->do(
                'Copying one concrete command prompt instead of extracting reusable pattern',
                'Mixing execution logic with unclear policy prose',
                'Missing onViolation for critical rules',
                'Non-deterministic ordering of phases/rules',
                'Hardcoded paths/values where runtime helpers are expected',
                'Editing compiled prompt files to patch behavior',
            );

        $this->guideline('phase-chain-anti-pattern')
            ->text('Bad chain pattern: calling ->example()->phase(...) repeatedly for each phase line. This often keeps only the last phase in compiled output.')
            ->example()->do(
                'BAD: ->example()->phase("PHASE 0 ...")->example()->phase("PHASE 1 ...")->example()->phase("PHASE 2 ...")',
                'GOOD: ->example()->phase("PHASE 0 ...")->phase("PHASE 1 ...")->phase("PHASE 2 ...")',
                'Rule: call ->example() once per sequence, then append all ->phase(...) calls to the same example context.',
            );

        $this->guideline('do-array-anti-pattern')
            ->text('Anti-pattern: for sequential steps, using ->do([ ... ]) joins steps and may remove explicit step separators in compiled prompt.')
            ->example()->do(
                'BAD (sequence): ->do(["step 1", "step 2", "step 3"])',
                'GOOD (sequence): ->do("step 1", "step 2", "step 3")',
                'Rule: pass sequence steps as separate do(...) arguments to preserve arrow-separated flow.',
                'Array in do([ ... ]) is acceptable only for intentionally single joined block.',
            );

        $this->guideline('definition-of-done')
            ->text('Prompt generation is complete only when compilation and artifact quality are verified.')
            ->example()->do(
                'PHP source compiles successfully',
                'Compiled prompt has expected meta, purpose, rules, and workflow sections',
                'No duplicated/conflicting rules',
                'No secret leakage in examples or templates',
                'Output is concise, actionable, and enforceable by agents',
                'Operator usage covers semantic intent (control flow, validation, reporting, orchestration), not just linear chains.',
            );
    }
}
