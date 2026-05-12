# SimPE-Mac-Wine — Handoff Document

**Date written:** 2026-05-08
**Written for:** Catherine (rhiamom@mac.com) and the next Claude session after migration from Intel Mac → Apple Silicon Mac.
**Why:** Claude's per-project memory lives in `~/.claude/projects/-Library-Developer-SimPE-Mac-Wine/memory/` and does NOT transfer when you move to a new machine. This file captures everything the next session needs.

---

## Part 1 — Project state as of 2026-05-08

### What's working

- The Wineskin SimPE wrapper is **fully functional on Intel Mac** (and on Apple Silicon via Rosetta).
- Recent end-to-end test: cloned an Aspyr Sims 2 stove. All file types rendered, edited, and committed cleanly: BCON, BHAV, CRES, SHPE, NREF, OBJD, STR#, GMND, GMDC, MMAT, TXMT, TXTR.
- Texture round-trip works: Export PNG → edit in GIMP → Import PNG → Build DXT → see new compressed texture.
- GMDC 3D preview works.
- App icon swapped to the SimPE logo (was the default Wine icon).

### Repo structure

```
/Library/Developer/SimPE-Mac-Wine/
├── build-simpe.sh              # Builds self-contained win-x64 publish
├── deploy.sh                   # Deploys publish into a SimPE.app, preserving user state
├── wineskin-stage.sh           # Stages a fresh Wineskin wrapper
├── package-dmg.sh              # (existing helper)
├── patches/
│   ├── apply.sh                # Applies patches idempotently before build
│   ├── 0001-mac-support.patch
│   ├── 0002-build-fix-wizardbase-postbuild.patch
│   └── 0003-mac-wine-listview-events.patch  # Wine LV event fixes
├── vendor/simpe-fixed/         # Submodule, points at github.com/rhiamom/SimPE-Fixed
├── Wineskin-SAMPLE/SimPE.app/  # Reference wrapper (gitignored)
└── APPLE-SILICON-MIGRATION-HANDOFF.md  # this file
```

### Two repos, both yours

- **`github.com/rhiamom/SimPE-Mac-Wine`** — the Mac-specific stuff (patches, build scripts, Wineskin scaffolding). Currently at `831b220`.
- **`github.com/rhiamom/SimPE-Fixed`** — the SimPE source itself, used as a submodule. Carries platform-agnostic SimPE work. Currently at `2ef5318`.

**Critical convention:** Mac/Wine-specific changes go in the `SimPE-Mac-Wine` repo (as patches under `patches/`). Platform-agnostic SimPE changes go upstream to `SimPE-Fixed` master.

### Recent work this session (2026-05-08)

1. **Fixed Wine ListView event quirks** — patch `0003-mac-wine-listview-events.patch` (committed `cff5395`):
   - Drop unconditional `resloader.Clear()` on empty selection (Wine fires spurious empty-select events).
   - Mirror `SimpleResourceSelect` single-click-to-open onto `lv_SelectionChanged` (Wine doesn't fire `ListView.Click` reliably).
   - Switch `SubsetSelectForm` LV from LargeIcon to Tile + force selection via `HitTest` on MouseDown/MouseUp.

2. **Wrote `deploy.sh`** — overlays publish into `/Applications/SimPE.app` while preserving runtime user state.

3. **Fixed BCnEncoder/Pfim DXT path** — pushed to SimPE-Fixed master as commit `2ef5318`:
   - Dropped stale `File.Exists(NvidiaDDSTool)` gates at five call sites (the gated branches already use BCnEncoder, not nvdxt).
   - Replaced Pfim's PNG handling in `LoadFileAsRgba` with `System.Drawing.Bitmap` + `LockBits` (Pfim silently throws on PNG).
   - Surfaced the previously silent failure via `Helper.ExceptionMessage`.
   - Force `pb.Image` after Build DXT (programmatic SelectedIndex doesn't always fire SelectedIndexChanged).

4. **Swapped app icon** — copied `vendor/simpe-fixed/Resources/SimPE.ico` → `.icns`, replaced `/Applications/SimPE.app/Contents/Resources/Configure.icns`. Original backed up alongside as `Configure.icns.wineskin-original`. Note: source ICO is only 48×48; will look chunky on Retina. If Catherine finds a higher-res SimPE logo, we should redo.

### Known minor quirks (not blocking)

- Subset selector's "Autoselect matching Textures" checkbox can override a manual subset pick when texture names collide. Workaround: uncheck it before clicking.
- The 48×48 source icon will look soft when scaled up. Higher-res replacement would help.

### Critical conventions (DO NOT VIOLATE)

1. **`vendor/simpe-fixed` working tree stays dirty.** Patches 0001/0002/0003 are applied locally by `patches/apply.sh` at build time. Don't commit them inside the submodule. Ever.
2. **Don't push Wine/Mac-specific patches upstream to SimPE-Fixed.** Only platform-agnostic fixes go there.
3. **`deploy.sh` deletes user state files on copy** unless they're in the preserve list. The preserve list covers `Packs.cfg`, `GameRoot.cfg`, `*.xreg`, `objcache*.simpepkg`. If new user-state files emerge, add them to `deploy.sh`.

---

## Part 2 — Migration to Apple Silicon (what Catherine does)

### Step 1: Move the repo

The repo is at `/Library/Developer/SimPE-Mac-Wine/` on the Intel Mac. On the new Apple Silicon Mac:

```bash
# Pick a destination — same path keeps things consistent
sudo mkdir -p /Library/Developer
cd /Library/Developer

# Either fresh clone (preferred — picks up everything from github)
git clone https://github.com/rhiamom/SimPE-Mac-Wine.git
cd SimPE-Mac-Wine
git submodule update --init --recursive

# OR transfer the existing folder via AirDrop / external drive / rsync
# rsync -av "user@intel-mac:/Library/Developer/SimPE-Mac-Wine/" /Library/Developer/SimPE-Mac-Wine/
```

If using fresh clone, the `Wineskin-SAMPLE/SimPE.app` won't be there (it's gitignored). Follow `Wineskin-SAMPLE/BUILD-WINESKIN.md` to recreate it, OR transfer the working `/Applications/SimPE.app` from Intel Mac.

### Step 2: Install developer tooling

```bash
# Xcode command-line tools (codesign, xcrun, notarytool)
xcode-select --install

# .NET 8 SDK — for build-simpe.sh
# Download from https://dotnet.microsoft.com/download/dotnet/8.0
# Pick the macOS Apple Silicon installer
```

### Step 3: Verify the build still works on Apple Silicon

```bash
cd /Library/Developer/SimPE-Mac-Wine
./build-simpe.sh
./deploy.sh   # Defaults to /Applications/SimPE.app
```

The build cross-compiles to `win-x64`, so even on Apple Silicon it produces a Windows-x64 publish folder. Run it through Wine and confirm it launches. (Wine + the .NET 8 win-x64 runtime go through Rosetta on Apple Silicon — this is fine.)

### Step 4: Apple Developer Program enrollment

1. Sign up at [developer.apple.com](https://developer.apple.com) — $99/year. Personal enrollment is fine.
2. Approval is usually same-day.
3. **Generate the Developer ID Application certificate ON THE APPLE SILICON MACHINE** (don't generate on Intel and try to transfer the private key — born here, stays here):
   - Open Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
   - Save the CSR file
   - Upload it at developer.apple.com under Certificates → "+" → Developer ID Application
   - Download the resulting `.cer`, double-click to install in Keychain
4. Create an app-specific password at [appleid.apple.com](https://appleid.apple.com) for use with notarytool.
5. Find your Team ID at developer.apple.com → Membership.
6. Set up the notarytool keychain profile:
   ```bash
   xcrun notarytool store-credentials notarytool-simpe \
     --apple-id you@example.com \
     --team-id YOURTEAMID \
     --password <app-specific-password>
   ```

### Step 5: Run the sign + notarize script

After Step 6 below creates the script:

```bash
./sign-and-notarize.sh "Developer ID Application: Your Name (TEAMID)"
```

Output lands in `dist/SimPE-Mac-Wine-YYYYMMDD-HHMM.zip`, ready for distribution.

---

## Part 3 — Pending task: create the sign-and-notarize script

This is what the previous session was about to write when the migration came up. The next session needs to **create two files** at the repo root, then verify the build still works.

### File 1: `wineskin-entitlements.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Hardened-runtime entitlements for the Wineskin SimPE bundle.

  Wine does several things that macOS's hardened runtime forbids by default,
  so we have to grant explicit exceptions or the notarized app will fail to
  launch with cryptic "killed: 9" or codesign errors:

    allow-jit
        Wine's CPU emulation paths and the .NET 8 RyuJIT both rely on
        runtime-generated code.

    allow-unsigned-executable-memory
        Wine maps Windows .exe / .dll pages as executable; those pages have
        no Apple signature.

    disable-library-validation
        We load .NET-runtime DLLs and SimPE plugin DLLs that aren't signed
        with our team identifier. Library validation would block them.

    disable-executable-page-protection
        Wine flips page protections (RW <-> RX) on JIT'd code regions.

    allow-dyld-environment-variables
        Wineskin sets DYLD_FALLBACK_LIBRARY_PATH (and friends) before exec'ing
        wineserver. With hardened runtime those env vars are stripped unless
        we explicitly allow them.
-->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
</dict>
</plist>
```

### File 2: `sign-and-notarize.sh` (chmod +x)

```bash
#!/bin/bash
set -euo pipefail

# Sign, notarize, and package /Applications/SimPE.app for distribution.
#
# Usage:
#   ./sign-and-notarize.sh "Developer ID Application: Your Name (TEAMID)"
#   ./sign-and-notarize.sh -s "..." -i /path/to/SimPE.app -p notarytool-simpe
#
# Flags:
#   -s   Code-signing identity (required if not in $SIGN_IDENTITY env var).
#        Run `security find-identity -v -p codesigning` to list available IDs.
#   -i   Source .app to sign. Default: /Applications/SimPE.app
#   -o   Output directory. Default: $REPO_ROOT/dist
#   -p   notarytool keychain profile name. Default: notarytool-simpe
#        Create one beforehand with:
#          xcrun notarytool store-credentials notarytool-simpe \
#            --apple-id you@example.com \
#            --team-id YOURTEAMID \
#            --password app-specific-password
#
# What this script does:
#   1. Stages a clean copy of the .app into $OUTDIR/staging
#   2. Strips per-user runtime state (Packs.cfg, GameRoot.cfg, *.xreg,
#      objcache*.simpepkg, drive_c/users/<name>/Documents/...) so each
#      recipient generates their own
#   3. Walks every Mach-O binary deepest-first and signs each with the
#      hardened runtime + Wineskin entitlements
#   4. Signs the outer .app last
#   5. Verifies the signature
#   6. Zips the .app with ditto (preserves resource forks / xattrs)
#   7. Submits to Apple's notarization service and waits for the result
#   8. Staples the notarization ticket to the .app so it works offline
#   9. Re-zips the stapled .app as the final distributable

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS="$REPO_ROOT/wineskin-entitlements.plist"

SRC_APP="/Applications/SimPE.app"
OUTDIR="$REPO_ROOT/dist"
PROFILE="notarytool-simpe"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

while getopts "s:i:o:p:h" opt; do
  case "$opt" in
    s) SIGN_IDENTITY="$OPTARG" ;;
    i) SRC_APP="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    h) sed -n '3,30p' "$0"; exit 0 ;;
    *) echo "Unknown flag. Run with -h for help." >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))
# Allow positional fallback for the identity (so the simple call shape works).
if [ -z "$SIGN_IDENTITY" ] && [ $# -gt 0 ]; then SIGN_IDENTITY="$1"; fi

if [ -z "$SIGN_IDENTITY" ]; then
  echo "Error: pass a Developer ID identity with -s '...' or as a positional arg." >&2
  echo "       Run 'security find-identity -v -p codesigning' to see what's available." >&2
  exit 2
fi
if [ ! -d "$SRC_APP" ]; then
  echo "Error: source app not found: $SRC_APP" >&2
  exit 2
fi
if [ ! -f "$ENTITLEMENTS" ]; then
  echo "Error: entitlements not found: $ENTITLEMENTS" >&2
  exit 2
fi
if ! command -v codesign >/dev/null; then
  echo "Error: codesign not in PATH. Install Xcode command-line tools." >&2
  exit 2
fi
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "Error: notarytool keychain profile '$PROFILE' is not set up." >&2
  echo "       Create it with:" >&2
  echo "         xcrun notarytool store-credentials $PROFILE \\" >&2
  echo "           --apple-id you@example.com \\" >&2
  echo "           --team-id YOURTEAMID \\" >&2
  echo "           --password <app-specific-password>" >&2
  exit 2
fi

mkdir -p "$OUTDIR"
STAGE="$OUTDIR/staging"
APP_NAME="$(basename "$SRC_APP")"
APP="$STAGE/$APP_NAME"

echo "==> Staging $SRC_APP -> $APP"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$SRC_APP" "$APP"

echo "==> Stripping per-user runtime state from staged copy"
DATA="$APP/Contents/drive_c/Program Files/SimPE/Data"
if [ -d "$DATA" ]; then
  # User-generated; recipients should produce their own on first launch.
  rm -f "$DATA/Packs.cfg" "$DATA/Packs.cfg.bak" "$DATA/GameRoot.cfg"
  rm -f "$DATA"/*.xreg
  rm -f "$DATA"/objcache*.simpepkg
fi
# Wine prefix user-dir name is bound to whoever created the wrapper.
# Wipe Documents/Settings under each user so no personal paths leak.
WUSERS="$APP/Contents/drive_c/users"
if [ -d "$WUSERS" ]; then
  for u in "$WUSERS"/*; do
    [ -d "$u" ] || continue
    rm -rf "$u/Documents" "$u/AppData/Local/Temp" 2>/dev/null || true
  done
fi
# Stale build/log artefacts.
rm -f "$APP/Contents/drive_c/Program Files/SimPE/pluginlog.txt"

echo "==> Locating Mach-O binaries to sign (deepest-first)"
# `file --mime-type` lets us filter for Mach-O so we skip Windows PEs,
# scripts, plists, etc.  The depth-sort makes inner items sign first.
TMPLIST="$STAGE/.machofiles"
find "$APP" -type f -print0 \
  | xargs -0 file --mime-type \
  | awk -F': *' '$2 ~ /application\/x-mach-binary/ { sub(":$","",$1); print $1 }' \
  | awk '{ n = gsub("/","/",$0); print n"\t"$0 }' \
  | sort -k1,1nr -k2,2 \
  | cut -f2- \
  > "$TMPLIST"
COUNT=$(wc -l < "$TMPLIST" | tr -d ' ')
echo "    found $COUNT Mach-O binaries"

echo "==> Signing inner binaries"
while IFS= read -r bin; do
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$bin" >/dev/null
done < "$TMPLIST"

echo "==> Signing nested .app bundles (if any)"
# Order nested .apps by depth too (innermost first) so the outer .app's
# signature covers already-signed inner .apps.
find "$APP" -mindepth 1 -name "*.app" -type d \
  | awk '{ n = gsub("/","/",$0); print n"\t"$0 }' \
  | sort -k1,1nr -k2,2 \
  | cut -f2- \
  | while IFS= read -r inner_app; do
      codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$inner_app" >/dev/null
    done

echo "==> Signing outer bundle: $APP"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"
spctl -a -t exec -vvv "$APP" || true

echo "==> Creating zip for notarization upload"
NOTARIZE_ZIP="$STAGE/SimPE.app.notarize.zip"
ditto -c -k --keepParent "$APP" "$NOTARIZE_ZIP"

echo "==> Submitting to Apple notary service (this can take 5-15 minutes)"
xcrun notarytool submit "$NOTARIZE_ZIP" \
  --keychain-profile "$PROFILE" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# Final distributable zip — name with date so successive builds don't clobber.
STAMP="$(date +%Y%m%d-%H%M)"
DIST_ZIP="$OUTDIR/SimPE-Mac-Wine-$STAMP.zip"
echo "==> Packaging final distributable: $DIST_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST_ZIP"

echo ""
echo "Done."
echo "  Signed + notarized + stapled .app:  $APP"
echo "  Distributable zip:                  $DIST_ZIP"
echo ""
echo "Recipients will be able to launch the app with no Gatekeeper warning."
```

### After creating both files

```bash
chmod +x sign-and-notarize.sh

# Add to git
git add sign-and-notarize.sh wineskin-entitlements.plist
git commit -m "Add sign + notarize pipeline for distribution"
git push origin main
```

### Likely first-run gotchas

Wineskin apps occasionally fail notarization or fail to launch after signing because of entitlements gaps. If you see "killed: 9" or specific entitlement errors after running the script and trying to launch the signed app:

1. Run `codesign -d --entitlements - /Applications/SimPE.app` to inspect what entitlements actually got applied.
2. Check Console.app for the specific killed-process reason (search for "SimPE" or "Wine").
3. Common missing entitlements that may need adding to `wineskin-entitlements.plist`:
   - `com.apple.security.cs.debugger` (if Wine needs ptrace)
   - `com.apple.security.get-task-allow` (only for development; never ship)
4. Notarization failures: `xcrun notarytool log <submission-id> --keychain-profile notarytool-simpe` shows the rejection details.

---

## Part 4 — Briefing for the next Claude session

If you're a fresh Claude session reading this on Apple Silicon, here's what you need to know:

1. **Read the project memory once it's recreated** — it'll go in `~/.claude/projects/-Library-Developer-SimPE-Mac-Wine/memory/` as you work.
2. **The user is Catherine (rhiamom@mac.com)**. She's the maintainer of both `SimPE-Mac-Wine` and `SimPE-Fixed` repos on GitHub.
3. **Iteration preference (important):** Catherine prefers small, isolated changes during visual UI debugging. Don't stack multiple changes between test cycles. Especially flag anything that changes UI layout (View modes, control reordering) before testing — past sessions have caused frustration by shuffling UI state without warning.
4. **Submodule convention (important):** `vendor/simpe-fixed` working tree is intentionally left dirty. Patches under `patches/` are applied locally at build time. Never commit those patches inside the submodule. Mac/Wine-specific stuff stays as patches in the parent repo; platform-agnostic SimPE work goes upstream to `SimPE-Fixed` master.
5. **Pending immediate task:** Create the two files in Part 3 above (`wineskin-entitlements.plist` and `sign-and-notarize.sh`). After that's in place, Catherine should set up her Developer ID cert + notarytool keychain profile per Part 2 Step 4, then run the script.
6. **Build + deploy is just** `./build-simpe.sh && ./deploy.sh` — preserves user state in the wrapper. Default deploy target is `/Applications/SimPE.app`.

---

*End of handoff document. Good luck on Apple Silicon. — previous Claude session*
