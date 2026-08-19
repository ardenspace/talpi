#!/bin/sh
# SessionStart: if this project has an unfinished talpi run, surface it
# with a position snapshot from the status script (the canonical
# decision table), so the session starts knowing where the run stands
# even before any skill is invoked.
set -u
ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ -d "$ROOT/.talpi" ] || exit 0

SELF="$(cd "$(dirname "$0")" && pwd)"
snapshot="$(sh "$SELF/../scripts/talpi-status.sh" "$ROOT" 2>/dev/null)" || snapshot=""

if [ -n "$snapshot" ]; then
  status="$(printf '%s\n' "$snapshot" | sed -n 's/^run_status: *//p' | head -1)"
  cat <<EOF
This project has a talpi run on disk. Position snapshot as of session
start (read-only — state can move; the skill re-runs the script before
acting, and its run is the authoritative one):

$snapshot

The next: line above is a snapshot for orientation, not an instruction
to act on directly.
EOF
  if [ "${status:-}" = "done" ]; then
    cat <<EOF
Use the talpiresume skill only to confirm the run is done and no work
remains. Do not restart the pipeline from scratch.
EOF
  else
    cat <<EOF
Use the talpiresume skill to continue from the right point — it
restores the context this snapshot does not carry (handoff.md,
conventions.md, uncommitted in-flight work) and handles the halted
path. Do not restart the pipeline from scratch.
EOF
  fi
  exit 0
fi

# Fallback: status script unavailable or failed — plain pointer.
status="unknown"
[ -f "$ROOT/.talpi/state.md" ] && \
  status="$(sed -n 's/^run_status: *//p' "$ROOT/.talpi/state.md" | head -1)"
if [ "${status:-unknown}" = "done" ]; then
  cat <<EOF
This project has a talpi run on disk (run_status: done).
Use the talpiresume skill only to confirm the run is done and no work
remains. Do not restart the pipeline from scratch.
EOF
  exit 0
fi
cat <<EOF
This project has a talpi run on disk (run_status: ${status:-unknown}).
Use the talpiresume skill to read .talpi/ state and continue from the
right point. Do not restart the pipeline from scratch.
EOF
exit 0
