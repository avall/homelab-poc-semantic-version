#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 15: snapshot simulation. Each push to PR CK-9016 prints the deploy of 0.0.0-CK-9016-SNAPSHOT; closing it prints the delete.
BRANCH="CK-9016-snapshot"
TITLE="test: CK-9016 snapshot simulation"
confirm_plan "  - PR \"$TITLE\" from $BRANCH to master: snapshot run 1 prints the deploy of 0.0.0-CK-9016-SNAPSHOT
  - push a second commit: snapshot run 2 prints the same version again
  - close the PR without merge: snapshot run 3 prints DELETE 0.0.0-CK-9016-SNAPSHOT; no tag"

# Waits until the branch has <count> snapshot runs, then watches the newest one and prints its simulated lines.
wait_snapshot_run() {
  local count="$1" run=""
  log "Waiting for snapshot run $count on $BRANCH"
  for _ in $(seq 1 30); do
    if [[ "$(gh run list --repo "$REPO" --workflow snapshot.yml --branch "$BRANCH" --limit 10 --json databaseId --jq length)" -ge "$count" ]]; then
      run=$(gh run list --repo "$REPO" --workflow snapshot.yml --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
      break
    fi
    sleep 5
  done
  [[ -n "$run" ]] || { echo "No snapshot run $count for $BRANCH" >&2; return 1; }
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null || true
  show_log "$run" '\[simulated\]|No Docker image|snapshot-version:'
}

create_branch master "$BRANCH"
make_change "$BRANCH" "$TITLE"
commit_and_push "$TITLE"
PR=$(open_pr master "$TITLE")
wait_snapshot_run 1
make_change "$BRANCH" "$TITLE (second push)"
commit_and_push "$TITLE (second push)"
wait_snapshot_run 2
log "Close PR #$PR without merge"
gh pr close "$PR" --repo "$REPO" --delete-branch
wait_snapshot_run 3
cleanup_worktree
show_result
