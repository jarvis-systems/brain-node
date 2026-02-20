---
name: "Release Guide"
description: "Step-by-step release checklist for jarvis-brain/node"
---

# Release Guide

## Prerequisites

- Clean git working tree (`git status` shows no uncommitted changes)
- All tests passing
- All benchmarks passing

## Release Checklist

### 1. Quality Gates

```
composer analyse
composer test
```

Both must pass with zero errors.

### 2. Benchmark Validation

```
composer benchmark:dry
composer benchmark:telemetry
composer benchmark:ci
```

### 3. Update CHANGELOG.md

Move `[Unreleased]` section to `[vX.Y.Z] — YYYY-MM-DD`.

### 4. Bump Version

Update `"version"` in `composer.json` to match the new tag.

### 5. Compile Both Modes

```
brain compile
STRICT_MODE=paranoid brain compile
```

Verify output is consistent.

### 6. Pin Verification (if releasing with pins)

```
PIN_STRICT=1 brain compile
PIN_STRICT=1 bash scripts/verify-pins.sh
```

### 7. Generate Manifest

```
bash scripts/generate-manifest.sh
```

Review `.docs/releases/manifest.json` for correctness.

### 8. Commit and Tag

```
git add -A
git commit -m "release: vX.Y.Z"
git tag vX.Y.Z
```

### 9. Push

```
git push origin master --tags
```

## Version Convention

- Format: `vMAJOR.MINOR.PATCH` (e.g., `v0.1.0`)
- Single source of truth: `composer.json` → `"version"` field
- Git tag MUST match composer.json version exactly
- Core version (`core/composer.json`) tracks independently

## What Constitutes a Version Bump

| Change | Bump |
|--------|------|
| Breaking API change in core builders | MAJOR |
| New archetype, new builder feature, new CLI command | MINOR |
| Bug fix, documentation, benchmark update | PATCH |
