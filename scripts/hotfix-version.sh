#!/usr/bin/env bash
# Hotfix line versions. Pure: no git, no network.
#   hotfix-version.sh line <tag>   X.Y.Z or X.Y.Z-hotfix.N (Z>=1) -> base production tag of the line
#   hotfix-version.sh next <base>  existing tags on stdin -> X.Y.(Z+1)-hotfix.(max N + 1)
set -euo pipefail

NUM='(0|[1-9][0-9]*)'
die() { echo "hotfix-version: $*" >&2; exit 1; }

line() {
  local tag="$1"
  if [[ "$tag" =~ ^$NUM\.$NUM\.$NUM$ ]]; then
    echo "$tag"
  elif [[ "$tag" =~ ^$NUM\.$NUM\.([1-9][0-9]*)-hotfix\.([1-9][0-9]*)$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] - 1))"
  else
    die "'$tag' is not a production tag X.Y.Z or a hotfix tag X.Y.Z-hotfix.N (Z>=1)"
  fi
}

next() {
  local base="$1" major minor patch prefix tag n max=0
  [[ "$base" =~ ^$NUM\.$NUM\.$NUM$ ]] || die "'$base' is not a production tag X.Y.Z"
  major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"
  prefix="$major.$minor.$((patch + 1))-hotfix."
  while IFS= read -r tag; do
    [[ "$tag" == "$prefix"* ]] || continue
    n="${tag#"$prefix"}"
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || continue
    if (( n > max )); then max=$n; fi
  done
  echo "$prefix$((max + 1))"
}

case "${1:-}" in
  line) [[ $# -eq 2 ]] || die "usage: $0 line <tag>"; line "$2" ;;
  next) [[ $# -eq 2 ]] || die "usage: $0 next <base> < tags"; next "$2" ;;
  *) die "usage: $0 line <tag> | next <base> < tags" ;;
esac
