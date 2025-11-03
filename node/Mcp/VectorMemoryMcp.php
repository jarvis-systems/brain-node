<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\StdioMcp;

#[Meta('id', 'vector-memory')]
class VectorMemoryMcp extends StdioMcp
{
    protected static function defaultCommand(): string
    {
        return 'uvx';
    }

    protected static function defaultArgs(): array
    {
        return [
            'vector-memory-mcp',
            '--working-dir',
            '/Users/xsaven/PhpstormProjects/jarvis-brain-node',
        ];
    }
}
