<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillReviewInclude;

#[Meta('id', 'skill:review')]
#[Meta('description', 'Show a pending proposal\'s diff and metadata')]
#[Purpose('Render proposal.json fields plus the unified diff (SKILL.md.patch) or full-content draft (SKILL.md.new) so the reviewer can decide apply vs reject.')]
#[Includes(SkillReviewInclude::class)]
class ReviewCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}