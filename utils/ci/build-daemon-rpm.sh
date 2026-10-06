#!/bin/bash
#
# Build the daemon .rpm with utils/packaging/daemon/rpm from a clean export of HEAD.
#
# Needs on PATH: rpmbuild, rpmspec, go (>= the version in daemon/go.mod), gcc, make,
# protoc, protoc-gen-go, protoc-gen-go-grpc, and python3 with a grpc_tools that supports
# --pyi_out (the spec runs the whole proto/Makefile); libnetfilter_queue-devel.
#
# Usage: [PKG_SNAPSHOT=ci12] build-daemon-rpm.sh <dir with the eBPF modules> [output dir]
# PKG_SNAPSHOT: test build id for the package version, see pkg-version.sh.
#
set -euo pipefail
. "$(dirname "$0")/pkg-version.sh"

ebpf_dir=$(realpath "${1:?usage: $0 <ebpf modules dir> [output dir]}")
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${2:-$repo/dist}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
top=$work/rpmbuild
mkdir -p "$top/SOURCES" "$top/SPECS"

spec=$top/SPECS/opensnitch.spec
cp "$repo/utils/packaging/daemon/rpm/opensnitch.spec" "$spec"
set_rpm_snapshot_version "$spec" "$repo"
version=$(rpmspec -q --srpm --qf '%{version}' "$spec")

# Source0 is the release tarball, with the eBPF modules already built.
git -C "$repo" archive --prefix="opensnitch-$version/" HEAD | tar -x -C "$work"
cp "$ebpf_dir"/opensnitch*.o "$work/opensnitch-$version/ebpf_prog/"
tar -czf "$top/SOURCES/opensnitch_$version.orig.tar.gz" -C "$work" "opensnitch-$version"

# dist: no distro suffix, like the release rpms (opensnitch-1.8.0-1.x86_64.rpm).
# gzip: the UI spec forces it for rpm-ostree (Silverblue); the daemon spec only got gzip
# because the release rpms are built on Debian.
GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}" \
    rpmbuild -bb --define "_topdir $top" --define "dist %{nil}" \
    --define "_binary_payload w9.gzdio" "$spec"

mkdir -p "$out"
cp "$top"/RPMS/*/opensnitch-[0-9]*.rpm "$out"/
ls -l "$out"/opensnitch-[0-9]*.rpm
