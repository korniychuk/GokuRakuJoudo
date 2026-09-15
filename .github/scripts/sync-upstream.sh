#!/usr/bin/env bash
# Mirror upstream master into origin/master and rebase `ankor` (fork patches) onto it.
# Runs inside a checkout of `ankor` whose origin pushes via a write deploy key.
# Env: FORCE_RELEASE=true runs the full path even when upstream is unchanged.
# Outputs (GITHUB_OUTPUT): release=true|false, failure_reason=<text> on failure.
set -euo pipefail

readonly UPSTREAM_URL='https://github.com/yqrashawn/GokuRakuJoudo.git'
readonly FORK_BRANCH='ankor'
readonly MIRROR_BRANCH='master'
readonly OUT="${GITHUB_OUTPUT:-/dev/stdout}"

fail() {
  echo "::error::$1" >&2
  echo "failure_reason=$1" >> "$OUT"
  exit 1
}

git config user.name 'goku-fork-bot'
git config user.email 'goku-fork-bot@users.noreply.github.com'

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --tags upstream "$MIRROR_BRANCH" || fail "cannot fetch upstream ${UPSTREAM_URL}"
git fetch origin "$MIRROR_BRANCH" "$FORK_BRANCH" || fail "cannot fetch origin"

upstream_sha="$(git rev-parse "upstream/${MIRROR_BRANCH}")"
mirror_sha="$(git rev-parse "origin/${MIRROR_BRANCH}")"
fork_sha="$(git rev-parse "origin/${FORK_BRANCH}")"

if [[ "$upstream_sha" == "$mirror_sha" && "${FORCE_RELEASE:-false}" != "true" ]]; then
  echo "upstream unchanged at ${upstream_sha} — nothing to do"
  echo "release=false" >> "$OUT"
  exit 0
fi

if ! git merge-base --is-ancestor "$mirror_sha" "$upstream_sha"; then
  fail "upstream ${MIRROR_BRANCH} was rewritten (${mirror_sha} is not an ancestor of ${upstream_sha}) — manual review needed"
fi

echo "upstream ${mirror_sha} -> ${upstream_sha}; rebasing ${FORK_BRANCH} (${fork_sha})"
if ! git rebase "$upstream_sha"; then
  conflicted="$(git diff --name-only --diff-filter=U | tr '\n' ' ')"
  git rebase --abort
  fail "rebase of ${FORK_BRANCH} onto upstream ${upstream_sha} conflicts in: ${conflicted:-unknown files}"
fi

lein test || fail "lein test failed on ${FORK_BRANCH} rebased onto upstream ${upstream_sha}"

# Atomic: the mirror and the rebased fork move together or not at all.
git push --atomic \
  --force-with-lease="refs/heads/${FORK_BRANCH}:${fork_sha}" \
  origin \
  "${upstream_sha}:refs/heads/${MIRROR_BRANCH}" \
  "HEAD:refs/heads/${FORK_BRANCH}" \
  || fail "push to origin rejected (branch moved during sync?)"

# Upstream release tags drive the fork version base (next-version.sh).
git push origin --tags || echo "::warning::pushing upstream tags failed — version base may lag"

echo "release=true" >> "$OUT"
