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
            '***REMOVED***',
        ];
    }
}
