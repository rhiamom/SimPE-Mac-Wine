# Local Patches for `vendor/simpe-fixed`

This directory holds Mac-specific modifications to the vendored `SimPE-Fixed` submodule. Patches live here — **not** as commits inside the submodule — so the submodule's history stays clean and is never pushed to its origin.

## Workflow

After a fresh clone (or after any `git submodule update`), apply the patches:

```bash
./patches/apply.sh
```

The script is idempotent: already-applied patches are skipped.

## Adding a new patch

1. Make and verify your changes inside `vendor/simpe-fixed/`.
2. From inside the submodule, generate the patch:
   ```bash
   cd vendor/simpe-fixed
   git diff > ../../patches/NNNN-short-description.patch
   ```
3. Commit the patch file in the parent repo. Do not commit inside the submodule.

## Updating an existing patch

If the upstream submodule moves and a patch no longer applies, regenerate it the same way after re-doing the change against the new base.

## Files

- `0001-mac-support.patch` — adds Mac edition support to `GameRootDialog` and Mac-aware path resolution to `Helper.SimPeDataPath`.
- `0002-build-fix-wizardbase-postbuild.patch` — empties the cmd-style `<PostBuildEvent>` in `SimPE.Wizardbase.csproj` (the only project that hadn't already been cleaned up). Without this, the solution can't build on macOS because `if not exist ... mkdir / copy` is `cmd.exe` syntax. The cross-platform `<Copy>` task in `vendor/simpe-fixed/Directory.Build.targets` already handles the equivalent unified-bin copy.
- `0003-mac-wine-listview-events.patch` — switches the `SubsetSelectForm` ListView to `View.Tile` and adds forced-selection mouse handlers, working around Wine's unreliable LargeIcon-view mouse events and `SelectedIndices` updates.
- `0004-mac-aspyr-subtype-tolerant-txtr.patch` — adds a SubType-tolerant fallback in `MmatWrapper.GetTxtr` for the four Stuff Packs (Ikea, Kitchen & Bath, Teen Style, Celebration) that Huge Lunatic extracted from the Windows install for the Aspyr Mac game. Those re-bundled TXTRs are stored with `SubType=0` while TXMT references encode a non-zero SubType, so the strict `LongInstance` lookup misses; the fallback retries with the lower 32-bit Instance only.
- `0005-mac-wine-fill-panel-layout.patch` — overrides `DockContainer.OnLayout` in the Ambertation NetDocks framework to explicitly position `Dock=Fill` panels using the same subtraction formula `CalculateDockAreaBounds` uses. Wine's WinForms layout engine sometimes fails to shrink Fill panels when edge-docked sibling DockContainers claim their strips, leaving Fill at stale bounds (the Resource ListView ended up hidden behind the Resource TreeView). The override applies correct bounds after every layout pass; recursion-guarded.
- `0006-mac-collection-creator-wine-paths.patch` — makes the Collection Creator plugin reach the Mac game folders through Wine. `Helper.DownloadsPath` (resolved by the Mac game-root flow from patch 0001) is the Wine-visible Sims 2 Downloads folder — e.g. a `Z:` path into the Aspyr container; `Collections`/`Thumbnails` are its siblings. The patch seeds unset Options paths (Collections, Thumbnails) from that root, and starts the Add-Object (`dlgAddObject`) and Batch-Add (`dlgPickFolder`) pickers there instead of Wine's empty `C:` drive. The genuine first-run Options prompt still auto-opens (gated on whether a saved `CollectionCreator.txt` existed *before* seeding, so the pre-filled paths don't suppress it) — the user confirms the pre-filled Mac folders and clicks OK. Only fills blanks — a saved user choice always wins. Touches only `CollectionCreatorForm.Handlers.cs`.
- `0007-mac-colorbinning-wine-downloads.patch` — defaults Theo's Color Binning Tool (`Plugin.CollectionCreator`'s sibling `ColorBinningTool`, the "Genetic Categorizer") package Open/Save dialogs to `SimPe.Helper.DownloadsPath` so they open in the Sims 2 Downloads folder (a `Z:` path under Wine) instead of Wine's empty `C:` drive. Set once in the `MainForm` constructor; WinForms then remembers the user's last-browsed folder for later opens. Touches only `ColorBinningTool/MainForm.cs`. (Theo's Alt Sim Surgery needs no path patch — it operates only on the loaded package and SimPE's in-memory file index.)

> An earlier `0006-version-bump-*.patch` (now retired, number reused above) set the Mac
> release version. It was dropped when `vendor/simpe-fixed` reached 0.8.2.14 — upstream now
> sets `<Version>` itself (the "Bump to 8.2.x" commits), so the Mac side no longer patches it.
