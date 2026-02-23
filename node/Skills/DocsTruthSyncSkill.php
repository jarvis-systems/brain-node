<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'docs-truth-sync')]
#[Meta('description', 'Classifies documentation as current-state vs frozen/historical and ensures sync')]
#[Purpose(<<<'PURPOSE'
Validates documentation accuracy by classifying docs into categories.
Distinguishes living documents (must match reality) from frozen snapshots.
Prevents stale documentation from misleading agents.
PURPOSE
)]
class DocsTruthSyncSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('classification')
            ->text('Documentation classification:')
            ->example()->do([
                'LIVING: Must reflect current state (e.g., snapshot reports, runbooks)',
                'FROZEN: Historical record, immutable (e.g., meeting notes, decisions)',
                'REFERENCE: Timeless patterns, architecture docs',
            ]);

        $this->guideline('living-doc-check')
            ->text('For LIVING documents, verify:')
            ->example()->do([
                'File existence matches documented paths',
                'Command outputs match documented examples',
                'Version numbers match actual releases',
                'Gate counts match audit output',
            ]);

        $this->guideline('stop-conditions')
            ->text('STOP if LIVING doc has:')
            ->example()->do([
                'References to deleted files',
                'Commands that no longer exist',
                'Version mismatches > 1 minor version',
                'Gate counts off by > 10%',
            ]);

        $this->guideline('evidence-required')
            ->text('Provide: doc classification, verification results, drift summary if any.');
    }
}
