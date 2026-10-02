#!/bin/zsh
# Build cmx (Release) and install it to /Applications.
# Usage: scripts/install.sh            — build, install, register
#        scripts/install.sh --no-build — reinstall the last Release build
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED="build"
APP="$DERIVED/Build/Products/Release/cmx.app"
DEST="/Applications/cmx.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ "${1:-}" != "--no-build" ]]; then
    echo "▸ Building Release…"
    xcodebuild -project cmx.xcodeproj -scheme cmx -configuration Release \
        -destination 'platform=macOS' -derivedDataPath "$DERIVED" build -quiet
fi

[[ -d "$APP" ]] || { echo "error: $APP not found — build failed?" >&2; exit 1; }

if pgrep -xq cmx; then
    echo "▸ Quitting running cmx…"
    osascript -e 'tell application "cmx" to quit' 2>/dev/null || true
    sleep 1
fi

echo "▸ Installing → $DEST"
rm -rf "$DEST"
# ditto, not cp: preserves the code signature and extended attributes
ditto "$APP" "$DEST"

echo "▸ Registering with LaunchServices…"
# The build product registers itself too; drop it so Launchpad and the
# .cbz association only see the installed copy.
"$LSREGISTER" -u "$PWD/$APP" 2>/dev/null || true
"$LSREGISTER" -f "$DEST"

echo "✓ Installed $(defaults read "$DEST/Contents/Info" CFBundleShortVersionString) → $DEST"
