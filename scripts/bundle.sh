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

# Ad-hoc codesign
codesign --force --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
