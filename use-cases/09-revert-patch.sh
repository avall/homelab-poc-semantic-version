#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 09: revert gives a PATCH (2.1.0 -> 2.1.1). Rename GitHub "Revert \"...\"" titles to this form.
TITLE="revert: CK-9009 restore whitespace in the greeting"
confirm_plan "  - PR \"$TITLE\" to master, squash merge
  - expect tag 2.1.1"
pr_flow master CK-9009-revert-trim "$TITLE"
show_result
