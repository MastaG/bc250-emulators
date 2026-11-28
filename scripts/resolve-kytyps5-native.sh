#!/usr/bin/env bash
# Resolve which KytyPS5-Native commit kytyps5-native-git builds.
#
# The newest commit of our MastaG/KytyPS5-Native fork's bc250 branch (since
# 2026-11-28): dmorazasanchez/KytyPS5-Native-beta's main with superkeka's dev
# merged in, UnicronNL's I/O and CPU work, and our APR read-path changes for
# the BC-250 (games that stream their assets). Before that the beta fork's main (from
# 2026-11-18), 2026-11-17 superkeka/KytyPS5-Native's main, from 2026-11-12 the
# beta fork's newest release, before that superkeka's newest release.
#
# Prints an env file: KYTY_TAG (the branch, shown in the CI summary) and the
# full commit. Set KYTY_COMMIT to build a specific commit instead.
set -Eeuo pipefail

REPOSITORY="MastaG/KytyPS5-Native"
BRANCH="bc250"

if [[ -n "${KYTY_COMMIT:-}" ]]; then
    commit="$KYTY_COMMIT"
else
    # A transient failure must not resolve to something else -- the build
    # cache keys on the commit -- so retry, then give up loudly.
    attempts=5 commit=""
    for attempt in $(seq 1 "$attempts"); do
        if out="$(git ls-remote "https://github.com/${REPOSITORY}.git" "refs/heads/${BRANCH}" 2>&1)"; then
            commit="$(awk 'NR == 1 { print $1 }' <<<"$out")"
            [[ "$commit" =~ ^[0-9a-f]{40}$ ]] && break
        fi
        commit=""
        printf 'WARN: could not resolve %s %s (attempt %d/%d): %s\n' \
            "$REPOSITORY" "$BRANCH" "$attempt" "$attempts" "${out%%$'\n'*}" >&2
        if (( attempt < attempts )); then sleep $(( attempt * 5 )); fi
    done
fi

if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'ERROR: could not resolve %s %s to a commit (got %q)\n' "$REPOSITORY" "$BRANCH" "$commit" >&2
    exit 1
fi

cat <<EOF_INFO
KYTY_TAG=${BRANCH}
KYTY_COMMIT=${commit}
EOF_INFO
