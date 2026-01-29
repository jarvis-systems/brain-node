<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskDecomposeInclude;

#[Meta('id', 'task:decompose')]
#[Meta('description', 'Decompose large task into subtasks (each <=5-8h)')]
#[Purpose('Split large vector task into 5-8h subtasks with logical execution order.')]
#[Includes(TaskDecomposeInclude::class)]
class DecomposeCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
