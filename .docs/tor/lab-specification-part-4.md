---
name: "Brain Lab Specification - Part 4: Extensions"
description: "Screen system, command registration, validation, and extension API"
part: 4
type: "tor"
date: "2025-12-17"
version: "1.0.0"
---

# Brain Lab Specification

## Part 4: Screen System and Extensions

---

## 1. Screen Architecture

### 1.1 Overview

Screens are the primary extension mechanism for Brain Lab. Each screen:

- Handles one or more commands
- Has access to workspace, context, and other screens
- Can spawn processes and interact with other components
- Auto-discovered via reflection

### 1.2 Screen Hierarchy

```
ScreenAbstract (base class)
├── Properties
│   ├── name: string          # Command name (e.g., "var")
│   ├── title: string         # Display title
│   ├── description: string   # Help text
│   ├── argumentDescription   # Argument format hint
│   ├── options: array        # Predefined options
│   └── detectRegexp: string  # Pattern matching
│
├── Methods
│   ├── main(Context, ...args): Context  # Entry point
│   ├── validateArguments(string, Context): bool|string|array
│   ├── options(...args): array          # Dynamic autocomplete
│   ├── command(): LabCommand            # Parent command
│   ├── screen(): Screen                 # REPL orchestrator
│   └── workspace(): WorkSpace           # Variables
│
└── Implementations
    ├── Variable    # /var command
    ├── Str         # /str-* commands
    ├── Help        # /help command
    ├── Evaluate    # /e command
    └── [Custom]    # User screens
```

### 1.3 Auto-Discovery

Screens are discovered at runtime:

```php
// In LabCommand
public function screens(): Collection
{
    $classes = Attributes::new()
        ->wherePath(implode(DS, [__DIR__, 'Lab', 'Screens']))
        ->classes();

    return $classes->filter(
        fn ($ref) => $ref->isSubclassOf(ScreenAbstract::class)
    )->map(
        fn ($ref) => $ref->newInstance()->setMeta([
            'command' => $this,
            'screen' => $this->screen,
            'workspace' => $this->workSpace,
        ])
    );
}
```

---

## 2. Creating Screens

### 2.1 Basic Screen Template

```php
<?php

declare(strict_types=1);

namespace BrainCLI\Console\AiCommands\Lab\Screens;

use BrainCLI\Console\AiCommands\Lab\Abstracts\ScreenAbstract;
use BrainCLI\Console\AiCommands\Lab\Dto\Context;

class MyCommand extends ScreenAbstract
{
    public function __construct()
    {
        parent::__construct(
            name: 'mycommand',           // Command: /mycommand
            title: 'My Command',         // Tab title
            description: 'Does something useful',
            argumentDescription: '<arg>',// Hint: /mycommand <arg>
        );
    }

    public function main(Context $context, string $arg): Context
    {
        // Command logic here
        $result = $this->doSomething($arg);

        return $context->result(['output' => $result]);
    }

    private function doSomething(string $arg): string
    {
        return "Processed: {$arg}";
    }
}
```

### 2.2 Pattern-Matching Screen

For commands with dynamic names (e.g., `/str-upper`, `/str-lower`):

```php
public function __construct()
{
    parent::__construct(
        name: 'str',
        title: 'String Functions',
        description: 'Illuminate\\Support\\Str methods',
        detectRegexp: '/^str\-([a-zA-Z\d\-\_\.]+)$/'
    );
}

public function main(Context $context, mixed $methodName, mixed $value, ...$args): Context
{
    // $methodName captured from regex group 1
    if (method_exists(Str::class, $methodName)) {
        $result = Str::{$methodName}($value, ...$args);
        return $context->result($result, append: true);
    }

    return $context->error("Method '{$methodName}' not found");
}
```

### 2.3 Screen with Autocomplete Options

```php
public function options(string ...$args): array
{
    // Return options for autocomplete
    return [
        'option1' => 'Description of option 1',
        'option2' => 'Description of option 2',
        'option3' => 'Description of option 3',
    ];
}

// Called when user types: /mycommand opt[TAB]
// Shows: option1, option2, option3
```

### 2.4 Dynamic Options Based on Arguments

```php
public function options(string $arg1 = '', string $arg2 = ''): array
{
    if ($arg1 === '') {
        // First argument options
        return [
            'create' => 'Create new item',
            'delete' => 'Delete item',
            'list' => 'List all items',
        ];
    }

    if ($arg1 === 'delete' && $arg2 === '') {
        // Show existing items for deletion
        return $this->workspace()->dotsVariables();
    }

    return [];
}
```

---

## 3. Argument Validation

### 3.1 validateArguments Method

```php
public function validateArguments(
    string|null $argument,
    Context $response
): bool|string|array
```

**Return values:**

| Return | Meaning |
|--------|---------|
| `true` | No arguments, valid |
| `false` | Invalid arguments |
| `string` | Error message |
| `array` | Parsed arguments (passed to `main()`) |

### 3.2 Built-in Argument Parsing

The base class provides comprehensive parsing:

```php
// Input: name="John" age=30 email=$this.email --active
// Parses to:
[
    'name' => 'John',
    'age' => 30,
    'email' => '<value from context>',
    'active' => true
]
```

**Supported formats:**

| Format | Result |
|--------|--------|
| `value` | Positional argument |
| `key=value` | Named argument |
| `"quoted string"` | String with spaces |
| `--flag` | Boolean flag (true) |
| `$variable` | Variable interpolation |
| `$this.field` | Context field access |
| `42` | Integer |
| `3.14` | Float |
| `true/false` | Boolean |
| `null` | Null value |
| `[1,2,3]` | JSON array |
| `{"a":1}` | JSON object |

### 3.3 Custom Validation

```php
public function validateArguments(string|null $argument, Context $response): bool|string|array
{
    // Call parent for basic parsing
    $args = parent::validateArguments($argument, $response);

    if (is_string($args)) {
        return $args; // Error from parent
    }

    if (!is_array($args)) {
        $args = [];
    }

    // Custom validation
    if (!isset($args[0])) {
        return "First argument is required";
    }

    if (!is_string($args[0]) || strlen($args[0]) < 3) {
        return "First argument must be at least 3 characters";
    }

    // Add computed values
    $args['computed'] = strtoupper($args[0]);

    return $args;
}
```

### 3.4 Command Chaining in Arguments

Arguments can include command chains:

```bash
/mycommand << /str-upper "hello" << /var result $this
```

The `<<` operator executes commands left-to-right, passing results via context.

---

## 4. Context DTO

### 4.1 Properties

```php
class Context extends Dto
{
    public function __construct(
        protected array|null $result = null,      // Command result
        protected array|null $info = null,        // Info messages (transient)
        protected array|null $error = null,       // Error messages (transient)
        protected array|null $success = null,     // Success messages (transient)
        protected array|null $warning = null,     // Warning messages (transient)
        protected array|null $nextVariants = null,// Autocomplete suggestions
        protected string|null $nextCommand = null,// Pre-fill input
        protected string|bool $pause = false,     // Pause before continue
        protected array $processes = [],          // Deferred processes
    ) {}
}
```

### 4.2 Fluent Methods

```php
// Set result (replaces or appends)
$context->result(['key' => 'value'], append: false);
$context->result(['more' => 'data'], append: true);

// Messages
$context->error('Something went wrong');
$context->success('Operation completed');
$context->warning('Check this');
$context->info('FYI');

// Flow control
$context->nextCommand('/suggested-command');
$context->nextVariants(['option1', 'option2']);
$context->pause('Press Enter to continue...');

// Processes
$context->process('name', ScreenClass::class, 'method', ...$args);
```

### 4.3 Merging Contexts

```php
// Full merge
$context->merge($otherContext);

// Selective merge
$context->merge($otherContext,
    result: true,
    info: false,
    error: true,
    success: false,
    warning: false,
    next: false,
    pause: false,
    processes: true,
);

// General merge (result + processes only)
$context->mergeGeneral($otherContext);
```

### 4.4 Context Persistence

Context auto-saves on changes:

```php
$response = Context::fromEmpty()
    ->setMeta(['onChange' => function (Context $response) {
        $this->saveResponse($response);
    }]);
```

---

## 5. WorkSpace API

### 5.1 Variable Operations

```php
// Set variable (supports dot notation)
$this->workspace()->setVariable('user.name', 'John');
$this->workspace()->setVariable('items', [1, 2, 3]);

// Get variable
$name = $this->workspace()->getVariable('user.name');
$items = $this->workspace()->getVariable('items', []); // with default

// Delete variable
$this->workspace()->forgetVariable('user.name');

// Get all as flat array
$all = $this->workspace()->dotsVariables();
// ['user.name' => 'John', 'items.0' => 1, ...]
```

### 5.2 States (Reserved)

```php
// For future use - storing complex state
public array $states = [];
```

---

## 6. Built-in Screens Reference

### 6.1 Variable Screen

```
/var name                    # Get variable
/var name "value"           # Set variable
/var name --del              # Delete variable
/var this.field             # Access result field
/var this.field "value"     # Set result field
```

### 6.2 Str Screen

```
/str-upper "text"           # UPPERCASE
/str-lower "TEXT"           # lowercase
/str-slug "Some Title"      # some-title
/str-camel "some_thing"     # someThing
/str-snake "someThing"      # some_thing
/str-contains "text" "ex"   # true
/str-length "text"          # 4
/str-replace "old" "new" $this
```

### 6.3 Evaluate Screen

```
/e /command args             # Execute command
/e !shell command           # Execute shell
/e $variable                # Get variable
/e command --isolated       # Isolated execution
```

### 6.4 Help Screen

```
/help                        # Show all commands
/help command               # Show command help
```

---

## 7. New Screens to Implement

### 7.1 Process Screen

```
/proc                        # List processes
/proc create !command       # Create process
/proc {id}                  # Switch to process
/proc kill {id}             # Kill process
/proc pause {id}            # Pause process
/proc resume {id}           # Resume process
/proc logs {id}             # View logs
```

### 7.2 Transform Screen

```
/transform upper            # Uppercase result
/transform json             # To JSON
/transform keys             # Array keys
/transform filter key=val   # Filter array
/transform pluck field      # Extract field
```

### 7.3 Agent Screen

```
/agent claude "prompt"      # Call Claude
/agent explore "query"      # Explore codebase
/agent list                 # List agents
```

### 7.4 Experiment Screen

```
/exp                         # Current experiment
/exp save "description"     # Save version
/exp load name              # Load experiment
/exp list                   # List experiments
/exp rollback v2            # Rollback to version
/exp delete name            # Delete experiment
```

### 7.5 Config Screen

```
/config                      # Show all config
/config key                 # Get config value
/config key value           # Set config value
/config reset               # Reset to defaults
```

---

## 8. Screen Communication

### 8.1 Calling Other Screens

```php
public function main(Context $context, string $arg): Context
{
    // Submit command through REPL
    return $this->screen()->submit($context, "/other-command {$arg}");
}
```

### 8.2 Direct Screen Access

```php
public function main(Context $context, string $arg): Context
{
    $screens = $this->command()->screens();
    $varScreen = $screens->first(fn($s) => $s->name === 'var');

    if ($varScreen) {
        return $varScreen->main($context, $arg, 'value');
    }

    return $context->error('Screen not found');
}
```

### 8.3 Spawning Processes

```php
public function main(Context $context, string $url): Context
{
    // Spawn background process
    $context->process(
        name: 'data-fetch',
        screenClass: self::class,
        screenMethod: 'fetchData',
        $url
    );

    return $context->success('Process started');
}

public function fetchData(Context $context, string $url): Context
{
    // This runs in separate process
    $data = Http::get($url)->json();
    return $context->result($data);
}
```

---

## 9. UI Integration

### 9.1 Output Methods

```php
// Via command output components
$this->line('Plain text');
$this->info('Info message');
$this->success('Success message');
$this->error('Error message');
$this->warn('Warning message');

// Table output
$this->twoColumnDetail('Key', 'Value');

// Bullet list
$this->bulletList(['Item 1', 'Item 2']);
```

### 9.2 Interactive Prompts

```php
// Confirmation
if ($this->confirm('Are you sure?')) {
    // proceed
}

// Input
$name = $this->ask('Enter name');

// Choice
$option = $this->choice('Select option', ['A', 'B', 'C']);
```

### 9.3 Progress Display

```php
// Task with progress
$this->task('Processing items', function () {
    // do work
    return true; // or false for failure
});
```

---

## 10. Error Handling

### 10.1 In Screens

```php
public function main(Context $context, string $arg): Context
{
    try {
        $result = $this->riskyOperation($arg);
        return $context->result($result);
    } catch (ValidationException $e) {
        return $context->error($e->getMessage())
            ->nextCommand("/mycommand {$arg}"); // Pre-fill for retry
    } catch (\Throwable $e) {
        if (Brain::isDebug()) {
            dd($e); // Full debug in debug mode
        }
        return $context->error("Operation failed: " . $e->getMessage());
    }
}
```

### 10.2 In Screen.php

```php
try {
    $response = $commandDetails->main($response, ...$validateArguments);
} catch (\Throwable $e) {
    if (Brain::isDebug()) {
        dd($e);
    }
    $response->error("Error executing '{$command}': " . $e->getMessage())
        ->nextCommand($modifier.$direction.$command, $argument);
}
```

---

## 11. Implementation Gaps

### 11.1 Missing Screens

| Screen | Priority | Complexity |
|--------|----------|------------|
| Process | Critical | High |
| Transform | High | Medium |
| Agent | High | High |
| Experiment | High | Medium |
| Config | Medium | Low |

### 11.2 Missing Features

| Feature | Priority |
|---------|----------|
| Screen dependencies | Medium |
| Screen hooks (before/after) | Low |
| Screen aliases | Low |
| Screen groups | Low |
| Lazy loading | Low |

See Part 5 for experiment system and roadmap.