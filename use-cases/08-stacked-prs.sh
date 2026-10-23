#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 08: a gh stack of 2 PRs (fix + feat) merged atomically with squash: one push, one release, highest bump wins.
TITLE_A="fix: CK-9008 trim whitespace in the greeting"
TITLE_B="feat: CK-9008 add greeting name parameter"
confirm_plan "  - gh stack init --base master CK-9008-a-trim, commit \"$TITLE_A\"
  - gh stack add CK-9008-b-name, commit \"$TITLE_B\"
  - gh stack submit --auto --open, set both PR titles, wait for checks
  - gh stack merge --yes --squash (atomic stack merge)
  - expect two squash commits in ONE push, guard OK for both, ONE release 2.1.0 (feat wins over fix)"
git -C "$REPO_ROOT" fetch --quiet origin
WT="$WORK_ROOT/CK-9008-stack"
git -C "$REPO_ROOT" worktree add --quiet --detach "$WT" origin/master
cd "$WT"
gh stack init --base master CK-9008-a-trim
make_change CK-9008-a-trim "$TITLE_A"
git add -A && git commit --quiet -m "$TITLE_A"
gh stack add CK-9008-b-name
make_change CK-9008-b-name "$TITLE_B"
git add -A && git commit --quiet -m "$TITLE_B"
gh stack submit --auto --open
PR_A=$(gh pr view CK-9008-a-trim --repo "$REPO" --json number --jq .number)
PR_B=$(gh pr view CK-9008-b-name --repo "$REPO" --json number --jq .number)
gh pr edit "$PR_A" --repo "$REPO" --title "$TITLE_A"
gh pr edit "$PR_B" --repo "$REPO" --title "$TITLE_B"
wait_checks "$PR_A"
wait_checks "$PR_B"
gh stack merge --yes --squash
SHA_B=$(merge_sha "$PR_B")
cd "$REPO_ROOT"
wait_release "$SHA_B" || true
echo "Release runs for the two merge commits (expect exactly one run covering both):"
gh run list --repo "$REPO" --workflow release.yml --limit 3
cleanup_worktree
show_result
