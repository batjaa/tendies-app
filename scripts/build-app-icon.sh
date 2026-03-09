#!/usr/bin/env bash
# Build AppIcon.icns from Resources/AppIcon-1024.png using sips, ImageMagick (alpha), and iconutil.
# Requires: sips (macOS), iconutil (macOS), ImageMagick (convert) for adding alpha channel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES="$REPO_ROOT/Resources"
SRC="$RESOURCES/AppIcon-1024.png"
ICONSET="$REPO_ROOT/AppIcon.iconset"
OUT="$RESOURCES/AppIcon.icns"
SQUARE_1024="$(mktemp -t AppIcon-1024-square).png"

if [[ ! -f "$SRC" ]]; then
    echo "Error: source icon not found at $SRC"
    exit 1
fi

# Ensure square 1024x1024 source (iconutil expects square; crop to square then resize)
W=$(sips -g pixelWidth "$SRC" | awk '/pixelWidth:/ {print $2}')
H=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight:/ {print $2}')
SIZE=$(( W > H ? H : W ))
sips -c "$SIZE" "$SIZE" "$SRC" --out "$SQUARE_1024"
sips -z 1024 1024 "$SQUARE_1024" --out "$SQUARE_1024"

mkdir -p "$ICONSET"

for size in 16 32 64 128 256 512 1024; do
  case "$size" in
    16)  out="icon_16x16.png";     r="16";;
    32)  out="icon_16x16@2x.png";  r="32";;
    64)  out="icon_32x32@2x.png";  r="64";;
    128) out="icon_128x128.png";   r="128";;
    256) out="icon_128x128@2x.png"; r="256";;
    512) out="icon_256x256@2x.png"; r="512";;
    1024) out="icon_512x512@2x.png"; r="1024";;
  esac
  sips -z "$r" "$r" "$SQUARE_1024" --out "$ICONSET/$out"
done
sips -z 32 32  "$SQUARE_1024" --out "$ICONSET/icon_32x32.png"
sips -z 256 256 "$SQUARE_1024" --out "$ICONSET/icon_256x256.png"
sips -z 512 512 "$SQUARE_1024" --out "$ICONSET/icon_512x512.png"

# iconutil requires PNGs to have an alpha channel (truecolor RGBA, not colormap)
if command -v magick &>/dev/null; then
  for f in "$ICONSET"/*.png; do
    magick "$f" -alpha set -type TrueColorAlpha "$f"
  done
elif command -v convert &>/dev/null; then
  for f in "$ICONSET"/*.png; do
    convert "$f" -alpha set -type TrueColorAlpha "$f"
  done
else
  echo "Warning: ImageMagick (magick or convert) not found; iconutil may fail without alpha. Install with: brew install imagemagick"
fi

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET" "$SQUARE_1024"

echo "Built $OUT"
