<?php

declare(strict_types=1);

namespace BrainNode\Commands;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Purpose;

#[Purpose('Command for test-command')]
class TestCommand extends CommandArchetype
{
    /**
     * Handle the architecture logic.
     */
    protected function handle(): void
    {
        //
    }
}
