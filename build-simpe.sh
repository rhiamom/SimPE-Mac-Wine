#!/bin/bash
set -e

# Build SimPE.Main.exe on macOS as a self-contained win-x64 executable.
# Output: vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish/
#
# Self-contained means the .NET 8 Windows Desktop Runtime ships inside the
# publish folder, so the Wine prefix does NOT need a separate winetricks
# dotnet80 install. Trade-off: publish folder grows from ~16 MB to ~80 MB.

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SUBMODULE_DIR="$REPO_ROOT/vendor/simpe-fixed"
SLN="$SUBMODULE_DIR/SimPE-Fixed.sln"
MAIN_PROJ="$SUBMODULE_DIR/SimPE.Main/SimPE.Main.csproj"

# Apply local patches before building.
"$REPO_ROOT/patches/apply.sh"

cd "$SUBMODULE_DIR"

# Clean to avoid NETSDK1152 from previous build artifacts colliding with publish.
dotnet clean "$SLN" -c Release -p:EnableWindowsTargeting=true >/dev/null
find . -type d \( -name bin -o -name obj \) -prune -exec rm -rf {} + 2>/dev/null || true

dotnet publish "$MAIN_PROJ" \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:EnableWindowsTargeting=true \
  -p:ErrorOnDuplicatePublishOutputFiles=false

PUBLISH_DIR="$SUBMODULE_DIR/SimPE.Main/bin/Release/win-x64/publish"
echo
echo "Publish output: $PUBLISH_DIR"
echo "Main binary:    $PUBLISH_DIR/SimPE.Main.exe"
