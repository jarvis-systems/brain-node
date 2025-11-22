<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\StdioMcp;

#[Meta('id', 'laravel-boost')]
class LaravelBoostMcp extends StdioMcp
{
    protected static function defaultCommand(): string
    {
        return 'php';
    }

    protected static function defaultArgs(): array
    {
        return [
            '/Users/xsaven/PhpstormProjects/getorder/customers/artisan',
            'boost:mcp',
        ];
    }
}
