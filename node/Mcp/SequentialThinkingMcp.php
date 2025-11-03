<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\StdioMcp;

#[Meta('id', 'sequential-thinking')]
class SequentialThinkingMcp extends StdioMcp
{
    protected static function defaultCommand(): string
    {
        return 'npx';
    }

    protected static function defaultArgs(): array
    {
        return [
            '-y',
            '@modelcontextprotocol/server-sequential-thinking',
        ];
    }
}
