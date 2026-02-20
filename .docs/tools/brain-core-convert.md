# brain-core convert — Single-File Compilation Tool

Debug and inspect individual Brain source files without running full `brain compile`.

## Command

```bash
./.brain/vendor/bin/brain-core convert <file> [options]
```

## When to Use

- Debugging a single include/agent/brain file during development
- Checking how mode changes affect a specific file's output
- Inspecting compiled structure without writing to `.claude/`
- Comparing standard vs paranoid output for the same source
- Quick iteration: edit source → convert → inspect → repeat

**Does NOT replace `brain compile`** — after development, always verify with full compile.

## Options

| Option | Description |
|--------|-------------|
| `--xml` | Output in XML format (Claude target) |
| `--json` | Output in JSON format (Codex/Gemini target) |
| `--yaml` | Output in YAML format (Qwen target) |
| `--toml` | Output in TOML format |
| `--meta` | Output only file metadata (no compiled structure) |
| `--variables` | Pass compilation variables as JSON |

## Environment Variables

| Variable | Values                              | Default     |
|----------|-------------------------------------|-------------|
| `STRICT_MODE` | relaxed, standard, strict, paranoid | from `.env` |
| `COGNITIVE_LEVEL` | standard, exhaustive                | from `.env` |
| `BRAIN_CLI_DEBUG` | 1,0                                 | 0           |

These override `.env` values (dotenv is immutable — shell env wins).

## Output Format

JSON object where the key is the source file path:

```json
{
  ".brain/node/Brain.php": {
    "id": "brain",
    "file": ".brain/node/Brain.php",
    "class": "BrainNode\\Brain",
    "meta": {"id": "brain-core", "purposeText": "..."},
    "namespace": "BrainNode",
    "namespaceType": null,
    "classBasename": "Brain",
    "format": "xml",
    "structure": "<system>\n<meta>..."
  }
}
```

The `structure` field contains the full compiled output as a string. With `--meta`, `structure` is `null`.

## Examples

### Inspect Brain in standard mode

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --xml
```

### Inspect Brain in paranoid+exhaustive mode

```bash
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --xml
```

### Compare line counts between modes

```bash
# Standard
STRICT_MODE=standard COGNITIVE_LEVEL=standard \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --xml \
  | jq -r 'to_entries[0].value.structure | split("\n") | length'
# → 322

# Paranoid+Exhaustive
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --xml \
  | jq -r 'to_entries[0].value.structure | split("\n") | length'
# → 623
```

### Inspect a specific agent

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Agents/ExploreMaster.php" --xml \
  | jq -r 'to_entries[0].value | {id, lines: (.structure | split("\n") | length)}'
```

### Get metadata only (no compilation)

```bash
./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --meta \
  | jq -r 'to_entries[0].value | {id, class, namespace}'
```

### Pipe compiled output to a file for review

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php" --xml \
  | jq -r 'to_entries[0].value.structure' > /tmp/brain-preview.md
```

## Key Differences from `brain compile`

| Aspect | `brain-core convert` | `brain compile` |
|--------|---------------------|-----------------|
| Scope | Single file | All files |
| Output | stdout (JSON) | Writes to `.claude/` |
| Variables | Template placeholders preserved (`{{ BRAIN_FOLDER }}`) | Variables resolved to actual paths |
| Side effects | None (read-only) | Writes compiled artifacts |
| Use case | Debug, inspect, compare | Production build |

## Multiple Files

Pass multiple files in one argument, separated by `&&`:

```bash
./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php && .brain/node/Agents/ExploreMaster.php" --xml
```

The output JSON object will contain a key per file:

```json
{
  ".brain/node/Brain.php": { "id": "brain", "structure": "..." },
  ".brain/node/Agents/ExploreMaster.php": { "id": "explore-master", "structure": "..." }
}
```

With environment variables:

```bash
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive \
  ./.brain/vendor/bin/brain-core convert ".brain/node/Brain.php && .brain/node/Agents/ExploreMaster.php" --xml
```

## Limitations

- Template variables (`{{ BRAIN_FOLDER }}` etc.) are NOT resolved — they appear as-is
- Does not write to disk — output is stdout only
- Does not run post-compile hooks or MCP config generation
