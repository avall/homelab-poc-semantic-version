#!/usr/bin/env bash
# Snapshot version of a PR branch: CK-1234-some-desc -> 0.0.0-CK-1234-SNAPSHOT. Pure: no git, no network.
# Usage: snapshot-version.sh <head_ref>
set -euo pipefail

ref="${1:-}"
if [[ "$ref" =~ ^(CK-[0-9]+)(-.*)?$ ]]; then
  echo "0.0.0-${BASH_REMATCH[1]}-SNAPSHOT"
else
  echo "snapshot-version: branch '$ref' does not start with a Jira key (CK-1234-description)" >&2
  exit 1
fi
