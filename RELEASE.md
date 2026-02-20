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

### 6. Pin Verification (MANDATORY)

Every release MUST pass pin verification. No exceptions.

```
PIN_STRICT=1 brain compile
PIN_STRICT=1 bash scripts/verify-pins.sh
```

Both commands must exit 0. If `verify-pins.sh` reports FAIL, update `pins.json` or recompile.

### 7. Generate Manifest

```
bash scripts/generate-manifest.sh
```

Review `.docs/releases/manifest.json` for correctness.

### 8. Build Release Bundle

```
bash scripts/build-release-bundle.sh
```

Verify `dist/brain-enterprise-vX.Y.Z.tar.gz` and `.sha256` exist.

### 9. Commit and Tag

```
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "release: vX.Y.Z"
```

### 10. Push

```
git push origin master --tags
```

CI will automatically run `brain-release.yml` on tag push: pin verification, manifest generation, bundle build, and artifact upload.

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
