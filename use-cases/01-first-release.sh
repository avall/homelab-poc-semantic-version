#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 01: first release. No tags yet, so semantic-release publishes 1.0.0.
TITLE="feat: CK-9001 add hello endpoint"
confirm_plan "  - branch CK-9001-add-hello-endpoint from master, small change, PR titled \"$TITLE\"
  - wait for build + pr-title, squash merge
  - expect tag 1.0.0, GitHub Release 1.0.0, simulated image and deploy of 1.0.0"
pr_flow master CK-9001-add-hello-endpoint "$TITLE"
show_result
