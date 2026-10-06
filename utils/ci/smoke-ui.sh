#!/bin/bash
#
# Start the installed UI with a plugin that imports requests enabled. It must still be
# running after 10 s (timeout exits 124) and must not print a Traceback.
# Independent of the package format.
#
# Runs with a temporary HOME, so it never touches a real ~/.config/opensnitch.
#
# Usage: smoke-ui.sh
#
set -euo pipefail

home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
mkdir -p "$home/.config/opensnitch"
printf '[plugins]\nlist=list_subscriptions\n' > "$home/.config/opensnitch/settings.conf"

rc=0
env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
    HOME="$home" QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" \
    timeout 10 opensnitch-ui > "$home/ui.log" 2>&1 || rc=$?
cat "$home/ui.log"

if [ "$rc" -ne 124 ]; then
    echo "UI exited with $rc before the timeout"
    exit 1
fi
if grep -q Traceback "$home/ui.log"; then
    echo "UI printed a Traceback"
    exit 1
fi
echo "UI smoke test passed"
