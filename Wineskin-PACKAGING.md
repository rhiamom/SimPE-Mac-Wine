# Wineskin Packaging Guide for SimPE-Mac-Wine

This repo currently contains only the SimPE-Fixed source tree. Wineskin packaging is not yet implemented, so this document describes the packaging approach and the recommended wrapper layout for a self-contained macOS Intel distribution.

## Goal

Create a macOS `SimPE.app` wrapper that:
- bundles Wine runtime
- bundles the Windows `SimPE.exe` build and local `Data/` folder
- exposes macOS paths to Wine so `The Sims 2.app` and macOS save folders can be discovered
- launches SimPE automatically without requiring user Wine setup

## Recommended Wineskin architecture

### App bundle layout

Package the final app as a standard macOS bundle with the following structure:

```
SimPE.app/
  Contents/
    MacOS/
      WineskinLauncher  # Wineskin binary or custom launcher script
      run-simpe.sh      # optional helper script
    Resources/
      drive_c/
        Program Files/
          SimPE/
            SimPE.exe
            SimPE.exe.config  # if needed
            Data/           # shipped SimPE data folder
      wineprefix/         # Wine prefix (C:\ equivalent)
      wrapper.log         # runtime log file
      Info.plist
```

A Wineskin wrapper typically stores `drive_c` and the Wine prefix inside `Contents/Resources/`.

### Wine drive mapping

`SimPE` must be able to see the macOS install path and the Sims 2 app bundle.

Configure Wine drives like this:
- `C:` → `Contents/Resources/drive_c/`
- `Z:` → `/`
- optional `D:` → `Contents/Resources/drive_c/Program Files/SimPE/`

This lets SimPE scan for `Z:\Applications\The Sims 2.app`.

## Packaging steps

### 1. Build SimPE

From the repo root, run `./build-simpe.sh`. It applies the patches in `patches/` and runs `dotnet publish -c Release -r win-x64 --self-contained true` against `vendor/simpe-fixed/SimPE.Main/SimPE.Main.csproj`. Output lands at `vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish/`.

### 2. Prepare local `Data/`

Copy `vendor/simpe-fixed/Data/` next to `SimPE.Main.exe` in the wrapper's `Program Files/SimPE/` folder.

`Data/` should be included in the app bundle so the patched `Helper.SimPeDataPath` can prefer it.

### 3. Create Wineskin wrapper

Use `Wineskin Winery` (or another Wineskin builder) to create a new wrapper.

Required wrapper settings:
- Windows EXE: `C:\Program Files\SimPE\SimPE.Main.exe`
- Engine: a recent Wine engine that supports 64-bit Windows binaries (the published EXE is x86-64). On Intel Macs, the WS11Wine* family or recent CrossOver-based engines from Wineskin Winery work.
- Set `Advanced -> Tools -> Configuration -> Advanced` for custom `Z:` drive mapping
- Set `Options -> Screen Options` to run in a single window if desired

### 3.1 .NET 8 Runtime: shipped self-contained

`SimPE-Fixed` is built for `net8.0-windows`. Rather than installing the runtime into the Wine prefix at packaging time, `build-simpe.sh` runs `dotnet publish --self-contained true -r win-x64`, which embeds the .NET 8 Windows Desktop Runtime directly inside the publish folder (`coreclr.dll`, `hostfxr.dll`, `System.Windows.Forms.dll`, etc.).

This means:
- No `winetricks dotnet80` step is required.
- The Wine prefix only needs to be a clean default prefix.
- The publish folder is ~176 MB; the entire `Contents/Resources/drive_c/Program Files/SimPE/` tree gets copied into the wrapper.

If you ever switch back to a framework-dependent build, you'd need to install `Microsoft.NET.Runtime.8.0` + `Microsoft.WindowsDesktop.App` into the prefix manually — but the self-contained path is recommended for distribution.

### 3.2 WineskinLauncher and wrapper defaults

A Wineskin wrapper uses `WineskinLauncher` as the executable entrypoint. For a Mac user-friendly package, ensure that:

- `Contents/Info.plist` sets `CFBundleExecutable` to `WineskinLauncher` or to a custom launcher script.
- `Contents/Resources/WineskinSettings.plist` contains the Wine prefix path and wrapper options.
- `Contents/Resources/drive_c/Program Files/SimPE/SimPE.Main.exe` is registered as the wrapper’s default Windows executable.
- `Z:` is configured as a global root drive so `/Applications` is accessible.

Recommended default settings in `WineskinSettings.plist`:
- `UseWineWrapper` = `true`
- `WINEDLLOVERRIDES` = `"mscoree,mshtml="` if needed by Wine
- `UseCrt` = `true`
- `CustomExecutable` = `"C:\Program Files\SimPE\SimPE.Main.exe"`
- `AdvancedOptions` include `Z` drive mapping to `/`

The wrapper should be built once, completely configured, and then packaged as a final `.app` bundle. Apple users should not need to run Wineskin setup or install runtime components manually.

### 4. Configure Wine environment

Set environment variables for the wrapper to ensure macOS paths are used:
- `WINEPREFIX` to the wrapper prefix path
- `HOME` to the real macOS home directory
- `WINEDEBUG=-all` to suppress Wine log spam

If using a custom launch script, the wrapper should also set:

```
export HOME="$HOME"
export WINEPREFIX="$WRAPPER_PATH/Contents/Resources/wineprefix"
export PATH="$WRAPPER_PATH/Contents/Resources/wineprefix/drive_c/windows:$PATH"
```

### 5. Expose `/Applications` and game bundle

The wrapper should expose `Z:` and/or a drive letter that includes `/Applications`.

This is critical so SimPE can detect `The Sims 2.app` and any Mac install path.

### 6. Optional preconfiguration

Pre-create a `GameRoot.cfg` or `GameRoot.cfg.xml` in the wrapper prefix if the app expects it. The wrapper can also detect `The Sims 2.app` on first run and populate the game root.

### 7. Test the wrapper

Test with a real Sims 2 installation on macOS. Confirm:
- SimPE launches
- game root scanning finds `/Applications/The Sims 2.app`
- saved game path detection resolves the Aspyr container path
- `SimPeDataPath` prefers the bundled `Data/` folder if present

## Important Mac-specific path notes

### Sims 2 app bundle scanning

The wrapper should make `The Sims 2.app` visible to Wine as a normal folder. A `Z:` drive mapping to `/` is the simplest solution.

Example runtime path inside Wine:
- `Z:\Applications\The Sims 2.app\Contents\MacOS\The Sims 2`

### Savegame location

The Aspyr macOS Sims 2 save folder is usually under:

```
~/Library/Containers/com.aspyr.sims2.appstore/Data/Library/Application Support/The Sims 2/
```

Your patched `PathProvider` should prefer this when the current platform is macOS.

## Recommended wrapper behavior

1. On first launch, detect `/Applications/The Sims 2.app`
2. If found, set the game root automatically and save it in the wrapper’s config
3. Launch `SimPE.exe` from Wine
4. Keep the wrapper self-contained so no separate Wine install is required

## 8. Build a DMG installer

Create a compressed DMG containing the complete `SimPE.app` bundle so end users can install it with a simple drag-and-drop.

- Build and stage `SimPE.app` once, with the finished Wine prefix and bundled `.NET 8 Desktop Runtime`.
- Verify the app launches cleanly on a test Intel Mac.
- Use `hdiutil create -format UDZO` to package the app into a compact read-only DMG.
- Optionally include a simple background image and a symbolic link to `/Applications` for a drag-to-install experience.

Example:

```bash
hdiutil create -volname "SimPE Installer" -srcfolder "SimPE.app" -fs HFS+ -format UDZO "SimPE-macOS.dmg"
```

### Drag-to-Applications installer layout

For the most Mac-friendly installer, create a DMG layout that includes:
- `SimPE.app`
- an alias to `/Applications`
- an optional custom background image and clear instructions

This gives users the familiar install flow:
1. open the DMG
2. drag `SimPE.app` to the Applications folder alias
3. eject the DMG

To create the alias manually, use Finder or the `ln -s /Applications "Applications"` command inside the mounted DMG source folder before packaging.

## 9. Distribution notes

- For macOS Intel users, distribute the DMG directly.
- If you want to publish outside your own site, consider signing and notarizing the DMG on a compatible macOS machine.
- If notarization is not possible, document that the app may require the user to allow it in System Preferences -> Security & Privacy.

## If Wineskin is too limiting

If Wineskin GUI automation is not viable, you can still build a custom wrapper by shipping a small launcher script inside `Contents/MacOS/` that runs the bundled Wine binaries and `SimPE.exe` directly.

That approach is more flexible for drive mapping and environment configuration, but Wineskin is still the easiest consumer-facing option.
