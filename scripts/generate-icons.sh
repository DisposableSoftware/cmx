#!/bin/zsh
# Redraw every icon and install it into the app target.
#   scripts/generate-icons.sh
#
# Each size is drawn at its own pixel size by generate-icons.swift — nothing is
# downscaled, because a downscaled 16px icon is unreadable mush.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "▸ Rendering…"
swift scripts/generate-icons.swift "$WORK"

echo "▸ App icon → Assets.xcassets"
SET="cmx/Assets.xcassets/AppIcon.appiconset"
for px in 16 32 64 128 256 512 1024; do
    cp "$WORK/app-$px.png" "$SET/icon_$px.png"
done

echo "▸ Document icon → cmx/cbz.icns"
ICONSET="$WORK/cbz.iconset"
mkdir -p "$ICONSET"
# 1x and 2x share a file: 16pt@2x is the same image as 32pt@1x.
cp "$WORK/doc-16.png"   "$ICONSET/icon_16x16.png"
cp "$WORK/doc-32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$WORK/doc-32.png"   "$ICONSET/icon_32x32.png"
cp "$WORK/doc-64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$WORK/doc-128.png"  "$ICONSET/icon_128x128.png"
cp "$WORK/doc-256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$WORK/doc-256.png"  "$ICONSET/icon_256x256.png"
cp "$WORK/doc-512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$WORK/doc-512.png"  "$ICONSET/icon_512x512.png"
cp "$WORK/doc-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o cmx/cbz.icns

echo "✓ Icons regenerated. Run scripts/install.sh to see them in Finder."
