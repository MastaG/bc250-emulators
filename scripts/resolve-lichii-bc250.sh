#!/usr/bin/env bash
# Resolve which commit of the BC-250 Lichii fork lichii-bc250 builds.
#
# The fork (lethevimlet/lichii-bc250) publishes no releases or tags: the
# newest commit of its main branch is what its own installer builds.
#
# Prints an env file with the full commit. Set LICHII_BC250_COMMIT to build a
# specific commit instead.
set -Eeuo pipefail

REPOSITORY="lethevimlet/lichii-bc250"
BRANCH="main"

if [[ -n "${LICHII_BC250_COMMIT:-}" ]]; then
    commit="$LICHII_BC250_COMMIT"
else
    # As in resolve-lichii.sh: a transient failure must not resolve to
    # something else -- the build cache keys on the commit -- so retry, then
    # give up loudly.
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
LICHII_BC250_COMMIT=${commit}
EOF_INFO
