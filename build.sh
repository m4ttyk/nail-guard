#!/bin/zsh
# Builds dist/NailGuard.app and the zip attached to GitHub releases.
set -e
cd "${0:A:h}"
swift build -c release
app=dist/NailGuard.app
rm -rf dist
mkdir -p "$app/Contents/MacOS"
cp .build/release/NailGuard "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
codesign --force --sign - "$app"
ditto -c -k --keepParent "$app" dist/NailGuard-macos-arm64.zip
