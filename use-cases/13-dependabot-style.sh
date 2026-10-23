#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 13: a Dependabot-style PR (label dependencies, no Jira key): pr-title skips validation, build(deps) gives no release.
TITLE="build(deps): bump example-lib from 1.0.0 to 1.1.0"
confirm_plan "  - create label dependencies if missing
  - PR \"$TITLE\" to master with label dependencies, squash merge
  - expect pr-title to pass (validation skipped by ignoreLabels) and no release"
gh label create dependencies --repo "$REPO" --color 0366d6 --description "Dependency updates" --force
create_branch master CK-9013-dependabot-style
make_change CK-9013-dependabot-style "$TITLE"
commit_and_push "$TITLE"
PR=$(open_pr master "$TITLE" --label dependencies)
wait_checks "$PR"
merge_pr "$PR"
wait_release "$(merge_sha "$PR")" || true
cleanup_worktree
show_result
