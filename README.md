# SimPE for Mac (SimPE-Mac-Wine)

SimPE, the *Sims 2* package editor, packaged as a normal Mac app. It is the
Windows SimPE from [SimPE-Fixed](https://github.com/rhiamom/SimPE-Fixed), run by
a bundled copy of Wine, so nobody has to set Wine up themselves.

- Runs on **Apple Silicon** (through Rosetta) and **Intel** Macs, macOS 10.15 or
  later.
- Works with the Aspyr **Sims 2 Super Collection**: SimPE finds the game and your
  Sims 2 folders (Downloads, Collections, Thumbnails) through Wine's `Z:` drive.
- Signed and notarized by Apple.

## Download

Get `SimPE-macOS.dmg` from the [Releases](../../releases) page, open it and drag
**SimPE** to Applications. On first launch, set the game folder when SimPE asks.

Quit SimPE with **File → Exit**. That is when it saves your window layout and
toolbar; force-quitting skips the save.

## How this repository is put together

This repo does not contain a rewrite of SimPE. It takes the Windows code
unchanged and adds a few Mac-specific changes on top:

| Path | What it is |
|---|---|
| `vendor/simpe-fixed/` | A git submodule pinned to a commit of [SimPE-Fixed](https://github.com/rhiamom/SimPE-Fixed), the maintained Windows SimPE. |
| `patches/` | The Mac changes, as numbered patch files (Wine workarounds, Mac game paths…). `patches/apply.sh` applies them; see `patches/README.md`. They are kept as patches, never committed inside the submodule. |
| `build-simpe.sh` | Applies the patches and builds SimPE as a self-contained Windows program (the .NET 8 runtime is included, so Wine needs nothing extra installed). |
| `deploy.sh` | Copies that build into a Wine wrapper app, keeping your SimPE settings. |
| `trim-wrapper.sh` | Removes the ~520 MB a stock Sikarugir wrapper carries that SimPE never uses (3D translators, Vulkan, audio/video, Wine Mono). Keeps Wine Gecko, which SimPE's About/Welcome windows need. |
| `wrapper/SimPE.icns` | The app icon. |
| `sign-and-notarize.sh` | Signs the wrapper with a Developer ID, notarizes it, and makes the release `.dmg`. |
| `BUILD-WRAPPER.md` | How to make the Wine wrapper itself. **Read this before building.** |

## Building it yourself

You need:

1. **Microsoft's .NET 8 SDK**, from <https://dotnet.microsoft.com/download/dotnet/8.0>.
   **Not** the Homebrew `dotnet@8` package: Homebrew's build lacks the
   Windows Desktop targets SimPE needs and fails with about 55 `MSB4019` errors.
   If both are installed, put Microsoft's first:
   ```sh
   export DOTNET_ROOT="$HOME/.dotnet"
   export PATH="$HOME/.dotnet:$PATH"
   ```
2. **A Wine wrapper app**, described in [BUILD-WRAPPER.md](BUILD-WRAPPER.md).
   The quickest way is to install the released `.dmg` and use that `SimPE.app`.

Then:

```sh
git clone --recurse-submodules https://github.com/rhiamom/SimPE-Mac-Wine.git
cd SimPE-Mac-Wine
./build-simpe.sh                      # patches + build (Wine is not needed to build)
./deploy.sh /Applications/SimPE.app   # put the build into your wrapper
open /Applications/SimPE.app
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`.

`vendor/simpe-fixed` normally shows as modified (`m`) in `git status`: that is
the patches applied on top of the pinned commit, which is expected.

## Updating to a newer SimPE-Fixed

```sh
cd vendor/simpe-fixed
git checkout -- .                     # drop the applied patches (they are regenerable)
git fetch origin && git checkout origin/master
cd ../..
./patches/apply.sh                    # re-apply; fix and regenerate any patch that fails
./build-simpe.sh
git add vendor/simpe-fixed && git commit -m "Bump vendor to <sha> — SimPE-Fixed <version>"
```

## Making a release

Before signing, run `./trim-wrapper.sh` on the app (safe to repeat; the first
time after 0.8.4.4 it removes Wine Mono). Then use that build for a while before
publishing.

`sign-and-notarize.sh` needs a *Developer ID Application* certificate in your
keychain and a `notarytool` keychain profile (default name `simpe-notary`; set
`SIGN_ID` / `NOTARY_PROFILE` to use your own). It cleans the wrapper back to a
first-run state, signs it, notarizes it, and writes `dist/SimPE-macOS.dmg`.

Don't launch the app between `deploy.sh` and signing: each launch makes Wine
re-create links to your own home folders inside the app, which breaks the
signature. (The script removes them, so re-running it also works.)

## Credits and licence

- **SimPE** © 2004–2007 Ambertation (Quaxi) and contributors; later versions by
  Chris Hatch; SimPE-Fixed and this Mac packaging by GramzeSweatshop (Rhiamom).
- **Wine** is provided by the [Sikarugir](https://github.com/Sikarugir-App)
  wrapper.

SimPE is released under the GNU General Public License, version 2 (see
`vendor/simpe-fixed/LICENSE.txt`); this repository's scripts and patches are
released under the same licence.
