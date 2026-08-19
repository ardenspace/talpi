#!/bin/sh
# talpi-journal: append one event to .talpi/journal.md in the canonical
# `- [<ISO date>] <event>` format. Mechanizes the append so no session
# ever hand-formats (or forgets) a journal line. Append-only by design.
#
# Usage: talpi-journal.sh "<event>" [project-root]
#   root defaults to $CLAUDE_PROJECT_DIR, then cwd.
set -u

EVENT="${1:?usage: talpi-journal.sh \"<event>\" [project-root]}"
ROOT="${2:-${CLAUDE_PROJECT_DIR:-.}}"
J="$ROOT/.talpi/journal.md"

[ -d "$ROOT/.talpi" ] || { echo "error: no .talpi/ at $ROOT" >&2; exit 1; }
nl='
'
case "$EVENT" in
  *"$nl"*) echo "error: event must be a single line" >&2; exit 1 ;;
esac

printf -- '- [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$EVENT" >> "$J"
tail -1 "$J"
