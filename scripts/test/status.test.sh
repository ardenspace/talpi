#!/bin/sh
# Contract test: the state-machine scripts (talpi-status/journal/state)
# encode the guard/resume decision table correctly.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

STATUS="$ROOT/scripts/talpi-status.sh"
JOURNAL="$ROOT/scripts/talpi-journal.sh"
STATE="$ROOT/scripts/talpi-state.sh"

for s in "$STATUS" "$JOURNAL" "$STATE"; do
  [ -f "$s" ] || { fail "missing $(basename "$s")"; continue; }
  sh -n "$s" 2>/dev/null && ok || fail "$(basename "$s") has syntax errors"
done

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Fixture helpers -------------------------------------------------------
mkrun() { # mkrun <dir>
  mkdir -p "$T/$1/.talpi"
}
setstate() { # setstate <dir> <status> <cur> <total>
  printf 'run_status: %s\ncurrent_phase: %s\nphases_total: %s\nupdated: x\n' \
    "$2" "$3" "$4" > "$T/$1/.talpi/state.md"
}
addj() { # addj <dir> <event>
  printf -- '- [2026-08-19T00:00:00Z] %s\n' "$2" >> "$T/$1/.talpi/journal.md"
}
run() { sh "$STATUS" "$T/$1"; }

# 1) No .talpi/ → none, route to talpispec.
out="$(sh "$STATUS" "$T")"
echo "$out" | grep -q 'run_status: none' && ok || fail "no .talpi: wrong status"
echo "$out" | grep -q 'talpispec' && ok || fail "no .talpi: no talpispec route"

# 2) Draft spec → speccing; refactor mode routes to talpirefactor.
mkrun a; printf 'status: draft\n' > "$T/a/.talpi/spec.md"
run a | grep -q 'next: route to talpispec' && ok || fail "draft spec: not routed to talpispec"
printf 'status: draft\nmode: refactor\n' > "$T/a/.talpi/spec.md"
run a | grep -q 'next: route to talpirefactor' && ok || fail "refactor draft: not routed to talpirefactor"

# 3) Approved spec, no approved plan → planning.
mkrun b; printf 'status: approved\n' > "$T/b/.talpi/spec.md"
run b | grep -q 'next: route to talpiplan' && ok || fail "approved spec: not routed to talpiplan"

# 4) Building mid-phase → phase loop + first unchecked step of the
#    CURRENT phase (not an earlier phase's leftovers).
mkrun c
printf 'status: approved\n' > "$T/c/.talpi/spec.md"
cat > "$T/c/.talpi/plan.md" <<'EOF'
status: approved
# Plan: demo
## Phase 1: setup
- [x] scaffold
## Phase 2: build
- [x] pin contracts
- [ ] wire the endpoint
- [ ] render the page
EOF
setstate c building 2 3
out="$(run c)"
echo "$out" | grep -q 'next: phase loop — work phase 2 of 3' && ok || fail "mid-phase: wrong next"
echo "$out" | grep -q 'step: wire the endpoint' && ok || fail "mid-phase: wrong first unchecked step"

# 5) All steps ticked in current phase → note, not a bogus step.
sed -i '' 's/- \[ \]/- [x]/' "$T/c/.talpi/plan.md" 2>/dev/null || sed -i 's/- \[ \]/- [x]/' "$T/c/.talpi/plan.md"
run c | grep -q 'note: no unchecked step' && ok || fail "ticked phase: missing note"

# 6) Phase loop over, tail = last phase reported → completion step 1.
mkrun d; setstate d building 4 3
addj d 'phase 3 reported'
run d | grep -q 'next: completion — every phase reported' && ok || fail "reported tail: no completion route"

# 7) Tail = run review (through <hash>) → re-enter completion, narrowed.
addj d 'run review (through abc1234): 2 findings (1 fixed, 1 noted)'
out="$(run d)"
echo "$out" | grep -q 're-enter Completion' && ok || fail "review tail: no re-enter"
echo "$out" | grep -q 'abc1234\.\.HEAD' && ok || fail "review tail: diff not narrowed to hash"

# 8) Tail = awaiting acceptance → wait, do not rebuild.
addj d 'final report sent, awaiting acceptance'
run d | grep -q 'next: awaiting acceptance' && ok || fail "awaiting tail: wrong route"

# 9) Tail = acceptance declined → reopen phase loop.
addj d 'acceptance declined: header color wrong'
run d | grep -q 'next: reopen phase loop' && ok || fail "declined tail: wrong route"

# 10) Journal `run done` beats a stale state.md → done + warning.
addj d 'run done'
out="$(run d)"
echo "$out" | grep -q 'run_status: done' && ok || fail "run done: journal did not win"
echo "$out" | grep -q 'warning: state.md run_status' && ok || fail "run done: no conflict warning"

# 11) Halted with reason; halted-then-resumed goes back to building.
mkrun e; setstate e halted 2 3
addj e 'run halted: verifier found auth model changed from spec'
out="$(run e)"
echo "$out" | grep -q 'run_status: halted' && ok || fail "halt: wrong status"
echo "$out" | grep -q 'reason: verifier found auth model changed' && ok || fail "halt: reason not surfaced"
addj e 'run resumed after ratifying the decision'
setstate e building 2 3
printf 'status: approved\n# Plan: demo\n## Phase 2: x\n- [ ] fix it\n' > "$T/e/.talpi/plan.md"
run e | grep -q 'next: phase loop' && ok || fail "resumed halt: did not return to phase loop"

# 12) Missing state.md → inferred status + warning.
mkrun f; printf 'status: approved\n' > "$T/f/.talpi/spec.md"
printf 'status: approved\n' > "$T/f/.talpi/plan.md"
out="$(run f)"
echo "$out" | grep -q 'warning: state.md missing' && ok || fail "missing state: no warning"
echo "$out" | grep -q 'run_status: building' && ok || fail "missing state: wrong inference"

# 13) talpi-journal appends the canonical format, refuses multiline.
mkrun g
out="$(sh "$JOURNAL" 'phase 1 started (base: abc1234)' "$T/g")"
grep -Eq '^- \[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\] phase 1 started \(base: abc1234\)$' \
  "$T/g/.talpi/journal.md" && ok || fail "journal append: wrong format"
sh "$JOURNAL" "two
lines" "$T/g" 2>/dev/null && fail "journal append: accepted multiline" || ok

# 14) talpi-state writes all four keys, validates vocabulary.
sh "$STATE" building 2 3 "$T/g" >/dev/null && ok || fail "state write failed"
for k in run_status current_phase phases_total updated; do
  grep -q "^$k: " "$T/g/.talpi/state.md" && ok || fail "state write: missing key $k"
done
sh "$STATE" bogus 1 1 "$T/g" 2>/dev/null && fail "state write: accepted bad status" || ok
sh "$STATE" building x 1 "$T/g" 2>/dev/null && fail "state write: accepted non-numeric phase" || ok

echo "status.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
