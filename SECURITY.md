# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| v0.1.x  | Yes       |
| < v0.1  | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in jarvis-brain/node, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

### How to Report

1. Email: xsaven@gmail.com
2. Subject: `[SECURITY] jarvis-brain/node — <brief description>`
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected version(s)
   - Potential impact assessment
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgement**: within 48 hours
- **Initial assessment**: within 7 days
- **Fix or mitigation**: within 30 days for critical, 90 days for non-critical

### Scope

The following are in scope:

- Prompt injection vectors in compiled output
- MCP configuration injection
- Pin bypass (supply chain)
- Secret leakage in compiled artifacts
- Arbitrary code execution via Brain CLI

The following are out of scope:

- Vulnerabilities in third-party MCP servers (report to upstream)
- AI model behavior (non-deterministic by nature)
- Issues requiring physical access to the machine

### Disclosure Policy

We follow coordinated disclosure. Please allow us reasonable time to address the issue before public disclosure.

### Credit

Security researchers who report valid vulnerabilities will be credited in the CHANGELOG (unless they prefer anonymity).
