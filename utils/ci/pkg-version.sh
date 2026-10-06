# Sourced by the package build scripts.
#
# With PKG_SNAPSHOT set (e.g. ci12), the package version becomes
# <version>~<PKG_SNAPSHOT>.g<commit>-<revision>, e.g. 1.9.0~ci12.g14fd693-1:
# - the ~ sorts it below <version>-<revision> (dpkg and rpm alike), so the official
#   release replaces it;
# - the commit keeps two different builds from sharing a version.
# Without PKG_SNAPSHOT the version from the changelog is used as is.

# snapshot_version <version> <repo>: prints <version>~<PKG_SNAPSHOT>.g<commit>.
# Format independent.
snapshot_version() {
    printf '%s~%s.g%s\n' "$1" "$PKG_SNAPSHOT" "$(git -C "$2" rev-parse --short=7 HEAD)"
}

# set_deb_snapshot_version <debian dir> <repo>: adds a changelog entry with the test
# build version.
set_deb_snapshot_version() {
    local debian=$1 repo=$2
    [ -n "${PKG_SNAPSHOT:-}" ] || return 0

    local pkg version new name email
    pkg=$(dpkg-parsechangelog -l "$debian/changelog" -S Source)
    version=$(dpkg-parsechangelog -l "$debian/changelog" -S Version)
    new=$(snapshot_version "${version%-*}" "$repo")-${version##*-}
    dpkg --compare-versions "$new" lt "$version" || { echo "$new does not sort below $version"; return 1; }
    name=${DEBFULLNAME:-$(git -C "$repo" config user.name || echo unknown)}
    email=${DEBEMAIL:-$(git -C "$repo" config user.email || echo unknown@invalid)}

    {
        printf '%s (%s) unstable; urgency=medium\n\n' "$pkg" "$new"
        printf '  * Unofficial test build %s.\n\n' "$PKG_SNAPSHOT"
        printf ' -- %s <%s>  %s\n\n' "$name" "$email" "$(date -R)"
        cat "$debian/changelog"
    } > "$debian/changelog.new"
    mv "$debian/changelog.new" "$debian/changelog"
    echo "package version: $new"
}

# set_rpm_snapshot_version <spec> <repo>: sets the spec's version to the test build
# version. Both spec styles are handled: "Version: x" (daemon) and "%define version x" (UI).
set_rpm_snapshot_version() {
    local spec=$1 repo=$2
    [ -n "${PKG_SNAPSHOT:-}" ] || return 0

    local version new
    version=$(rpmspec -q --srpm --qf '%{version}' "$spec")
    new=$(snapshot_version "$version" "$repo")
    [ "$(rpm --eval "%{lua: print(rpm.vercmp('$new', '$version'))}")" = -1 ] \
        || { echo "$new does not sort below $version"; return 1; }
    sed -i -E "s/^(Version:[[:space:]]+).*/\1$new/; s/^(%define version ).*/\1$new/" "$spec"
    [ "$(rpmspec -q --srpm --qf '%{version}' "$spec")" = "$new" ] || { echo "version not set in $spec"; return 1; }
    echo "package version: $new"
}
