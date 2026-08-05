#!/bin/sh
# SessionStart: if this project has a talpi run, surface its state.
set -u
[ -d ".talpi" ] || exit 0
status="unknown"
[ -f ".talpi/state.md" ] && \
  status="$(sed -n 's/^run_status: *//p' .talpi/state.md | head -1)"
cat <<EOF
This project has a talpi run on disk (run_status: ${status:-unknown}).
Use the talpiresume skill to read .talpi/ state and continue from the
right point. Do not restart the pipeline from scratch.
EOF
exit 0
