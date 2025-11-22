<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskNextInclude;

#[Meta('id', 'task:next')]
#[Meta('description', 'Get next task to execute (in_progress or highest priority pending)')]
#[Purpose('Smart selection of next task to work on. Returns currently in_progress task or highest priority pending task. Shows task details, parent hierarchy, and related vector memory insights. Simple utility command for task workflow.')]
#[Includes(TaskNextInclude::class)]
class NextCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
