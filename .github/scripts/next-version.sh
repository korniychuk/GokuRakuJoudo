#!/usr/bin/env bash
# Print the next fork release version as GITHUB_OUTPUT lines:
#   commit=<sha>  base=v0.8.0  tag=v0.8.0-ankor.3  formula_version=0.8.0.3
# base = newest upstream tag (vX.Y.Z, fork tags excluded); N = last -ankor.N for that base + 1.
# Homebrew gets a purely numeric version so `brew upgrade` orders releases correctly.
set -euo pipefail

readonly FORK_SUFFIX='-ankor.'

base="$(git tag --list 'v[0-9]*' --sort=-v:refname | grep -v -- "$FORK_SUFFIX" | head -n 1 || true)"
if [[ -z "$base" ]]; then
  echo "::error::no upstream vX.Y.Z tag found — fetch tags before computing the version" >&2
  exit 1
fi

last_n="$(git tag --list "${base}${FORK_SUFFIX}*" | sed "s/^${base}${FORK_SUFFIX}//" | sort -n | tail -n 1)"
next_n=$(( ${last_n:-0} + 1 ))

echo "commit=$(git rev-parse HEAD)"
echo "base=${base}"
echo "tag=${base}${FORK_SUFFIX}${next_n}"
echo "formula_version=${base#v}.${next_n}"
