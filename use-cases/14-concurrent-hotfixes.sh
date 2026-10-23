#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 14: two hotfix PRs open at the same time on hotfix/1.0.0. Each merge releases the next hotfix.N, cumulative.
TITLE_A="fix: CK-9014 reject empty greeting on production 1.0.0"
TITLE_B="fix: CK-9015 trim greeting on production 1.0.0"
confirm_plan "  - run hotfix-start with base_tag=1.0.0 (reuses hotfix/1.0.0)
  - open PR \"$TITLE_A\" (CK-9014-hotfix) and PR \"$TITLE_B\" (CK-9015-hotfix) to hotfix/1.0.0, both from the same line commit
  - squash merge A: expect 1.0.1-hotfix.2; squash merge B: expect 1.0.1-hotfix.3 (contains hotfix.1, CK-9014 and CK-9015)
  - run hotfix-start with base_tag=1.0.1-hotfix.2: expect it to reuse hotfix/1.0.0 and print 1.0.1-hotfix.4
  (numbers assume case 11 released 1.0.1-hotfix.1)"
require_tag 1.0.0
hotfix_start 1.0.0
create_branch hotfix/1.0.0 CK-9014-hotfix
make_change CK-9014-hotfix "$TITLE_A"
commit_and_push "$TITLE_A"
PR_A=$(open_pr hotfix/1.0.0 "$TITLE_A")
cleanup_worktree
create_branch hotfix/1.0.0 CK-9015-hotfix
make_change CK-9015-hotfix "$TITLE_B"
commit_and_push "$TITLE_B"
PR_B=$(open_pr hotfix/1.0.0 "$TITLE_B")
cleanup_worktree
wait_checks "$PR_A"
wait_checks "$PR_B"
merge_pr "$PR_A"
wait_hotfix_release "$TITLE_A" || true
merge_pr "$PR_B"
wait_hotfix_release "$TITLE_B" || true
hotfix_start 1.0.1-hotfix.2
show_result
echo "Latest release (expect a master version, not a hotfix): $(latest_release)"
