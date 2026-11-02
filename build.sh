#!/bin/zsh
# Builds dist/NailGuard.app and the disk image attached to GitHub releases.
set -e
cd "${0:A:h}"
swift build -c release
app=dist/NailGuard.app
rm -rf dist
mkdir -p "$app/Contents/MacOS"
cp .build/release/NailGuard "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
codesign --force --sign - "$app"

# Drag-to-install disk image: the app next to a link to /Applications.
stage=dist/dmg
mkdir -p "$stage"
ditto "$app" "$stage/NailGuard.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "Nail Guard" -srcfolder "$stage" -format UDZO dist/NailGuard-macos-arm64.dmg
rm -rf "$stage"
