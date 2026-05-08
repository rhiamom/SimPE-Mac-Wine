#!/bin/bash
set -e

# Deploy the latest build-simpe.sh publish output into a Wineskin SimPE.app,
# preserving user-state files that SimPE generates at runtime (Packs.cfg,
# GameRoot.cfg, the *.xreg layout/registry files, and the objcache*).
#
# Usage:
#   ./deploy.sh                       # defaults to /Applications/SimPE.app
#   ./deploy.sh /path/to/SimPE.app    # custom target

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO_ROOT/vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish"
DEST_APP="${1:-/Applications/SimPE.app}"
DEST="$DEST_APP/Contents/drive_c/Program Files/SimPE"

if [ ! -d "$SRC" ]; then
  echo "Error: publish folder not found at $SRC"
  echo "       Run ./build-simpe.sh first."
  exit 1
fi

if [ ! -d "$DEST_APP" ]; then
  echo "Error: $DEST_APP does not exist."
  echo "       Stage a Wineskin wrapper there first (see Wineskin-SAMPLE/)."
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Stash user state generated at runtime so the rm -rf below doesn't lose it.
# Packs.cfg / GameRoot.cfg are pack-scan results; .xreg files are SimPE's
# layout + recent-files state; objcache*.simpepkg is the built object index.
mkdir -p "$STAGE/Data"
if [ -d "$DEST/Data" ]; then
  for f in "$DEST/Data/Packs.cfg" \
           "$DEST/Data/Packs.cfg.bak" \
           "$DEST/Data/GameRoot.cfg"; do
    [ -f "$f" ] && cp "$f" "$STAGE/Data/"
  done
  for f in "$DEST/Data"/*.xreg "$DEST/Data"/objcache*.simpepkg; do
    [ -f "$f" ] && cp "$f" "$STAGE/Data/"
  done
fi

# Wipe and redeploy from publish.
rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

# Restore stashed user state on top of the fresh deploy.
if [ -n "$(ls -A "$STAGE/Data" 2>/dev/null)" ]; then
  cp -R "$STAGE/Data"/. "$DEST/Data"/
fi

echo "Deployed to $DEST_APP"
echo "  Root items: $(ls "$DEST" 2>/dev/null | wc -l | tr -d ' ')"
echo "  Plugins:    $(ls "$DEST/Plugins" 2>/dev/null | wc -l | tr -d ' ')"
echo "  Data files: $(ls "$DEST/Data" 2>/dev/null | wc -l | tr -d ' ')"

if [ -f "$DEST/Data/Packs.cfg" ]; then
  echo "  Packs.cfg:  preserved"
else
  echo "  Packs.cfg:  not present (re-run pack discovery in SimPE)"
fi
