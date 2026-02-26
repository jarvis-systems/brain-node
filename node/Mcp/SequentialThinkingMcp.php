<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\Schemas\SequentialThinkingSchema;
use BrainCore\Mcp\StdioMcp;
use BrainCore\Mcp\Traits\McpSchemaTrait;

#[Meta('id', 'sequential-thinking')]
class SequentialThinkingMcp extends StdioMcp
{
    use McpSchemaTrait;

    protected static function getSchemaClass(): string
    {
        return SequentialThinkingSchema::class;
    }

    public static function defaultCommand(): string
    {
        return 'npx';
    }

    public static function defaultArgs(): array
    {
        return [
            '-y',
            '@modelcontextprotocol/server-sequential-thinking',
        ];
    }
}
