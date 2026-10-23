#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 03: perf gives a PATCH (1.0.1 -> 1.0.2).
TITLE="perf(hello): CK-9003 cache the greeting response"
confirm_plan "  - PR \"$TITLE\" to master, squash merge
  - expect tag 1.0.2"
pr_flow master CK-9003-cache-greeting "$TITLE"
show_result
