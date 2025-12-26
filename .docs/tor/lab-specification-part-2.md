---
name: "Brain Lab Specification - Part 2: UI/UX"
description: "User interface, navigation, modes, and real-time features"
part: 2
type: "tor"
date: "2025-12-17"
version: "1.0.0"
---

# Brain Lab Specification

## Part 2: UI/UX and Navigation

---

## 1. Screen Layout

### 1.1 Main Layout Structure

```
┌────────────────────────────────────────────────────────────────┐
│ [Main] [Proc:agent-1] [Proc:build] [+]              F1:Help    │  ← Tab Bar
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      CONTENT AREA                         │  │
│  │                                                           │  │
│  │   (Mode-dependent content: see section 2)                 │  │
│  │                                                           │  │
│  │                                                           │  │
│  │                                                           │  │
│  │                                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│ > /command here...                                              │  ← Input Line
│   ↑ history | ↓ suggestions | Tab accept | Enter submit        │  ← Hint Line
├────────────────────────────────────────────────────────────────┤
│ & 0 │ $ 5 │ P: 2/3 │ Exp: v3 │ Mem 1.2KB │ 14:32:05           │  ← Status Bar
└────────────────────────────────────────────────────────────────┘
```

### 1.2 Layout Dimensions

| Region | Height | Description |
|--------|--------|-------------|
| Tab Bar | 1 line | Process tabs + shortcuts hint |
| Content Area | Dynamic | Fills remaining space |
| Input Line | 1 line | Command input |
| Hint Line | 1 line | Contextual hints |
| Status Bar | 1 line | System status |

**Minimum terminal size:** 80 columns × 24 rows

### 1.3 Color Scheme

| Element | Color | Termwind Class |
|---------|-------|----------------|
| Tab active | Cyan | `bg-cyan-600 text-white` |
| Tab inactive | Gray | `bg-gray-700 text-gray-400` |
| Tab with updates | Yellow | `bg-yellow-600 text-black` |
| Input line | White | `text-white` |
| Error message | Red | `bg-red-600 text-white` |
| Success message | Green | `bg-green-600 text-white` |
| Warning message | Yellow | `bg-yellow-600 text-black` |
| Info message | Blue | `bg-blue-600 text-white` |
| Status bar | Dark gray | `bg-gray-800 text-gray-300` |

---

## 2. Content Modes

### 2.1 Mode Overview

| Mode | Trigger | Description |
|------|---------|-------------|
| **Standard** | Default | Variables + Result panels |
| **Process** | Tab switch | Process output stream |
| **Editor** | `/edit` command | Multi-line editor |
| **Viewer** | `/view` command | Scrollable output |
| **Help** | F1 | Help overlay |
| **Experiments** | F2 | Experiment browser |

### 2.2 Standard Mode

Two-panel layout for main workspace:

```
┌────────────────────┬───────────────────────────────────────────┐
│   VARIABLES        │              RESULT                       │
├────────────────────┼───────────────────────────────────────────┤
│ $name     "John"   │ [12:30] $0:                               │
│ $count    42       │ {"status": "ok", "data": [...]}           │
│ $items    Array(5) │                                            │
│ $config   Object   │ [12:31] $1:                               │
│                    │ Command executed successfully              │
└────────────────────┴───────────────────────────────────────────┘
```

**Variables Panel:**
- Left side, fixed width (20-25 chars)
- Shows all workspace variables
- Type-colored values
- Scrollable if many variables

**Result Panel:**
- Right side, fills remaining width
- Shows command results with timestamps
- Scrollable history
- JSON/array formatting

### 2.3 Process Mode

Full-width output for selected process:

```
┌────────────────────────────────────────────────────────────────┐
│ Process: agent-claude                      Status: Running     │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ [12:30:45] Starting agent...                                    │
│ [12:30:46] Connecting to API...                                 │
│ [12:30:47] Processing request...                                │
│ [12:30:48] > Analyzing your question about architecture...      │
│ [12:30:49] > The recommended approach is to use...              │
│ [12:30:50] > ...                                                │
│                                                                 │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Features:**
- Real-time output streaming
- Scrollable history (Page Up/Down)
- Process status indicator
- Input line can send to process stdin

### 2.4 Editor Mode

Multi-line text editor:

```
┌────────────────────────────────────────────────────────────────┐
│ Editor: config.json                        Line 5/42  Col 12   │
├────────────────────────────────────────────────────────────────┤
│   1 │ {                                                         │
│   2 │   "name": "example",                                      │
│   3 │   "version": "1.0.0",                                     │
│ > 4 │   "dependencies": {█                                      │
│   5 │     "react": "^18.0.0",                                   │
│   6 │   }                                                       │
│   7 │ }                                                         │
└────────────────────────────────────────────────────────────────┘
│ Ctrl+S: Save  Ctrl+Q: Quit  Ctrl+G: Go to line                 │
```

**Features:**
- Line numbers
- Cursor position indicator
- Basic editing (insert, delete, navigate)
- Save/discard confirmation

### 2.5 Viewer Mode

Read-only scrollable content:

```
┌────────────────────────────────────────────────────────────────┐
│ Viewing: Large output                     Lines 50-75 of 200   │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ [content lines...]                                              │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
│ ↑↓: Scroll  PgUp/PgDn: Page  /: Search  q: Close              │
```

**Features:**
- Fast scrolling with vim-like keys
- Search within content
- Line highlighting
- Export to file

### 2.6 Help Overlay (F1)

Modal overlay with keybindings:

```
┌────────────────────────────────────────────────────────────────┐
│                        BRAIN LAB HELP                          │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NAVIGATION                    COMMANDS                        │
│  ──────────                    ────────                        │
│  Tab        Next process tab   /         Screen commands       │
│  Shift+Tab  Prev process tab   !         Shell commands        │
│  ←→         Switch tabs        $         Variables             │
│  F1         This help          @         Agent calls           │
│  F2         Experiments        #         Comments              │
│  F3         Processes          ^         Transforms            │
│  F4         Variables                                          │
│  F10        Exit lab           MODIFIERS                       │
│                                ─────────                       │
│  EDITING                       +         Accumulate result     │
│  ───────                       &         Debug/isolated        │
│  ↑          History up         *()()     Parallel execution    │
│  ↓          Suggestions                                        │
│  Tab        Accept ghost                                       │
│  Enter      Submit                                             │
│                                                                 │
│                    Press any key to close                       │
└────────────────────────────────────────────────────────────────┘
```

### 2.7 Experiments Browser (F2)

Experiment management overlay:

```
┌────────────────────────────────────────────────────────────────┐
│                      EXPERIMENTS                                │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CURRENT: data-pipeline v3                                      │
│  ───────────────────────────                                    │
│                                                                 │
│  > v3   2025-12-17 14:30  "Added filtering step"               │
│    v2   2025-12-17 12:15  "Initial pipeline"                   │
│    v1   2025-12-17 10:00  "Created experiment"                 │
│                                                                 │
│  ──────────────────────────────────────────────────────────     │
│  OTHER EXPERIMENTS                                              │
│  ──────────────────────────────────────────────────────────     │
│    api-testing      v5   2025-12-16                            │
│    data-analysis    v2   2025-12-15                            │
│                                                                 │
│  [N] New  [L] Load  [S] Save  [R] Rollback  [D] Delete  [Q] Close│
└────────────────────────────────────────────────────────────────┘
```

---

## 3. Navigation

### 3.1 Global Keyboard Shortcuts

| Key | Action | Context |
|-----|--------|---------|
| `Tab` | Next process tab | Always |
| `Shift+Tab` | Previous process tab | Always |
| `←` / `→` | Switch tabs | When not in input |
| `F1` | Help overlay | Always |
| `F2` | Experiments browser | Always |
| `F3` | Process manager | Always |
| `F4` | Variables panel toggle | Standard mode |
| `F5` | Refresh/re-render | Always |
| `F10` | Exit Lab | Always |
| `Ctrl+C` | Cancel current process | Always |
| `Ctrl+D` | Exit (if input empty) | Input line |
| `Escape` | Close overlay / Cancel | Overlays |

### 3.2 Input Line Navigation

| Key | Action |
|-----|--------|
| `←` / `→` | Move cursor |
| `Home` / `Ctrl+A` | Start of line |
| `End` / `Ctrl+E` | End of line |
| `Ctrl+←` | Previous word |
| `Ctrl+→` | Next word |
| `Backspace` | Delete char before |
| `Delete` | Delete char after |
| `Ctrl+U` | Clear line |
| `Ctrl+K` | Clear to end |
| `Ctrl+W` | Delete previous word |

### 3.3 History Navigation

| Key | Action |
|-----|--------|
| `↑` | Open history menu / Previous entry |
| `↓` | Close history / Next entry |
| `Page Up` | Jump 5 entries up |
| `Page Down` | Jump 5 entries down |
| `Enter` | Select entry |
| `Escape` | Close menu |

### 3.4 Autocomplete Navigation

| Key | Action |
|-----|--------|
| `↓` | Open suggestions / Next item |
| `↑` | Previous item / Close if at top |
| `Tab` | Accept ghost suggestion |
| `Enter` | Submit immediately |
| `Escape` | Close menu |

### 3.5 Mode-Specific Navigation

**Viewer/Editor Mode:**

| Key | Action |
|-----|--------|
| `j` / `↓` | Line down |
| `k` / `↑` | Line up |
| `Page Up` | Page up |
| `Page Down` | Page down |
| `g` | Go to top |
| `G` | Go to bottom |
| `/` | Search |
| `n` | Next search result |
| `N` | Previous search result |
| `q` | Close mode |

---

## 4. Tab Bar

### 4.1 Tab Types

| Type | Icon | Color | Description |
|------|------|-------|-------------|
| Main | `[M]` | Cyan | Main workspace (always first) |
| Process | `[P]` | Gray/Yellow | Background process |
| Agent | `[@]` | Purple | AI agent conversation |
| New | `[+]` | White | Create new tab |

### 4.2 Tab States

| State | Visual | Behavior |
|-------|--------|----------|
| Active | Bright background | Content displayed |
| Inactive | Dim background | Content preserved |
| Has updates | Pulsing dot | Process has new output |
| Error | Red indicator | Process encountered error |
| Completed | Green checkmark | Process finished successfully |

### 4.3 Tab Rendering

```php
// Pseudo-code for tab rendering
foreach ($tabs as $index => $tab) {
    $style = $tab->isActive ? 'bg-cyan-600' : 'bg-gray-700';
    $indicator = match($tab->status) {
        'running' => '●',
        'completed' => '✓',
        'error' => '✗',
        'updates' => '◉',
        default => ''
    };
    render("<span class='{$style}'>[{$tab->shortName}]{$indicator}</span>");
}
```

---

## 5. Status Bar

### 5.1 Status Bar Layout

```
│ & 0 │ $ 5 │ P: 2/3 │ Exp: v3 │ Mem 1.2KB │ 14:32:05 │
  │     │     │         │         │           │
  │     │     │         │         │           └── Current time
  │     │     │         │         └── Memory usage
  │     │     │         └── Experiment version
  │     │     └── Processes: active/total
  │     └── Variable count
  └── Debug mode indicator
```

### 5.2 Status Indicators

| Indicator | Meaning | Format |
|-----------|---------|--------|
| `&` | Debug/isolated commands | `& N` (count of debug runs) |
| `$` | Variables | `$ N` (variable count) |
| `P` | Processes | `P: A/T` (active/total) |
| `Exp` | Experiment | `Exp: vN` or `Exp: -` |
| `Mem` | Memory | Human-readable size |
| `Time` | Clock | `HH:MM:SS` |

### 5.3 Real-time Updates

Status bar updates via ReactPHP timer:

```php
$loop->addPeriodicTimer(1.0, function () {
    $this->statusBar->update([
        'time' => date('H:i:s'),
        'memory' => $this->calculateMemory(),
        'processes' => $this->processManager->getStats(),
    ]);
    $this->render();
});
```

---

## 6. Real-time Features

### 6.1 Live Updates

| Feature | Update Frequency | Trigger |
|---------|------------------|---------|
| Clock | 1 second | Timer |
| Process output | Immediate | stdout/stderr |
| Variable changes | Immediate | Set operation |
| Tab indicators | Immediate | State change |
| Memory usage | 5 seconds | Timer |

### 6.2 Process Output Streaming

```php
// ReactPHP process with live output
$process = new Process('long-running-command');
$process->start($loop);

$process->stdout->on('data', function ($chunk) use ($tab) {
    $tab->appendOutput($chunk);
    if ($tab->isActive()) {
        $this->renderContentArea();
    } else {
        $tab->markHasUpdates();
        $this->renderTabBar();
    }
});
```

### 6.3 Progress Indicators

For operations with known progress (file processing, batch operations):

```
┌────────────────────────────────────────────────────────────────┐
│ Process: data-import                        Items: 350/1000    │
│ [████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 35%            │
│ Elapsed: 00:02:15                                               │
└────────────────────────────────────────────────────────────────┘
```

For streaming operations (unknown length):

```
┌────────────────────────────────────────────────────────────────┐
│ Process: build-watch                        Status: RUNNING    │
│ [●●●○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○○] streaming...   │
│ Output lines: 234                                               │
└────────────────────────────────────────────────────────────────┘
```

---

## 7. Message Display

### 7.1 Message Types

| Type | Background | Icon | Duration |
|------|------------|------|----------|
| Error | Red | ✗ | Until dismissed |
| Warning | Yellow | ⚠ | 5 seconds |
| Success | Green | ✓ | 3 seconds |
| Info | Blue | ℹ | 3 seconds |

### 7.2 Message Area

Messages appear between content and input:

```
├────────────────────────────────────────────────────────────────┤
│ [Content area...]                                               │
├────────────────────────────────────────────────────────────────┤
│ ✗ Error: Command not found: /invalid                           │
├────────────────────────────────────────────────────────────────┤
│ > /command                                                      │
```

### 7.3 Message Queue

Multiple messages stack:

```php
$messages = [
    ['type' => 'error', 'text' => 'First error'],
    ['type' => 'warning', 'text' => 'Warning message'],
];
// Render all, newest at bottom
```

---

## 8. Implementation Gaps

### 8.1 Current vs Required

| Feature | Current | Required |
|---------|---------|----------|
| Tab bar | None | Full implementation |
| F-key shortcuts | None | All F1-F10 |
| Full-screen modes | None | 6 modes |
| Real-time process output | Partial | Complete streaming |
| Status bar | Basic | Full indicators |
| Overlay modals | None | Help, Experiments |
| Editor mode | None | Basic text editor |
| Viewer mode | None | Scrollable viewer |

### 8.2 ReactPHP Migration

Current implementation uses blocking I/O. Required changes:

1. Replace `prompt()` with async input handling
2. Add event loop for process monitoring
3. Implement non-blocking render cycle
4. Add timer-based UI updates

See Part 3 for detailed process architecture.