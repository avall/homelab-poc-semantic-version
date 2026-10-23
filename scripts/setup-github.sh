#!/usr/bin/env bash
# One-time GitHub setup for the semantic-release POC (proposal §6). Idempotent; asks before every change.
# Usage: scripts/setup-github.sh [owner/name] [--yes]
set -euo pipefail

REPO=""
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=true ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) REPO="$arg" ;;
  esac
done
REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
DEFAULT_BRANCH="master"

info() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

confirm() {
  printf '%s\n' "$1"
  $ASSUME_YES && return 0
  local answer
  read -r -p "Apply? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Runs a gh api write and reports HTTP errors without aborting the script.
api_write() {
  local out
  if out=$(gh api "$@" 2>&1); then
    echo "OK"
  else
    warn "request failed: gh api $1 $2"
    warn "$out"
    if [[ "$out" == *"Upgrade to GitHub Pro"* || "$out" == *"HTTP 403"* ]]; then
      warn "This feature is not available for this repository/plan (rulesets need a public repo, GitHub Pro, Team or Enterprise)."
    fi
    return 1
  fi
}

rename_default_branch() {
  info "Default branch"
  local current
  current=$(gh api "repos/$REPO" --jq .default_branch)
  if [[ "$current" == "$DEFAULT_BRANCH" ]]; then
    echo "Already '$DEFAULT_BRANCH'."
    return
  fi
  confirm "Rename default branch '$current' -> '$DEFAULT_BRANCH' (POST repos/$REPO/branches/$current/rename)" || return 0
  api_write -X POST "repos/$REPO/branches/$current/rename" -f new_name="$DEFAULT_BRANCH" || return 0
  echo "Local clones: git branch -m $current $DEFAULT_BRANCH && git fetch origin && git branch -u origin/$DEFAULT_BRANCH $DEFAULT_BRANCH && git remote set-head origin -a"
}

configure_merges() {
  info "Merge settings"
  local wanted='{"allow_squash_merge":true,"allow_merge_commit":false,"allow_rebase_merge":false,"squash_merge_commit_title":"PR_TITLE","squash_merge_commit_message":"BLANK","delete_branch_on_merge":true}'
  local current
  current=$(gh api "repos/$REPO" --jq '{allow_squash_merge,allow_merge_commit,allow_rebase_merge,squash_merge_commit_title,squash_merge_commit_message,delete_branch_on_merge}' | jq -cS .)
  if [[ "$current" == "$(jq -cS . <<<"$wanted")" ]]; then
    echo "Already configured: $current"
    return
  fi
  confirm "PATCH repos/$REPO with $wanted (current: $current)" || return 0
  api_write -X PATCH "repos/$REPO" --input - <<<"$wanted" || true
}

# Creates the ruleset by name, or updates it in place when it already exists.
upsert_ruleset() {
  local name="$1" payload="$2" existing
  if ! existing=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>&1); then
    warn "Cannot list rulesets: $existing"
    warn "Rulesets are not available here (private repo on a free plan?). Make the repo public or upgrade, then re-run."
    return 0
  fi
  if [[ -n "$existing" ]]; then
    confirm "Update ruleset '$name' (id $existing): $(jq -c . <<<"$payload")" || return 0
    api_write -X PUT "repos/$REPO/rulesets/$existing" --input - <<<"$payload" || true
  else
    confirm "Create ruleset '$name': $(jq -c . <<<"$payload")" || return 0
    api_write -X POST "repos/$REPO/rulesets" --input - <<<"$payload" || true
  fi
}

branch_ruleset() {
  info "Branch ruleset (master and hotfix lines hotfix/*, never deleted)"
  upsert_ruleset "release-branches" "$(cat <<'JSON'
{
  "name": "release-branches",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH", "refs/heads/hotfix/*"], "exclude": [] } },
  "rules": [
    { "type": "pull_request", "parameters": {
        "allowed_merge_methods": ["squash"],
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": 0,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": true,
        "required_status_checks": [ { "context": "build" }, { "context": "pr-title" } ] } },
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ]
}
JSON
)"
}

# Bypass: actor 15368 is the GitHub Actions app (GITHUB_TOKEN), role 5 is repository admin.
# Limitation: the admin bypass also lets a human admin push tags; only an org-owned GitHub App token would be stricter.
tag_ruleset() {
  info "Tag ruleset (X.Y.Z and X.Y.Z-hotfix.N tags only created by the release workflows)"
  upsert_ruleset "release-tags" "$(cat <<'JSON'
{
  "name": "release-tags",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_id": 15368, "actor_type": "Integration", "bypass_mode": "always" },
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "conditions": { "ref_name": { "include": ["refs/tags/*.*.*"], "exclude": [] } },
  "rules": [
    { "type": "creation" },
    { "type": "update", "parameters": { "update_allows_fetch_and_merge": false } },
    { "type": "deletion" }
  ]
}
JSON
)"
}

immutable_releases() {
  info "Immutable releases"
  local state
  if ! state=$(gh api "repos/$REPO/immutable-releases" --jq .enabled 2>&1); then
    warn "Cannot read the setting ($state). Enable it manually: Settings > General > Releases > Enable release immutability."
    return 0
  fi
  if [[ "$state" == "true" ]]; then
    echo "Already enabled."
    return
  fi
  confirm "Enable immutable releases (PUT repos/$REPO/immutable-releases)" || return 0
  api_write -X PUT "repos/$REPO/immutable-releases" \
    || warn "Enable it manually: Settings > General > Releases > Enable release immutability."
}

command -v gh >/dev/null || { echo "gh CLI is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
echo "Repository: $REPO"
rename_default_branch
configure_merges
branch_ruleset
tag_ruleset
immutable_releases
info "Done. Review: gh api repos/$REPO/rulesets ; gh repo view $REPO --web"
