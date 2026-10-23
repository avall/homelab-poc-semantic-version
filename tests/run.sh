#!/usr/bin/env bash
# Table-driven tests for scripts/hotfix-version.sh, scripts/snapshot-version.sh and scripts/check-commit-message.sh. No network.
# Usage: bash tests/run.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOTFIX="$ROOT/scripts/hotfix-version.sh"
SNAPSHOT="$ROOT/scripts/snapshot-version.sh"
COMMIT_MSG="$ROOT/scripts/check-commit-message.sh"
PASS=0
FAIL=0

# Each case: name | script | args (space separated) | stdin tags (space separated) | expected exit (0 or err) | expected stdout
CASES=(
  "line: production tag|$HOTFIX|line 1.0.0||0|1.0.0"
  "line: major tag|$HOTFIX|line 2.0.0||0|2.0.0"
  "line: multi-digit tag|$HOTFIX|line 10.20.30||0|10.20.30"
  "line: hotfix tag maps to its base|$HOTFIX|line 1.0.1-hotfix.2||0|1.0.0"
  "line: hotfix.10 tag maps to its base|$HOTFIX|line 2.0.1-hotfix.10||0|2.0.0"
  "line: hotfix tag on minor line|$HOTFIX|line 1.1.1-hotfix.1||0|1.1.0"
  "line: invalid empty|$HOTFIX|line||err|"
  "line: invalid v prefix|$HOTFIX|line v1.0.0||err|"
  "line: invalid two parts|$HOTFIX|line 1.0||err|"
  "line: invalid four parts|$HOTFIX|line 1.0.0.0||err|"
  "line: invalid leading zero|$HOTFIX|line 01.0.0||err|"
  "line: invalid other pre-release|$HOTFIX|line 1.0.1-rc.1||err|"
  "line: invalid hotfix with patch 0|$HOTFIX|line 1.0.0-hotfix.1||err|"
  "line: invalid hotfix.0|$HOTFIX|line 1.0.1-hotfix.0||err|"
  "line: invalid hotfix without number|$HOTFIX|line 1.0.1-hotfix.||err|"
  "line: invalid text|$HOTFIX|line hotfix/1.0.0||err|"
  "next: no tags|$HOTFIX|next 1.0.0||0|1.0.1-hotfix.1"
  "next: only master tags|$HOTFIX|next 1.0.0|1.0.0 1.0.1 1.0.2 2.0.0|0|1.0.1-hotfix.1"
  "next: after hotfix.1|$HOTFIX|next 1.0.0|1.0.0 1.0.1 1.0.1-hotfix.1 2.0.0|0|1.0.1-hotfix.2"
  "next: numeric max hotfix.10 beats hotfix.9|$HOTFIX|next 1.0.0|1.0.1-hotfix.9 1.0.1-hotfix.10 1.0.1-hotfix.2|0|1.0.1-hotfix.11"
  "next: other lines ignored|$HOTFIX|next 1.0.0|2.0.1-hotfix.5 1.1.1-hotfix.7 11.0.1-hotfix.9 1.0.1-hotfix.3|0|1.0.1-hotfix.4"
  "next: base 2.0.0|$HOTFIX|next 2.0.0|1.0.1-hotfix.7 2.0.0 2.0.1-hotfix.3|0|2.0.1-hotfix.4"
  "next: base 2.0.0 no hotfix yet|$HOTFIX|next 2.0.0|1.0.1-hotfix.7 2.0.0|0|2.0.1-hotfix.1"
  "next: similar tags ignored|$HOTFIX|next 1.0.0|1.0.1-hotfix.3-x x1.0.1-hotfix.8 1.0.1-hotfix.04|0|1.0.1-hotfix.1"
  "next: invalid base is a hotfix tag|$HOTFIX|next 1.0.1-hotfix.2||err|"
  "next: invalid base|$HOTFIX|next 1.0||err|"
  "next: missing base|$HOTFIX|next||err|"
  "invalid command|$HOTFIX|bump 1.0.0||err|"
  "snapshot: branch with description|$SNAPSHOT|CK-1234-some-desc||0|0.0.0-CK-1234-SNAPSHOT"
  "snapshot: branch is only the key|$SNAPSHOT|CK-9016||0|0.0.0-CK-9016-SNAPSHOT"
  "snapshot: short key|$SNAPSHOT|CK-1-x||0|0.0.0-CK-1-SNAPSHOT"
  "snapshot: invalid master|$SNAPSHOT|master||err|"
  "snapshot: invalid lower case key|$SNAPSHOT|ck-1234-x||err|"
  "snapshot: invalid key without digits|$SNAPSHOT|CK-abc||err|"
  "snapshot: invalid digits followed by letters|$SNAPSHOT|CK-1234abc||err|"
  "snapshot: invalid prefix before key|$SNAPSHOT|feature/CK-1234-x||err|"
  "snapshot: invalid hotfix line|$SNAPSHOT|hotfix/1.0.0||err|"
  "snapshot: invalid empty|$SNAPSHOT|||err|"
)

for case in "${CASES[@]}"; do
  IFS='|' read -r name script args tags want_rc want_out <<<"$case"
  read -r -a argv <<<"$args"
  out=$(tr ' ' '\n' <<<"$tags" | bash "$script" ${argv[@]+"${argv[@]}"} 2>/dev/null)
  rc=$?
  if [[ "$want_rc" == "0" && $rc -eq 0 && "$out" == "$want_out" ]] \
    || [[ "$want_rc" == "err" && $rc -ne 0 && -z "$out" ]]; then
    PASS=$((PASS + 1))
    echo "PASS $name"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL $name: expected rc=$want_rc out='$want_out', got rc=$rc out='$out'"
  fi
done

# Commit message guard: name | expected subject | message (printf %b escapes) | expected exit (0 or err)
T="fix: CK-1 handle null (#7)"
MSG_CASES=(
  "guard: subject only|$T|$T|0"
  "guard: subject with trailing newline|$T|$T\n|0"
  "guard: Dependabot trailers|$T|$T\n\nSigned-off-by: dependabot[bot] <support@github.com>\nCo-authored-by: dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>\nCo-authored-by: Jandrinet <a@b.c>|0"
  "guard: co-author trailer only|$T|$T\n\nCo-authored-by: Ana <ana@x.y>|0"
  "guard: edited subject|$T|fix: CK-1 edited in the merge dialog (#7)|err"
  "guard: subject without PR number|$T|fix: CK-1 handle null|err"
  "guard: body text added|$T|$T\n\nsome description|err"
  "guard: breaking change footer added|$T|$T\n\nBREAKING CHANGE: removes the endpoint|err"
  "guard: trailer without blank line|$T|$T\nCo-authored-by: Ana <ana@x.y>|err"
  "guard: empty message|$T||err"
)
for case in "${MSG_CASES[@]}"; do
  IFS='|' read -r name expected message want_rc <<<"$case"
  out=$(printf '%b' "$message" | bash "$COMMIT_MSG" "$expected" 2>&1)
  rc=$?
  if [[ "$want_rc" == "0" && $rc -eq 0 ]] || [[ "$want_rc" == "err" && $rc -ne 0 ]]; then
    PASS=$((PASS + 1))
    echo "PASS $name"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL $name: expected rc=$want_rc, got rc=$rc out='$out'"
  fi
done

echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
