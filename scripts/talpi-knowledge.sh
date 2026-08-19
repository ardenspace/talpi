#!/bin/sh
# talpi-knowledge: the trust gate over .talpi/knowledge.md — the file
# that carries knowledge across runs. A model distills the file; this
# script, not a model, decides what survives:
#
#   check  [root] — read-only. Validates the title, the three sections
#                   in order, and each entry's grammar. Decision quotes
#                   (and rationales) resolve content-addressed: the text
#                   must appear verbatim in spec.md, archive/*/spec.md,
#                   or journal.md — the source: field is a hint, never
#                   trusted, so entries survive an archive move. Open
#                   questions must end with '?'. Facts whose scope files
#                   changed since their `as of` hash are flagged
#                   `stale — demote to question`.
#   replay [root] — runs every Fact's command from the project root; a
#                   fact passes iff the command exits 0 and its output
#                   contains the expect: text.
#
# Exit 0 when every entry passes; 1 when any entry fails or is stale.
#
# Usage: talpi-knowledge.sh check|replay [project-root]
#   root defaults to $CLAUDE_PROJECT_DIR, then cwd.
set -u

CMD="${1:?usage: talpi-knowledge.sh check|replay [project-root]}"
ROOT="${2:-${CLAUDE_PROJECT_DIR:-.}}"
T="$ROOT/.talpi"
K="$T/knowledge.md"

case "$CMD" in
  check|replay) ;;
  *) echo "error: unknown command '$CMD' (check|replay)" >&2; exit 1 ;;
esac

if [ ! -f "$K" ]; then
  echo "no knowledge.md at $ROOT — nothing to $CMD"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BAD=0
flag() { echo "$1"; BAD=1; }

# Split one section's entries into files $TMP/<prefix>.<n>. An entry
# starts at a `- ` line; two-space-indented lines continue it, with the
# leading `- `/two spaces stripped so every field line is `<key>: <val>`.
split_section() { # $1 = section title, $2 = file prefix
  awk -v sec="$1" -v out="$TMP/$2" '
    /^## /    { insec = ($0 == "## " sec); next }
    !insec    { next }
    /^- /     { n++; print substr($0, 3) > (out "." n); next }
    /^  [^ ]/ { if (n) print substr($0, 3) > (out "." n) }
  ' "$K"
}

field() { # $1 = entry file, $2 = key
  sed -n "s/^$2: //p" "$1" | head -1
}

label() { # first 48 chars, for report lines
  printf '%s' "$1" | cut -c1-48
}

split_section "Decisions" d
split_section "Verified facts" f
split_section "Open questions" q

# --- replay: run every Fact's command from the project root -----------
if [ "$CMD" = "replay" ]; then
  for e in "$TMP"/f.*; do
    [ -f "$e" ] || continue
    name="$(field "$e" fact)"; cmd="$(field "$e" command)"; exp="$(field "$e" expect)"
    if [ -z "$name" ] || [ -z "$cmd" ] || [ -z "$exp" ]; then
      flag "replay fail: entry missing fact:/command:/expect: — ${name:-unnamed}"
      continue
    fi
    out="$( (cd "$ROOT" && sh -c "$cmd") 2>&1 )"; st=$?
    if [ "$st" -ne 0 ]; then
      flag "replay fail: $name — command exited $st"
    elif ! printf '%s\n' "$out" | grep -Fq "$exp"; then
      flag "replay fail: $name — output does not contain the expect text"
    else
      echo "replay pass: $name"
    fi
  done
  if [ "$BAD" -eq 0 ]; then
    echo "knowledge replay: clean"
  else
    echo "knowledge replay: entries failed — drop or demote to Open questions"
  fi
  exit "$BAD"
fi

# --- check: structure -------------------------------------------------
[ "$(head -1 "$K")" = "# Knowledge" ] \
  || flag "structure fail: first line must be '# Knowledge'"
if [ "$(grep '^## ' "$K")" != "## Decisions
## Verified facts
## Open questions" ]; then
  flag "structure fail: sections must be exactly '## Decisions', '## Verified facts', '## Open questions', in that order"
fi

# --- check: Decisions are content-addressed verbatim quotes -----------
# The provenance store: spec.md, every archived spec, and the journal.
# The source: field is never consulted — content is the address.
provenance_has() {
  for p in "$T/spec.md" "$T"/archive/*/spec.md "$T/journal.md"; do
    [ -f "$p" ] || continue
    grep -Fq "$1" "$p" && return 0
  done
  return 1
}

for e in "$TMP"/d.*; do
  [ -f "$e" ] || continue
  quote="$(field "$e" quote)"
  if [ -z "$quote" ]; then flag "decision fail: entry missing quote:"; continue; fi
  l="$(label "$quote")"
  [ -n "$(field "$e" source)" ] || flag "decision fail: missing source: — $l"
  [ -n "$(field "$e" date)" ]   || flag "decision fail: missing date: — $l"
  if ! provenance_has "$quote"; then
    flag "decision fail: quote not found verbatim in spec.md, archive/*/spec.md, or journal.md — drop or demote to question: $l"
    continue
  fi
  rationale="$(field "$e" rationale)"
  if [ -n "$rationale" ] && ! provenance_has "$rationale"; then
    flag "decision fail: rationale not found verbatim in spec.md, archive/*/spec.md, or journal.md — drop or demote to question: $l"
    continue
  fi
  echo "decision ok: $l"
done

# --- check: Facts have the full grammar and fresh scopes --------------
in_git=0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1
[ "$in_git" -eq 1 ] || echo "note: not a git repository — staleness unchecked"

for e in "$TMP"/f.*; do
  [ -f "$e" ] || continue
  name="$(field "$e" fact)"
  if [ -z "$name" ]; then flag "fact fail: entry missing fact:"; continue; fi
  bad=0
  for key in command expect scope; do
    [ -n "$(field "$e" "$key")" ] || { flag "fact fail: missing $key: — $name"; bad=1; }
  done
  hash="$(field "$e" "as of")"
  [ -n "$hash" ] || { flag "fact fail: missing 'as of:' — $name"; bad=1; }
  [ "$bad" -eq 0 ] || continue
  if [ "$in_git" -eq 1 ]; then
    if ! git -C "$ROOT" rev-parse --quiet --verify "$hash^{commit}" >/dev/null 2>&1; then
      flag "fact fail: 'as of' hash '$hash' not found in this repository — $name"
      continue
    fi
    scope="$(field "$e" scope)"
    # Working tree vs the recorded hash, so uncommitted edits count too.
    # $scope is deliberately unquoted: space-separated paths.
    changed="$(git -C "$ROOT" diff --name-only "$hash" -- $scope 2>/dev/null)"
    if [ -n "$changed" ]; then
      flag "fact stale — demote to question: $name (scope changed since $hash)"
      continue
    fi
  fi
  echo "fact ok: $name"
done

# --- check: Open questions are questions, not statements --------------
for e in "$TMP"/q.*; do
  [ -f "$e" ] || continue
  question="$(field "$e" question)"
  if [ -z "$question" ]; then flag "question fail: entry missing question:"; continue; fi
  case "$question" in
    *\?) echo "question ok: $(label "$question")" ;;
    *)   flag "question fail: statement form banned — must end with '?': $(label "$question")" ;;
  esac
done

if [ "$BAD" -eq 0 ]; then
  echo "knowledge check: clean"
else
  echo "knowledge check: entries failed — drop or demote to Open questions"
fi
exit "$BAD"
