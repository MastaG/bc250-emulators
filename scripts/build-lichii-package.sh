#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${ROOT_DIR}/packages/lichii"
BUILD_DIR="${LICHII_BUILD_DIR:-${ROOT_DIR}/build/lichii}"
OUT_DIR="${ROOT_DIR}/out/repo"
PKGREL="${LICHII_PKGREL:-${BC250_PKGREL:-1}}"

# The workflow resolves the release once and passes it in, so the fingerprint
# and the build always agree on the commit. Run by hand, resolve it here.
if [[ -z "${LICHII_TAG:-}" || -z "${LICHII_COMMIT:-}" || -z "${LICHII_BUILD:-}" ]]; then
    eval "$("$ROOT_DIR/scripts/resolve-lichii.sh")"
fi
[[ "$LICHII_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'ERROR: invalid LICHII_COMMIT: %s\n' "$LICHII_COMMIT" >&2
    exit 1
}
[[ "$LICHII_BUILD" =~ ^[0-9]+$ && "$LICHII_TAG" == "build-${LICHII_BUILD}" ]] || {
    printf 'ERROR: LICHII_TAG %s and LICHII_BUILD %s do not match\n' "$LICHII_TAG" "$LICHII_BUILD" >&2
    exit 1
}
[[ "$PKGREL" =~ ^[0-9]+$ ]] || {
    printf 'ERROR: invalid pkgrel: %s\n' "$PKGREL" >&2
    exit 1
}

rm -rf -- "$BUILD_DIR"
mkdir -p -- "$BUILD_DIR"
cp -- "$PKG_DIR"/lichii-steam-sync "$BUILD_DIR/"
sed -e "s/@LICHII_TAG@/${LICHII_TAG}/" -e "s/@LICHII_COMMIT@/${LICHII_COMMIT}/" \
    -e "s/@LICHII_BUILD@/${LICHII_BUILD}/" -e "s/@PKGREL@/${PKGREL}/" \
    "$PKG_DIR/PKGBUILD.in" > "$BUILD_DIR/PKGBUILD"
if grep -n '@[A-Z_]*@' "$BUILD_DIR/PKGBUILD"; then
    printf 'ERROR: unreplaced placeholder in the lichii PKGBUILD\n' >&2
    exit 1
fi

cd -- "$BUILD_DIR"
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
makepkg --syncdeps --noconfirm --cleanbuild --clean --skippgpcheck

shopt -s nullglob
packages=("$BUILD_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} == 2 )) || {
    printf 'ERROR: expected lichii + lichii-steam-sync; found %d package(s)\n' "${#packages[@]}" >&2
    exit 1
}

emulator="" sync=""
for package in "${packages[@]}"; do
    pkginfo="$(bsdtar -xOf "$package" .PKGINFO)"
    name="$(awk -F ' = ' '$1 == "pkgname" { print $2; exit }' <<<"$pkginfo")"
    version="$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$pkginfo")"
    [[ "$version" == "${LICHII_BUILD}-${PKGREL}" ]] || {
        printf 'ERROR: unexpected %s version %s for %s\n' "$name" "$version" "$LICHII_TAG" >&2
        exit 1
    }
    case "$name" in
        lichii) emulator="$package" ;;
        lichii-steam-sync) sync="$package" ;;
        *) printf 'ERROR: unexpected package %s\n' "$name" >&2; exit 1 ;;
    esac
done
[[ -n "$emulator" && -n "$sync" ]] || {
    printf 'ERROR: lichii or lichii-steam-sync is missing\n' >&2
    exit 1
}

# What a user runs must be there; upstream's eden-* names and the updater must not.
listing="$(bsdtar -tf "$emulator")"
for path in usr/bin/lichii usr/bin/lichii-cli usr/bin/lichii-room usr/lib/lichii/libnxformat.so \
            usr/share/applications/io.github.zortos293.lichii.desktop; do
    grep -qx -- "$path" <<<"$listing" || {
        printf 'ERROR: lichii is missing %s\n' "$path" >&2
        exit 1
    }
done
if grep -E '^usr/bin/eden' <<<"$listing"; then
    printf 'ERROR: lichii ships eden-* binaries (above); they clash with the Eden emulator\n' >&2
    exit 1
fi
grep -qx 'depend = lichii-steam-sync' < <(bsdtar -xOf "$emulator" .PKGINFO) || {
    printf 'ERROR: lichii does not depend on lichii-steam-sync\n' >&2
    exit 1
}
grep -qx 'usr/bin/lichii-steam-sync' < <(bsdtar -tf "$sync") || {
    printf 'ERROR: lichii-steam-sync is missing usr/bin/lichii-steam-sync\n' >&2
    exit 1
}
# The BC-250's RDSEED is broken (see the PKGBUILD): no compiled code may use it.
if command -v objdump >/dev/null; then
    tmp="$(mktemp -d)"
    bsdtar -xf "$emulator" -C "$tmp" usr/bin/lichii usr/bin/lichii-cli usr/bin/lichii-room
    if objdump -d --no-show-raw-insn "$tmp"/usr/bin/lichii* | awk '{ print $2 }' | grep -qx rdseed; then
        rm -rf -- "$tmp"
        printf 'ERROR: a lichii binary contains RDSEED, which the BC-250 cannot run correctly\n' >&2
        exit 1
    fi
    rm -rf -- "$tmp"
fi

makepkg --printsrcinfo > .SRCINFO

# out/repo holds what the release published so far (the workflow seeds it):
# replace the previous lichii split packages with this build's. Until
# 2026-11-12 they were built as pkgbase lichii-bc250, versioned by the bare
# build number (150-2); those go too. The BC-250 fork, also lichii-bc250 but
# versioned by date, is not this script's.
mkdir -p -- "$OUT_DIR"
for old in "$OUT_DIR"/*.pkg.tar.zst; do
    info="$(bsdtar -xOf "$old" .PKGINFO 2>/dev/null)" || continue
    base="$(awk -F ' = ' '$1 == "pkgbase" { print $2; exit }' <<<"$info")"
    version="$(awk -F ' = ' '$1 == "pkgver" { print $2; exit }' <<<"$info")"
    [[ "$base" == lichii || ( "$base" == lichii-bc250 && "$version" =~ ^[0-9]+- ) ]] || continue
    printf '==> Removing previous package: %s\n' "$(basename -- "$old")"
    rm -f -- "$old"
done
cp -- "${packages[@]}" "$OUT_DIR/"
# The old name's sidecar (it has a tag; the fork's has none) would describe the
# fork in the release notes until the fork's first build replaces it.
if grep -q '^LICHII_BC250_TAG=' "$OUT_DIR/lichii-bc250-info.env" 2>/dev/null; then
    rm -f -- "$OUT_DIR/lichii-bc250-info.env" "$OUT_DIR/lichii-bc250-PKGBUILD" "$OUT_DIR/lichii-bc250.SRCINFO"
fi

cp -- "$BUILD_DIR/PKGBUILD" "$OUT_DIR/lichii-PKGBUILD"
cp -- "$BUILD_DIR/.SRCINFO" "$OUT_DIR/lichii.SRCINFO"

cat > "$OUT_DIR/lichii-info.env" <<EOF_INFO
LICHII_FINGERPRINT=${LICHII_FINGERPRINT:-unknown}
LICHII_TAG=${LICHII_TAG}
LICHII_COMMIT=${LICHII_COMMIT}
LICHII_PKGVER=${LICHII_BUILD}
LICHII_PKGREL=${PKGREL}
EOF_INFO

printf '==> lichii + lichii-steam-sync staged in %s\n' "$OUT_DIR"
printf '    Version: %s-%s (%s)\n' "$LICHII_BUILD" "$PKGREL" "$LICHII_TAG"
