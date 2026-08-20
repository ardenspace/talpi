#!/bin/sh
# talpi-status: read .talpi/ off disk and print where the run is and
# what happens next. The guard/resume decision table lives HERE, not in
# skill prose — skills run this and follow the `next:` line, so routing
# is a tool call, not a prose-reading exercise. Read-only: never writes.
#
# Usage: talpi-status.sh [project-root]
#   root defaults to $CLAUDE_PROJECT_DIR, then cwd.
#
# Output (line-oriented, stable keys):
#   run_status: none|speccing|planning|building|done|halted
#   current_phase / phases_total  (when state.md has them)
#   mode: refactor                (when spec.md declares it)
#   next: <action>                (exactly one)
#   step: <text>                  (first unchecked step, mid-phase only)
#   note: / reason: / warning:    (supporting detail; warnings mean
#                                  state.md disagrees with the journal —
#                                  the journal wins, rewrite state.md)
set -u

ROOT="${1:-${CLAUDE_PROJECT_DIR:-.}}"
T="$ROOT/.talpi"
JOURNAL="$T/journal.md"
STATE="$T/state.md"
SPEC="$T/spec.md"
PLAN="$T/plan.md"

if [ ! -d "$T" ]; then
  echo "run_status: none"
  echo "next: no talpi run on disk — start with the talpispec skill (talpirefactor for restructuring an existing codebase)"
  exit 0
fi

# --- journal tamper check: append-only is mechanical ------------------
# Same byte-prefix rule talpi-journal.sh enforces before appending; here
# it only warns — status is read-only, and the human decides how to
# restore the committed lines.
if [ -f "$JOURNAL" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  prefix="$(git -C "$ROOT" rev-parse --show-prefix 2>/dev/null)"
  if git -C "$ROOT" cat-file -e "HEAD:${prefix}.talpi/journal.md" 2>/dev/null; then
    HEADJ="$(mktemp)"
    git -C "$ROOT" show "HEAD:${prefix}.talpi/journal.md" > "$HEADJ"
    n=$(($(wc -c < "$HEADJ")))
    if [ "$n" -gt 0 ] && ! head -c "$n" "$JOURNAL" | cmp -s "$HEADJ" -; then
      echo "warning: journal.md tampered — the committed journal is not a byte-prefix of the working copy (append-only violated; journal lines are provenance, restore them before trusting state)"
    fi
    rm -f "$HEADJ"
  fi
fi

# --- read the snapshot and status markers -----------------------------
state_status=""; cur=""; total=""
if [ -f "$STATE" ]; then
  state_status="$(sed -n 's/^run_status: *//p' "$STATE" | head -1)"
  cur="$(sed -n 's/^current_phase: *//p' "$STATE" | head -1)"
  total="$(sed -n 's/^phases_total: *//p' "$STATE" | head -1)"
fi
spec_status=""; spec_mode=""
if [ -f "$SPEC" ]; then
  spec_status="$(head -1 "$SPEC" | sed -n 's/^status: *//p')"
  spec_mode="$(sed -n '2s/^mode: *//p' "$SPEC")"
fi
plan_status=""
[ -f "$PLAN" ] && plan_status="$(head -1 "$PLAN" | sed -n 's/^status: *//p')"

# --- journal scan: line number of the LAST occurrence of each event ---
# Events are matched from "] " onward so free text inside other events
# cannot false-positive. Missing journal → all empty.
ln_of() {
  if [ -f "$JOURNAL" ]; then
    grep -Fn "$1" "$JOURNAL" | tail -1 | cut -d: -f1
  fi
}
n_done="$(ln_of '] run done')"
n_halt="$(ln_of '] run halted:')"
n_resume="$(ln_of 'resumed')"

# --- multi-run: events before the last run-start marker are history ---
# A new run over a done project archives spec.md/plan.md and journals
# `run started over done run` (talpispec) or `refactor run started over
# done run` (talpirefactor). journal.md itself never moves — one
# history, many runs — so events before the last such marker belong to
# the archived run and must not route this one.
a="$(ln_of '] run started over done run')"
b="$(ln_of '] refactor run started over done run')"
n_start="$a"
if [ -n "$b" ] && { [ -z "$n_start" ] || [ "$b" -gt "$n_start" ]; }; then
  n_start="$b"
fi
past_start() { # blank a line number that precedes the last run-start marker
  if [ -n "${1:-}" ] && [ -n "$n_start" ] && [ "$1" -lt "$n_start" ]; then
    echo ""
  else
    echo "${1:-}"
  fi
}
n_done="$(past_start "$n_done")"
n_halt="$(past_start "$n_halt")"
n_resume="$(past_start "$n_resume")"

# --- effective run_status: journal wins over state.md -----------------
jstatus=""
if [ -n "$n_done" ] && { [ -z "$n_halt" ] || [ "$n_done" -gt "$n_halt" ]; }; then
  jstatus="done"
elif [ -n "$n_halt" ] && { [ -z "$n_resume" ] || [ "$n_resume" -lt "$n_halt" ]; } \
     && { [ -z "$n_done" ] || [ "$n_done" -lt "$n_halt" ]; }; then
  jstatus="halted"
fi

status="$state_status"
if [ -n "$jstatus" ]; then
  if [ -n "$state_status" ] && [ "$state_status" != "$jstatus" ]; then
    echo "warning: state.md run_status '$state_status' contradicts journal '$jstatus' — journal wins; rewrite state.md (talpi-state.sh)"
  fi
  status="$jstatus"
fi
if [ -z "$status" ]; then
  # No readable state.md and no decisive journal line: infer from the
  # spec/plan status markers (talpiresume's fallback ladder).
  if [ ! -f "$SPEC" ] || [ "$spec_status" != "approved" ]; then
    status="speccing"
  elif [ "$plan_status" != "approved" ]; then
    status="planning"
  else
    status="building"
  fi
  echo "warning: state.md missing or unreadable — run_status inferred; rewrite state.md (talpi-state.sh)"
fi

echo "run_status: $status"
[ -n "$cur" ] && echo "current_phase: $cur"
[ -n "$total" ] && echo "phases_total: $total"
[ "$spec_mode" = "refactor" ] && echo "mode: refactor"

# --- route ------------------------------------------------------------
case "$status" in
  speccing)
    if [ "$spec_mode" = "refactor" ]; then
      echo "next: route to talpirefactor — spec draft resumes there"
    else
      echo "next: route to talpispec — no approved spec yet"
    fi
    exit 0 ;;
  planning)
    echo "next: route to talpiplan — spec approved, no approved plan"
    exit 0 ;;
  done)
    echo "next: run done — nothing to build; summarize the run for the human"
    exit 0 ;;
  halted)
    reason=""
    [ -n "$n_halt" ] && reason="$(sed -n "${n_halt}p" "$JOURNAL" | sed 's/.*] run halted: *//')"
    [ -n "$reason" ] && echo "reason: $reason"
    echo "next: halted — present the halt reason to the human for a ruling before anything continues"
    exit 0 ;;
  building) ;;
  *)
    echo "warning: unknown run_status '$status' in state.md"
    echo "next: journal inconclusive — reconstruct state per the talpiresume skill"
    exit 0 ;;
esac

# --- building: phase loop or completion? ------------------------------
if ! echo "$cur" | grep -Eq '^[0-9]+$' || ! echo "$total" | grep -Eq '^[0-9]+$'; then
  echo "warning: current_phase/phases_total unreadable in state.md — reconstruct from plan.md and the journal; rewrite state.md (talpi-state.sh)"
  echo "next: journal inconclusive — reconstruct state per the talpiresume skill"
  exit 0
fi

if [ "$cur" -le "$total" ]; then
  echo "next: phase loop — work phase $cur of $total"
  if [ -f "$PLAN" ]; then
    step="$(awk -v n="$cur" '
      /^## Phase /{ inphase = ($0 ~ "^## Phase " n ":") }
      inphase && /^- \[ \]/{ print substr($0, 7); exit }
    ' "$PLAN")"
    if [ -n "$step" ]; then
      echo "step: $step"
    else
      echo "note: no unchecked step in plan.md phase $cur — if all steps are ticked, the phase is at contracts-green/verification"
    fi
  fi
  exit 0
fi

# current_phase past phases_total: the phase loop is over; the journal's
# most recent completion event decides where completion stands.
n_reported="$(past_start "$(ln_of "] phase $total reported")")"
n_review="$(past_start "$(ln_of '] run review (through ')")"
n_await="$(past_start "$(ln_of '] final report sent, awaiting acceptance')")"
n_declined="$(past_start "$(ln_of '] acceptance declined')")"

last=0; which=""
for pair in "reported:${n_reported:-}" "review:${n_review:-}" "await:${n_await:-}" "declined:${n_declined:-}"; do
  name="${pair%%:*}"; n="${pair#*:}"
  if [ -n "$n" ] && [ "$n" -gt "$last" ]; then last="$n"; which="$name"; fi
done

case "$which" in
  reported)
    echo "next: completion — every phase reported but completion never ran; enter Completion at step 1 (smoke run)"
    ;;
  review)
    hash="$(sed -n "${last}p" "$JOURNAL" | sed 's/.*run review (through \([^)]*\)).*/\1/')"
    echo "next: completion — interrupted after the run review; re-enter Completion at step 1"
    [ -n "$hash" ] && echo "note: narrow the run review diff to ${hash}..HEAD — earlier commits were already reviewed"
    ;;
  await)
    echo "next: awaiting acceptance — the final report is pending the human; remind them and wait, do not rebuild or re-send"
    ;;
  declined)
    echo "next: reopen phase loop — acceptance was declined; append the Acceptance-fixes phase to plan.md if it is missing, sync state.md counters (talpi-state.sh), and run it as a normal phase"
    ;;
  *)
    echo "warning: current_phase ($cur) is past phases_total ($total) but the journal has no completion event"
    echo "next: journal inconclusive — reconstruct state per the talpiresume skill"
    ;;
esac
exit 0
