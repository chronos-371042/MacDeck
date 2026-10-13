#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
# File-provider folders can add Finder metadata to .app directories.
# Stage the distribution in a temporary directory and omit those attributes.
STAGING_DIR="$(mktemp -d /private/tmp/macdeck-package.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto --norsrc --noextattr build/MacDeck.app "$STAGING_DIR/MacDeck.app"
codesign --force --sign - "$STAGING_DIR/MacDeck.app"
codesign --verify --deep --strict "$STAGING_DIR/MacDeck.app"
ditto -c -k --norsrc --noextattr --keepParent "$STAGING_DIR/MacDeck.app" dist/MacDeck-0.1.0-arm64.zip
ditto -x -k dist/MacDeck-0.1.0-arm64.zip "$STAGING_DIR/verify"
codesign --verify --deep --strict "$STAGING_DIR/verify/MacDeck.app"
printf '%s\n' "$(pwd)/dist/MacDeck-0.1.0-arm64.zip"
