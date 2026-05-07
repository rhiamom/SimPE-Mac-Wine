# Wineskin Sample Bundle for SimPE

This sample shows a minimal app bundle layout and a launcher script for a self-contained Wine-based `SimPE.app`.

## Example bundle structure

```
Wineskin-SAMPLE/
  Contents/
    MacOS/
      run-simpe.sh
    Resources/
      drive_c/
        Program Files/
          SimPE/
            SimPE.exe
            Data/
      wineprefix/
      wine/  # optional bundled Wine runtime
    Info.plist
```

## What this sample does

- sets a Wine prefix inside `Contents/Resources/wineprefix`
- exports `HOME` and `WINEDEBUG`
- uses a bundled Wine binary if available
- launches `SimPE.exe` from `drive_c/Program Files/SimPE/`
- leaves a standard Wine `Z:` mapping available if configured in Wine

## Wineskin-specific notes

- A Wineskin wrapper should use `WineskinLauncher` as the main bundle executable.
- `Contents/Resources/WineskinSettings.plist` should point the wrapper at `C:\\Program Files\\SimPE\\SimPE.exe`.
- The completed Wine prefix should include `.NET 8 Desktop Runtime` so the app is ready-to-run.
- Use a final `SimPE.app` bundle that contains the prefix and `drive_c` folder so users do not need to install anything.
- `wineskin-stage.sh` can be used to copy sample settings into an existing wrapper and stage the install.

## Staging example

Run from the `Wineskin-SAMPLE` directory after you have created a Wineskin wrapper named `SimPE.app`:

```bash
chmod +x install-dotnet8.sh wineskin-stage.sh package-dmg.sh
./wineskin-stage.sh
```

This script:
- copies `WineskinSettings.plist` into the wrapper
- updates `Info.plist` to use `WineskinLauncher`
- stages the sample `run-simpe.sh`
- creates the Wine prefix and installs `.NET 8` if `winetricks` is available

After staging and verifying the wrapper, create the installer DMG:

```bash
./package-dmg.sh
```

This will produce `dist/SimPE-macOS.dmg` containing the completed `SimPE.app` and a `/Applications` alias.

### Recommended DMG layout

For the best Mac user experience, build the DMG so it includes:
- `SimPE.app`
- a link or alias to `/Applications`
- optionally a custom background image telling users to drag the app into Applications

The current `package-dmg.sh` script already stages the `Applications` alias automatically so the installer behaves like a standard macOS app installer.

## Notes

- In a Wineskin wrapper, the real executable is usually `WineskinLauncher` and Wineskin manages drives.
- This sample is a minimal custom macOS wrapper example that can be adapted into a Wineskin configuration.
- The `Info.plist` below is the required macOS metadata for a bundle.
