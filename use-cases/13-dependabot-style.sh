#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 13: only dependabot[bot] may skip the Jira key. A person using a Dependabot-style title is rejected.
TITLE="build(deps): bump example-lib from 1.0.0 to 1.1.0"
confirm_plan "  - PR \"$TITLE\" to master opened by you (not dependabot[bot])
  - expect pr-title to FAIL (no Jira key); the PR is closed without merge
  - the positive case is a real Dependabot PR: its pr-title must pass"
create_branch master CK-9013-dependabot-style
make_change CK-9013-dependabot-style "$TITLE"
commit_and_push "$TITLE"
PR=$(open_pr master "$TITLE")
if wait_checks "$PR"; then echo "UNEXPECTED: checks passed"; else echo "Expected: pr-title failed for a non-Dependabot author"; fi
gh pr close "$PR" --repo "$REPO" --delete-branch
cleanup_worktree
echo "Open Dependabot PRs (their pr-title must pass):"
gh pr list --repo "$REPO" --author "app/dependabot" --json number,title --jq '.[] | "#\(.number) \(.title)"'
