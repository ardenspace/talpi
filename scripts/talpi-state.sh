#!/bin/sh
# talpi-state: rewrite .talpi/state.md in full (all four keys) with the
# vocabulary validated and `updated` stamped. Mechanizes the snapshot
# write so a session cannot drop a key or invent a status.
#
# Usage: talpi-state.sh <run_status> <current_phase> <phases_total> [project-root]
#   root defaults to $CLAUDE_PROJECT_DIR, then cwd.
set -u

USAGE="usage: talpi-state.sh <run_status> <current_phase> <phases_total> [project-root]"
S="${1:?$USAGE}"; C="${2:?$USAGE}"; P="${3:?$USAGE}"
ROOT="${4:-${CLAUDE_PROJECT_DIR:-.}}"

case "$S" in
  speccing|planning|building|done|halted) ;;
  *) echo "error: invalid run_status '$S' (speccing|planning|building|done|halted)" >&2; exit 1 ;;
esac
echo "$C" | grep -Eq '^[0-9]+$' || { echo "error: current_phase must be a number, got '$C'" >&2; exit 1; }
echo "$P" | grep -Eq '^[0-9]+$' || { echo "error: phases_total must be a number, got '$P'" >&2; exit 1; }
[ -d "$ROOT/.talpi" ] || { echo "error: no .talpi/ at $ROOT" >&2; exit 1; }

printf 'run_status: %s\ncurrent_phase: %s\nphases_total: %s\nupdated: %s\n' \
  "$S" "$C" "$P" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/.talpi/state.md"
cat "$ROOT/.talpi/state.md"
