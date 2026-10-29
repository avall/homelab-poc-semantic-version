#!/usr/bin/env bash
# Fails when hotfix/X.Y.Z would not release X.Y.(Z+1)-hotfix.N; prints the reason.
# Usage: hotfix-guard.sh <branch> <next-version> <last-version>
set -euo pipefail

branch="$1" next="$2" last="$3"

if [[ -n "$next" && "$branch" =~ ^hotfix/([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  base="${branch#hotfix/}"
  expected="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))-hotfix."
  if [[ "$next" != "$expected"* ]]; then
    if [[ -n "$last" && "$last" != "$base" && "$last" != "$expected"* ]]; then
      echo "${branch} contains release ${last}: it was updated from master and can no longer be released as a hotfix of ${base}"
    else
      echo "${branch} only accepts patch-level changes (fix, perf, revert): computed ${next}, expected ${expected}N"
    fi
    exit 1
  fi
fi
