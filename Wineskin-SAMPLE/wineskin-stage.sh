#!/bin/bash
set -e

# Sample Wineskin staging script for SimPE. Run this from the Wineskin-SAMPLE directory.
# It assumes a Wineskin wrapper app already exists at SimPE.app.

APP_NAME="SimPE.app"
APP_DIR="$PWD/$APP_NAME"
RESOURCE_DIR="$APP_DIR/Contents/Resources"
MACOS_DIR="$APP_DIR/Contents/MacOS"

if [ ! -d "$APP_DIR" ]; then
  echo "Error: $APP_NAME not found in $PWD"
  exit 1
fi

if [ ! -d "$RESOURCE_DIR" ]; then
  echo "Error: Resources folder missing in $APP_NAME"
  exit 1
fi

# Copy the sample Wineskin settings into the wrapper.
cp -f "$PWD/WineskinSettings.plist" "$RESOURCE_DIR/"

# Ensure the entrypoint is set.
if [ -f "$APP_DIR/Contents/Info.plist" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable WineskinLauncher" "$APP_DIR/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string WineskinLauncher" "$APP_DIR/Contents/Info.plist"
fi

# Stage the sample launcher if needed.
if [ -f "$PWD/Contents/MacOS/run-simpe.sh" ]; then
  mkdir -p "$MACOS_DIR"
  cp -f "$PWD/Contents/MacOS/run-simpe.sh" "$MACOS_DIR/"
  chmod +x "$MACOS_DIR/run-simpe.sh"
fi

# Ensure the wineprefix exists before install.
mkdir -p "$RESOURCE_DIR/wineprefix"

# Install .NET 8 inside the wrapper prefix.
# This script assumes wine and winetricks are available on the host.
export WINEPREFIX="$RESOURCE_DIR/wineprefix"
export WINESKIN_APP="$APP_DIR"

if [ -x "$PWD/install-dotnet8.sh" ]; then
  "$PWD/install-dotnet8.sh"
else
  echo "Warning: install-dotnet8.sh not found or executable. Run it manually with the correct wrapper prefix."
fi

echo "Wineskin staging complete. Verify the wrapper in Wineskin Winery if necessary."
