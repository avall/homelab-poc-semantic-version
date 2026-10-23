#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 04: feat gives a MINOR (1.0.2 -> 1.1.0).
TITLE="feat(hello): CK-9004 add greeting language header"
confirm_plan "  - PR \"$TITLE\" to master, squash merge
  - expect tag 1.1.0"
pr_flow master CK-9004-greeting-language "$TITLE"
show_result
