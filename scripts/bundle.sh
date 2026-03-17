#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TendiesApp"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"
BINARY="${BUILD_DIR}/${APP_NAME}"

# Accept optional binary path (used by CI for universal binary)
if [[ $# -ge 1 ]]; then
    BINARY="$1"
fi

if [[ ! -f "$BINARY" ]]; then
    echo "Error: binary not found at $BINARY"
    echo "Run 'swift build -c release' first, or pass the binary path as an argument."
    exit 1
fi

echo "Bundling ${APP_BUNDLE}..."

# Clean previous bundle
rm -rf "$APP_BUNDLE"

# Create .app structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary and Info.plist
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"

# Build app icon (.icns) if script and source are available
if [[ -x "scripts/build-app-icon.sh" ]]; then
    echo "Building AppIcon.icns..."
    bash scripts/build-app-icon.sh || echo "Warning: failed to build AppIcon.icns; continuing without custom icon"
fi

# Copy icon into bundle if present
if [[ -f "Resources/AppIcon.icns" ]]; then
    cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Codesign: use Developer ID if CODESIGN_IDENTITY is set, otherwise ad-hoc
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    echo "Signing with: ${CODESIGN_IDENTITY}"
    codesign --force --options runtime --sign "$CODESIGN_IDENTITY" \
        "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    codesign --force --options runtime --sign "$CODESIGN_IDENTITY" \
        "${APP_BUNDLE}"
else
    echo "Ad-hoc signing (set CODESIGN_IDENTITY for Developer ID signing)"
    codesign --force --sign - "${APP_BUNDLE}"
fi

codesign --verify --verbose "${APP_BUNDLE}"
echo "Done: ${APP_BUNDLE}"
