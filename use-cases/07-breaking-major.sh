#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 07: "!" after the type/scope is the only breaking signal: MAJOR (1.1.0 -> 2.0.0).
TITLE="feat(api)!: CK-9007 remove the deprecated greeting parameter"
confirm_plan "  - PR \"$TITLE\" to master, squash merge
  - expect tag 2.0.0"
pr_flow master CK-9007-remove-greeting-param "$TITLE"
show_result
