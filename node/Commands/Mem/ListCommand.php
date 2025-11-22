<?php

declare(strict_types=1);

namespace BrainNode\Commands\Mem;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Mem\MemList;

#[Meta('id', 'mem:list')]
#[Meta('description', 'List recent memories chronologically')]
#[Purpose('Lists recent memories in chronological order. Accepts optional limit parameter via $ARGUMENTS (default 10, max 50). Shows previews with category and tags.')]
#[Includes(MemList::class)]
class ListCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}