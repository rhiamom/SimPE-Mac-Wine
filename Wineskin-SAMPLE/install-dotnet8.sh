#!/bin/bash
set -e

# Sample script to install .NET 8 into a Wine prefix for SimPE.
# Run this on the host machine while building the Wineskin wrapper.

WINEPREFIX="${WINEPREFIX:-$PWD/SimPE.app/Contents/Resources/wineprefix}"
WINE="$(command -v wine || true)"
WINETRICKS="$(command -v winetricks || true)"

if [ -z "$WINE" ]; then
  echo "Error: wine is required on the host to install .NET 8 into the wrapper prefix."
  exit 1
fi

mkdir -p "$WINEPREFIX"
export WINEPREFIX
export WINE

if [ -z "$WINETRICKS" ]; then
  echo "Error: winetricks is required to install dotnet8 automatically."
  exit 1
fi

# Use winetricks to install the .NET 8 runtime and desktop runtime.
# If your Wine engine or wrapper does not support dotnet8 directly, replace this with an explicit
# installation using the Microsoft .NET 8 Desktop Runtime installer for Windows.

echo "Installing .NET 8 runtime into Wine prefix: $WINEPREFIX"

winetricks -q dotnet80

# Some wrappers may require the runtime to be installed in a specific prefix layout.
# In that case, run the official .NET 8 Desktop Runtime installer inside Wine instead.

if [ $? -ne 0 ]; then
  echo "Failed to install dotnet80 with winetricks."
  exit 1
fi

# Confirm the runtime was installed.
if ! wine --version >/dev/null 2>&1; then
  echo "Error: Wine is not available after dotnet installation."
  exit 1
fi

echo "Installed .NET 8 into prefix successfully."

echo "Copy the completed wineprefix and Wineskin settings into the app bundle before packaging."
