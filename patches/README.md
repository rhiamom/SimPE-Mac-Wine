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
