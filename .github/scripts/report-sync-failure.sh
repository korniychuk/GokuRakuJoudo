#!/usr/bin/env bash
# Open (or comment on) the single open `upstream-sync` issue after a failed sync.
# Env: GH_TOKEN, REASON (may be empty if the job died before sync-upstream.sh reported).
set -euo pipefail

readonly LABEL='upstream-sync'
readonly RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

body="Upstream sync failed: ${REASON:-job failed before the sync script reported a reason}.

Run: ${RUN_URL}

Resolve locally: fetch upstream, rebase \`ankor\` onto \`upstream/master\`, run \`lein test\`, push, then re-run the workflow."

gh label create "$LABEL" --repo "$GITHUB_REPOSITORY" --color B60205 \
  --description 'Automatic upstream sync needs attention' --force >/dev/null

existing="$(gh issue list --repo "$GITHUB_REPOSITORY" --label "$LABEL" --state open \
  --json number --jq '.[0].number // empty')"

if [[ -n "$existing" ]]; then
  gh issue comment "$existing" --repo "$GITHUB_REPOSITORY" --body "$body"
  exit 0
fi
gh issue create --repo "$GITHUB_REPOSITORY" --label "$LABEL" \
  --title 'Upstream sync needs attention' --body "$body"
