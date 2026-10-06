#!/bin/bash
#
# Check an installed daemon package: the binary runs and the eBPF modules and the
# systemd unit are in place. Independent of the package format.
#
# Usage: smoke-daemon.sh
#
set -euo pipefail

opensnitchd -version
for f in /usr/lib/opensnitchd/ebpf/opensnitch.o \
         /usr/lib/opensnitchd/ebpf/opensnitch-dns.o \
         /usr/lib/opensnitchd/ebpf/opensnitch-procs.o \
         /usr/lib/systemd/system/opensnitch.service; do
    test -s "$f" || { echo "missing or empty: $f"; exit 1; }
done
echo "daemon smoke test passed"
