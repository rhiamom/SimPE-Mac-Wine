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
WIZARDS_PROJ="$SUBMODULE_DIR/Wizards of SimPe/Wizards of SimPe.csproj"

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

# Step 2: Stash the whole unified bin/Release, not just Plugins/ and Data/.
# Many plugin DLLs must ALSO sit at the top level next to SimPE.Main.exe
# (the Windows and Linux releases ship 58 of them in both places), and the
# Collection Creator reads its images from a data/ folder next to whichever
# copy of its DLL was loaded. Overlaying only Plugins/ left 29 plugins
# without their top-level copy in every Mac release up to 0.8.4.10.
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
cp -R "$SUBMODULE_DIR/bin/Release" "$STAGE_DIR/Release"

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

# Step 4b: Republish "Wizards of SimPe" self-contained and overlay it.
#
# SimPE.ToolBoxWorkshops has a ProjectReference to "Wizards of SimPe", so
# Main's publish builds Wizards transitively — but `--self-contained` does NOT
# propagate through ProjectReferences to WinExe projects. The transitive build
# produces a framework-dependent `Wizards of SimPe.runtimeconfig.json` that
# asks for an installed Microsoft.NETCore.App 8.0.0. Inside the Wine prefix
# there's no shared runtime, so launching Wizards from SimPE's menu pops
# Wine's "You must install or update .NET" dialog.
#
# Publishing Wizards directly with --self-contained writes a runtimeconfig
# that uses `includedFrameworks` (matching Main) so it consumes the runtime
# DLLs already sitting alongside it in the SimPE folder.
dotnet publish "$WIZARDS_PROJ" \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:EnableWindowsTargeting=true \
  -p:ErrorOnDuplicatePublishOutputFiles=false

WIZARDS_PUBLISH_DIR="$SUBMODULE_DIR/Wizards of SimPe/bin/Release/win-x64/publish"
cp -R "$WIZARDS_PUBLISH_DIR"/. "$PUBLISH_DIR"/

# Step 5: Overlay the stashed bin/Release into the publish output. Files the
# publish already has are kept: its SimPE.Main.* and "Wizards of SimPe".*
# (self-contained apphost, runtimeconfig with includedFrameworks, deps)
# must win over bin/Release's framework-dependent ones. Building on the Mac
# also leaves native macOS files in bin/Release (an extension-less
# "Wizards of SimPe" apphost and runtimes/*/native/libglfw*); Wine never
# uses them, and unsigned Mach-O files would break notarization.
rsync -a --ignore-existing \
  --exclude '/runtimes/' --exclude '/Wizards of SimPe' --exclude '/SimPE.Main' \
  "$STAGE_DIR/Release"/ "$PUBLISH_DIR"/
# The same macOS apphosts can also arrive through the publish steps.
rm -f "$PUBLISH_DIR/Wizards of SimPe" "$PUBLISH_DIR/SimPE.Main"
if [ -d "$PUBLISH_DIR/Plugins/data/Images" ]; then
  mkdir -p "$PUBLISH_DIR/Data/Images"
  cp "$PUBLISH_DIR/Plugins/data/Images"/* "$PUBLISH_DIR/Data/Images"/
fi

echo
echo "Publish output: $PUBLISH_DIR"
echo "Main binary:    $PUBLISH_DIR/SimPE.Main.exe"
echo "Plugins:        $(ls "$PUBLISH_DIR/Plugins" 2>/dev/null | wc -l | tr -d ' ') items"
echo "Also top-level: $(cd "$PUBLISH_DIR/Plugins" && for f in *.dll; do [ -e "../$f" ] && echo; done | wc -l | tr -d ' ') plugin DLLs"
echo "Data files:     $(ls "$PUBLISH_DIR/Data" 2>/dev/null | wc -l | tr -d ' ') files"
