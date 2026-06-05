#!/bin/bash
# Convert SVG to PNG app icon sizes
# Requires: brew install librsvg (for rsvg-convert)
# Usage: bash appicon-generate.sh

echo "============================================"
echo "  VetMap App Icon Generator"
echo "============================================"
echo ""

if command -v rsvg-convert &> /dev/null; then
  SRC="$(dirname "$0")/appicon.svg"
  OUT_DIR="$(dirname "$0")"

  echo "Generating 1024x1024 PNG (for App Store)..."
  rsvg-convert -w 1024 -h 1024 "$SRC" -o "$OUT_DIR/appicon-1024.png"
  echo "  -> $OUT_DIR/appicon-1024.png"

  echo ""
  echo "Done! Add the PNG to Assets.xcassets → AppIcon in Xcode."
else
  echo "rsvg-convert not found."
  echo ""
  echo "Option 1: Install librsvg with Homebrew"
  echo "  brew install librsvg"
  echo "  Then re-run this script."
  echo ""
  echo "Option 2: Use Preview.app (macOS built-in)"
  echo "  1. Open appicon.svg in Preview"
  echo "  2. File → Export → PNG"
  echo "  3. Set width/height = 1024"
  echo "  4. Save as appicon-1024.png"
  echo ""
  echo "Option 3: Use ImageMagick"
  echo "  brew install imagemagick"
  echo "  magick appicon.svg -resize 1024x1024 appicon-1024.png"
fi
