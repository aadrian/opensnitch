#!/bin/bash
#
# Build the UI .deb with utils/packaging/ui/deb from a clean export of HEAD.
#
# Needs the Build-Depends of utils/packaging/ui/deb/debian/control (dpkg-buildpackage checks them).
#
# Usage: [PKG_SNAPSHOT=ci12] build-ui-deb.sh [output dir]
# PKG_SNAPSHOT: test build id for the package version, see pkg-version.sh.
#
set -euo pipefail
. "$(dirname "$0")/pkg-version.sh"

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${1:-$repo/dist}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git -C "$repo" archive --prefix=src/ HEAD | tar -x -C "$work"
cp -r "$work/src/utils/packaging/ui/deb/debian" "$work/src/ui/debian"
set_deb_snapshot_version "$work/src/ui/debian" "$repo"

cd "$work/src/ui"
dpkg-buildpackage -b -us -uc

mkdir -p "$out"
cp "$work"/src/python3-opensnitch-ui_*.deb "$out"/
ls -l "$out"/python3-opensnitch-ui_*.deb
