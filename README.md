# Nail Guard

A macOS app that uses the camera to catch you touching your mouth or biting your nails. When it does, all screens go black and a harsh buzzer plays until you move your hand away.

Detection runs on your Mac with Apple Vision. Video never leaves the computer.

## Use

1. Download the `.dmg` from [Releases](https://github.com/m4ttyk/nail-guard/releases). It needs macOS 14 or newer on Apple silicon.
2. Open it and drag Nail Guard to Applications.
3. The app is not notarized, so macOS blocks the first launch. Try to open it, then choose **Open Anyway** in System Settings → Privacy & Security. Or run: `xattr -d com.apple.quarantine /Applications/NailGuard.app`
4. Allow camera access and click Start.

Press **Esc** to stop during a penalty. If Esc does not respond, click the black screen and press it again.

Touching your mouth for 2 checks in a row triggers the penalty, including while eating or drinking. Detection is based on hand-to-mouth distance and was tuned on very few images, so expect mistakes.

## Build

Requires Xcode 26 or newer.

```bash
swift test
./build.sh
open dist/NailGuard.app
```
