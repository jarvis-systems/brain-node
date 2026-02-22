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
        $apiKey = getenv('CONTEXT7_API_KEY');

        return array_filter([
            '-y',
            '@upstash/context7-mcp',
            ...($apiKey ? ['--api-key', $apiKey] : []),
        ]);
    }
}
