#!/usr/bin/env bash
# The merge gate: everything the offline lab can check, in one exit code.
# Usage: bash test/gate.sh [path/to/traces-dir]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
TRACES="${1:-$ROOT/../VerdantWorkingdir/traces}"
fail=0
LUA=lua; command -v lua >/dev/null 2>&1 || LUA=lua5.4
LUAC=luac; command -v luac >/dev/null 2>&1 || LUAC=luac5.4

step() { printf '%-28s ' "$1"; }
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

step "luac"
bad_files=""
while IFS= read -r f; do $LUAC -p "$f" 2>/dev/null || bad_files="$bad_files $f"; done < <(find . -name '*.lua' -not -path './.git/*')
[ -z "$bad_files" ] && pass "all files parse" || bad "$bad_files"

step "harness DEBUG"
out=$($LUA test/harness/run.lua . 1 2>&1 | tail -1); case "$out" in *" 0 failed"*) pass "$out";; *) bad "$out";; esac
step "harness release"
out=$($LUA test/harness/run.lua . 0 2>&1 | tail -1); case "$out" in *" 0 failed"*) pass "$out";; *) bad "$out";; esac

rm -f test/simlab/out/*.svg
step "simlab scenarios"
n=$($LUA test/simlab/run.lua . --svg 2>&1 | grep -cE '^PASS'); f=$($LUA test/simlab/run.lua . 2>&1 | grep -cE '^FAIL')
[ "$f" = "0" ] && [ "$n" -ge 3 ] && pass "$n scenarios" || bad "$f failing"
step "simlab mockups"
$LUA test/simlab/mockups.lua . >/dev/null 2>&1 && pass "rendered" || bad "mockups crashed"
step "audit (default + min)"
out=$($LUA test/simlab/audit.lua . 2>&1 | tail -1); case "$out" in *"0 finding"*) pass "$out";; *) bad "$out";; esac

if [ -d "$TRACES" ]; then
  for t in "$TRACES"/*.lua; do
    [ -f "$t" ] || continue
    rm -f test/simlab/out/replay_*.svg
    step "replay $(basename "$t" .lua)"
    if $LUA test/simlab/replay.lua . "$t" --svg >/dev/null 2>&1; then
      out=$($LUA test/simlab/audit.lua . 2>&1 | tail -1)
      case "$out" in *"0 finding"*) pass "$out";; *) bad "$out";; esac
    else
      bad "replay crashed"
    fi
  done
else
  step "replay"; echo "skip (no traces at $TRACES)"
fi

if [ "$fail" = "0" ]; then echo "== GATE: clean =="; else echo "== GATE: NOT CLEAN =="; fi
exit $fail
