#!/usr/bin/env bash
# Writes ./.releaserc.json from origin/master's .github/release/releaserc.json.
# hotfix/X.Y.Z branches are added as a `hotfix` prerelease branch for their own runs only.
# Prints `true` for a hotfix branch, `false` otherwise.
# Usage: prepare-releaserc.sh <branch>
set -euo pipefail

branch="$1"
base_config="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/releaserc.json"

git show origin/master:.github/release/releaserc.json > "$base_config"
if [[ "$branch" =~ ^hotfix/[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  jq --arg b "$branch" '.branches = ["master", {"name": $b, "prerelease": "hotfix"}]' \
    "$base_config" > .releaserc.json
  echo true
else
  cp "$base_config" .releaserc.json
  echo false
fi
