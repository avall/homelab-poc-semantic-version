#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 06: invalid titles fail pr-title; fixing the title with gh pr edit makes it pass.
INVALID=(
  "CK-9006"
  "Feature: CK-9006 document the PR title rules"
  "feat add CK-9006 document the PR title rules"
  "docs: document the PR title rules"
)
VALID="docs: CK-9006 document the PR title rules"
confirm_plan "  - open a PR to master and walk it through invalid titles (pr-title must FAIL each time):
$(printf "      %s\n" "${INVALID[@]}")
  - rename it to \"$VALID\" (pr-title must PASS), squash merge
  - expect no release (docs), latest tag still 1.1.0"
create_branch master CK-9006-title-rules
make_change CK-9006-title-rules "$VALID"
commit_and_push "$VALID"
PR=$(open_pr master "${INVALID[0]}")
for t in "${INVALID[@]}"; do
  [[ "$t" == "${INVALID[0]}" ]] || gh pr edit "$PR" --repo "$REPO" --title "$t"
  if wait_title_check "$PR"; then echo "UNEXPECTED: \"$t\" passed"; exit 1; else echo "EXPECTED: \"$t\" rejected"; fi
done
gh pr edit "$PR" --repo "$REPO" --title "$VALID"
wait_title_check "$PR" && echo "EXPECTED: \"$VALID\" accepted"
wait_checks "$PR"
merge_pr "$PR"
wait_release "$(merge_sha "$PR")" || true
cleanup_worktree
show_result
