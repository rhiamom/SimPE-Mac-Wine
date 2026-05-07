#!/bin/bash
set -e

# Apply local Mac-support patches to the vendored SimPE-Fixed submodule.
# Idempotent: if a patch is already applied, it's skipped.
#
# These patches are kept here (not committed inside vendor/simpe-fixed)
# so the submodule's history stays clean and never gets pushed to its origin.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="$REPO_ROOT/patches"
SUBMODULE_DIR="$REPO_ROOT/vendor/simpe-fixed"

if [ ! -d "$SUBMODULE_DIR/.git" ] && [ ! -f "$SUBMODULE_DIR/.git" ]; then
  echo "Error: $SUBMODULE_DIR is not a git checkout. Run 'git submodule update --init' first."
  exit 1
fi

cd "$SUBMODULE_DIR"

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $PATCH_DIR"
  exit 0
fi

for patch in "${patches[@]}"; do
  name="$(basename "$patch")"

  if git apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "[skip] $name already applied"
    continue
  fi

  if git apply --check "$patch" >/dev/null 2>&1; then
    git apply "$patch"
    echo "[ok]   $name applied"
    continue
  fi

  echo "[fail] $name does not apply cleanly to current submodule state"
  echo "       Resolve manually, then re-run this script."
  exit 1
done

echo "All patches processed."
