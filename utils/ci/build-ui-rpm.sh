#!/bin/bash
#
# Build the UI .rpm with utils/packaging/ui/rpm from a clean export of HEAD.
#
# Needs on PATH: rpmbuild, rpmspec, make, python3 with setuptools, lrelease (or
# lrelease-qt6, Fedora's name for it).
#
# Usage: [PKG_SNAPSHOT=ci12] build-ui-rpm.sh [output dir]
# PKG_SNAPSHOT: test build id for the package version, see pkg-version.sh.
#
set -euo pipefail
. "$(dirname "$0")/pkg-version.sh"

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${1:-$repo/dist}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
top=$work/rpmbuild
mkdir -p "$top/SOURCES" "$top/SPECS" "$work/bin"

spec=$top/SPECS/opensnitch-ui.spec
cp "$repo/utils/packaging/ui/rpm/opensnitch-ui.spec" "$spec"
# The source tarball and its top dir are named after unmangled_version, which keeps the
# plain version; only the package version gets the snapshot.
src=opensnitch-ui-$(rpmspec -q --srpm --qf '%{version}' "$spec")
set_rpm_snapshot_version "$spec" "$repo"
git -C "$repo" archive --prefix="$src/" HEAD:ui | gzip > "$top/SOURCES/$src.tar.gz"

# ui/i18n/Makefile calls lrelease.
if ! command -v lrelease >/dev/null; then
    ln -s "$(command -v lrelease-qt6)" "$work/bin/lrelease"
fi

# setup.py writes the python3 it finds on PATH into the opensnitch-ui shebang. root's PATH
# often has /usr/sbin first, and on Fedora /usr/sbin/python3 exists but no package provides
# it, so the rpm would require it and fail to install.
PATH="$work/bin:$(tr : '\n' <<<"$PATH" | grep -v sbin | paste -sd:)" \
    rpmbuild -bb --define "_topdir $top" "$spec"
rpm -qp --requires "$top"/RPMS/noarch/opensnitch-ui-*.rpm | grep -qx /usr/bin/python3

mkdir -p "$out"
cp "$top"/RPMS/noarch/opensnitch-ui-*.rpm "$out"/
ls -l "$out"/opensnitch-ui-*.rpm
