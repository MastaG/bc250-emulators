#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${ROOT_DIR}/packages/kytyps5-native-git"
BUILD_DIR="${KYTYPS5_NATIVE_GIT_BUILD_DIR:-${ROOT_DIR}/build/kytyps5-native-git}"
OUT_DIR="${ROOT_DIR}/out/repo"
PKGREL="${KYTYPS5_NATIVE_GIT_PKGREL:-1}"

# The workflow resolves the release once and passes it in, so the fingerprint
# and the build always agree on the commit. Run by hand, resolve it here.
if [[ -z "${KYTY_TAG:-}" || -z "${KYTY_COMMIT:-}" ]]; then
    eval "$("$ROOT_DIR/scripts/resolve-kytyps5-native.sh")"
fi
[[ "$KYTY_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'ERROR: invalid KYTY_COMMIT: %s\n' "$KYTY_COMMIT" >&2
    exit 1
}
[[ "$PKGREL" =~ ^[0-9]+$ ]] || {
    printf 'ERROR: invalid pkgrel: %s\n' "$PKGREL" >&2
    exit 1
}

# Work on a copy: makepkg rewrites pkgver in the PKGBUILD it runs.
rm -rf -- "$BUILD_DIR"
mkdir -p -- "$BUILD_DIR"
cp -- "$PKG_DIR"/kytyps5-native-wrapper.sh "$PKG_DIR"/kytyps5-native.desktop \
    "$PKG_DIR"/kyty-lodhw.service "$PKG_DIR"/kytyps5-steam-sync \
    "$PKG_DIR"/kytyps5-native-git.install "$BUILD_DIR/"
sed -e "s/@KYTY_COMMIT@/${KYTY_COMMIT}/" -e "s/@KYTY_TAG@/${KYTY_TAG}/" -e "s/@PKGREL@/${PKGREL}/" \
    "$PKG_DIR/PKGBUILD.in" > "$BUILD_DIR/PKGBUILD"
if grep -n '@[A-Z_]*@' "$BUILD_DIR/PKGBUILD"; then
    printf 'ERROR: unreplaced placeholder in the kytyps5-native-git PKGBUILD\n' >&2
    exit 1
fi

cd -- "$BUILD_DIR"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
# Two steps: pkgver() resets pkgrel to 1 whenever the version changes. Fetch
# and resolve the version first, put the run's pkgrel back, then build: the
# second pkgver() finds the same version and keeps it, so a packaging-only
# rebuild of the same commit is still an update.
makepkg --syncdeps --noconfirm --nobuild --cleanbuild --skippgpcheck
sed -i "s/^pkgrel=.*/pkgrel=${PKGREL}/" PKGBUILD
makepkg --syncdeps --noconfirm --noextract --clean --skippgpcheck

shopt -s nullglob
packages=("$BUILD_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} == 1 )) || {
    printf 'ERROR: expected exactly one kytyps5-native-git package; found %d\n' "${#packages[@]}" >&2
    exit 1
}

pkginfo="$(bsdtar -xOf "${packages[0]}" .PKGINFO)"
pkgver_full="$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$pkginfo")"
pkgver="${pkgver_full%-*}"
pkgrel="${pkgver_full##*-}"
[[ "$pkgver" =~ ^[0-9]{8}\.r[0-9]+\.g[0-9a-f]{7}$ && "$pkgver" == *".g${KYTY_COMMIT:0:7}" && "$pkgrel" == "$PKGREL" ]] || {
    printf 'ERROR: unexpected kytyps5-native-git version %s for commit %s\n' "$pkgver_full" "$KYTY_COMMIT" >&2
    exit 1
}

# The pieces a user runs must be there; the bundled Qt and the self-updater
# must not.
listing="$(bsdtar -tf "${packages[0]}")"
for path in usr/lib/kytyps5-native/kyty_emulator usr/lib/kytyps5-native/kyty_launcher \
            usr/lib/kytyps5-native/kyty-lodhw usr/lib/kytyps5-native/kytyps5-run.sh \
            usr/lib/kytyps5-native/VERSION usr/lib/kytyps5-native/assets/fonts/NotoSans-Regular.ttf \
            usr/bin/kytyps5-native usr/bin/kytyps5-steam-sync \
            usr/lib/systemd/system/kyty-lodhw.service; do
    grep -qx -- "$path" <<<"$listing" || {
        printf 'ERROR: kytyps5-native-git is missing %s\n' "$path" >&2
        exit 1
    }
done
if grep -E '^(opt/|usr/lib/kytyps5-native/(kyty_updater|lib/|plugins/|qt\.conf|include/))' <<<"$listing"; then
    printf 'ERROR: kytyps5-native-git ships files it should leave out (above)\n' >&2
    exit 1
fi

# makepkg wrote the resolved pkgver back into the PKGBUILD, so .SRCINFO
# describes this build.
makepkg --printsrcinfo > .SRCINFO

# out/repo holds what the release published so far (the workflow seeds it):
# replace the previous kytyps5-native-git package with this build's.
mkdir -p -- "$OUT_DIR"
for old in "$OUT_DIR"/*.pkg.tar.zst; do
    [[ "$(bsdtar -xOf "$old" .PKGINFO 2>/dev/null | awk -F ' = ' '$1 == "pkgbase" { print $2; exit }')" == kytyps5-native-git ]] || continue
    printf '==> Removing previous package: %s\n' "$(basename -- "$old")"
    rm -f -- "$old"
done
cp -- "${packages[@]}" "$OUT_DIR/"

cp -- "$BUILD_DIR/PKGBUILD" "$OUT_DIR/kytyps5-native-git-PKGBUILD"
cp -- "$BUILD_DIR/.SRCINFO" "$OUT_DIR/kytyps5-native-git.SRCINFO"

cat > "$OUT_DIR/kytyps5-native-git-info.env" <<EOF_INFO
KYTYPS5_NATIVE_GIT_FINGERPRINT=${KYTYPS5_NATIVE_GIT_FINGERPRINT:-unknown}
KYTYPS5_NATIVE_GIT_TAG=${KYTY_TAG}
KYTYPS5_NATIVE_GIT_COMMIT=${KYTY_COMMIT}
KYTYPS5_NATIVE_GIT_PKGVER=${pkgver}
KYTYPS5_NATIVE_GIT_PKGREL=${pkgrel}
EOF_INFO

printf '==> kytyps5-native-git staged in %s\n' "$OUT_DIR"
printf '    Version: %s-%s (%s)\n' "$pkgver" "$pkgrel" "$KYTY_TAG"
