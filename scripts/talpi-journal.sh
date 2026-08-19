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

# Append-only guard: the committed (HEAD) journal must be a byte-prefix
# of the working copy. A mismatch means a committed line was edited or
# removed — journal.md is a provenance store (knowledge.md's verbatim
# quotes resolve against its lines), so refuse to build on a tampered
# one. Outside a git repo, or before the journal's first commit, there
# is nothing to hold the line against and the guard skips.
if [ -f "$J" ] && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  prefix="$(git -C "$ROOT" rev-parse --show-prefix 2>/dev/null)"
  if git -C "$ROOT" cat-file -e "HEAD:${prefix}.talpi/journal.md" 2>/dev/null; then
    HEADJ="$(mktemp)"
    git -C "$ROOT" show "HEAD:${prefix}.talpi/journal.md" > "$HEADJ"
    n=$(($(wc -c < "$HEADJ")))
    if [ "$n" -gt 0 ] && ! head -c "$n" "$J" | cmp -s "$HEADJ" -; then
      rm -f "$HEADJ"
      echo "error: journal.md tampered — the committed journal is not a byte-prefix of the working copy; append refused (restore the committed lines first)" >&2
      exit 1
    fi
    rm -f "$HEADJ"
  fi
fi

printf -- '- [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$EVENT" >> "$J"
tail -1 "$J"
