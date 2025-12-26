---
name: "Brain Lab Specification - Part 5: Advanced Features"
description: "Experiments, versioning, workspace management, and development roadmap"
part: 5
type: "tor"
date: "2025-12-17"
version: "1.0.0"
---

# Brain Lab Specification

## Part 5: Advanced Features and Roadmap

---

## 1. Experiment System

### 1.1 Overview

Experiments are versioned snapshots of workspace state that allow:

- **Save** - Capture current state with description
- **Load** - Restore previous state
- **Rollback** - Revert to specific version
- **Compare** - Diff between versions
- **Branch** - Create variations

### 1.2 File Structure

```
.laboratories/{workspace}/
├── experiments/
│   ├── index.json                    # Experiment registry
│   ├── data-pipeline/
│   │   ├── meta.json                 # Experiment metadata
│   │   ├── v1/
│   │   │   ├── snapshot.json         # Full state snapshot
│   │   │   └── meta.json             # Version metadata
│   │   ├── v2/
│   │   │   ├── snapshot.json
│   │   │   └── meta.json
│   │   └── current -> v2             # Symlink to current
│   └── api-testing/
│       ├── meta.json
│       └── ...
└── ...
```

### 1.3 Data Structures

**Experiment Index:**

```json
{
  "active": "data-pipeline",
  "experiments": [
    {
      "name": "data-pipeline",
      "created": "2025-12-17T10:00:00Z",
      "currentVersion": 3,
      "description": "Data transformation pipeline"
    },
    {
      "name": "api-testing",
      "created": "2025-12-16T14:30:00Z",
      "currentVersion": 5,
      "description": "API endpoint tests"
    }
  ]
}
```

**Version Snapshot:**

```json
{
  "version": 3,
  "description": "Added filtering step",
  "timestamp": "2025-12-17T14:30:00Z",
  "state": {
    "variables": {
      "source": "https://api.example.com",
      "filters": ["active", "verified"]
    },
    "result": [...],
    "processes": [...]
  },
  "checksum": "sha256:abc123..."
}
```

### 1.4 Experiment Commands

| Command | Description |
|---------|-------------|
| `/exp` | Show current experiment status |
| `/exp new <name>` | Create new experiment |
| `/exp save "<description>"` | Save current state as new version |
| `/exp load <name>` | Switch to experiment |
| `/exp list` | List all experiments |
| `/exp versions` | List versions of current experiment |
| `/exp rollback <v>` | Revert to version |
| `/exp delete <name>` | Delete experiment |
| `/exp diff <v1> <v2>` | Compare versions |
| `/exp branch <name>` | Create branch from current |
| `/exp export <name>` | Export to file |
| `/exp import <file>` | Import from file |

### 1.5 Version Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    Experiment: data-pipeline                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  v1 ─────► v2 ─────► v3 (current)                           │
│            │                                                 │
│            └─────► v2-alt (branch)                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.6 Auto-Save Behavior

```php
// Auto-save on significant changes
class ExperimentManager
{
    private int $changeCount = 0;
    private int $autoSaveThreshold = 10;

    public function trackChange(): void
    {
        $this->changeCount++;

        if ($this->changeCount >= $this->autoSaveThreshold) {
            $this->autoSave();
            $this->changeCount = 0;
        }
    }

    private function autoSave(): void
    {
        // Create auto-save version with timestamp
        $this->saveVersion("Auto-save: " . date('H:i:s'));
    }
}
```

---

## 2. Workspace Management

### 2.1 Multi-Workspace Support

```bash
brain lab                    # Default workspace
brain lab myproject         # Named workspace
brain lab experiment-1      # Another workspace
```

### 2.2 Workspace Structure

```
.laboratories/
├── default/                 # Default workspace
│   ├── workspace.json
│   ├── runtime.json
│   ├── .lab_history
│   ├── processes/
│   └── experiments/
├── myproject/               # Named workspace
│   ├── workspace.json
│   ├── runtime.json
│   ├── .lab_history
│   ├── processes/
│   └── experiments/
└── .config/                 # Global config
    └── settings.json
```

### 2.3 Workspace Commands

| Command | Description |
|---------|-------------|
| `/ws` | Show current workspace info |
| `/ws list` | List all workspaces |
| `/ws create <name>` | Create new workspace |
| `/ws switch <name>` | Switch workspace |
| `/ws delete <name>` | Delete workspace |
| `/ws export <name>` | Export workspace |
| `/ws import <file>` | Import workspace |
| `/ws clear` | Clear current workspace |

### 2.4 Workspace Isolation

Each workspace has isolated:

- Variables
- Command history
- Processes
- Experiments
- Configuration

---

## 3. Configuration System

### 3.1 Config Hierarchy

```
1. Default values (code)
2. Global config (.laboratories/.config/settings.json)
3. Workspace config ({workspace}/config.json)
4. Environment variables (BRAIN_LAB_*)
5. Command-line arguments
```

### 3.2 Configuration Options

```json
{
  "ui": {
    "theme": "default",
    "statusBar": true,
    "tabBar": true,
    "variablesPanel": true,
    "maxResultLines": 100
  },
  "process": {
    "maxConcurrent": 10,
    "defaultTimeout": 3600,
    "outputBufferSize": 10485760
  },
  "history": {
    "maxEntries": 100,
    "persistHistory": true
  },
  "experiment": {
    "autoSave": true,
    "autoSaveInterval": 10,
    "maxVersions": 50
  },
  "extensions": {
    "searchPaths": ["./screens"],
    "autoload": true
  }
}
```

### 3.3 Config Commands

```
/config                      # Show all settings
/config ui.theme            # Get specific value
/config ui.theme dark       # Set value
/config reset               # Reset to defaults
/config export              # Export config
/config import <file>       # Import config
```

---

## 4. Extension Screens (Examples)

### 4.1 Overview

This section demonstrates how Screen classes can extend Lab functionality. These are **not core features** - they are examples of what developers can build using the Screen extension API.

**Key principle:** Lab provides the platform and routing. All functionality comes from Screen classes.

### 4.2 Example: AI Agent Screens

Developers can create Screen classes that wrap AI agents:

```
┌─────────────────────────────────────────────────────────────┐
│           Screen Classes (user-implemented)                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ ClaudeScreen│  │ExploreScreen│  │   CustomScreen      │  │
│  │ handles @   │  │ handles @   │  │   handles @         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Screen API                                │
│  - Context input/output                                      │
│  - Process spawning                                          │
│  - Workspace access                                          │
│  - Async execution via ReactPHP                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 Potential Screen Implementations

| Screen | Direction | Description |
|--------|-----------|-------------|
| Claude | `@claude` | AI assistant wrapper |
| Explore | `@explore` | Codebase search |
| Commit | `@commit` | Git message generator |
| Docs | `@docs` | Documentation lookup |
| Api | `@api` | External API client |

**Note:** These are examples. Developers implement what they need.

### 4.4 Example Usage

```bash
@claude "Explain this code"          # Calls ClaudeScreen
@claude << /var code                 # With piped context
@explore "Find auth files"           # Calls ExploreScreen
@api POST /users $this              # Calls ApiScreen
```

### 4.5 Screen Implementation Pattern

```php
// Example: User creates ClaudeScreen
class ClaudeScreen extends ScreenAbstract
{
    public function __construct()
    {
        parent::__construct(
            name: 'claude',          // Handles @claude
            title: 'Claude AI',
            description: 'AI assistant integration',
        );
    }

    public function main(Context $context, string $prompt): Context
    {
        // Spawn async process for streaming response
        $context->process(
            name: 'claude-response',
            screenClass: self::class,
            screenMethod: 'streamResponse',
            $prompt, $context->result()
        );

        return $context->info('Claude is processing...');
    }
}
```

---

## 5. Development Roadmap

### 5.1 Phase 1: Core Infrastructure (MVP)

**Priority: Critical**
**Estimated effort: 2-3 weeks**

| Task | Description | Status |
|------|-------------|--------|
| ReactPHP integration | Async event loop | TODO |
| ProcessManager | Process lifecycle | TODO |
| Tab UI | Tab bar component | TODO |
| Status bar | Real-time status | Partial |
| Full-screen modes | Mode switching | TODO |

**Deliverables:**
- Working ReactPHP event loop
- Basic process spawn/kill
- Tab navigation
- Full-screen rendering

### 5.2 Phase 2: DSL Extensions

**Priority: High**
**Estimated effort: 1-2 weeks**

| Task | Description | Status |
|------|-------------|--------|
| `^` Transform pipes | Data transformation | TODO |
| `@` Extension direction | Routing to Screen classes | TODO |
| `#` Comments | Note logging | TODO |
| Chained transforms | Pipeline execution | TODO |

**Deliverables:**
- Complete DSL implementation
- Transform screen
- Extension direction routing

### 5.3 Phase 3: Process Management

**Priority: High**
**Estimated effort: 2 weeks**

| Task | Description | Status |
|------|-------------|--------|
| Process persistence | State save/load | TODO |
| Process recovery | Resume on restart | TODO |
| Process IPC | Inter-process comm | TODO |
| Process UI | Process tab view | TODO |

**Deliverables:**
- Full process lifecycle
- Persistent processes
- Process tab interface

### 5.4 Phase 4: Experiments

**Priority: High**
**Estimated effort: 1-2 weeks**

| Task | Description | Status |
|------|-------------|--------|
| Experiment manager | Core functionality | TODO |
| Version snapshots | Save/load state | TODO |
| Experiment browser | F2 overlay | TODO |
| Diff/compare | Version comparison | TODO |

**Deliverables:**
- Complete experiment system
- Version management
- Experiment browser UI

### 5.5 Phase 5: Polish & Documentation

**Priority: Medium**
**Estimated effort: 1 week**

| Task | Description | Status |
|------|-------------|--------|
| Help system | F1 overlay | TODO |
| Config system | Settings management | TODO |
| Error handling | Improved UX | TODO |
| Documentation | User guide | TODO |

**Deliverables:**
- Complete help system
- Configuration UI
- User documentation

### 5.6 Phase 6: Example Screen Implementations (Future)

**Priority: Later**
**Estimated effort: 2-3 weeks**

| Task | Description | Status |
|------|-------------|--------|
| AI Screen examples | Claude/GPT wrapper screens | TODO |
| API Screen examples | External API client screens | TODO |
| Streaming support | Live output in process tabs | TODO |
| Conversation screens | Multi-turn interaction patterns | TODO |

**Deliverables:**
- Example Screen implementations
- Streaming response handling
- Conversation UI patterns

**Note:** These are optional examples, not core features.

---

## 6. Technical Debt

### 6.1 Current Issues

| Issue | Impact | Resolution |
|-------|--------|------------|
| Blocking I/O | No real-time updates | ReactPHP migration |
| No process pool | Single command at a time | ProcessManager |
| Manual rendering | Inconsistent UI | Render cycle |
| No state recovery | Lost on crash | Persistence layer |

### 6.2 Refactoring Needed

1. **Screen.php** - Split into components
2. **Context.php** - Add validation
3. **CommandLinePrompt.php** - Extract ReactPHP code
4. **LabCommand.php** - Move logic to managers

---

## 7. Testing Strategy

### 7.1 Unit Tests

| Component | Tests |
|-----------|-------|
| Context DTO | Result manipulation, merging |
| WorkSpace | Variable operations |
| Argument parsing | Type conversion, validation |
| DSL regex | Command pattern matching |

### 7.2 Integration Tests

| Feature | Tests |
|---------|-------|
| Screen execution | Command routing, result handling |
| Process lifecycle | Spawn, kill, state transitions |
| Experiment versioning | Save, load, rollback |

### 7.3 E2E Tests

| Scenario | Tests |
|----------|-------|
| Full workflow | Create variables, execute commands, save experiment |
| Process management | Spawn process, monitor output, terminate |
| Recovery | Crash simulation, state restoration |

---

## 8. Appendix

### 8.1 DSL Quick Reference

```
DIRECTIONS
/         Screen command        /help, /var name "value"
!         Shell command         !npm run build
$         Variable access       $myvar, $this.field
@         Extension direction   @screen "args" (routes to Screen)
#         Comment               #note This is a note
^         Transform             ^upper, ^filter:key=val

MODIFIERS
+         Accumulate result     +!echo test
&         Debug/isolated        &/command args
*()()     Parallel execution    *(!cmd1)(!cmd2)

OPERATORS
<<        Command chain         /cmd1 << /cmd2 << /cmd3
-N        Remove last N         -3
--N       Remove first N        --2

ARGUMENTS
value                           Positional
key=value                       Named
"quoted string"                 String with spaces
--flag                          Boolean flag
$variable                       Variable interpolation
$this.field                     Result field access
```

### 8.2 Keyboard Shortcuts Reference

```
GLOBAL
Tab           Next tab
Shift+Tab     Previous tab
F1            Help
F2            Experiments
F3            Processes
F10           Exit

INPUT
↑             History / Previous
↓             Suggestions / Next
Tab           Accept suggestion
Enter         Submit
Ctrl+C        Cancel
Ctrl+U        Clear line

VIEWER/EDITOR
j/k           Up/down line
g/G           Top/bottom
/             Search
q             Close
```

### 8.3 File Locations

```
.laboratories/
├── {workspace}/
│   ├── workspace.json      Variables
│   ├── runtime.json        Context state
│   ├── .lab_history        Command history
│   ├── config.json         Workspace config
│   ├── processes/          Process states + logs
│   └── experiments/        Experiment versions
└── .config/
    └── settings.json       Global settings
```

---

## Document Information

**Total Parts:** 5
**Cross-References:**
- [Part 1: Core Architecture](./lab-specification-part-1.md)
- [Part 2: UI/UX](./lab-specification-part-2.md)
- [Part 3: Processes](./lab-specification-part-3.md)
- [Part 4: Extensions](./lab-specification-part-4.md)
- Part 5: Advanced (this document)

**Version History:**
- 1.0.0 (2025-12-17): Initial specification