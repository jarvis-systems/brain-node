<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\StdioMcp;

#[Meta('id', 'mock-echo')]
class MockEchoMcp extends StdioMcp
{
    public static function defaultCommand(): string
    {
        return 'php';
    }
    public static function defaultArgs(): array
    {
        return [
            'scripts/mock-mcp-server.php',
        ];
    }
}
