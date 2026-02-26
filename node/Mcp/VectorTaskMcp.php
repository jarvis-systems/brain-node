<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\Schemas\VectorTaskSchema;
use BrainCore\Mcp\StdioMcp;
use BrainCore\Mcp\Traits\McpSchemaTrait;

#[Meta('id', 'vector-task')]
class VectorTaskMcp extends StdioMcp
{
    use McpSchemaTrait;

    protected static function getSchemaClass(): string
    {
        return VectorTaskSchema::class;
    }
    public static function defaultCommand(): string
    {
        return 'uvx';
    }

    public static function defaultArgs(): array
    {
        return [
            'vector-task-mcp',
            '--working-dir',
            '.',
            '--timezone',
            'Europe/Kyiv',
        ];
    }
}
