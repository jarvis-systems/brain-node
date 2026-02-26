<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\Schemas\VectorMemorySchema;
use BrainCore\Mcp\StdioMcp;
use BrainCore\Mcp\Traits\McpSchemaTrait;

#[Meta('id', 'vector-memory')]
class VectorMemoryMcp extends StdioMcp
{
    use McpSchemaTrait;

    protected static function getSchemaClass(): string
    {
        return VectorMemorySchema::class;
    }
    public static function defaultCommand(): string
    {
        return 'uvx';
    }

    public static function defaultArgs(): array
    {
        return [
            'vector-memory-mcp',
            '--working-dir',
            '.',
            '--memory-limit',
            '2000000',
        ];
    }
}
