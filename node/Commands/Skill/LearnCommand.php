<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillLearnInclude;

#[Meta('id', 'skill:learn')]
#[Meta('description', 'Auto-detect skill candidate patterns in current session')]
#[Purpose('Zero-arg command. Brain scans current session signals (git, recent tasks, recent memory, conversation), surfaces 1-5 candidate patterns, lets the user pick, then auto-derives action/target/rationale/evidence/confidence and writes a pending proposal via the shared triage + write pipeline. Replaces the legacy /skill:propose god-command for "Brain wants to record an insight" flow.')]
#[Includes(SkillLearnInclude::class)]
class LearnCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}