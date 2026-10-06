#!/bin/bash
#
# Print the Markdown notes for a test pre-release of the packages in <dist dir>.
# <upstream ref> is upstream's master; the commits on HEAD that it lacks are listed.
#
# Usage: test-release-notes.sh <dist dir> <upstream ref>
#
set -euo pipefail

dist=${1:?usage: $0 <dist dir> <upstream ref>}
upstream=$(git rev-parse "${2:?usage: $0 <dist dir> <upstream ref>}")
head=$(git rev-parse HEAD)
repo=${GITHUB_REPOSITORY:-aadrian/opensnitch}

daemon=$(basename "$(ls "$dist"/opensnitch_*.deb)")
ui=$(basename "$(ls "$dist"/python3-opensnitch-ui_*.deb)")
daemon_rpm=$(basename "$(ls "$dist"/opensnitch-[0-9]*.rpm)")
ui_rpm=$(basename "$(ls "$dist"/opensnitch-ui-*.rpm)")
version=$(dpkg-deb -f "$dist/$daemon" Version)

cat <<EOF
Test build \`$version\`, built from [\`${head:0:7}\`](https://github.com/$repo/commit/$head): the upstream master branch ([\`${upstream:0:7}\`](https://github.com/evilsocket/opensnitch/commit/$upstream)) plus the commits listed at the end. It is not an official release; its version sorts below the official 1.9.0, so installing that later replaces this build.

## Packages

- \`$daemon\`, \`$daemon_rpm\`: daemon
- \`$ui\`, \`$ui_rpm\`: UI

The packages are not signed. Check the downloads with \`sha256sum -c SHA256SUMS\`.

Tested by CI on Debian 13, Ubuntu 24.04 and Ubuntu 26.04 (debs) and on Fedora 43, 44 and 45 (rpms), all amd64: fresh install, upgrade from 1.8.0, and switching back to 1.8.0. They need glibc 2.34 or newer; Debian 12 and Ubuntu 22.04 should work but are not tested.

## Back up your settings first

\`\`\`
sudo tar -czf opensnitch-backup.tar.gz /etc/opensnitchd ~/.config/opensnitch
\`\`\`

If you set a database file in the UI preferences, back it up as well.

## Install, or switch from any other version

Debian, Ubuntu:

\`\`\`
sudo apt install --reinstall --allow-downgrades ./$daemon ./$ui
\`\`\`

Fedora:

\`\`\`
sudo dnf install ./$daemon_rpm ./$ui_rpm
\`\`\`

The same commands work with the 1.8.0 packages from https://github.com/evilsocket/opensnitch/releases/tag/v1.8.0 to go back. Your changes in \`/etc/opensnitchd\` are kept on every switch. To restore the backup:

\`\`\`
sudo tar -xzf opensnitch-backup.tar.gz -C /
sudo systemctl restart opensnitch
\`\`\`

## Commits not in upstream master

EOF
git log --no-merges --format='- [`%h`](https://github.com/'"$repo"'/commit/%H) %s' "$upstream..$head"
