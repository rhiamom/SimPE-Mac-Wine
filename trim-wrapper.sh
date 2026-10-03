#!/bin/bash
set -euo pipefail

# Remove the parts of a stock Sikarugir wrapper that SimPE never uses: the
# ~293 MB that was removed from the wrapper behind every SimPE for Mac release
# up to 0.8.4.4, plus Wine Mono (~230 MB) and Wine Gecko (~210 MB), removed
# from 2026-10-03 on. SimPE is a plain WinForms program on its own bundled
# .NET 8: it needs no 3D translation layers, no Vulkan, no audio/video
# playback, not Wine Mono (Wine's stand-in for the old Windows .NET
# Framework), and not Wine Gecko (Wine's web-page engine).
#
# About Gecko: SimPE.Main/About.cs does create a WebBrowser control, but the
# About and Welcome windows keep it hidden and show their text in a
# RichTextBox; the only window that shows it (ShowTutorials) is never called.
#
# The list below was worked out on 2026-10-03 by comparing the released
# SimPE.app with a stock Sikarugir Template-1.0.11 + WS12WineSikarugir10.0_6
# wrapper; these are exactly the files the release lacks. Mono and Gecko
# were tested on 2026-10-03 (start-up, Object Workshop catalogue, About and
# Welcome windows). Safe to re-run.
#
# Usage:
#   ./trim-wrapper.sh                      # defaults to /Applications/SimPE.app
#   ./trim-wrapper.sh /path/to/SimPE.app

APP="${1:-/Applications/SimPE.app}"
C="$APP/Contents"

if [ ! -d "$C/SharedSupport/wine" ]; then
  echo "Error: $APP does not look like a Sikarugir wrapper (no Contents/SharedSupport/wine)." >&2
  exit 1
fi

before=$(du -sm "$APP" | cut -f1)

remove() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    rm -rf "$1"
    echo "  removed ${1#"$APP"/}"
  fi
}

echo "Trimming $APP"
# Audio/video playback (GStreamer) and Wine's bridge to it.
remove "$C/Frameworks/GStreamer.framework"
remove "$C/SharedSupport/wine/lib/wine/i386-windows/winegstreamer.dll"
remove "$C/SharedSupport/wine/lib/wine/x86_64-windows/winegstreamer.dll"
remove "$C/SharedSupport/wine/lib/wine/x86_64-unix/winegstreamer.so"
# 3D graphics translators for games (D3DMetal, DXMT, DXVK, D9VK, cnc-ddraw).
remove "$C/Frameworks/renderer"
# Vulkan-to-Metal, used only by those translators.
remove "$C/Frameworks/libMoltenVK.dylib"
remove "$C/Frameworks/moltenvkcx"
# Settings helper for extra custom launchers.
remove "$C/Configure.app/Contents/Resources/CustomEXE.app"
# Wine Mono, and tell the wrapper not to (re)install it.
remove "$C/SharedSupport/wine/share/wine/mono"
if /usr/libexec/PlistBuddy -c 'Print :"Skip Mono"' "$C/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Set :"Skip Mono" 1' "$C/Info.plist"
else
  /usr/libexec/PlistBuddy -c 'Add :"Skip Mono" integer 1' "$C/Info.plist"
fi
echo "  set Skip Mono = 1 in Info.plist"
# Wine Gecko, and tell the wrapper not to (re)install it.
remove "$C/SharedSupport/wine/share/wine/gecko"
if /usr/libexec/PlistBuddy -c 'Print :"Skip Gecko"' "$C/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Set :"Skip Gecko" 1' "$C/Info.plist"
else
  /usr/libexec/PlistBuddy -c 'Add :"Skip Gecko" integer 1' "$C/Info.plist"
fi
echo "  set Skip Gecko = 1 in Info.plist"

after=$(du -sm "$APP" | cut -f1)
echo "Done: ${before} MB -> ${after} MB"
echo "Leave the wrapper's graphics options (DXVK, D3DMetal, DXMT...) switched off."
