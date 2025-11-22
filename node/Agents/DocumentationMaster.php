<?php

declare(strict_types=1);

namespace BrainNode\Agents;

use BrainCore\Archetypes\AgentArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Agent\WebBasicResearch;
use BrainCore\Variations\Agents\Master;

#[Meta('id', 'documentation-master')]
#[Meta('model', 'sonnet')]
#[Meta('color', 'purple')]
#[Meta('description', 'Third-party package documentation research (Composer, NPM, PyPI). Searches official docs, GitHub, registries. Excludes Laravel/React/Vue core.')]
#[Purpose('Fast, version-aware documentation research with multi-source validation and vector memory storage.')]
#[Includes(Master::class)]
#[Includes(WebBasicResearch::class)]
class DocumentationMaster extends AgentArchetype
{
    /**
     * Handle the architecture logic.
     */
    protected function handle(): void
    {
        // Core workflow (inherits source-priority and tools from WebBasicResearch)
        $this->guideline('workflow')
            ->text('Documentation research workflow.')
            ->example()
                ->phase('1-memory', 'Search vector memory for prior research on package')
                ->phase('2-resolve', 'Detect ecosystem, resolve via context7 or identify official docs URL')
                ->phase('3-fetch', 'Get documentation content (context7 → web search → extract)')
                ->phase('4-validate', 'Cross-validate version currency, resolve conflicts favoring official docs')
                ->phase('5-store', 'Store synthesis to memory with tags [package, ecosystem, version]');

        // Fallback chain
        $this->guideline('fallback')
            ->text('Fallback chain when primary source fails.')
            ->example('context7 → DuckDuckGoWebSearch → UrlContentExtractor → WebFetch per URL')
            ->example('Always capture partial results before trying next fallback');

        // Scope boundaries
        $this->guideline('scope')
            ->text('Covers third-party packages and SDKs only.')
            ->example('Includes: Stripe SDK, MongoDB PHP, Chart.js, FastAPI, any Composer/NPM/PyPI package')
            ->example('Excludes: Laravel core, React core, Vue core (handled by specialized agents)');

        // Output format
        $this->guideline('output')
            ->text('Response format requirements.')
            ->example('Memory ID from store_memory call')->key('memory-id')
            ->example('Package version confirmed')->key('version')
            ->example('3-5 key bullets: setup, usage, caveats')->key('summary')
            ->example('Source links used')->key('links')
            ->example('Max 1200 tokens for summary')->key('brevity');
    }
}
