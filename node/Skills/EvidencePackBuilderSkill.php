<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'evidence-pack-builder')]
#[Meta('description', 'Formats evidence packs consistently with live command output for EVIDENCE-ONLY reports')]
#[Purpose(<<<'PURPOSE'
Builds structured evidence packs from live command execution.
Every claim must be backed by actual command output.
Enforces EVIDENCE-ONLY contract: no speculation, no assumptions.
PURPOSE
)]
class EvidencePackBuilderSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('contract')
            ->text('EVIDENCE-ONLY mode: every row MUST have live command output.')
            ->goal('Zero speculation, zero assumptions, 100% verifiable.');

        $this->guideline('structure')
            ->text('Evidence pack structure:')
            ->example()->do([
                '## Section Name',
                '```bash',
                'command --executed',
                '```',
                '```',
                'actual output from command',
                '```',
                '**Verdict**: PASS/FAIL based on output',
            ]);

        $this->guideline('stop-conditions')
            ->text('STOP immediately if:')
            ->example()->do([
                'Command returns non-zero exit code',
                'Output is missing or truncated',
                'Cannot verify claim from actual output',
            ]);

        $this->guideline('output')
            ->text('Return structured evidence pack with: section, command, output, verdict.');
    }
}
