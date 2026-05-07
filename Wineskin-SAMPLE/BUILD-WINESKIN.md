# First Wineskin Wrapper Build Checklist

This is the step-by-step workflow for the first creation of a `SimPE.app` Wineskin wrapper.

## Prerequisites

- Intel macOS machine (supported target)
- Wineskin Winery installed
- `.NET 8 SDK` installed on macOS (already present if `dotnet --list-sdks` shows `8.0.x`)
- A Wine engine (Wineskin Winery downloads these for you)

## 1. Build SimPE

From the repo root, run:

```bash
./build-simpe.sh
```

This applies the local patches in `patches/` and runs `dotnet publish` with `--self-contained true -r win-x64`. Output lands in:

```
vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish/
```

The publish folder is ~176 MB and includes the .NET 8 Windows Desktop Runtime, so the Wine prefix does not need a separate runtime install. The main binary is `SimPE.Main.exe`.

## 2. Create the Wineskin wrapper

1. Open Wineskin Winery.
2. Create a new wrapper.
3. Choose a Wine engine that supports WinForms and .NET 8 support paths (e.g. `CX11` or `WS9Wine1.7`).
4. Name the wrapper `SimPE` so it creates `SimPE.app`.
5. In Wineskin options:
   - Set the executable to `C:\Program Files\SimPE\SimPE.exe`
   - Configure a `Z:` drive mapping to `/`
   - Enable single-window mode if desired
   - Leave advanced settings defaults unless you need custom overrides

## 3. Copy SimPE into the wrapper

1. Locate the new wrapper app in Finder.
2. Right-click and choose `Show Package Contents`.
3. Copy the **entire publish folder contents** (`vendor/simpe-fixed/SimPE.Main/bin/Release/win-x64/publish/`) into:
   - `Contents/Resources/drive_c/Program Files/SimPE/`
4. Also copy `vendor/simpe-fixed/Data/` into the same `SimPE/` folder so it lands at:
   - `Contents/Resources/drive_c/Program Files/SimPE/Data/`
5. If `Program Files` does not exist, create it.

## 4. Stage Wineskin settings

1. Copy `Wineskin-SAMPLE/WineskinSettings.plist` into:
   - `SimPE.app/Contents/Resources/`
2. If you want the sample launcher available, ensure `Contents/MacOS/run-simpe.sh` exists.
3. Run the staging script from `Wineskin-SAMPLE`:

```bash
cd Wineskin-SAMPLE
chmod +x wineskin-stage.sh package-dmg.sh
./wineskin-stage.sh
```

This will:
- copy `WineskinSettings.plist` into the wrapper
- update `Info.plist` to use `WineskinLauncher`
- stage the sample `run-simpe.sh` launcher
- ensure the Wine prefix directory exists

## 5. Verify the wrapper

1. Open `SimPE.app` from Finder.
2. Confirm it launches.
3. If it fails, inspect the wrapper logs and ensure:
   - `Z:` is mapped to `/`
   - `C:\Program Files\SimPE\SimPE.Main.exe` exists
   - the publish folder's runtime files (`coreclr.dll`, `hostfxr.dll`, `System.Windows.Forms.dll`) are present alongside `SimPE.Main.exe`

## 6. Create the DMG installer

Once the wrapper is verified, build the final installer DMG:

```bash
cd Wineskin-SAMPLE
./package-dmg.sh
```

The script creates:
- `dist/SimPE-macOS.dmg`

The DMG includes:
- `SimPE.app`
- an alias to `/Applications`

## 7. Optional: bundle a custom background

For polished UX, open the mounted DMG in Finder, add a custom background image, and arrange icons before creating the final `UDZO` image.

## 8. Distribution notes

- Test the final DMG on a clean Intel Mac.
- If you publish outside your own environment, consider signing and notarizing the app.
- If notarization is not available, instruct users to allow the app via `System Preferences -> Security & Privacy`.
