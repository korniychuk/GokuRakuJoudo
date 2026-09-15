#!/usr/bin/env bash
# Keep `ankor` (fork patches) rebased onto upstream master and decide whether to release.
# Runs inside a fork checkout whose origin pushes via a write deploy key.
# A release is due when upstream moved, when the `ankor` tip was never released (a failed
# release retries on the next run; a manual commit ships automatically), or FORCE_RELEASE=true.
# Outputs (GITHUB_OUTPUT): release=true|false, commit=<sha to build>, failure_reason=<text>.
set -euo pipefail

readonly UPSTREAM_URL='https://github.com/yqrashawn/GokuRakuJoudo.git'
readonly FORK_BRANCH='ankor'
readonly MIRROR_BRANCH='master'
readonly FORK_TAG_GLOB='v*-ankor.*'
readonly OUT="${GITHUB_OUTPUT:-/dev/stdout}"

fail() {
  printf '::error::%s\n' "$1" >&2
  printf 'failure_reason=%s\n' "$1" >> "$OUT"
  exit 1
}

git config user.name 'goku-fork-bot'
git config user.email 'goku-fork-bot@users.noreply.github.com'

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --tags upstream "$MIRROR_BRANCH" || fail "cannot fetch upstream ${UPSTREAM_URL}"
git fetch --tags origin "$MIRROR_BRANCH" "$FORK_BRANCH" || fail "cannot fetch origin"

upstream_sha="$(git rev-parse "upstream/${MIRROR_BRANCH}")"
mirror_sha="$(git rev-parse "origin/${MIRROR_BRANCH}")"
fork_sha="$(git rev-parse "origin/${FORK_BRANCH}")"

# Work on the fetched tip, not the checkout: a push that landed between checkout and fetch
# must be rebased, not silently overwritten under a lease that already names it.
git checkout -q -B "$FORK_BRANCH" "$fork_sha"

upstream_changed=false
if [[ "$upstream_sha" != "$mirror_sha" ]]; then
  if ! git merge-base --is-ancestor "$mirror_sha" "$upstream_sha"; then
    fail "upstream ${MIRROR_BRANCH} was rewritten (${mirror_sha} is not an ancestor of ${upstream_sha}) — manual review needed"
  fi
  printf 'upstream %s -> %s; rebasing %s (%s)\n' "$mirror_sha" "$upstream_sha" "$FORK_BRANCH" "$fork_sha"
  if ! git rebase "$upstream_sha"; then
    conflicted="$(git diff --name-only --diff-filter=U | tr '\n' ' ')"
    git rebase --abort
    fail "rebase of ${FORK_BRANCH} onto upstream ${upstream_sha} conflicts in: ${conflicted:-unknown files}"
  fi
  upstream_changed=true
fi

head_sha="$(git rev-parse HEAD)"
last_tag="$(git tag --list "$FORK_TAG_GLOB" --sort=-v:refname | head -n 1)"
last_tag_sha=''
[[ -n "$last_tag" ]] && last_tag_sha="$(git rev-list -n 1 "$last_tag")"

if [[ "$upstream_changed" == false && "$head_sha" == "$last_tag_sha" && "${FORCE_RELEASE:-false}" != true ]]; then
  printf 'upstream unchanged at %s; %s %s already released as %s — nothing to do\n' \
    "$upstream_sha" "$FORK_BRANCH" "$head_sha" "$last_tag"
  printf 'release=false\n' >> "$OUT"
  exit 0
fi

lein test || fail "lein test failed on ${FORK_BRANCH} ${head_sha} (upstream ${upstream_sha})"

if [[ "$upstream_changed" == true ]]; then
  # Atomic: the mirror and the rebased fork move together or not at all.
  git push --atomic \
    --force-with-lease="refs/heads/${FORK_BRANCH}:${fork_sha}" \
    origin \
    "${upstream_sha}:refs/heads/${MIRROR_BRANCH}" \
    "HEAD:refs/heads/${FORK_BRANCH}" \
    || fail "push to origin rejected (branch moved during sync?)"
  git push origin --tags || printf '::warning::pushing upstream tags to the fork failed\n'
fi

printf 'commit=%s\nrelease=true\n' "$head_sha" >> "$OUT"
