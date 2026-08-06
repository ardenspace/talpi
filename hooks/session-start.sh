#!/bin/sh
# SessionStart: if this project has an unfinished talpi run, surface it.
set -u
ROOT="${CLAUDE_PROJECT_DIR:-.}"
[ -d "$ROOT/.talpi" ] || exit 0
status="unknown"
[ -f "$ROOT/.talpi/state.md" ] && \
  status="$(sed -n 's/^run_status: *//p' "$ROOT/.talpi/state.md" | head -1)"
# A finished run needs no routing — stay quiet.
[ "${status:-unknown}" = "done" ] && exit 0
cat <<EOF
This project has a talpi run on disk (run_status: ${status:-unknown}).
Use the talpiresume skill to read .talpi/ state and continue from the
right point. Do not restart the pipeline from scratch.
EOF
exit 0
