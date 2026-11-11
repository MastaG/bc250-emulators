#!/usr/bin/env bash
# Runs as root inside an archlinux:base-devel container with the checkout at
# /workspace: prepares the container, builds one component as the unprivileged
# user `builder` (makepkg refuses root), then rebuilds the pacman database from
# every package in out/repo -- the ones the release already had (seeded by the
# workflow) plus this build's.
#
#   ci-build.sh <component>
set -Eeuo pipefail

COMPONENT="${1:?component name is required}"
REPO_NAME="${REPO_NAME:-bc250-emulators}"
: "${PKGREL:?PKGREL is required}"

# A local signing key first, so archlinux-keyring's post-install can sign the
# keys it imports instead of logging an error that looks like a failure.
pacman-key --init >/dev/null 2>&1
pacman -Sy --noconfirm --needed archlinux-keyring
pacman -Su --noconfirm --needed base-devel git curl libarchive sudo

id builder >/dev/null 2>&1 || useradd --create-home --shell /bin/bash builder
printf 'builder ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder
chmod 0440 /etc/sudoers.d/builder
mkdir -p /workspace/out/repo
chown -R builder:builder /workspace

case "$COMPONENT" in
    lichii-bc250)
        runuser -u builder -- env HOME=/home/builder \
            LICHII_TAG="${LICHII_TAG:?}" LICHII_BUILD="${LICHII_BUILD:?}" LICHII_COMMIT="${LICHII_COMMIT:?}" \
            LICHII_BC250_PKGREL="$PKGREL" \
            LICHII_BC250_FINGERPRINT="${LICHII_BC250_FINGERPRINT:-unknown}" \
            /workspace/scripts/build-lichii-bc250-package.sh
        ;;
    *)
        printf 'ERROR: unknown component: %s\n' "$COMPONENT" >&2
        exit 1
        ;;
esac

# The database, rebuilt from scratch. GitHub release assets cannot be symlinks,
# so the .db/.files names repo-add links are replaced by real copies.
cd /workspace/out/repo
rm -f -- "$REPO_NAME".db* "$REPO_NAME".files*
shopt -s nullglob
packages=(*.pkg.tar.zst)
(( ${#packages[@]} )) || { printf 'ERROR: no packages in out/repo\n' >&2; exit 1; }
runuser -u builder -- repo-add "$REPO_NAME.db.tar.zst" "${packages[@]}"
for kind in db files; do
    rm -f -- "$REPO_NAME.$kind"
    cp -- "$REPO_NAME.$kind.tar.zst" "$REPO_NAME.$kind"
done
chown -R builder:builder /workspace/out
printf '==> %s: %d package(s) in the database\n' "$REPO_NAME" "${#packages[@]}"
