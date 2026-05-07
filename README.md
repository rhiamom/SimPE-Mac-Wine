# SimPE-Mac-Wine

A packaged SimPE distribution for Intel Macs that bundles Wine, so non-technical Sims 2 users can install and run SimPE without configuring Wine themselves.

## Status

Early work in progress. The repo currently contains only the submodule pointer for SimPE-Fixed; packaging, Wine integration, and the installer are not yet built.

## Repo structure

- `vendor/simpe-fixed/` — git submodule tracking [SimPE-Fixed](https://github.com/rhiamom/SimPE-Fixed), the SimPE source this project wraps.

## Cloning

This repo uses a submodule. Clone with:

    git clone --recurse-submodules https://github.com/rhiamom/SimPE-Mac-Wine.git

If you already cloned without `--recurse-submodules`:

    git submodule update --init --recursive

## Updating SimPE-Fixed

To pull in the latest changes from SimPE-Fixed:

    git submodule update --remote vendor/simpe-fixed
    git add vendor/simpe-fixed
    git commit -m "Bump SimPE-Fixed submodule"
    git push

## Target environment

- Intel Mac (x86_64).
- macOS 12 (Monterey) or later.

Apple Silicon support is not planned at this time.

## License

TBD.
