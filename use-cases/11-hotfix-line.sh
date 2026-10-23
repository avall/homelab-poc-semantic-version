#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 11: production runs 1.0.0 while master is at 2.x. Fix it on the hotfix line hotfix/1.0.0, then port the fix to master.
HOTFIX="fix: CK-9011 handle null greeting on production 1.0.0"
PORT="fix: CK-9011 port null greeting hotfix from hotfix/1.0.0"
confirm_plan "  - run hotfix-start with base_tag=1.0.0: creates hotfix/1.0.0 from tag 1.0.0 (or reuses it), prints 1.0.1-hotfix.1
  - PR \"$HOTFIX\" from CK-9011-hotfix to hotfix/1.0.0, squash merge: expect tag 1.0.1-hotfix.1, Latest release unchanged
  - branch CK-9011-port from master, cherry-pick the hotfix commit, PR \"$PORT\" to master: expect the next master patch (2.1.3 in order)"
require_tag 1.0.0
hotfix_start 1.0.0
LATEST_BEFORE=$(latest_release)
create_branch hotfix/1.0.0 CK-9011-hotfix
make_change CK-9011-hotfix "$HOTFIX"
commit_and_push "$HOTFIX"
PR=$(open_pr hotfix/1.0.0 "$HOTFIX")
wait_checks "$PR"
merge_pr "$PR"
HOTFIX_SHA=$(merge_sha "$PR")
wait_hotfix_release "$HOTFIX" || true
cleanup_worktree
echo "Latest release before: $LATEST_BEFORE, after the hotfix: $(latest_release) (expect unchanged)"
create_branch master CK-9011-port
git -C "$WT" fetch --quiet origin
git -C "$WT" cherry-pick "$HOTFIX_SHA"
log "Push CK-9011-port"
git -C "$WT" push --quiet -u origin CK-9011-port
PR=$(open_pr master "$PORT")
wait_checks "$PR"
merge_pr "$PR"
wait_release "$(merge_sha "$PR")" || true
cleanup_worktree
show_result
echo "Latest release: $(latest_release)"
