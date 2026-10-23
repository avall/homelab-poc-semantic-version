#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 02: fix gives a PATCH (1.0.0 -> 1.0.1).
TITLE="fix: CK-9002 return plain text content type"
confirm_plan "  - PR \"$TITLE\" to master, squash merge
  - expect tag 1.0.1"
pr_flow master CK-9002-plain-text-fix "$TITLE"
show_result
