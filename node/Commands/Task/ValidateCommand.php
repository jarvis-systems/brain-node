<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskValidateInclude;

#[Meta('id', 'task:validate')]
#[Meta('description', 'Validate task execution command')]
#[Purpose('Validate tasks')]
#[Includes(TaskValidateInclude::class)]
class ValidateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
