#!/usr/bin/env bash
# Runs as root inside an archlinux:base-devel container with the checkout at
# /workspace: prepares the container, builds the given components as the
# unprivileged user `builder` (makepkg refuses root), then rebuilds the pacman
# database from every package in out/repo -- the ones the release already had
# (seeded by the workflow) plus this run's.
#
#   ci-build.sh <component>...
#
# One component failing does not stop the others: what did build still goes
# into the database (a failed component keeps its previous packages), and the
# script exits non-zero at the end so the run shows the failure.
set -Eeuo pipefail

(( $# )) || { printf 'ERROR: no component given\n' >&2; exit 1; }
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

as_builder() { runuser -u builder -- env HOME=/home/builder "$@"; }

failed=()
for component in "$@"; do
    printf '::group::build %s\n' "$component"
    case "$component" in
        lichii)
            as_builder \
                LICHII_TAG="${LICHII_TAG:?}" LICHII_BUILD="${LICHII_BUILD:?}" LICHII_COMMIT="${LICHII_COMMIT:?}" \
                LICHII_PKGREL="$PKGREL" \
                LICHII_FINGERPRINT="${LICHII_FINGERPRINT:-unknown}" \
                /workspace/scripts/build-lichii-package.sh || failed+=("$component")
            ;;
        lichii-bc250)
            as_builder \
                LICHII_BC250_COMMIT="${LICHII_BC250_COMMIT:?}" \
                LICHII_BC250_PKGREL="$PKGREL" \
                LICHII_BC250_FINGERPRINT="${LICHII_BC250_FINGERPRINT:-unknown}" \
                /workspace/scripts/build-lichii-bc250-package.sh || failed+=("$component")
            ;;
        kytyps5-native-git)
            as_builder \
                KYTY_TAG="${KYTY_TAG:?}" KYTY_COMMIT="${KYTY_COMMIT:?}" \
                KYTYPS5_NATIVE_GIT_PKGREL="$PKGREL" \
                KYTYPS5_NATIVE_GIT_FINGERPRINT="${KYTYPS5_NATIVE_GIT_FINGERPRINT:-unknown}" \
                /workspace/scripts/build-kytyps5-native-git-package.sh || failed+=("$component")
            ;;
        *)
            printf 'ERROR: unknown component: %s\n' "$component" >&2
            failed+=("$component")
            ;;
    esac
    printf '::endgroup::\n'
done

# The database, rebuilt from scratch. GitHub release assets cannot be symlinks,
# so the .db/.files names repo-add links are replaced by real copies.
cd /workspace/out/repo
rm -f -- "$REPO_NAME".db* "$REPO_NAME".files*
shopt -s nullglob
packages=(*.pkg.tar.zst)
if (( ${#packages[@]} )); then
    as_builder repo-add "$REPO_NAME.db.tar.zst" "${packages[@]}"
    for kind in db files; do
        rm -f -- "$REPO_NAME.$kind"
        cp -- "$REPO_NAME.$kind.tar.zst" "$REPO_NAME.$kind"
    done
    printf '==> %s: %d package(s) in the database\n' "$REPO_NAME" "${#packages[@]}"
else
    printf 'WARN: no packages in out/repo, no database written\n' >&2
fi
chown -R builder:builder /workspace/out

if (( ${#failed[@]} )); then
    printf '::error title=Build failed::%s\n' "${failed[*]}"
    exit 1
fi
