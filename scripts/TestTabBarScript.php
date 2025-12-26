<?php

declare(strict_types=1);

namespace BrainScripts;

use BrainCLI\Console\AiCommands\Lab\Dto\Tab;
use BrainCLI\Console\AiCommands\Lab\TabBar;
use Illuminate\Console\Command;
use ReflectionClass;

use function Laravel\Prompts\error;
use function Laravel\Prompts\info;

class TestTabBarScript extends Command
{
    protected $signature = 'test-tab-bar {--details : Show detailed test output}';

    protected $description = 'Test Tab DTO and TabBar renderer (14 runtime tests)';

    private int $passed = 0;
    private int $failed = 0;

    public function handle(): int
    {
        $this->line("=== TAB DTO TESTS ===\n");

        // Test 1: State transitions
        $this->runTest(1, "State transitions (Active/Error/Completed)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            $tab->markActive();
            if (!$tab->isActive()) return "markActive() failed - isActive() returned false";

            $tab->markError();
            if (!$tab->isError()) return "markError() failed - isError() returned false";

            $tab->markCompleted();
            if ($tab->isError()) return "markCompleted() failed - isError() still true";
            if ($tab->isActive()) return "markCompleted() failed - isActive() still true";

            return true;
        });

        // Test 2: Indicator mapping
        $this->runTest(2, "Indicator mapping (5 states)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            $indicators = [
                'ACTIVE' => '●',
                'INACTIVE' => '○',
                'COMPLETED' => '✓',
                'ERROR' => '✗',
                'HAS_UPDATES' => '◉'
            ];

            foreach ($indicators as $state => $expected) {
                $tab->state = constant(Tab::class . '::STATE_' . $state);
                $actual = $tab->getIndicator();
                if ($actual !== $expected) {
                    return "State $state expected '$expected', got '$actual'";
                }
            }

            return true;
        });

        // Test 3: Content management
        $this->runTest(3, "Content management (addLine/clearContent/getLineCount)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            if ($tab->getLineCount() !== 0) return "Initial line count should be 0";

            $tab->addLine("Line 1");
            $tab->addLine("Line 2");
            if ($tab->getLineCount() !== 2) return "Line count should be 2 after 2 addLine calls";

            $tab->clearContent();
            if ($tab->getLineCount() !== 0) return "Line count should be 0 after clearContent";

            return true;
        });

        // Test 4: Type constants
        $this->runTest(4, "Type constants (4 types exist via reflection)", function() {
            $reflection = new ReflectionClass(Tab::class);
            $constants = $reflection->getConstants();

            $requiredTypes = ['TYPE_MAIN', 'TYPE_PROCESS', 'TYPE_AGENT', 'TYPE_NEW'];
            foreach ($requiredTypes as $type) {
                if (!array_key_exists($type, $constants)) {
                    return "Constant $type not found";
                }
            }

            // Verify constructor sets type
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);
            if ($tab->type !== Tab::TYPE_MAIN) {
                return "Constructor did not set type correctly";
            }

            return true;
        });

        // Test 5: Default values
        $this->runTest(5, "Default values (state=Inactive, scrollPosition=0, metadata=null)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            if ($tab->state !== Tab::STATE_INACTIVE) {
                return "Default state should be INACTIVE, got: " . $tab->state;
            }
            if ($tab->scrollPosition !== 0) {
                return "Default scrollPosition should be 0, got: " . $tab->scrollPosition;
            }
            if ($tab->metadata !== null) {
                return "Default metadata should be null";
            }

            return true;
        });

        // Test 6: State query methods
        $this->runTest(6, "State query methods (isActive/isError/hasUpdates)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            // Initial state: all should be false
            if ($tab->isActive() || $tab->isError() || $tab->hasUpdates()) {
                return "All query methods should return false initially";
            }

            $tab->markActive();
            if (!$tab->isActive() || $tab->isError() || $tab->hasUpdates()) {
                return "Only isActive() should be true after markActive()";
            }

            $tab->markError();
            if ($tab->isActive() || !$tab->isError() || $tab->hasUpdates()) {
                return "Only isError() should be true after markError()";
            }

            $tab->markHasUpdates();
            if ($tab->isActive() || $tab->isError() || !$tab->hasUpdates()) {
                return "Only hasUpdates() should be true after markHasUpdates()";
            }

            return true;
        });

        // Test 7: Fluent API
        $this->runTest(7, "Fluent API (methods return \$this, chaining works)", function() {
            $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);

            // Test that methods return $this
            $result1 = $tab->markActive();
            if ($result1 !== $tab) return "markActive() should return \$this";

            $result2 = $tab->markError();
            if ($result2 !== $tab) return "markError() should return \$this";

            // Test chaining
            $result = $tab->markInactive()->markCompleted();
            if ($result !== $tab) return "Method chaining failed";
            if ($tab->state !== Tab::STATE_COMPLETED) return "Chaining didn't update state correctly";

            return true;
        });

        $this->line("\n=== TABBAR TESTS ===\n");

        // Test 8: Empty tabs handling
        $this->runTest(8, "Empty tabs handling (render([]) doesn't crash)", function() {
            try {
                ob_start();
                TabBar::render([]);
                $output = ob_get_clean();
                return is_string($output);
            } catch (\Throwable $e) {
                return "Exception thrown: " . $e->getMessage();
            }
        });

        // Test 9: Single tab rendering
        $this->runTest(9, "Single tab rendering (type icon + state CSS present)", function() {
            $tab = new Tab(id: 'main', name: 'Main', type: Tab::TYPE_MAIN);
            $tab->markActive();

            ob_start();
            TabBar::render([$tab]);
            $output = ob_get_clean();

            if (!str_contains($output, '[M]')) return "Type icon [M] not found in output";
            if (!str_contains($output, 'bg-cyan-600')) return "Active state CSS not found in output";

            return true;
        });

        // Test 10: Multiple tabs spacing
        $this->runTest(10, "Multiple tabs spacing (3 tabs all present)", function() {
            $tabs = [
                new Tab(id: 'main', name: 'Main', type: Tab::TYPE_MAIN),
                new Tab(id: 'proc', name: 'Process', type: Tab::TYPE_PROCESS),
                new Tab(id: 'agent', name: 'Agent', type: Tab::TYPE_AGENT)
            ];

            ob_start();
            TabBar::render($tabs);
            $output = ob_get_clean();

            if (!str_contains($output, 'Main')) return "Main tab not found";
            if (!str_contains($output, 'Process')) return "Process tab not found";
            if (!str_contains($output, 'Agent')) return "Agent tab not found";

            return true;
        });

        // Test 11: Type icon mapping
        $this->runTest(11, "Type icon mapping (4 type icons)", function() {
            $types = [
                Tab::TYPE_MAIN => '[M]',
                Tab::TYPE_PROCESS => '[P]',
                Tab::TYPE_AGENT => '[@]',
                Tab::TYPE_NEW => '[+]'
            ];

            foreach ($types as $type => $expectedIcon) {
                $tab = new Tab(id: 'test', name: 'Test', type: $type);

                ob_start();
                TabBar::render([$tab]);
                $output = ob_get_clean();

                if (!str_contains($output, $expectedIcon)) {
                    return "Expected icon '$expectedIcon' for type '$type' not found";
                }
            }

            return true;
        });

        // Test 12: State CSS classes
        $this->runTest(12, "State CSS classes (5 states)", function() {
            $states = [
                Tab::STATE_ACTIVE => 'bg-cyan-600',
                Tab::STATE_INACTIVE => 'bg-gray-700',
                Tab::STATE_HAS_UPDATES => 'bg-yellow-600',
                Tab::STATE_ERROR => 'bg-red-600',
                Tab::STATE_COMPLETED => 'bg-green-600'
            ];

            foreach ($states as $state => $expectedCSS) {
                $tab = new Tab(id: 'test', name: 'Test', type: Tab::TYPE_MAIN);
                $tab->state = $state;

                ob_start();
                TabBar::render([$tab]);
                $output = ob_get_clean();

                if (!str_contains($output, $expectedCSS)) {
                    return "Expected CSS '$expectedCSS' for state '$state' not found";
                }
            }

            return true;
        });

        // Test 13: Name truncation
        $this->runTest(13, "Name truncation (short unchanged, long truncated)", function() {
            // Short name (unchanged)
            $shortTab = new Tab(id: 'short', name: 'Short', type: Tab::TYPE_MAIN);
            ob_start();
            TabBar::render([$shortTab]);
            $shortOutput = ob_get_clean();

            if (!str_contains($shortOutput, 'Short')) {
                return "Short name should be unchanged";
            }

            // Long name (truncated) - 19 chars should be truncated to 15 with ellipsis
            $longTab = new Tab(id: 'long', name: 'VeryLongTabNameHere', type: Tab::TYPE_MAIN);
            ob_start();
            TabBar::render([$longTab]);
            $longOutput = ob_get_clean();

            if (!str_contains($longOutput, '…')) {
                return "Long name should be truncated with ellipsis";
            }
            if (str_contains($longOutput, 'VeryLongTabNameHere')) {
                return "Full long name should not appear in output";
            }

            return true;
        });

        // Test 14: Unicode handling
        $this->runTest(14, "Unicode handling (multibyte chars truncate correctly)", function() {
            // Test with emoji (multibyte)
            $emojiTab = new Tab(id: 'emoji', name: '🚀 Rocket Launch Test', type: Tab::TYPE_MAIN);
            ob_start();
            TabBar::render([$emojiTab]);
            $emojiOutput = ob_get_clean();

            // Should contain ellipsis if truncated (name is 21 chars)
            if (!str_contains($emojiOutput, '…')) {
                return "Emoji name should be truncated with ellipsis";
            }

            // Test with Cyrillic (multibyte)
            $cyrillicTab = new Tab(id: 'cyrillic', name: 'Привіт світ тест назва', type: Tab::TYPE_MAIN);
            ob_start();
            TabBar::render([$cyrillicTab]);
            $cyrillicOutput = ob_get_clean();

            // Should be truncated (name is 22 chars)
            if (!str_contains($cyrillicOutput, '…')) {
                return "Cyrillic name should be truncated with ellipsis";
            }

            return true;
        });

        // Summary
        $this->line("\n=== SUMMARY ===");
        info("Passed: {$this->passed}/14");

        if ($this->failed > 0) {
            error("Failed: {$this->failed}/14");
            return 1;
        }

        return 0;
    }

    private function runTest(int $number, string $description, callable $test): void
    {
        $result = $test();

        if ($result === true) {
            $this->passed++;
            info("✓ Test $number: $description");
        } else {
            $this->failed++;
            error("✗ Test $number: $description - FAILED");

            if ($this->option('details')) {
                $this->line("  Error: " . (is_string($result) ? $result : 'Test returned false'));
            }
        }
    }
}