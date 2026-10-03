# Making the Wine wrapper (SimPE.app)

`build-simpe.sh` builds SimPE as a Windows program. To run it on a Mac it goes
inside a **Wine wrapper**: a Mac app that contains Wine and a small Windows
folder tree (a "prefix"). The wrapper is about 1.3 GB, so it is not kept in git;
you either reuse a released one or make your own.

The released SimPE for Mac was built with:

| | |
|---|---|
| Wrapper tool | **Sikarugir Creator 1.0.1** (<https://github.com/Sikarugir-App/Creator>) |
| Wrapper template | Sikarugir **Template-1.0.11** |
| Wine engine | **WS12WineSikarugir10.0_6** = Wine 10.0, Sikarugir revision 6 |
| Trimmed | about 290 MB of unused parts removed (`trim-wrapper.sh`) |
| Icon | SimPE's own, `wrapper/SimPE.icns` |

## The quick way: reuse the released app

1. Download `SimPE-macOS.dmg` from the [Releases](../../releases) page and drag
   **SimPE** to Applications.
2. Build and deploy into it:
   ```sh
   ./build-simpe.sh
   ./deploy.sh /Applications/SimPE.app
   ```

`deploy.sh` replaces only SimPE's own folder inside the app and keeps your
SimPE settings (game folder, layout, toolbar).

## Making a wrapper from scratch

1. Install **Sikarugir Creator** (from the GitHub page above, or with Homebrew:
   `brew install --cask Sikarugir-App/sikarugir/sikarugir`).
2. In Sikarugir Creator, download the **WS12WineSikarugir10.0_6** engine (Wine
   10.0, Sikarugir revision 6; a later 10.0 revision should also work) and the
   wrapper template (**1.0.11** was used).
3. Create a new wrapper named **SimPE**, which makes `SimPE.app`. Move it to
   `/Applications` (the scripts default to that path). Creating the wrapper also
   creates its Wine prefix in `Contents/SharedSupport/prefix/`; the template
   already has the `Contents/drive_c` shortcut into it that `deploy.sh` uses.
4. **Trim it.** A stock wrapper carries about 290 MB of 3D-graphics translators,
   Vulkan and audio/video playback that SimPE never uses. Remove them:
   ```sh
   ./trim-wrapper.sh /Applications/SimPE.app
   ```
   This removes exactly what the released app leaves out (tested against a stock
   1.0.11 + 10.0_6 wrapper: afterwards the two match).
5. **Give it SimPE's icon:**
   ```sh
   cp wrapper/SimPE.icns /Applications/SimPE.app/Contents/Resources/Configure.icns
   ```
   (Choosing the icon in Sikarugir Creator does the same; it also keeps the old
   one as `Configure.icns.wineskin-original`.)
6. Make SimPE's folder in the prefix, then build and deploy:
   ```sh
   mkdir -p "/Applications/SimPE.app/Contents/SharedSupport/prefix/drive_c/Program Files/SimPE"
   ./build-simpe.sh
   ./deploy.sh /Applications/SimPE.app
   ```
7. Open the wrapper's settings (right-click **SimPE.app → Show Package Contents →
   Contents → Configure.app**) and set:
   - **Program to run:** `C:\Program Files\SimPE\SimPE.Main.exe`
     (stored in `Contents/Info.plist` as `Program Name and Path`).
   - Leave the graphics options (DXVK, D3DMetal, DXMT…) **off**. Their files were
     removed in step 4.
8. Keyboard and screen settings in the Wine registry. The released app has these;
   set them with `regedit` from Configure.app, or add them to
   `Contents/SharedSupport/prefix/user.reg`:
   ```
   [Software\\Wine\\Mac Driver]
   "LeftCommandIsCtrl"="Y"
   "LeftOptionIsAlt"="Y"
   "RightCommandIsCtrl"="Y"
   "RightOptionIsAlt"="Y"

   [Software\\Wine\\Fonts]
   "LogPixels"=dword:00000060
   ```
   With these, **⌘** works as **Ctrl** (⌘C copies, ⌘S saves) and **⌥** as **Alt**.
   `LogPixels` 96 is Windows' normal 100 % scale, which SimPE's windows are laid out for.
9. Launch `SimPE.app`. Nothing else needs installing in Wine: the build is
   self-contained (it carries its own .NET 8 runtime), so no winetricks. Wine's
   own `gecko` and `mono` add-ons are still in the released app; they were never
   removed.

## Things that are normal

- **`Z:` is the whole Mac disk.** That is how SimPE reaches the game and the
  Sims 2 folders, for example
  `Z:\Users\<you>\Library\Containers\com.aspyr.sims2.appstore\Data\Library\Application Support\Aspyr\The Sims 2`.
- **Wine makes links to your Desktop, Documents, Downloads and so on** inside
  the prefix (`drive_c/users/…`) every time the app starts. They point outside
  the app, so `sign-and-notarize.sh` removes them before signing.
- The first launch after a fresh deploy asks for the game folder; SimPE then
  writes `Data/GameRoot.cfg` inside the app.
