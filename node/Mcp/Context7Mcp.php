<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\StdioMcp;

#[Meta('id', 'context7')]
class Context7Mcp extends StdioMcp
{
    protected static function defaultCommand(): string
    {
        return 'npx';
    }

    protected static function defaultArgs(): array
    {
        return [
            '-y',
            '@upstash/context7-mcp',
            '--api-key',
            'ctx7sk-d066fdcb-bd7e-4e10-acf4-522c7621e2c4',
        ];
    }
}
