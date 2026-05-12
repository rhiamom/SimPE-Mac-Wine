#!/bin/bash
set -e

# Determine the wrapper root and resource paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="$WRAPPER_DIR/Resources"
WINEPREFIX="$RESOURCES_DIR/wineprefix"
WINE_BIN="$RESOURCES_DIR/wine/bin/wine"

# Use the system wine if no bundled runtime exists.
if [ ! -x "$WINE_BIN" ]; then
    WINE_BIN="$(command -v wine || true)"
fi

if [ -z "$WINE_BIN" ] || [ ! -x "$WINE_BIN" ]; then
    echo "Error: Wine binary not found in bundle or system PATH."
    exit 1
fi

export WINEPREFIX="$WINEPREFIX"
export HOME="${HOME:-$(getent passwd $(whoami) | cut -d: -f6)}"
export WINEDEBUG="-all"

SIMPE_EXE="$RESOURCES_DIR/drive_c/Program Files/SimPE/SimPE.Main.exe"
if [ ! -f "$SIMPE_EXE" ]; then
    echo "Error: SimPE.Main.exe not found at $SIMPE_EXE"
    exit 1
fi

# Make sure the prefix exists
mkdir -p "$WINEPREFIX"

# Launch SimPE through Wine
exec "$WINE_BIN" "$(printf '%s' "$SIMPE_EXE")"
