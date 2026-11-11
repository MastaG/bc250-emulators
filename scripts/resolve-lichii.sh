#!/usr/bin/env bash
# Resolve which Lichii release lichii-bc250 builds.
#
# Upstream's CI tags every successful nx2 build as build-<n> and publishes it
# as a GitHub release; the newest non-prerelease release is the newest build
# upstream itself put out as usable. Plain tags and prereleases are skipped:
# a tag can exist before its release builds have finished or after they failed.
#
# Prints an env file: the tag, its build number (the package version) and the
# full commit. Set LICHII_TAG to build a specific release instead.
set -Eeuo pipefail

REPOSITORY="zortos293/lichii"
TAG="${LICHII_TAG:-}"

# As in resolve-kytyps5-native.sh: plain curl, and a transient failure must not
# resolve to something else -- the build cache keys on the commit -- so retry,
# then give up loudly.
attempts=5
retry() {
    local what="$1" out attempt
    shift
    for attempt in $(seq 1 "$attempts"); do
        if out="$("$@" 2>&1)"; then
            printf '%s\n' "$out"
            return 0
        fi
        printf 'WARN: could not query %s (attempt %d/%d): %s\n' \
            "$what" "$attempt" "$attempts" "${out%%$'\n'*}" >&2
        if (( attempt < attempts )); then sleep $(( attempt * 5 )); fi
    done
    printf 'ERROR: gave up querying %s after %d attempts\n' "$what" "$attempts" >&2
    return 1
}

if [[ -z "$TAG" ]]; then
    auth=()
    token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    [[ -z "$token" ]] || auth=(-H "Authorization: Bearer $token")
    TAG="$(retry "the latest release" curl -fsSL "${auth[@]}" \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/${REPOSITORY}/releases/latest" |
        sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
fi

# Upstream tags look like build-130. Anything else means its release scheme
# changed; stop rather than guess.
if [[ ! "$TAG" =~ ^build-([0-9]+)$ ]]; then
    printf 'ERROR: unexpected Lichii tag: %s\n' "$TAG" >&2
    exit 1
fi
build="${BASH_REMATCH[1]}"

refs="$(retry "the tag ${TAG}" git ls-remote "https://github.com/${REPOSITORY}.git" \
    "refs/tags/${TAG}" "refs/tags/${TAG}^{}")"
commit="$(awk '$2 ~ /\^\{\}$/ { print $1 }' <<<"$refs")"
[[ -n "$commit" ]] || commit="$(awk 'NR == 1 { print $1 }' <<<"$refs")"

if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'ERROR: tag %s resolved to %q, not a commit\n' "$TAG" "$commit" >&2
    exit 1
fi

cat <<EOF_INFO
LICHII_TAG=${TAG}
LICHII_BUILD=${build}
LICHII_COMMIT=${commit}
EOF_INFO
