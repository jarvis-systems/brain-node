<?php

declare(strict_types=1);

namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'client-format-triage')]
#[Meta('description', 'Interprets verify-client-formats.sh output and provides remediation guidance')]
#[Purpose(<<<'PURPOSE'
Analyzes client format verification output to diagnose issues.
Maps FAIL cases to specific remediation actions.
Provides actionable guidance for format drift correction.
PURPOSE
)]
class ClientFormatTriageSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('triage-sequence')
            ->text('Client format triage sequence:')
            ->example()->do(
                '1. Run: bash scripts/verify-client-formats.sh',
                '2. Parse output for [FAIL] markers',
                '3. Classify failure type by pattern',
                '4. Map to remediation action',
            );

        $this->guideline('failure-patterns')
            ->text('Common failure patterns and fixes:')
            ->example()->do(
                'missing YAML front matter → Add --- header with name/description',
                'wrong file extension → Rename or regenerate',
                'bare model ID → Translate alias via client enum',
                'empty skills dir → Add at least 1 skill',
                'missing trust_level → Add to .codex/config.toml',
            );

        $this->guideline('client-specific-notes')
            ->text('Client-specific format requirements:')
            ->example()->do(
                'Claude: .md files, flat skills/',
                'OpenCode: .md files, flat skills/, provider/model IDs',
                'Codex: .md prompts, .agents/skills/*/SKILL.md',
                'Gemini/Qwen: .toml commands, .md skills',
            );

        $this->guideline('evidence-required')
            ->text('Provide: raw FAIL output, classified issue type, remediation command.');
    }
}
