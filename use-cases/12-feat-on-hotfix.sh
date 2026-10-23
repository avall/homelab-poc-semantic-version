#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 12: a feat PR into a hotfix line fails pr-title, so it cannot be merged and nothing is released.
TITLE="feat: CK-9012 add a feature on the 1.0.0 hotfix line"
confirm_plan "  - run hotfix-start with base_tag=1.0.0 (reuses hotfix/1.0.0)
  - PR \"$TITLE\" from CK-9012-feat-on-hotfix to hotfix/1.0.0
  - expect pr-title to FAIL (hotfix lines accept only fix, perf, revert) and the PR to be BLOCKED; no merge, no tag
  - close the PR and delete its branch"
require_tag 1.0.0
hotfix_start 1.0.0
create_branch hotfix/1.0.0 CK-9012-feat-on-hotfix
make_change CK-9012-feat-on-hotfix "$TITLE"
commit_and_push "$TITLE"
PR=$(open_pr hotfix/1.0.0 "$TITLE")
if wait_title_check "$PR"; then echo "UNEXPECTED: pr-title passed"; else echo "pr-title failed as expected"; fi
sleep 10
echo "Merge state (expect BLOCKED): $(gh pr view "$PR" --repo "$REPO" --json mergeStateStatus --jq .mergeStateStatus)"
log "Close PR #$PR without merge"
gh pr close "$PR" --repo "$REPO" --delete-branch
cleanup_worktree
show_result
