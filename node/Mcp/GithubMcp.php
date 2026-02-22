<?php

declare(strict_types=1);

namespace BrainNode\Mcp;

use BrainCore\Attributes\Meta;
use BrainCore\Mcp\HttpMcp;

#[Meta('id', 'github')]
class GithubMcp extends HttpMcp
{
    protected static function defaultUrl(): string
    {
        return 'https://api.githubcopilot.com/mcp';
    }

    protected static function defaultHeaders(): array
    {
        return [
            'Authorization' => 'Bearer ' . (getenv('GITHUB_MCP_TOKEN') ?: ''),
            'X-MCP-Toolsets' => 'issues',
        ];
    }
}
