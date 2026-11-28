#!/usr/bin/env bash
# helixsr: the official HelixSR release archive, repackaged unmodified (packages/helixsr).
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${ROOT_DIR}/packages/helixsr"
BUILD_DIR="${HELIXSR_BUILD_DIR:-${ROOT_DIR}/build/helixsr}"
OUT_DIR="${ROOT_DIR}/out/repo"
PKGREL="${HELIXSR_PKGREL:-1}"
[[ "$PKGREL" =~ ^[0-9]+$ ]] || {
    printf 'ERROR: invalid pkgrel: %s\n' "$PKGREL" >&2
    exit 1
}

rm -rf -- "$BUILD_DIR"
mkdir -p -- "$BUILD_DIR"
sed -e "s/@PKGREL@/${PKGREL}/" "$PKG_DIR/PKGBUILD.in" > "$BUILD_DIR/PKGBUILD"
if grep -n '@[A-Z_]*@' "$BUILD_DIR/PKGBUILD"; then
    printf 'ERROR: unreplaced placeholder in the helixsr PKGBUILD\n' >&2
    exit 1
fi

cd -- "$BUILD_DIR"
makepkg --syncdeps --noconfirm --cleanbuild --clean

shopt -s nullglob
packages=("$BUILD_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} == 1 )) || {
    printf 'ERROR: expected exactly one helixsr package; found %d\n' "${#packages[@]}" >&2
    exit 1
}
package="${packages[0]}"
pkginfo="$(bsdtar -xOf "$package" .PKGINFO)"
version="$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$pkginfo")"
listing="$(bsdtar -tf "$package")"
for path in "usr/share/helixsr/HelixSR-${version%-*}.zip" usr/share/licenses/helixsr/LICENSE; do
    grep -qx -- "$path" <<<"$listing" || {
        printf 'ERROR: helixsr is missing %s\n' "$path" >&2
        exit 1
    }
done

makepkg --printsrcinfo > .SRCINFO

mkdir -p -- "$OUT_DIR"
for old in "$OUT_DIR"/*.pkg.tar.zst; do
    [[ "$(bsdtar -xOf "$old" .PKGINFO 2>/dev/null | awk -F ' = ' '$1 == "pkgname" { print $2; exit }')" == helixsr ]] || continue
    printf '==> Removing previous package: %s\n' "$(basename -- "$old")"
    rm -f -- "$old"
done
cp -- "$package" "$OUT_DIR/"
cp -- "$BUILD_DIR/PKGBUILD" "$OUT_DIR/helixsr-PKGBUILD"
cp -- "$BUILD_DIR/.SRCINFO" "$OUT_DIR/helixsr.SRCINFO"
cat > "$OUT_DIR/helixsr-info.env" <<EOF_INFO
HELIXSR_FINGERPRINT=${HELIXSR_FINGERPRINT:-unknown}
HELIXSR_PKGVER=${version%-*}
HELIXSR_PKGREL=${PKGREL}
EOF_INFO

printf '==> helixsr staged in %s\n' "$OUT_DIR"
printf '    Version: %s\n' "$version"
