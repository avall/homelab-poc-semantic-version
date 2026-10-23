#!/usr/bin/env bash
# Checks a squash commit message (stdin) against "<PR title> (#<number>)".
# The body may only hold the trailers GitHub adds even with a BLANK message (Co-authored-by, Signed-off-by).
# Usage: git log -1 --format=%B <sha> | check-commit-message.sh "<PR title> (#<number>)"
set -euo pipefail

expected="${1:?expected subject required}"
mapfile -t lines < <(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')   # drop trailing blank lines

if [[ ${#lines[@]} -eq 0 || "${lines[0]}" != "$expected" ]]; then
  echo "subject differs from its PR title. Expected: $expected. Got: ${lines[0]:-<empty>}"
  exit 1
fi
[[ ${#lines[@]} -eq 1 ]] && exit 0
if [[ -n "${lines[1]}" ]]; then
  echo "line 2 must be blank before the trailers. Got: ${lines[1]}"
  exit 1
fi
for line in "${lines[@]:2}"; do
  [[ "$line" =~ ^(Co-authored-by|Signed-off-by):\ .+$ ]] && continue
  echo "body may only contain Co-authored-by or Signed-off-by trailers. Got: $line"
  exit 1
done
