#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${ROOT_DIR}/packages/lichii-bc250"
BUILD_DIR="${LICHII_BC250_BUILD_DIR:-${ROOT_DIR}/build/lichii-bc250}"
OUT_DIR="${ROOT_DIR}/out/repo"
PKGREL="${LICHII_BC250_PKGREL:-${BC250_PKGREL:-1}}"

# The workflow resolves the commit once and passes it in, so the fingerprint
# and the build always agree. Run by hand, resolve it here.
if [[ -z "${LICHII_BC250_COMMIT:-}" ]]; then
    eval "$("$ROOT_DIR/scripts/resolve-lichii-bc250.sh")"
fi
[[ "$LICHII_BC250_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'ERROR: invalid LICHII_BC250_COMMIT: %s\n' "$LICHII_BC250_COMMIT" >&2
    exit 1
}
[[ "$PKGREL" =~ ^[0-9]+$ ]] || {
    printf 'ERROR: invalid pkgrel: %s\n' "$PKGREL" >&2
    exit 1
}

rm -rf -- "$BUILD_DIR"
mkdir -p -- "$BUILD_DIR"
cp -- "$PKG_DIR"/lichii-bc250-env "$PKG_DIR"/lichii-bc250-wrapper "$BUILD_DIR/"
sed -e "s/@LICHII_BC250_COMMIT@/${LICHII_BC250_COMMIT}/" -e "s/@PKGREL@/${PKGREL}/" \
    "$PKG_DIR/PKGBUILD.in" > "$BUILD_DIR/PKGBUILD"
if grep -n '@[A-Z_0-9]*@' "$BUILD_DIR/PKGBUILD"; then
    printf 'ERROR: unreplaced placeholder in the lichii-bc250 PKGBUILD\n' >&2
    exit 1
fi

cd -- "$BUILD_DIR"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
# lichii-steam-sync is a runtime dependency from this repository (packages/lichii),
# not from Arch, so --syncdeps cannot install it: install everything else here
# and let makepkg skip the check.
mapfile -t deps < <(bash -c 'source ./PKGBUILD; printf "%s\n" "${depends[@]}" "${makedepends[@]}"' |
    grep -vx 'lichii-steam-sync')
sudo pacman -S --needed --noconfirm "${deps[@]}"
makepkg --nodeps --noconfirm --cleanbuild --clean --skippgpcheck

shopt -s nullglob
packages=("$BUILD_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} == 1 )) || {
    printf 'ERROR: expected one lichii-bc250 package; found %d\n' "${#packages[@]}" >&2
    exit 1
}
package="${packages[0]}"
pkginfo="$(bsdtar -xOf "$package" .PKGINFO)"
version="$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$pkginfo")"
short="${LICHII_BC250_COMMIT:0:9}"
[[ "$version" =~ ^[0-9]{8}\.r[0-9]+\.g${short}-${PKGREL}$ ]] || {
    printf 'ERROR: unexpected lichii-bc250 version %s for commit %s\n' "$version" "$LICHII_BC250_COMMIT" >&2
    exit 1
}

# What a user runs must be there. Nothing may clash with packages/lichii or
# Eden: no /usr/bin/lichii or eden-*, no /usr/lib/lichii, no upstream ids.
listing="$(bsdtar -tf "$package")"
for path in usr/bin/lichii-bc250 usr/bin/lichii-bc250-cli usr/bin/lichii-bc250-room \
            usr/lib/lichii-bc250/lichii-bc250 usr/lib/lichii-bc250/lichii-bc250-cli \
            usr/lib/lichii-bc250/lichii-bc250-env usr/lib/lichii-bc250/libnxformat.so \
            usr/share/applications/io.github.lethevimlet.lichii-bc250.desktop \
            usr/share/doc/lichii-bc250/oot.ini; do
    grep -qx -- "$path" <<<"$listing" || {
        printf 'ERROR: lichii-bc250 is missing %s\n' "$path" >&2
        exit 1
    }
done
if grep -E '^usr/bin/(lichii|eden)($|-cli$|-room$)|^usr/lib/lichii/|zortos293|^usr/lib/udev/' <<<"$listing"; then
    printf 'ERROR: lichii-bc250 ships files (above) that clash with lichii or Eden\n' >&2
    exit 1
fi
grep -qx 'depend = lichii-steam-sync' <<<"$pkginfo" || {
    printf 'ERROR: lichii-bc250 does not depend on lichii-steam-sync\n' >&2
    exit 1
}
tmp="$(mktemp -d)"
bsdtar -xf "$package" -C "$tmp" usr/lib/lichii-bc250 usr/bin/lichii-bc250-room
# The Qt binary finds libnxformat in its own folder, not in /usr/lib/lichii.
if ! readelf -d "$tmp/usr/lib/lichii-bc250/lichii-bc250" | grep -qE 'R(UN)?PATH.*\[\$ORIGIN\]'; then
    readelf -d "$tmp/usr/lib/lichii-bc250/lichii-bc250" | grep -E 'RPATH|RUNPATH' >&2 || true
    rm -rf -- "$tmp"
    printf 'ERROR: lichii-bc250 does not look for libnxformat beside itself\n' >&2
    exit 1
fi
# The BC-250's RDSEED is broken (packages/lichii/PKGBUILD.in): no compiled code may use it.
if command -v objdump >/dev/null &&
   objdump -d --no-show-raw-insn "$tmp"/usr/lib/lichii-bc250/lichii-bc250 "$tmp"/usr/lib/lichii-bc250/lichii-bc250-cli \
       "$tmp"/usr/bin/lichii-bc250-room | awk '{ print $2 }' | grep -qx rdseed; then
    rm -rf -- "$tmp"
    printf 'ERROR: a lichii-bc250 binary contains RDSEED, which the BC-250 cannot run correctly\n' >&2
    exit 1
fi
rm -rf -- "$tmp"

makepkg --printsrcinfo > .SRCINFO

# out/repo holds what the release published so far (the workflow seeds it):
# replace the previous fork package with this build's. Only pkgname
# lichii-bc250 with a dated version: the ones versioned by a bare build number
# (150 ...) are the old name of packages/lichii, and its build script retires
# them. (The first fork builds had epoch 1, 1:r<count>...; they go too.)
mkdir -p -- "$OUT_DIR"
for old in "$OUT_DIR"/*.pkg.tar.zst; do
    info="$(bsdtar -xOf "$old" .PKGINFO 2>/dev/null)" || continue
    [[ "$(awk -F ' = ' '$1 == "pkgname" { print $2; exit }' <<<"$info")" == lichii-bc250 &&
       ! "$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$info")" =~ ^[0-9]+- ]] || continue
    printf '==> Removing previous package: %s\n' "$(basename -- "$old")"
    rm -f -- "$old"
done
cp -- "$package" "$OUT_DIR/"

cp -- "$BUILD_DIR/PKGBUILD" "$OUT_DIR/lichii-bc250-PKGBUILD"
cp -- "$BUILD_DIR/.SRCINFO" "$OUT_DIR/lichii-bc250.SRCINFO"

cat > "$OUT_DIR/lichii-bc250-info.env" <<EOF_INFO
LICHII_BC250_FINGERPRINT=${LICHII_BC250_FINGERPRINT:-unknown}
LICHII_BC250_COMMIT=${LICHII_BC250_COMMIT}
LICHII_BC250_PKGVER=${version%-*}
LICHII_BC250_PKGREL=${PKGREL}
EOF_INFO

printf '==> lichii-bc250 staged in %s\n' "$OUT_DIR"
printf '    Version: %s (%s)\n' "$version" "$LICHII_BC250_COMMIT"
