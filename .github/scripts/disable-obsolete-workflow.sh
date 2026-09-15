#!/usr/bin/env bash
# Keep upstream's broken build-and-release.yaml (on: push) off: it still lives on the mirror
# `master` and on upstream tags, so a push can register and start it. No-op until GitHub has
# registered it. Env: GH_TOKEN with actions:write, GITHUB_REPOSITORY.
set -euo pipefail

readonly OBSOLETE='build-and-release.yaml'

state="$(gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/${OBSOLETE}" --jq .state 2>/dev/null || true)"
[[ "$state" == active ]] || exit 0

gh workflow disable "$OBSOLETE" --repo "$GITHUB_REPOSITORY"
gh run list --repo "$GITHUB_REPOSITORY" --workflow "$OBSOLETE" --status queued \
  --json databaseId --jq '.[].databaseId' \
  | xargs -r -n 1 gh run cancel --repo "$GITHUB_REPOSITORY"
printf '::warning::disabled upstream %s (it was registered as active)\n' "$OBSOLETE"
