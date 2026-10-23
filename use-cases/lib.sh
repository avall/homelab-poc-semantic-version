#!/usr/bin/env bash
# Shared helpers for the use-case scripts. Source it; do not run it.
# Every script prints its plan and asks for confirmation unless --yes is passed.
set -euo pipefail

ASSUME_YES=false
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
WORK_ROOT="${WORK_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/semver-use-cases.XXXXXX")}"
REPO=""
WT=""

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --yes|-y) ASSUME_YES=true ;;
      -h|--help) echo "Usage: $0 [--yes]"; exit 0 ;;
      *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
  done
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
}

log() { printf '\n==> %s\n' "$*"; }

# Prints the plan and stops unless the user confirms.
confirm_plan() {
  printf 'Repository: %s\n\nThis use case will:\n%s\n\n' "$REPO" "$1"
  $ASSUME_YES && return 0
  local answer
  read -r -p "These are remote writes (push, PR, merge). Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
}

# Creates a worktree on a new branch from origin/<base> (or from a tag).
create_branch() {
  local base="$1" branch="$2" start
  git -C "$REPO_ROOT" fetch --quiet --tags origin
  if git -C "$REPO_ROOT" rev-parse --verify --quiet "origin/$base" >/dev/null; then start="origin/$base"; else start="$base"; fi
  WT="$WORK_ROOT/$branch"
  log "Branch $branch from $start"
  git -C "$REPO_ROOT" worktree add --quiet -B "$branch" "$WT" "$start"
}

# Appends one line to a playground file: a small real change for the PR.
make_change() {
  local name="$1" text="$2"
  mkdir -p "$WT/use-cases/playground"
  printf '%s %s\n' "$(date -u +%FT%TZ)" "$text" >> "$WT/use-cases/playground/$name.txt"
}

commit_and_push() {
  local message="$1" branch
  branch="$(git -C "$WT" branch --show-current)"
  git -C "$WT" add -A
  git -C "$WT" commit --quiet -m "$message"
  log "Push $branch"
  git -C "$WT" push --quiet -u origin "$branch"
}

# Opens a PR and prints its number. Extra args go to gh pr create (e.g. --label).
open_pr() {
  local base="$1" title="$2" branch url
  shift 2
  branch="$(git -C "$WT" branch --show-current)"
  url=$(gh pr create --repo "$REPO" --base "$base" --head "$branch" --title "$title" \
    --body "Use-case PR created by use-cases scripts. Fake Jira key." "$@")
  log "PR opened: $url" >&2
  basename "$url"
}

# Waits for the PR checks; returns non-zero when a check fails.
wait_checks() {
  local pr="$1"
  log "Waiting for checks on PR #$pr"
  sleep 15
  gh pr checks "$pr" --repo "$REPO" --watch --interval 10
}

# Waits for the pr-title run of the current title and returns its result.
wait_title_check() {
  local pr="$1" title run=""
  title="$(gh pr view "$pr" --repo "$REPO" --json title --jq .title)"
  log "Waiting for pr-title on: $title"
  for _ in $(seq 1 30); do
    run=$(gh run list --repo "$REPO" --workflow pr-title.yml --limit 10 --json databaseId,displayTitle \
      --jq "[.[] | select(.displayTitle == \"$title\")][0].databaseId // empty")
    [[ -n "$run" ]] && break
    sleep 5
  done
  [[ -n "$run" ]] || { echo "No pr-title run found for '$title'" >&2; return 1; }
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null
}

# Squash-merges a PR; an optional subject simulates an edit in the merge dialog.
# The branch ruleset requires branches to be up to date: update a PR that is behind its base and re-run its checks.
update_if_behind() {
  local pr="$1" state=""
  for _ in $(seq 1 10); do
    state=$(gh pr view "$pr" --repo "$REPO" --json mergeStateStatus --jq .mergeStateStatus)
    [[ "$state" != "UNKNOWN" ]] && break
    sleep 3
  done
  [[ "$state" == "BEHIND" ]] || return 0
  log "PR #$pr is behind its base: update branch and wait for checks"
  gh pr update-branch "$pr" --repo "$REPO"
  wait_checks "$pr"
}

merge_pr() {
  local pr="$1" subject="${2:-}"
  update_if_behind "$pr"
  log "Squash merge PR #$pr${subject:+ with edited subject: $subject}"
  if [[ -n "$subject" ]]; then
    gh pr merge "$pr" --repo "$REPO" --squash --subject "$subject"
  else
    gh pr merge "$pr" --repo "$REPO" --squash
  fi
}

merge_sha() {
  gh pr view "$1" --repo "$REPO" --json mergeCommit --jq .mergeCommit.oid
}

# Waits for the release workflow run of a commit; returns its exit status.
wait_release() {
  local sha="$1" run=""
  log "Waiting for the release workflow on $sha"
  for _ in $(seq 1 30); do
    run=$(gh run list --repo "$REPO" --workflow release.yml --commit "$sha" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    [[ -n "$run" ]] && break
    sleep 5
  done
  [[ -n "$run" ]] || { echo "No release run found for $sha" >&2; return 1; }
  local rc=0
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null || rc=$?
  gh run view "$run" --repo "$REPO" --log 2>/dev/null \
    | grep -E 'OK [0-9a-f]{40}|::error::|Published release|There are no relevant changes|IMAGE docker|DEPLOYMENT OF VERSION' \
    | grep -vE 'echo|msg=' || true
  echo "Run: $(gh run view "$run" --repo "$REPO" --json url --jq .url)"
  return "$rc"
}

# Stops unless the tag exists on origin (hotfix cases need 1.0.0 from case 01).
require_tag() {
  git -C "$REPO_ROOT" fetch --quiet --tags origin
  git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/tags/$1" >/dev/null || { echo "Tag $1 not found: run case 01 first" >&2; exit 1; }
}

# Prints the run log lines that match a pattern, without the script source lines.
show_log() {
  gh run view "$1" --repo "$REPO" --log 2>/dev/null | grep -E "$2" | grep -vE 'echo|\$|state=|re=' || true
  echo "Run: $(gh run view "$1" --repo "$REPO" --json url --jq .url)"
}

# Runs hotfix-start for a base tag and waits for it; returns its exit status.
hotfix_start() {
  local tag="$1" before run="" rc=0
  before=$(gh run list --repo "$REPO" --workflow hotfix-start.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0')
  log "Run hotfix-start with base_tag=$tag"
  gh workflow run hotfix-start.yml --repo "$REPO" --ref master -f base_tag="$tag"
  for _ in $(seq 1 30); do
    sleep 5
    run=$(gh run list --repo "$REPO" --workflow hotfix-start.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0')
    [[ "$run" != "$before" ]] && break
  done
  [[ "$run" != "$before" ]] || { echo "No new hotfix-start run" >&2; return 1; }
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null || rc=$?
  show_log "$run" 'Hotfix line|Created line|Reused existing line|Next version|::error::|hotfix-version:'
  return "$rc"
}

# Waits for the hotfix-release run of a merged PR (display title = PR title); returns its exit status.
wait_hotfix_release() {
  local title="$1" run="" rc=0
  log "Waiting for hotfix-release on: $title"
  for _ in $(seq 1 30); do
    run=$(gh run list --repo "$REPO" --workflow hotfix-release.yml --limit 20 --json databaseId,displayTitle \
      --jq "[.[] | select(.displayTitle == \"$title\")][0].databaseId // empty")
    [[ -n "$run" ]] && break
    sleep 5
  done
  [[ -n "$run" ]] || { echo "No hotfix-release run found for '$title'" >&2; return 1; }
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null || rc=$?
  show_log "$run" 'Hotfix version|IMAGE docker|::error::|https://github.com/.*/releases/tag/'
  return "$rc"
}

latest_release() {
  gh release view --repo "$REPO" --json tagName --jq .tagName
}

show_result() {
  log "Latest releases and tags"
  gh release list --repo "$REPO" --limit 5
  git -C "$REPO_ROOT" fetch --quiet --tags origin
  git -C "$REPO_ROOT" tag --sort=-v:refname | head -5
}

# Full flow: branch, change, push, PR, checks, squash merge, release run.
pr_flow() {
  local base="$1" branch="$2" title="$3" pr
  create_branch "$base" "$branch"
  make_change "$branch" "$title"
  commit_and_push "$title"
  pr=$(open_pr "$base" "$title")
  wait_checks "$pr"
  merge_pr "$pr"
  wait_release "$(merge_sha "$pr")" || true
  cleanup_worktree
}

cleanup_worktree() {
  [[ -n "$WT" && -d "$WT" ]] && git -C "$REPO_ROOT" worktree remove --force "$WT"
  WT=""
}
