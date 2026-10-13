#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
STAGING_DIR="$(mktemp -d /private/tmp/macdeck-build.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="$STAGING_DIR/MacDeck.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 \
  -module-cache-path build/module-cache \
  -framework SwiftUI -framework AppKit -framework GameController \
  Sources/*.swift -o "$APP/Contents/MacOS/MacDeck"
cp Resources/Info.plist "$APP/Contents/Info.plist"
xcrun swift -module-cache-path build/module-cache Scripts/Icon.swift "$APP/Contents/Resources"
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --norsrc --noextattr "$APP" build/MacDeck.app
xattr -dr com.apple.FinderInfo build/MacDeck.app 2>/dev/null || true
printf '%s\n' "$(pwd)/build/MacDeck.app"
