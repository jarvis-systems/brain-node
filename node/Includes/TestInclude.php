<?php

declare(strict_types=1);

namespace BrainNode\Includes;

use BrainCore\Archetypes\IncludeArchetype;
use BrainCore\Attributes\Purpose;

#[Purpose('Include for test-include')]
class TestInclude extends IncludeArchetype
{
    /**
     * Handle the architecture logic.
     */
    protected function handle(): void
    {
        //
    }
}
