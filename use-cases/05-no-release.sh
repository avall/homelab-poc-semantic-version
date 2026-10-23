#!/usr/bin/env bash
# shellcheck source=use-cases/lib.sh
source "$(dirname "$0")/lib.sh"
parse_args "$@"

# Case 05: docs, chore, test and refactor change nothing at runtime: no tag.
TITLES=(
  "docs: CK-9051 describe the hello endpoint"
  "chore: CK-9052 tidy the playground folder"
  "test: CK-9053 add a test note for the hello endpoint"
  "refactor(hello): CK-9054 rename the greeting constant"
)
confirm_plan "  - 4 PRs to master, one per title, each squash merged:
$(printf "      %s\n" "${TITLES[@]}")
  - expect 4 release runs that log \"There are no relevant changes\" and no new tag (still 1.1.0)"
i=1
for t in "${TITLES[@]}"; do
  pr_flow master "CK-905$i-no-release-$i" "$t"
  i=$((i + 1))
done
show_result
