#!/bin/bash
#
# Build the daemon .deb with utils/packaging/daemon/deb from a clean export of HEAD.
#
# Go dependencies come from go.mod (module mode), not from the distro's golang-*-dev
# packages, so the package can be built on any Debian/Ubuntu with a recent Go.
#
# Needs on PATH: go (>= the version in daemon/go.mod), protoc, protoc-gen-go,
# protoc-gen-go-grpc, dpkg-buildpackage, dh-golang, pkg-config, libnetfilter-queue-dev.
#
# Usage: [PKG_SNAPSHOT=ci12] build-daemon-deb.sh <dir with the eBPF modules> [output dir]
# PKG_SNAPSHOT: test build id for the package version, see pkg-version.sh.
#
set -euo pipefail
. "$(dirname "$0")/pkg-version.sh"

ebpf_dir=$(realpath "${1:?usage: $0 <ebpf modules dir> [output dir]}")
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${2:-$repo/dist}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git -C "$repo" archive --prefix=src/ HEAD | tar -x -C "$work"
src=$work/src
cp -r "$src/utils/packaging/daemon/deb/debian" "$src/debian"
set_deb_snapshot_version "$src/debian" "$repo"
cp "$ebpf_dir"/opensnitch*.o "$src/ebpf_prog/"

# dh-golang copies the sources to _build before debian/rules generates these.
make -C "$src/proto" ../daemon/ui/protocol/ui.pb.go

# dh-golang only forces GOPATH mode when GO111MODULE and GOPROXY are unset.
# It runs go from _build, which has no go.mod: the workspace points go to daemon/.
# Tests need root and nfqueue, so they don't run here.
# -d: the golang-*-dev Build-Depends are not used in module mode.
# dh_golang fills Built-Using from the distro packages that own the Go sources; none do
# here (Go and the modules are downloaded), and it fails, so it's replaced by a no-op.
cd "$src"
printf 'go %s\n\nuse ./daemon\n' "$(awk '$1 == "go" {print $2}' daemon/go.mod)" > go.work
mkdir "$work/bin"
printf '#!/bin/sh\nexit 0\n' > "$work/bin/dh_golang"
chmod +x "$work/bin/dh_golang"
PATH="$work/bin:$PATH" GO111MODULE=on GOWORK="$src/go.work" \
    GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}" \
    DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -us -uc -d

mkdir -p "$out"
cp "$work"/opensnitch_*.deb "$out"/
ls -l "$out"/opensnitch_*.deb
