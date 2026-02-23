<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'repo-boundary-preflight')]
#[Meta('description', 'Prevents cross-repo commits by checking file changes against repo boundaries')]
#[Purpose(<<<'PURPOSE'
Validates that pending changes stay within allowed repo boundaries.
Prevents accidental cross-contamination between root/core/cli repos.
Must run BEFORE any commit in monorepo environment.
PURPOSE
)]
class RepoBoundaryPreflightSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('check-sequence')
            ->text('Pre-commit boundary check sequence:')
            ->example()->do([
                '1. Run: git diff --name-only --cached (staged) or git diff --name-only (unstaged)',
                '2. Classify each file by repo: root/, core/, cli/',
                '3. If files span multiple repos → BLOCK with clear message',
                '4. If all files within single repo → ALLOW',
            ]);

        $this->guideline('repo-classification')
            ->text('Repo classification rules:')
            ->example()->do([
                'root: files NOT in core/ or cli/',
                'core: files starting with core/',
                'cli: files starting with cli/',
            ]);

        $this->guideline('stop-conditions')
            ->text('STOP and reject commit if:')
            ->example()->do([
                'Changes in both root and core/',
                'Changes in both root and cli/',
                'Changes in both core/ and cli/',
                'Any combination spanning 2+ repos',
            ]);

        $this->guideline('evidence-required')
            ->text('Must provide: list of changed files per repo, boundary violation if any.');
    }
}
