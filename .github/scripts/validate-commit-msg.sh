#!/usr/bin/env bash
# Validates a commit message: <type>(CK-<number>)[!]: <subject>
# Usage: validate-commit-msg.sh <message-file>   or   ... | validate-commit-msg.sh
set -euo pipefail

pattern='^(feat|fix|perf|refactor|docs|test|build|ci|chore|revert)\(CK-[0-9]+\)!?: .+'

if [[ $# -gt 0 ]]; then
  message="$(<"$1")"
else
  message="$(cat)"
fi

first_line=""
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == \#* ]] && continue
  first_line="$line"
  break
done <<< "$message"

if [[ "$first_line" =~ ^(Merge\ |fixup!\ |squash!\ |amend!\ |chore\(release\):\ ) ]]; then
  exit 0
fi

if [[ "$first_line" =~ $pattern ]]; then
  exit 0
fi

cat >&2 <<EOF
Invalid commit message: "${first_line}"

Expected: <type>(CK-<number>)[!]: <subject>
Types:    feat fix perf refactor docs test build ci chore revert

Examples:
  feat(CK-123): add hello endpoint
  fix(CK-45): handle empty name
  feat(CK-7)!: remove v1 API
EOF
exit 1
