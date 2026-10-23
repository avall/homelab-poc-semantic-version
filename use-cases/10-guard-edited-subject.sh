#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 10: the merge subject is edited in the merge dialog: the guard fails the release, no tag. Recovery: fix forward.
TITLE="fix: CK-9010 handle empty greeting"
EDITED="fix: CK-9010 edited in the merge dialog"
FORWARD="fix: CK-9010 fix forward after edited merge subject"
confirm_plan "  - PR \"$TITLE\" to master, merged with --subject \"$EDITED\"
  - expect the release run to FAIL at the guard (commit message differs from its PR title), no tag
  - fix forward: PR \"$FORWARD\", squash merge
  - expect tag 2.1.2 (its notes include both fixes)"
create_branch master CK-9010-empty-greeting
make_change CK-9010-empty-greeting "$TITLE"
commit_and_push "$TITLE"
PR=$(open_pr master "$TITLE")
wait_checks "$PR"
merge_pr "$PR" "$EDITED"
if wait_release "$(merge_sha "$PR")"; then echo "UNEXPECTED: release passed"; else echo "EXPECTED: guard failed, no release"; fi
cleanup_worktree
show_result
pr_flow master CK-9010-fix-forward "$FORWARD"
show_result
