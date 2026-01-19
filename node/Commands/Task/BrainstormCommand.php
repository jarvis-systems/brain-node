<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskBrainstormInclude;

#[Meta('id', 'task:brainstorm')]
#[Meta('description', 'Collaborative brainstorming session anchored to a vector task. Loads task context, prompts for topic, facilitates ideation with research delegation and optional task creation.')]
#[Purpose('Facilitates structured brainstorming for vector tasks. Loads task by ID, asks user for discussion topic, then provides collaborative ideation with agent delegation for research (web, code, docs) and ability to create subtasks from brainstorm outcomes.')]
#[Includes(TaskBrainstormInclude::class)]
class BrainstormCommand extends CommandArchetype
{
    protected function handle(): void
    {
        // Logic defined in TaskBrainstormInclude
    }
}
