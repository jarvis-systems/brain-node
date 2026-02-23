<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'health-check')]
#[Meta('description', 'Run project health checks: tests, static analysis, compile verification, and audit gates')]
#[Purpose(<<<'PURPOSE'
Executes the full project health check suite in a deterministic order.
Reports pass/fail status for each gate with evidence output.
No external calls, no secrets, no side effects beyond stdout.
PURPOSE
)]
class HealthCheckSkill extends SkillArchetype
{
    /**
     * Handle the architecture logic.
     */
    protected function handle(): void
    {
        $this->guideline('usage')
            ->text('Run /health-check to execute all project quality gates and get a pass/fail summary.')
            ->example()->do([
                'composer test — run PHPUnit test suite',
                'composer analyse — run PHPStan static analysis',
                'bash scripts/verify-compile-metrics.sh — verify compile output metrics',
                'bash scripts/audit-enterprise.sh — run enterprise audit checks',
                'bash scripts/verify-client-formats.sh — verify client format consistency',
            ]);

        $this->guideline('output')
            ->text('Return a structured summary with gate name, status (PASS/FAIL), and key metrics for each check.');
    }
}
