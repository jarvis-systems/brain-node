<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillRejectInclude;

#[Meta('id', 'skill:reject')]
#[Meta('description', 'Reject a pending skill proposal with a reason')]
#[Purpose('Log a rejected proposal to history-references/{date}-rejected-{slug}.md with reason and decided_by, then remove the pending folder.')]
#[Includes(SkillRejectInclude::class)]
class RejectCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}