---
name: "Brain Lab Specification - Part 3: Processes"
description: "Process architecture, state management, lifecycle, and inter-process communication"
part: 3
type: "tor"
date: "2025-12-17"
version: "1.0.0"
---

# Brain Lab Specification

## Part 3: Process Management

---

## 1. Process Architecture

### 1.1 Overview

Brain Lab supports two types of process execution:

| Type | Technology | Use Case |
|------|------------|----------|
| **Sync Process** | Symfony Process | Short shell commands |
| **Async Process** | ReactPHP ChildProcess | Long-running, streamable |
| **Async Task** | ReactPHP Promise | Internal async operations |

### 1.2 ProcessManager Class

```
ProcessManager
├── activeProcesses: Map<id, Process>
├── processStates: Map<id, ProcessState>
├── loop: LoopInterface
│
├── spawn(config: ProcessConfig): Process
├── kill(id: string): void
├── pause(id: string): void
├── resume(id: string): void
├── send(id: string, input: string): void
├── getOutput(id: string): string
├── getStats(): ProcessStats
│
└── Events:
    ├── onOutput(id, chunk)
    ├── onError(id, error)
    ├── onComplete(id, exitCode)
    └── onStateChange(id, state)
```

### 1.3 Process Configuration

```php
class ProcessConfig
{
    public function __construct(
        public string $command,           // Command to execute
        public ?array $args = null,       // Command arguments
        public ?string $cwd = null,       // Working directory
        public ?array $env = null,        // Environment variables
        public ?int $timeout = null,      // Timeout in seconds (null = infinite)
        public bool $tty = false,         // Allocate TTY
        public string $type = 'shell',    // shell | php | agent
        public ?string $screenClass = null, // ScreenAbstract for agent type
        public ?string $screenMethod = null,
        public array $screenArgs = [],
    ) {}
}
```

---

## 2. Process Types

### 2.1 Shell Process

Direct shell command execution:

```bash
!npm run build
!git status
!docker compose up -d
```

**Implementation:**

```php
$process = new React\ChildProcess\Process($command);
$process->start($loop);

$process->stdout->on('data', fn($chunk) => $this->appendOutput($id, $chunk));
$process->stderr->on('data', fn($chunk) => $this->appendError($id, $chunk));
$process->on('exit', fn($code) => $this->handleExit($id, $code));
```

### 2.2 Screen Process

Internal Lab screen as background process:

```php
// Created via Context->process()
$context->process(
    name: 'data-fetch',
    screenClass: DataFetcher::class,
    screenMethod: 'fetchAll',
    ...['url' => 'https://api.example.com']
);
```

**Execution:**

```php
// ProcessManager spawns PHP process
$php = PHP_BINARY;
$script = <<<'PHP'
<?php
require 'vendor/autoload.php';
$screen = new {$screenClass}();
$result = $screen->{$screenMethod}($context, ...$args);
echo json_encode($result->toArray());
PHP;

$process = new Process("$php -r '$script'");
```

### 2.3 Agent Process

AI agent execution:

```bash
@claude "Explain this code"
```

**Implementation:**

```php
// Agent process streams response
$agent = new AgentProcess($agentType, $prompt);
$agent->onChunk(fn($chunk) => $this->appendOutput($id, $chunk));
$agent->onComplete(fn($result) => $this->handleAgentComplete($id, $result));
$agent->start($loop);
```

---

## 3. Process Lifecycle

### 3.1 States

```
┌─────────┐    spawn()    ┌─────────┐    start()    ┌─────────┐
│ PENDING │ ────────────► │ READY   │ ────────────► │ RUNNING │
└─────────┘               └─────────┘               └────┬────┘
                                                         │
                          ┌─────────────────────────────┤
                          │                             │
                          ▼                             ▼
                    ┌──────────┐                 ┌───────────┐
                    │ PAUSED   │ ◄─────────────► │ COMPLETED │
                    └──────────┘    resume()     └───────────┘
                          │                             │
                          │         kill()              │
                          └─────────────┬───────────────┘
                                        ▼
                                  ┌──────────┐
                                  │ STOPPED  │
                                  └──────────┘
                                        │
                                        ▼
                                  ┌──────────┐
                                  │ FAILED   │
                                  └──────────┘
```

### 3.2 State Definitions

| State | Description | Recoverable |
|-------|-------------|-------------|
| `PENDING` | Created, waiting to start | Yes |
| `READY` | Configured, can be started | Yes |
| `RUNNING` | Actively executing | Yes |
| `PAUSED` | Temporarily suspended | Yes |
| `COMPLETED` | Finished successfully | No |
| `STOPPED` | Manually terminated | Yes |
| `FAILED` | Error occurred | Depends |

### 3.3 Lifecycle Events

```php
interface ProcessLifecycleListener
{
    public function onCreated(Process $process): void;
    public function onStarted(Process $process): void;
    public function onOutput(Process $process, string $chunk, string $stream): void;
    public function onPaused(Process $process): void;
    public function onResumed(Process $process): void;
    public function onCompleted(Process $process, int $exitCode): void;
    public function onFailed(Process $process, Throwable $error): void;
    public function onStopped(Process $process): void;
}
```

---

## 4. State Persistence

### 4.1 File Structure

```
.laboratories/{workspace}/
├── workspace.json           # Variables
├── runtime.json             # Main context
├── processes/
│   ├── proc-001.json       # Process 1 state
│   ├── proc-001.log        # Process 1 output log
│   ├── proc-002.json       # Process 2 state
│   ├── proc-002.log        # Process 2 output log
│   └── ...
└── .lab_history            # Command history
```

### 4.2 ProcessState DTO

```php
class ProcessState extends Dto
{
    public function __construct(
        public string $id,
        public string $name,
        public string $type,              // shell | screen | agent
        public string $status,            // lifecycle state
        public ProcessConfig $config,
        public string $createdAt,
        public ?string $startedAt = null,
        public ?string $completedAt = null,
        public ?int $exitCode = null,
        public ?string $error = null,
        public array $metadata = [],      // Custom data
        public int $outputLines = 0,      // Lines in log file
        public int $pid = 0,              // OS process ID (if running)
    ) {}
}
```

### 4.3 Auto-Save Strategy

```php
// Save on state change
$process->on('state', function ($state) {
    $this->saveProcessState($this->id, $state);
});

// Save output periodically (batch)
$outputBuffer = [];
$process->on('output', function ($chunk) use (&$outputBuffer) {
    $outputBuffer[] = $chunk;
});

$loop->addPeriodicTimer(1.0, function () use (&$outputBuffer, $id) {
    if (!empty($outputBuffer)) {
        $this->appendToLog($id, implode('', $outputBuffer));
        $outputBuffer = [];
    }
});
```

### 4.4 Process Recovery on Restart

```php
// On Lab startup
public function recoverProcesses(): void
{
    $processFiles = glob("{$this->path}/processes/*.json");

    foreach ($processFiles as $file) {
        $state = ProcessState::from(file_get_contents($file));

        if ($state->status === 'RUNNING' || $state->status === 'PAUSED') {
            // Mark as interrupted, can be resumed
            $state->status = 'STOPPED';
            $state->metadata['interrupted'] = true;
            $this->saveProcessState($state->id, $state);

            // Add to UI for user decision
            $this->addRecoverableProcess($state);
        }
    }
}
```

---

## 5. Process Commands

### 5.1 Process Screen Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/proc` | List all processes | `/proc` |
| `/proc create` | Create new process | `/proc create !npm run watch` |
| `/proc {id}` | Switch to process tab | `/proc 1` |
| `/proc kill {id}` | Terminate process | `/proc kill 1` |
| `/proc pause {id}` | Pause process | `/proc pause 1` |
| `/proc resume {id}` | Resume process | `/proc resume 1` |
| `/proc restart {id}` | Restart process | `/proc restart 1` |
| `/proc send {id} {input}` | Send input to stdin | `/proc send 1 "yes"` |
| `/proc logs {id}` | View full logs | `/proc logs 1` |
| `/proc clear {id}` | Clear output buffer | `/proc clear 1` |

### 5.2 Process Listing Output

```
┌────────────────────────────────────────────────────────────────┐
│ ID  │ Name          │ Type   │ Status   │ Runtime  │ Exit     │
├─────┼───────────────┼────────┼──────────┼──────────┼──────────┤
│ 1   │ build         │ shell  │ RUNNING  │ 00:02:34 │ -        │
│ 2   │ agent-claude  │ agent  │ RUNNING  │ 00:00:45 │ -        │
│ 3   │ test-suite    │ shell  │ COMPLETED│ 00:05:12 │ 0        │
│ 4   │ data-fetch    │ screen │ FAILED   │ 00:01:30 │ 1        │
└────────────────────────────────────────────────────────────────┘
```

---

## 6. Inter-Process Communication

### 6.1 Output Channels

Each process has multiple output channels:

| Channel | Description | Capture |
|---------|-------------|---------|
| `stdout` | Standard output | Default |
| `stderr` | Error output | Merged or separate |
| `events` | Process events | Internal |
| `state` | State changes | Internal |

### 6.2 IPC via Files

For complex data exchange:

```php
// Process writes to shared file
$sharedFile = "{$workspace}/shared/{$processId}.json";
file_put_contents($sharedFile, json_encode($data));

// Main process reads
$data = json_decode(file_get_contents($sharedFile), true);
```

### 6.3 IPC via Pipes

For streaming communication:

```php
// Create named pipe
$pipePath = "{$workspace}/pipes/{$processId}";
posix_mkfifo($pipePath, 0600);

// Process writes
$pipe = fopen($pipePath, 'w');
fwrite($pipe, $message);

// Main reads (non-blocking)
$pipe = fopen($pipePath, 'r');
stream_set_blocking($pipe, false);
```

### 6.4 Event Bus

Internal event system for process coordination:

```php
class ProcessEventBus
{
    private array $listeners = [];

    public function emit(string $event, array $data = []): void
    {
        foreach ($this->listeners[$event] ?? [] as $listener) {
            $listener($data);
        }
    }

    public function on(string $event, callable $listener): void
    {
        $this->listeners[$event][] = $listener;
    }
}

// Usage
$bus->on('process.output', function ($data) {
    $this->updateTab($data['id'], $data['chunk']);
});

$bus->emit('process.output', [
    'id' => $processId,
    'chunk' => $outputChunk,
]);
```

---

## 7. Screen-Spawned Processes

### 7.1 Overview

Screen classes can spawn processes via `Context->process()`. These processes run independently and can be monitored via tabs.

### 7.2 Screen Process Flow

```
┌─────────────────┐
│  /command args  │ ───► Screen.main() ───► Context.process()
└─────────────────┘                              │
                                                 ▼
┌─────────────────────────────────────────────────────────┐
│              ProcessManager.spawn(config)                │
│  - Create process state                                  │
│  - Start execution (Symfony Process or ReactPHP)         │
│  - Create tab for monitoring                             │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│              Process Tab (real-time)                     │
│  [timestamp] Starting process...                         │
│  [timestamp] Output line 1...                            │
│  [timestamp] Output line 2...                            │
└─────────────────────────────────────────────────────────┘
```

### 7.3 Extended Process State

Screens can extend ProcessState for custom data:

```php
class CustomProcessState extends ProcessState
{
    public function __construct(
        // ... parent properties
        public array $customData = [],
        public ?string $customField = null,
    ) {}
}
```

---

## 8. Resource Management

### 8.1 Limits

| Resource | Default Limit | Configurable |
|----------|---------------|--------------|
| Max processes | 10 | Yes |
| Output buffer | 10 MB | Yes |
| Log file size | 50 MB | Yes |
| Process timeout | 1 hour | Yes |
| Agent tokens | 4096 | Yes |

### 8.2 Cleanup

```php
// Auto-cleanup old completed processes
public function cleanupOldProcesses(int $keepDays = 7): void
{
    $cutoff = time() - ($keepDays * 86400);

    foreach ($this->getProcessStates() as $state) {
        if ($state->status === 'COMPLETED' || $state->status === 'FAILED') {
            $completedTime = strtotime($state->completedAt);
            if ($completedTime < $cutoff) {
                $this->deleteProcess($state->id);
            }
        }
    }
}
```

### 8.3 Memory Management

```php
// Truncate output buffer when too large
$maxBuffer = 10 * 1024 * 1024; // 10 MB

$process->on('output', function ($chunk) use (&$buffer, $maxBuffer) {
    $buffer .= $chunk;

    if (strlen($buffer) > $maxBuffer) {
        // Keep last 80%
        $buffer = substr($buffer, -intval($maxBuffer * 0.8));
        $this->state->metadata['truncated'] = true;
    }
});
```

---

## 9. Error Handling

### 9.1 Error Types

| Error | Handling | Recovery |
|-------|----------|----------|
| Spawn failure | Log + notify | Show config error |
| Timeout | Kill + mark failed | Allow restart |
| OOM | Kill + mark failed | Suggest limits |
| Exit non-zero | Mark failed | Show stderr |
| Signal (SIGKILL) | Mark stopped | Allow restart |

### 9.2 Error Display

```
┌────────────────────────────────────────────────────────────────┐
│ Process: test-runner                       Status: FAILED      │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Exit code: 1                                                    │
│ Runtime: 00:02:34                                               │
│                                                                 │
│ Error output:                                                   │
│ ──────────────                                                  │
│ npm ERR! Test failed                                            │
│ npm ERR! Exit status 1                                          │
│                                                                 │
│ Actions: [R] Restart  [L] View logs  [D] Delete  [Q] Close     │
└────────────────────────────────────────────────────────────────┘
```

---

## 10. Implementation Status

### ✅ Completed (Task #4)
- ReactPHP event loop integration
- Signal handlers (SIGINT/SIGTERM) with graceful shutdown
- Periodic timers (1s runtime clock, 5s memory stats)
- processAsync() infrastructure for async child processes
- drawAsync() promise chain for non-blocking REPL

### ❌ Not Yet Implemented (Task #5)
- ProcessManager class
- ProcessConfig/ProcessState DTOs
- Process persistence
- Process recovery

### 10.1 Current State

```php
// Current: Context stores process specs (not running processes)
public function process(
    string $name,
    string $screenClass,
    string $screenMethod,
    ...$args
): static {
    $this->processes[] = [
        'name' => $name,
        'screenClass' => $screenClass,
        'screenMethod' => $screenMethod,
        'args' => $args,
    ];
    return $this;
}
```

### 10.2 Required Implementation

1. **ProcessManager class** - Full lifecycle management
2. **ReactPHP integration** - ✅ COMPLETED (event loop, signals, timers)
3. **ProcessState DTO** - Persistent state
4. **Tab integration** - Process tabs in UI
5. **Log management** - File-based output storage
6. **Recovery system** - Resume on restart
7. **Resource limits** - Memory/timeout management

### 10.3 Migration Path

1. ✅ DONE: Integrate ReactPHP event loop and async infrastructure
2. Create `ProcessManager` with basic spawn/kill
3. Add `ProcessState` persistence
4. Integrate with Screen for tabs
5. Implement recovery on startup
6. Add agent process support

See Part 4 for Screen extension API.