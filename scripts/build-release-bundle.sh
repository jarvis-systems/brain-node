#!/usr/bin/env bash
# build-release-bundle.sh — Build enterprise release bundle
# Output: dist/brain-enterprise-vX.Y.Z.tar.gz + .sha256

set -euo pipefail

COMPOSER_FILE="composer.json"
DIST_DIR="dist"
MANIFEST_FILE=".docs/releases/manifest.json"

# Extract version from composer.json
VERSION=$(jq -r '.version // empty' "$COMPOSER_FILE" 2>/dev/null)
if [[ -z "$VERSION" ]]; then
    echo "ERROR: No version found in $COMPOSER_FILE"
    exit 1
fi

BUNDLE_NAME="brain-enterprise-${VERSION}"
TARBALL="${DIST_DIR}/${BUNDLE_NAME}.tar.gz"
SHA_FILE="${DIST_DIR}/${BUNDLE_NAME}.sha256"

echo "Building release bundle: ${BUNDLE_NAME}"
echo "Version: ${VERSION}"
echo ""

# Pre-flight checks
ERRORS=0

if [[ ! -d ".claude" ]]; then
    echo "ERROR: .claude/ directory not found. Run 'brain compile' first."
    ERRORS=1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: $MANIFEST_FILE not found. Run 'bash scripts/generate-manifest.sh' first."
    ERRORS=1
fi

if [[ ! -f "pins.json" ]]; then
    echo "ERROR: pins.json not found."
    ERRORS=1
fi

if [[ ! -f "LICENSE" ]]; then
    echo "ERROR: LICENSE file not found."
    ERRORS=1
fi

if [[ "$ERRORS" -eq 1 ]]; then
    echo ""
    echo "Bundle build FAILED. Fix errors above."
    exit 1
fi

# Clean previous build
rm -rf "${DIST_DIR:?}/${BUNDLE_NAME}"
mkdir -p "$DIST_DIR"

# Create staging directory
STAGING="${DIST_DIR}/${BUNDLE_NAME}"
mkdir -p "$STAGING"

# Copy artifacts
echo "Collecting artifacts..."

# Compiled output
if [[ -d ".claude" ]]; then
    cp -r .claude "$STAGING/.claude"
fi

if [[ -d ".opencode" ]]; then
    cp -r .opencode "$STAGING/.opencode"
fi

# Documentation
if [[ -d ".docs/product" ]]; then
    mkdir -p "$STAGING/.docs/product"
    cp -r .docs/product/* "$STAGING/.docs/product/"
fi

# Manifest
mkdir -p "$STAGING/.docs/releases"
cp "$MANIFEST_FILE" "$STAGING/.docs/releases/"

# Root files
for FILE in RELEASE.md CHANGELOG.md LICENSE SECURITY.md SUPPORT.md pins.json; do
    if [[ -f "$FILE" ]]; then
        cp "$FILE" "$STAGING/"
    fi
done

# .mcp.json is EXCLUDED from bundles — it contains resolved secrets
# (API keys, tokens) materialized at compile time via getenv().
# Users must run 'brain compile' locally to generate their own .mcp.json.

# Demo: scripts + scenarios (for demo-enterprise.sh from bundle)
mkdir -p "$STAGING/scripts"
for DEMO_SCRIPT in demo-enterprise.sh benchmark-llm-suite.sh; do
    if [[ -f "scripts/$DEMO_SCRIPT" ]]; then
        cp "scripts/$DEMO_SCRIPT" "$STAGING/scripts/"
        chmod +x "$STAGING/scripts/$DEMO_SCRIPT"
    fi
done

mkdir -p "$STAGING/.docs/benchmarks/scenarios"
for DEMO_SID in MT-001 MT-002 ADV-003; do
    for SF in .docs/benchmarks/scenarios/${DEMO_SID}*.json; do
        [[ -f "$SF" ]] && cp "$SF" "$STAGING/.docs/benchmarks/scenarios/"
    done
done

# Ops evidence (optional — include if previously generated)
if [[ -f "${DIST_DIR}/ops-evidence.json" ]]; then
    mkdir -p "$STAGING/dist"
    cp "${DIST_DIR}/ops-evidence.json" "$STAGING/dist/"
fi

# Count files
FILE_COUNT=$(find "$STAGING" -type f | wc -l | tr -d ' ')
echo "Staged ${FILE_COUNT} files"

# Create tarball
echo "Creating tarball..."
tar -czf "$TARBALL" -C "$DIST_DIR" "$BUNDLE_NAME"

# Generate SHA256
if command -v sha256sum &>/dev/null; then
    sha256sum "$TARBALL" > "$SHA_FILE"
elif command -v shasum &>/dev/null; then
    shasum -a 256 "$TARBALL" > "$SHA_FILE"
else
    echo "WARNING: No sha256 tool found. Skipping checksum."
    SHA_FILE=""
fi

# Cleanup staging
rm -rf "$STAGING"

# Report
TARBALL_SIZE=$(du -h "$TARBALL" | cut -f1)
echo ""
echo "Bundle built successfully:"
echo "  Tarball: ${TARBALL} (${TARBALL_SIZE})"
if [[ -n "$SHA_FILE" ]]; then
    echo "  SHA256:  ${SHA_FILE}"
    echo "  Hash:    $(cut -d' ' -f1 "$SHA_FILE")"
fi
echo "  Files:   ${FILE_COUNT}"
echo ""
echo "Done."
