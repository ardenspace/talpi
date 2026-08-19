#!/bin/sh
# Contract test: docs/state-format.md is the single source of truth
# for .talpi/ state files; skills may only reference files defined there.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

SF="$ROOT/docs/state-format.md"

# 1) The contract doc exists and defines every canonical state file.
if [ ! -f "$SF" ]; then
  fail "missing docs/state-format.md"
else
  ok
  for f in spec.md plan.md conventions.md state.md journal.md handoff.md knowledge.md; do
    grep -q "\.talpi/$f" "$SF" && ok || fail "state-format.md does not define .talpi/$f"
  done
fi

# 2) It defines the run_status vocabulary.
if [ -f "$SF" ]; then
  for s in speccing planning building done halted; do
    grep -q "$s" "$SF" && ok || fail "state-format.md missing run_status '$s'"
  done
fi

# 3) Skills only reference state files the contract defines.
if [ -d "$ROOT/skills" ]; then
  refs="$(grep -rhoE '\.talpi/[a-z-]+\.md' "$ROOT/skills" 2>/dev/null | sort -u)"
  for r in $refs; do
    grep -q "$r" "$SF" && ok || fail "skills reference undefined state file: $r"
  done
fi

echo "state-format.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
