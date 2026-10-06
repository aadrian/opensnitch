#!/bin/bash
#
# Build the eBPF modules against the kernel 6.0 headers, with the same steps as
# utils/packaging/build_modules.sh, but the kernel sources come from kernel.org and
# are kept in a cache dir (github.com rate-limits repeated downloads of the tarball).
#
# Needs: wget, xz, make, gcc, flex, bison, bc, rsync, python3, clang, llc, llvm-strip, libelf-dev, libssl-dev.
#
# Usage: build-ebpf.sh <output dir> [cache dir]
#
set -euo pipefail

kver=6.0
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
out=$(realpath -m "${1:?usage: $0 <output dir> [cache dir]}")
cache=$(realpath -m "${2:-${XDG_CACHE_HOME:-$HOME/.cache}/opensnitch-ci}")
tarball=$cache/linux-$kver.tar.xz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ ! -f "$tarball" ]; then
    mkdir -p "$cache"
    wget -q -O "$work/linux.tar.xz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$kver.tar.xz"
    wget -q -O "$work/sha256sums.asc" https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc
    sum=$(awk -v f="linux-$kver.tar.xz" '$2 == f {print $1}' "$work/sha256sums.asc")
    echo "$sum  $work/linux.tar.xz" | sha256sum -c -
    mv "$work/linux.tar.xz" "$tarball"
fi

tar -xf "$tarball" -C "$work"
kdir=$work/linux-$kver
(
    cd "$kdir"
    make olddefconfig >/dev/null
    make prepare >/dev/null
    make headers_install >/dev/null
)

cp -r "$repo/ebpf_prog" "$work/ebpf_prog"
make -C "$work/ebpf_prog" KERNEL_VER=$kver KERNEL_DIR="$kdir" KERNEL_HEADERS="$kdir" ARCH=x86 >/dev/null
llvm-strip -g "$work"/ebpf_prog/opensnitch*.o
objdump -h "$work/ebpf_prog/opensnitch.o" | grep -q 'kprobe/tcp_v4_connect'

mkdir -p "$out"
cp "$work"/ebpf_prog/opensnitch*.o "$out"/
ls -l "$out"/opensnitch*.o
