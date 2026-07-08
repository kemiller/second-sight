#!/bin/bash
# Builds dist/SecondSight.app from the SwiftPM release binary.
# Usage: Scripts/build-app.sh [--install]
#   --install  also copy the app to /Applications (enables Launch at Login)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/SecondSight.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/SecondSight "$APP/Contents/MacOS/SecondSight"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/SecondSight.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/SecondSight.app"
fi
