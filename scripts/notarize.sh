#!/usr/bin/env bash
set -euo pipefail

# Notarize TendiesApp.zip with Apple
# Required env vars:
#   APPLE_ID          - Apple ID email
#   APPLE_PASSWORD    - App-specific password (NOT your Apple ID password)
#   APPLE_TEAM_ID     - Developer Team ID (10-char alphanumeric)

APP_ZIP="${1:-TendiesApp.zip}"

if [[ ! -f "$APP_ZIP" ]]; then
    echo "Error: $APP_ZIP not found"
    exit 1
fi

for var in APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

echo "Submitting ${APP_ZIP} for notarization..."
xcrun notarytool submit "$APP_ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

echo "Stapling notarization ticket..."
# Unzip, staple, re-zip
rm -rf TendiesApp.app
unzip -q "$APP_ZIP"
xcrun stapler staple TendiesApp.app
rm "$APP_ZIP"
zip -r "$APP_ZIP" TendiesApp.app
rm -rf TendiesApp.app

echo "Notarization complete: ${APP_ZIP}"
