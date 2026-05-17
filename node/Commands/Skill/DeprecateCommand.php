<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillDeprecateInclude;

#[Meta('id', 'skill:deprecate')]
#[Meta('description', 'Deprecate an existing skill')]
#[Purpose('One-arg interactive command. Asks the user for a deprecation reason plus an optional replacement skill id, builds a frontmatter patch adding deprecated: true (and replacement when given) to node/Skills/{name}/SKILL.md, then writes the pending proposal via the shared triage + write pipeline as a deprecate-skill proposal.')]
#[Includes(SkillDeprecateInclude::class)]
class DeprecateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}