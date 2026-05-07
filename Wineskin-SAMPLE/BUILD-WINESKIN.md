# First Wineskin Wrapper Build Checklist

This is the step-by-step workflow for the first creation of a `SimPE.app` Wineskin wrapper.

## Prerequisites

- Intel macOS machine (supported target)
- Wineskin Winery installed
- `wine` and `winetricks` available on the host machine (for staging and .NET install)
- A built SimPE executable from `vendor/simpe-fixed`

## 1. Build SimPE

1. Open `vendor/simpe-fixed/SimPE.Main/SimPE.Main.csproj` in Visual Studio on Windows or use MSBuild.
2. Build the project for `Release` targeting `net8.0-windows`.
3. Collect the full Release output folder contents from `vendor/simpe-fixed/SimPE.Main/bin/Release/net8.0-windows` or the matching publish directory.
   - all DLLs and helper files from the Release folder
   - `SimPE.exe`
   - `SimPE.exe.config` if present
   - any duplicate support files from `SimPE.Main/bin/Release` if required
   - `Data/` folder from the source tree

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
3. Copy the full Release output and `Data/` folder into:
   - `Contents/Resources/drive_c/Program Files/SimPE/`
4. If `Program Files` does not exist, create it.

## 4. Stage Wineskin settings and .NET 8

1. Copy `Wineskin-SAMPLE/WineskinSettings.plist` into:
   - `SimPE.app/Contents/Resources/`
2. If you want the sample launcher available, ensure `Contents/MacOS/run-simpe.sh` exists.
3. Run the staging script from `Wineskin-SAMPLE`:

```bash
cd Wineskin-SAMPLE
chmod +x install-dotnet8.sh wineskin-stage.sh package-dmg.sh
./wineskin-stage.sh
```

This will:
- copy `WineskinSettings.plist` into the wrapper
- update `Info.plist` to use `WineskinLauncher`
- stage the sample `run-simpe.sh` launcher
- create the Wine prefix and install `.NET 8` if `winetricks` is available

## 5. Verify the wrapper

1. Open `SimPE.app` from Finder.
2. Confirm it launches.
3. If it fails, inspect the wrapper logs and ensure:
   - `Z:` is mapped to `/`
   - `C:\Program Files\SimPE\SimPE.exe` exists
   - the Wine prefix contains the .NET 8 runtime

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
