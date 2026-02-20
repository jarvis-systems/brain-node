---
name: "Support & Troubleshooting"
description: "Common issues, troubleshooting checklist, bug report template, and required artifacts"
type: "product"
version: "v0.1.0"
status: "active"
---

# Support & Troubleshooting

## Troubleshooting Checklist

| # | Issue | Check | Fix |
|---|-------|-------|-----|
| 1 | Compile fails | `BRAIN_CLI_DEBUG=1 brain compile` | Read stack trace, fix source PHP |
| 2 | MCP server not connecting | `uvx vector-memory-mcp --help` | Check Python/uvx installation |
| 3 | Pin verification fails | `PIN_STRICT=1 bash scripts/verify-pins.sh` | Recompile with `PIN_STRICT=1 brain compile` |
| 4 | Benchmark dry-run fails | `composer benchmark:dry` | Fix scenario JSON syntax |
| 5 | Baselines JSON invalid | `jq empty .docs/benchmarks/baselines/baselines.json` | Fix JSON syntax |
| 6 | Agent not found | `brain list:masters` | Check `.brain/node/Agents/` for class |
| 7 | Command not found | `brain list` | Check `.brain/node/Commands/` for class |
| 8 | Compile discipline CI fail | `git diff HEAD~1 -- .brain/node/ node/` | Run `brain compile` and commit artifacts |
| 9 | Memory MCP timeout | Check `memory/` directory permissions | Ensure SQLite file is writable |
| 10 | Wrong compiled output | Compare source vs artifact | Delete `.claude/` and recompile |

## Bug Report Template

When reporting an issue, provide the following:

**Environment:**
- OS and version: `uname -a`
- PHP version: `php -v`
- Brain CLI version: `brain --version`
- Node.js version: `node -v`

**Configuration:**
- STRICT_MODE value
- COGNITIVE_LEVEL value
- PIN_STRICT value
- Contents of `pins.json`

**Reproduction:**
- Exact command that failed
- Full error output (with `BRAIN_CLI_DEBUG=1` if compile failure)
- Expected behavior vs actual behavior

**Artifacts:**
- `.mcp.json` (compiled MCP config)
- Benchmark report JSON (if benchmark-related)
- `git status` output
- `git log --oneline -5` output

## Required Artifacts for Diagnosis

| Artifact | Command | When Needed |
|----------|---------|-------------|
| Compile debug output | `BRAIN_CLI_DEBUG=1 brain compile 2>&1` | Compile failures |
| MCP config | `cat .mcp.json` | MCP connection issues |
| Pin status | `PIN_STRICT=1 bash scripts/verify-pins.sh` | Version mismatch |
| Benchmark report | `composer benchmark:ci 2>&1` | Benchmark failures |
| Build manifest | `bash scripts/generate-manifest.sh` | Release issues |
| Git state | `git status && git log --oneline -5` | Any issue |
