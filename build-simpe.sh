#!/bin/bash
set -e

# Build SimPE.Main.exe on macOS as a self-contained win-x64 executable.
# Output: vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish/
#
# Self-contained means the .NET 8 Windows Desktop Runtime ships inside the
# publish folder, so the Wine prefix does NOT need a separate winetricks
# dotnet80 install. Trade-off: publish folder grows from ~16 MB to ~210 MB
# once plugins, Data/, and sidecar files are overlaid.

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SUBMODULE_DIR="$REPO_ROOT/vendor/simpe-fixed"
SLN="$SUBMODULE_DIR/SimPE-Fixed.sln"
MAIN_PROJ="$SUBMODULE_DIR/SimPE.Main/SimPE.Main.csproj"

# Apply local patches before building.
"$REPO_ROOT/patches/apply.sh"

cd "$SUBMODULE_DIR"

# Step 1: Solution-wide build.
#
# `dotnet publish SimPE.Main` only follows direct project references and
# misses two things SimPE needs at runtime:
#   - Plugin DLLs (e.g. simpe.bhav.plugin.dll, pjse.coder.plugin.dll) are
#     loaded dynamically and aren't listed as project references.
#   - The Data/ folder of XML files (additional_careers.xml, hoods.xml, etc.)
#     produced by SimPE.Helper's custom MSBuild target.
#   - Plugin sidecar files like Plugins/pjse.coder.plugin/GlobalStrings.package.
#
# A full solution build populates vendor/simpe-fixed/bin/Release/ with all
# of the above via Directory.Build.targets' SimPeCopyToUnifiedBin target.
dotnet build "$SLN" -c Release --graph -p:EnableWindowsTargeting=true

# Step 2: Stash the artifacts publish would otherwise miss.
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
[ -d "$SUBMODULE_DIR/bin/Release/Plugins" ] && cp -R "$SUBMODULE_DIR/bin/Release/Plugins" "$STAGE_DIR/Plugins"
[ -d "$SUBMODULE_DIR/bin/Release/Data" ]    && cp -R "$SUBMODULE_DIR/bin/Release/Data"    "$STAGE_DIR/Data"

# Step 3: Clean before publish to avoid NETSDK1152 (the build above leaves
# non-RID outputs that collide with the publish step's RID-specific outputs).
dotnet clean "$SLN" -c Release -p:EnableWindowsTargeting=true >/dev/null
find . -type d \( -name bin -o -name obj \) -prune -exec rm -rf {} + 2>/dev/null || true

# Step 4: Publish SimPE.Main self-contained for win-x64. This produces the
# .NET 8 runtime + apphost (SimPE.Main.exe) + all directly-referenced DLLs.
dotnet publish "$MAIN_PROJ" \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:EnableWindowsTargeting=true \
  -p:ErrorOnDuplicatePublishOutputFiles=false

PUBLISH_DIR="$SUBMODULE_DIR/SimPE.Main/bin/Release/win-x64/publish"

# Step 5: Overlay plugins and data into the publish output.
[ -d "$STAGE_DIR/Plugins" ] && cp -R "$STAGE_DIR/Plugins" "$PUBLISH_DIR/"
[ -d "$STAGE_DIR/Data" ]    && cp -R "$STAGE_DIR/Data"    "$PUBLISH_DIR/"

echo
echo "Publish output: $PUBLISH_DIR"
echo "Main binary:    $PUBLISH_DIR/SimPE.Main.exe"
echo "Plugins:        $(ls "$PUBLISH_DIR/Plugins" 2>/dev/null | wc -l | tr -d ' ') items"
echo "Data files:     $(ls "$PUBLISH_DIR/Data" 2>/dev/null | wc -l | tr -d ' ') files"
