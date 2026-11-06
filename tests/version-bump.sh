#!/usr/bin/env bash
# Layer 1 version tests: runs the real release config and scripts with semantic-release in a throwaway repository
# whose origin is a local bare repository. Nothing reaches GitHub: no branches, PRs, tags or releases.
# Usage: bash tests/version-bump.sh [--keep]   (--keep leaves the work directory for inspection)
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SEMANTIC_RELEASE=semantic-release@25.0.9
PRESET=conventional-changelog-conventionalcommits@9.3.1
KEEP=false
[[ "${1:-}" == "--keep" ]] && KEEP=true

WORK=$(mktemp -d "${TMPDIR:-/tmp}/version-bump.XXXXXX")
cleanup() { if $KEEP; then echo "Work directory kept: $WORK"; else rm -rf "$WORK"; fi; }
trap cleanup EXIT

# No credentials, no CI context and no user git config: nothing can authenticate against GitHub
unset GITHUB_TOKEN GH_TOKEN GITHUB_ACTIONS GITHUB_REPOSITORY GITHUB_REF GITHUB_EVENT_NAME CI
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$WORK/gitconfig" RUNNER_TEMP="$WORK"
git config --file "$GIT_CONFIG_GLOBAL" user.name "version-bump-test"
git config --file "$GIT_CONFIG_GLOBAL" user.email "version-bump-test@example.invalid"
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch master

PASSED=0 FAILED=0
REPO="" REMOTE=""

g() { git -C "$REPO" "$@"; }

# Fresh local bare origin plus a clone holding the real .github directory, with tag 0.0.0 unless --no-baseline
new_repo() {
  REMOTE="$WORK/$1.git" REPO="$WORK/$1"
  git init -q --bare "$REMOTE"
  git init -q "$REPO"
  cp -R "$ROOT/.github" "$REPO/.github"
  printf '.releaserc.json\n' >> "$REPO/.git/info/exclude"
  g remote add origin "file://$REMOTE"
  g add -A
  g commit -q --no-verify -m "chore: initial commit"
  [[ "${2:-}" == "--no-baseline" ]] || g tag 0.0.0
  g push -q origin master --tags
}

commit() { g commit -q --no-verify --allow-empty -m "$1"; }

# Refuses to go on unless origin is the local bare repository of this run
assert_local_origin() {
  local url
  url=$(g remote get-url origin)
  if [[ "$url" != "file://$WORK/"* ]]; then
    echo "Refusing to run: origin is $url, expected a file:// remote under $WORK" >&2
    exit 2
  fi
}

# Runs semantic-release on <branch> as the semantic-version action does; --release publishes to the local origin
run_semantic_release() {
  local branch=$1 mode=$2 dry_run=(--dry-run)
  [[ "$mode" == release ]] && dry_run=()
  assert_local_origin
  g switch -q "$branch"
  g push -q origin "$branch" --tags
  HOTFIX=$(cd "$REPO" && bash .github/scripts/prepare-releaserc.sh "$branch")
  # The test config drops @semantic-release/github and pins the repository to the local bare origin
  jq --arg url "file://$REMOTE" '.repositoryUrl = $url
    | .plugins |= map(select((if type == "array" then .[0] else . end) != "@semantic-release/github"))' \
    "$REPO/.releaserc.json" > "$WORK/releaserc.json"
  mv "$WORK/releaserc.json" "$REPO/.releaserc.json"
  LOG="$WORK/semantic-release.log"
  if ! (cd "$REPO" && npx --yes -p "$SEMANTIC_RELEASE" -p "$PRESET" semantic-release --no-ci "${dry_run[@]}") \
      > "$LOG" 2>&1; then
    echo "semantic-release failed on $branch, log:" >&2
    cat "$LOG" >&2
    exit 1
  fi
  NEXT=$(sed -nE 's/.*[Tt]he next release version is ([0-9A-Za-z.-]+).*/\1/p' "$LOG" | tail -n 1)
  LAST=$(sed -nE 's/.*associated with version ([0-9A-Za-z.-]+) on branch.*/\1/p' "$LOG" | tail -n 1)
  TYPE=$(sed -nE 's/.*Analysis of [0-9]+ commits complete: (major|minor|patch) release.*/\1/p' "$LOG" | tail -n 1)
}

# check <name> <branch> <expected: version | none | rejected> [--release]
check() {
  local name=$1 branch=$2 expected=$3 mode=${4:-dry-run} actual reason=""
  # Same order as CI: dry run, hotfix guard, then the real release only if the guard passed
  run_semantic_release "$branch" dry-run
  actual=${NEXT:-none}
  if ! reason=$(cd "$REPO" && bash .github/scripts/hotfix-guard.sh "$branch" "$NEXT" "$LAST"); then
    actual=rejected
  elif [[ "$mode" == --release ]]; then
    run_semantic_release "$branch" release
  fi
  if [[ "$actual" == "$expected" ]]; then
    PASSED=$((PASSED + 1))
    printf 'PASS  %-46s %-16s last=%-16s %s\n' "$name" "$actual" "${LAST:-none}" "${TYPE:-}${reason:+ ($reason)}"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL  %-46s expected %s, got %s (next=%s last=%s)\n' "$name" "$expected" "$actual" "${NEXT:-none}" \
      "${LAST:-none}"
  fi
}

echo "== First release without any tag"
new_repo no-tags --no-baseline
commit "fix(CK-1): first fix"
check "fix without tags starts at 1.0.0" master 1.0.0

echo "== Release line from baseline tag 0.0.0"
new_repo story
commit "fix(CK-1): handle empty greeting"
check "fix -> patch" master 0.0.1 --release
commit "feat(CK-2): add farewell endpoint"
check "feat -> minor" master 0.1.0 --release
commit "docs(CK-3): document the endpoints"
check "docs -> no release" master none
commit "chore(CK-4): tidy build"
commit "ci(CK-4): cache maven"
check "docs + chore + ci -> no release" master none
commit "perf(CK-5): cache greetings"
check "perf -> patch" master 0.1.1 --release
commit "revert(CK-6): revert greeting cache"
check "revert -> patch" master 0.1.2 --release

g switch -q -c CK-7-merge master
commit "fix(CK-7): trim names"
commit "feat(CK-7): add greeting language"
g switch -q master
g merge -q --no-ff CK-7-merge -m "Merge pull request #7 from avall/CK-7-merge"
check "merge commit with fix + feat -> minor" master 0.2.0 --release

commit "feat(CK-8)!: rename the greeting endpoint"
check "feat! -> major" master 1.0.0 --release
commit "$(printf 'fix(CK-9): drop legacy field\n\nBREAKING CHANGE: the legacy field is removed')"
check "BREAKING CHANGE footer -> major" master 2.0.0 --release

echo "== Hotfix line on production tag 2.0.0 while master moves on"
commit "feat(CK-10): add greeting history"
check "master moves on -> minor" master 2.1.0 --release

g switch -q -c hotfix/2.0.0 2.0.0
commit "fix(CK-11): hotfix null greeting"
check "hotfix fix -> first hotfix" hotfix/2.0.0 2.0.1-hotfix.1 --release
commit "fix(CK-12): hotfix timeout"
check "second hotfix fix -> hotfix.2" hotfix/2.0.0 2.0.1-hotfix.2 --release
commit "feat(CK-13): new feature on hotfix"
check "feat on hotfix -> rejected by the guard" hotfix/2.0.0 rejected
g reset -q --hard HEAD~1
g push -q -f origin hotfix/2.0.0

g switch -q master
g merge -q --no-ff hotfix/2.0.0 -m "fix(CK-12): port hotfix 2.0.1-hotfix.2 to master"
check "hotfix port to master -> patch" master 2.1.1 --release

g switch -q hotfix/2.0.0
g merge -q --no-ff master -m "Merge branch 'master' into hotfix/2.0.0"
commit "fix(CK-14): late hotfix"
check "hotfix updated from master -> rejected" hotfix/2.0.0 rejected

echo "== Hotfix branches not named hotfix/<production tag>"
for branch in hotfix/001 hotfix/2.0 hotfix/v2.0.0; do
  g switch -q -c "$branch" 2.0.0
  commit "fix(CK-15): hotfix on $branch"
  check "$branch not a release branch -> none" "$branch" none
  [[ "$HOTFIX" == false ]] || { FAILED=$((FAILED + 1)); echo "FAIL  $branch was treated as a hotfix branch"; }
done

echo "== Hotfix branch recreated from an older tag of its line (2.0.1-hotfix.2 already released)"
g switch -q master
g branch -q -D hotfix/2.0.0
g switch -q -c hotfix/2.0.0 2.0.0
commit "fix(CK-16): hotfix from the production tag"
g push -q -f origin hotfix/2.0.0
check "hotfix from 2.0.0 -> rejected (tag exists)" hotfix/2.0.0 rejected
g reset -q --hard 2.0.1-hotfix.1
commit "fix(CK-17): hotfix from hotfix.1"
g push -q -f origin hotfix/2.0.0
check "hotfix from hotfix.1 -> rejected (tag exists)" hotfix/2.0.0 rejected
g reset -q --hard 2.0.1-hotfix.2
commit "fix(CK-18): hotfix from the latest hotfix tag"
g push -q -f origin hotfix/2.0.0
check "hotfix from hotfix.2 -> hotfix.3" hotfix/2.0.0 2.0.1-hotfix.3

echo
echo "Passed: $PASSED  Failed: $FAILED"
[[ "$FAILED" -eq 0 ]]
