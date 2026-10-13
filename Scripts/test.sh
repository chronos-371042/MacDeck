#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache Sources/SteamLibrary.swift Tests/main.swift -o build/MacDeckTests
build/MacDeckTests "$@"
