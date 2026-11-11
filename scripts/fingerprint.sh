#!/usr/bin/env bash
# Fingerprint of one component: the upstream commit it builds plus our own
# packaging. CI rebuilds a component only when its fingerprint differs from the
# one the release recorded (<component>-info.env), or when forced.
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENT="${1:?component name is required}"

hash_files() {
    local file
    for file in "$@"; do
        [[ -f "$file" ]] || { printf 'ERROR: missing %s\n' "$file" >&2; exit 1; }
        printf '%s  %s\n' "$(sha256sum < "$file" | awk '{print $1}')" "${file#"$ROOT_DIR"/}"
    done
}

case "$COMPONENT" in
    lichii-bc250)
        # Upstream publishes several builds a day; this rebuilds at most once
        # per CI run, with whichever release is newest then.
        if [[ -z "${LICHII_COMMIT:-}" ]]; then
            eval "$("$ROOT_DIR/scripts/resolve-lichii.sh")"
        fi
        [[ "$LICHII_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
            printf 'ERROR: invalid LICHII_COMMIT: %s\n' "$LICHII_COMMIT" >&2
            exit 1
        }
        {
            printf 'lichii-commit  %s\n' "$LICHII_COMMIT"
            hash_files "$ROOT_DIR"/packages/lichii-bc250/PKGBUILD.in \
                "$ROOT_DIR"/packages/lichii-bc250/lichii-steam-sync \
                "$ROOT_DIR"/scripts/build-lichii-bc250-package.sh \
                "$ROOT_DIR"/scripts/resolve-lichii.sh \
                "$ROOT_DIR"/scripts/ci-build.sh
        } | sha256sum | awk '{print $1}'
        ;;
    *)
        printf 'ERROR: unknown component: %s\n' "$COMPONENT" >&2
        exit 1
        ;;
esac
