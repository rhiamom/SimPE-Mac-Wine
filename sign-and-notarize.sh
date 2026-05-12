#!/bin/bash
set -euo pipefail

# Sign the Wineskin/Sikarugir SimPE.app with Developer ID, notarize, staple,
# package into a DMG, sign and notarize the DMG, staple. Re-runnable.

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${SIMPE_APP:-/Applications/SimPE.app}"
SIGN_ID="${SIGN_ID:-Developer ID Application: Catherine Gramze (AJHGU52KS3)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-simpe-notary}"
ENTITLEMENTS="$REPO_ROOT/entitlements.plist"
DIST_DIR="$REPO_ROOT/dist"
DMG_NAME="${DMG_NAME:-SimPE-macOS.dmg}"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_VOLUME="${DMG_VOLUME:-SimPE Installer}"

if [ ! -d "$APP" ]; then
  echo "Error: app bundle not found at $APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "==> Writing entitlements to $ENTITLEMENTS"
cat > "$ENTITLEMENTS" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.allow-relative-library-paths</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.get-task-allow</key>
    <false/>
</dict>
</plist>
PLIST_EOF

CODESIGN_FLAGS=(--force --timestamp --options runtime --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS")

# Wrapper: codesign occasionally fails with "A timestamp was expected but was
# not found" when Apple's timestamp server hiccups. Retry up to 5 times with
# escalating backoff before giving up.
codesign_retry_invoke() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if codesign "$@" 2>&1; then
      return 0
    fi
    echo "    codesign failed (attempt $attempt/5), backing off $((attempt * 5))s and retrying"
    sleep $((attempt * 5))
  done
  echo "    codesign FINAL FAILURE for: $*"
  return 1
}

# Wine regenerates dosdevices/ on every launch based on whatever is mounted; the
# symlinks reference the developer's local volumes (e.g. d: -> /Volumes/...). They
# must not ship and they break codesign --verify --deep when they point at raw
# devices. Same for runtime user state in the SimPE Data folder.
echo "==> Cleaning Wine dosdevices and SimPE runtime state"
DOSDEVICES="$APP/Contents/SharedSupport/prefix/dosdevices"
SIMPE_DATA="$APP/Contents/SharedSupport/prefix/drive_c/Program Files/SimPE"
rm -rf "$DOSDEVICES"
rm -f  "$SIMPE_DATA/pluginlog.txt"
rm -f  "$SIMPE_DATA/Data/Packs.cfg" "$SIMPE_DATA/Data/Packs.cfg.bak" "$SIMPE_DATA/Data/GameRoot.cfg"
rm -f  "$SIMPE_DATA/Data"/*.xreg
rm -f  "$SIMPE_DATA/Data"/objcache*.simpepkg

# `dotnet publish -r win-x64` on macOS accidentally creates a native macOS
# apphost (extension-less Mach-O) next to each Windows .exe. These are unsigned
# and live inside the Wine prefix where no Mach-O should exist; notarization
# rejects the bundle if any survive.
echo "==> Removing stray macOS apphosts from the Wine prefix"
find "$APP/Contents/SharedSupport/prefix/drive_c" -type f 2>/dev/null | while IFS= read -r f; do
  if file -h "$f" 2>/dev/null | grep -q "Mach-O"; then
    echo "    rm: $f"
    rm -f "$f"
  fi
done

# Strip xattrs from the whole bundle (com.apple.lastuseddate etc. cling after
# any Finder/launch interaction and can interfere with notarization).
echo "==> Stripping extended attributes"
xattr -cr "$APP" 2>/dev/null || true

echo "==> Discovering Mach-O files (this scan takes a minute)"
MACHO_LIST="$(mktemp)"
trap 'rm -f "$MACHO_LIST"' EXIT

# Walk every regular file outside the Wine prefix's drive_c (which is full of
# Windows PE binaries we must not sign) and outside any pre-existing
# _CodeSignature directories. Keep depth so we can sort deepest-first.
find "$APP" -type f \
    ! -path "*/SharedSupport/prefix/drive_c/*" \
    ! -path "*/_CodeSignature/*" \
    -print0 |
while IFS= read -r -d '' f; do
  if file -h "$f" 2>/dev/null | grep -q "Mach-O"; then
    d=$(awk -F/ '{print NF}' <<< "$f")
    printf '%s\t%s\n' "$d" "$f"
  fi
done | sort -rn | cut -f2- > "$MACHO_LIST"

NUM=$(wc -l < "$MACHO_LIST" | tr -d ' ')
echo "==> Signing $NUM Mach-O files (deepest first)"
while IFS= read -r f; do
  codesign_retry_invoke "${CODESIGN_FLAGS[@]}" "$f" 2>&1 | sed 's/^/    /'
done < "$MACHO_LIST"

echo "==> Signing nested .framework bundles (deepest first)"
find "$APP" -type d -name "*.framework" ! -path "*/drive_c/*" |
  awk '{print gsub("/","/"), $0}' | sort -rn | cut -d' ' -f2- |
while IFS= read -r b; do
  echo "    $b"
  codesign_retry_invoke "${CODESIGN_FLAGS[@]}" "$b"
done

echo "==> Signing nested .app bundles (deepest first)"
find "$APP" -mindepth 1 -type d -name "*.app" ! -path "*/drive_c/*" |
  awk '{print gsub("/","/"), $0}' | sort -rn | cut -d' ' -f2- |
while IFS= read -r b; do
  echo "    $b"
  codesign_retry_invoke "${CODESIGN_FLAGS[@]}" "$b"
done

echo "==> Signing top-level bundle: $APP"
codesign_retry_invoke "${CODESIGN_FLAGS[@]}" "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "    spctl assessment (will fail until notarized — informational):"
spctl --assess --type exec --verbose "$APP" 2>&1 | sed 's/^/    /' || true

ZIP_FOR_NOTARY="$DIST_DIR/SimPE-app-for-notary.zip"
rm -f "$ZIP_FOR_NOTARY"

echo "==> Zipping .app for notarization upload"
ditto -c -k --keepParent "$APP" "$ZIP_FOR_NOTARY"

echo "==> Submitting .app to notarytool (typically 5–20 min)"
xcrun notarytool submit "$ZIP_FOR_NOTARY" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

rm -f "$ZIP_FOR_NOTARY"

echo "==> Stapling .app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Building DMG at $DMG_PATH"
rm -f "$DMG_PATH"
DMG_STAGE="$(mktemp -d)"
trap 'rm -f "$MACHO_LIST"; rm -rf "$DMG_STAGE"' EXIT
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$DMG_VOLUME" \
  -srcfolder "$DMG_STAGE" \
  -fs HFS+ \
  -format UDZO \
  "$DMG_PATH"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG_PATH"

echo "==> Submitting DMG to notarytool"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo
echo "============================================================"
echo "  Done."
echo "  App: $APP"
echo "  DMG: $DMG_PATH"
echo "============================================================"
