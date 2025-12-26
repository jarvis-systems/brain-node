---
name: "Brain Lab Specification - Part 1: Core"
description: "Overview, architecture, and DSL syntax for the Brain Lab interactive environment"
part: 1
type: "tor"
date: "2025-12-17"
version: "1.0.0"
---

# Brain Lab Specification

## Part 1: Core Architecture and DSL

---

## 1. Overview

### 1.1 Purpose

Brain Lab is an interactive CLI environment for:

- **Data manipulation** - Transform, filter, and process data through command chains
- **Process orchestration** - Spawn, monitor, and control background processes
- **Experiment management** - Save, version, and replay workflows
- **Agent interaction** - Interface with AI agents through dedicated syntax
- **Real-time monitoring** - Live updates of process status and outputs

### 1.2 Design Principles

| Principle | Description |
|-----------|-------------|
| **Composability** | Commands pipe into each other via `<<` chains |
| **Persistence** | Context and processes survive restarts |
| **Extensibility** | Screen-based plugin architecture |
| **Real-time** | ReactPHP event loop for async operations |
| **Keyboard-first** | Full navigation via keyboard shortcuts |

### 1.3 Technology Stack

| Component | Technology |
|-----------|------------|
| Runtime | PHP 8.2+ |
| Async I/O | ReactPHP (react/event-loop, react/child-process) |
| Terminal UI | Termwind (HTML-like rendering) |
| Input handling | Custom CommandLinePrompt with dual menus |
| Process management | Symfony Process + ReactPHP async |
| Data persistence | JSON files per workspace |

---

## 2. Architecture

### 2.1 High-Level Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        Brain Lab                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Tab Bar    │  │  Process 1  │  │  Process 2  │ ...   │  │
│  │  [Main][P1][P2]                                        │  │
│  └─────────────┴──┴─────────────┴──┴─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Content Area                       │   │
│  │  ┌────────────────────┐  ┌────────────────────────┐  │   │
│  │  │   Variables Panel  │  │     Result Panel       │  │   │
│  │  │   $name: "John"    │  │   [command output]     │  │   │
│  │  │   $count: 42       │  │                        │  │   │
│  │  └────────────────────┘  └────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐   │
│  │ > /command argument << /chain                        │   │
│  │   [autocomplete menu] or [history menu]              │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  │ & 0 │ $ 5 │ P: 2/3 │ Mem 1.2KB │ Time 14:32:05 │        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Diagram

```
LabCommand (entry point)
│
├── Screen (REPL orchestrator)
│   ├── CommandLinePrompt (input with autocomplete + history)
│   ├── ProcessManager (async process pool)
│   └── Renderer (Termwind-based UI)
│
├── WorkSpace (persistent variables)
│   └── workspace.json
│
├── Context (request/response DTO)
│   └── runtime.json
│
├── ProcessPool
│   ├── Process instances (Symfony/ReactPHP)
│   └── process-{id}.json (per-process state)
│
└── Screens/ (command implementations)
    ├── Variable.php
    ├── Str.php
    ├── Process.php
    ├── Agent.php
    └── [extensions]
```

### 2.3 Event Loop Integration

```php
// ReactPHP loop runs continuously
$loop = Loop::get();

// STDIN handling (async)
$stdin = new ReadableResourceStream(STDIN, $loop);
$stdin->on('data', fn($data) => $prompt->handleInput($data));

// Process output handling (async)
foreach ($processes as $process) {
    $process->stdout->on('data', fn($data) => $this->appendOutput($data));
}

// Periodic refresh (status bar, process status)
$loop->addPeriodicTimer(1.0, fn() => $this->refreshUI());

// Run loop
$loop->run();
```

---

## 3. DSL Syntax

### 3.1 Direction Prefixes

Brain Lab uses prefix characters to route commands to different handlers:

| Prefix | Name | Handler | Example |
|--------|------|---------|---------|
| `/` | Screen command | Screen classes | `/help`, `/var name value` |
| `!` | Shell command | Symfony Process | `!npm run test` |
| `$` | Variable access | WorkSpace | `$myvar`, `$user.email` |
| `@` | Extension prefix | Screen classes (reserved) | `@custom "argument"` |
| `#` | Comment/Note | Logger Screen | `#note TODO: refactor` |
| `^` | Pipe/Transform | Transform Screen | `^upper`, `^json`, `^filter:key` |

**Note:** All directions except `!` and `$` route to Screen classes. The prefix determines which Screen handles the command. New directions can be added by implementing corresponding Screen classes.

### 3.2 Modifiers

Modifiers change how commands execute:

| Modifier | Position | Effect | Example |
|----------|----------|--------|---------|
| `+` | Before direction | Accumulate (append) result | `+!echo test` |
| `&` | Before direction | Debug/isolated mode | `&/str-upper "text"` |
| `*` | Wrap command | Parallel execution | `*(!cmd1)(!cmd2)` |

### 3.3 Command Format

```
[modifier][direction]command [arguments]
```

**Examples:**

```bash
/help                      # Show help
/var name "John Doe"       # Set variable
+!git status               # Shell command, append result
$this.email                # Access current result field
+/str-upper "hello"        # Transform string, append
@claude "What is 2+2?"     # Call AI agent
^json                      # Transform result to JSON
#note This is a comment    # Add note to log
```

### 3.4 Variable Syntax

**Workspace Variables:**
```bash
$varname                   # Get variable value
$user.name                 # Nested access (dot notation)
$items.0                   # Array index access
```

**Current Result Access:**
```bash
$this                      # Entire current result
$this.field                # Field from current result
$this.user.email           # Nested field access
```

### 3.5 Command Chaining

Commands can be chained using `<<` operator:

```bash
/var name "value" << /str-upper $name << /var result $this
```

**Execution order:** Left to right. Each command receives context from previous.

**Chain semantics:**
1. Execute first command
2. Pass result to next command via context
3. Continue until chain ends
4. Final result displayed

### 3.6 Parallel Execution

Execute multiple commands simultaneously:

```bash
*(!npm run build)(!npm run test)(!npm run lint)
```

**Syntax:** `*(direction command)(direction command)...`

**Behavior:**
- All commands start immediately
- Results merged into single response
- First modifier applies to all (e.g., `+*` for accumulate)
- Progress shown for each parallel task

### 3.7 Array Slicing

Manipulate array results with slice operators:

| Operator | Effect | Example |
|----------|--------|---------|
| `-N` | Remove last N elements | `-3` removes last 3 |
| `--N` | Remove first N elements | `--2` removes first 2 |
| `-0` | Clear result | `-0` empties result |

---

## 4. Argument Parsing

### 4.1 Type Conversion

Arguments are automatically converted:

| Input | Type | Result |
|-------|------|--------|
| `42` | int | `42` |
| `3.14` | float | `3.14` |
| `true` | bool | `true` |
| `false` | bool | `false` |
| `null` | null | `null` |
| `"text"` | string | `"text"` |
| `[1,2,3]` | array | `[1, 2, 3]` (JSON) |
| `{"a":1}` | array | `['a' => 1]` (JSON) |

### 4.2 Named Arguments

Use `key=value` syntax:

```bash
/command name="John" age=30 active=true
```

**Result:** `['name' => 'John', 'age' => 30, 'active' => true]`

### 4.3 Flags

Boolean flags with `--` prefix:

```bash
/command --verbose --force
```

**Result:** `['verbose' => true, 'force' => true]`

### 4.4 Variable Interpolation

Variables expand in arguments:

```bash
/command $varname $this.field
```

**Resolution order:**
1. `$this.*` - Current result
2. `$name` - Workspace variable

---

## 5. Transform Pipes (^)

Transform pipes modify the current result in-place.

### 5.1 Built-in Transforms

| Pipe | Description | Example |
|------|-------------|---------|
| `^upper` | Uppercase string | `^upper` |
| `^lower` | Lowercase string | `^lower` |
| `^json` | Convert to JSON | `^json` |
| `^array` | Convert to array | `^array` |
| `^keys` | Get array keys | `^keys` |
| `^values` | Get array values | `^values` |
| `^count` | Count elements | `^count` |
| `^first` | First element | `^first` |
| `^last` | Last element | `^last` |
| `^reverse` | Reverse array | `^reverse` |
| `^sort` | Sort array | `^sort` |
| `^unique` | Remove duplicates | `^unique` |
| `^flatten` | Flatten nested array | `^flatten` |

### 5.2 Parameterized Transforms

```bash
^filter:status=active      # Filter by field
^pluck:name                 # Extract field from each item
^take:5                     # Take first 5 elements
^skip:10                    # Skip first 10 elements
^chunk:3                    # Split into chunks of 3
^map:fieldname              # Map to field
```

### 5.3 Chained Transforms

```bash
^filter:active=true ^pluck:name ^sort ^unique
```

---

## 6. Extension Direction (@)

### 6.1 Overview

The `@` prefix is a **reserved direction** that routes to Screen classes, identical to `/`. It exists for semantic separation - use `@` for extensions that feel like "external calls" (agents, APIs, services).

### 6.2 Syntax

```bash
@screen-name "argument"
@screen-name $variable
@screen-name << /command-for-context
```

### 6.3 Implementation

The `@` direction is handled by Screen classes registered with `@` prefix:

```php
// In Screen.php commandDirection()
'@' => (function () use ($command, $argument, &$response) {
    // Route to Screen class that handles @{command}
    // Same logic as '/' direction
})(),
```

### 6.4 Use Cases

Screen developers can use `@` prefix for:
- AI agent wrappers (implemented as Screen)
- External API calls
- Service integrations
- Any extension that feels like "calling something external"

**Note:** Lab core does NOT implement any `@` handlers. All `@` functionality comes from user-created Screen classes.

---

## 7. Comments (#)

### 7.1 Syntax

```bash
#note This is a note         # Add note to session log
#todo Fix this later         # Add TODO marker
#tag:important               # Tag current result
```

### 7.2 Usage

- Comments are logged but don't affect result
- Can be used for documentation within workflows
- Tags can filter/search session history

---

## 8. Error Handling

### 8.1 Error Display

Errors appear in dedicated message area:
- Red background for errors
- Yellow for warnings
- Green for success messages

### 8.2 Error Recovery

On error:
1. Command preserved in input (can edit and retry)
2. Context unchanged (no partial updates)
3. Error message displayed
4. History not updated for failed commands

### 8.3 Debug Mode

```bash
&/command arguments
```

Debug mode (`&` prefix):
- Shows full stack trace on error
- Isolated execution (doesn't affect main context)
- Detailed output of intermediate values

---

## 9. Gaps from Current Implementation

### 9.1 Missing DSL Features

| Feature | Status | Priority |
|---------|--------|----------|
| `@` Extension direction | Not implemented | High |
| `#` Comment direction | Not implemented | Medium |
| `^` Transform direction | Not implemented | High |
| Chained transforms | Not implemented | High |

### 9.2 Missing Core Features

| Feature | Status | Priority |
|---------|--------|----------|
| Process pool | Partial (Context.processes) | Critical |
| Tab-based UI | Not implemented | Critical |
| F-key shortcuts | Not implemented | High |
| Full-screen modes | Not implemented | Critical |
| Experiment versioning | Not implemented | High |

See Part 2 for UI/UX specifications.
See Part 3 for Process management specifications.