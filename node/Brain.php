<?php

declare(strict_types=1);

namespace BrainNode;

use BrainCore\Archetypes\BrainArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Universal\EvidenceContractInclude;
use BrainCore\Variations\Brain\Scrutinizer;

#[Meta('id', 'brain-core')]
#[Purpose('Two-package AI agent orchestration system — declarative PHP configuration compiled to multi-target output (XML/JSON/YAML/TOML) for Claude, Codex, Qwen, Gemini agents. Compile-time single-mode architecture with deterministic builds, schema validation, and enterprise CI gates.')]

#[Includes(Scrutinizer::class)]         // Include the Scrutinizer brain variation
#[Includes(EvidenceContractInclude::class)]
class Brain extends BrainArchetype
{
    /**
     * Handle the architecture logic.
     *
     * @return void
     */
    protected function handle(): void
    {
        // Brain orchestration logic can be added here if needed
    }
}
