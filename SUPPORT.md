# Support

## Getting Help

### Documentation

Start with the operator documentation in `.docs/product/`:

| Doc | Purpose |
|-----|---------|
| `00-overview.md` | What Brain is and isn't |
| `01-installation.md` | Setup and prerequisites |
| `02-configuration.md` | Env vars, modes, pinning |
| `03-runbooks.md` | Operational procedures |
| `04-security-model.md` | Threat model and mitigations |
| `05-support.md` | Troubleshooting checklist |

### CLI Self-Help

```
brain --help
brain docs --help
brain docs --search <query>
```

## Bug Reports

Open a GitHub issue with:

1. **Environment**: PHP version, OS, Brain CLI version (`brain --version`)
2. **Mode**: STRICT_MODE and COGNITIVE_LEVEL values
3. **Steps to reproduce**: exact commands run
4. **Expected vs actual**: what should happen vs what happened
5. **Artifacts**: attach `manifest.json`, benchmark report, or compile output

## Feature Requests

Open a GitHub issue with `[Feature]` prefix. Include:

1. **Use case**: what problem does this solve?
2. **Proposed solution**: how should it work?
3. **Alternatives considered**: what else was evaluated?

## Commercial Support

For enterprise support, SLA agreements, or custom integrations, contact: xsaven@gmail.com

## Community

- GitHub Issues: bug reports and feature requests
- Pull Requests: contributions welcome (follow existing code style)
