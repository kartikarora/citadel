#!/usr/bin/env bash
set -euo pipefail

SRC="branding/production/citadel-app-icon-colored.png"
ICONSET="branding/Citadel.iconset"

mkdir -p "$ICONSET"

sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png"
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png"
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png"

# Also update individual production PNGs
cp "$ICONSET/icon_512x512.png" branding/production/citadel-logo-app-icon-512.png
cp "$ICONSET/icon_512x512@2x.png" branding/production/citadel-logo-app-icon-1024.png
cp "$ICONSET/icon_256x256.png" branding/production/citadel-logo-app-icon-256.png
cp "$ICONSET/icon_128x128.png" branding/production/citadel-logo-app-icon-128.png

iconutil -c icns "$ICONSET" -o branding/AppIcon.icns
echo "==> branding/AppIcon.icns rebuilt successfully!"
