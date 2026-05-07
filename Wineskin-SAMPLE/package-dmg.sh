#!/bin/bash
set -e

# Create a compressed DMG installer for the final SimPE.app bundle.
# Usage: ./package-dmg.sh

APP_NAME="SimPE.app"
DMG_NAME="SimPE-macOS.dmg"
VOLUME_NAME="SimPE Installer"
OUTPUT_DIR="$PWD/dist"
APP_DIR="$PWD/$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
  echo "Error: $APP_NAME not found in $PWD"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/$DMG_NAME"

# Create a temporary staging folder with the app and an Applications alias.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cp -R "$APP_DIR" "$TMPDIR/"
ln -s /Applications "$TMPDIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$TMPDIR" \
  -fs HFS+ \
  -format UDZO \
  "$OUTPUT_DIR/$DMG_NAME"

echo "Created $OUTPUT_DIR/$DMG_NAME"
