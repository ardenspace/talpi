#!/bin/sh
# Contract test: plugin manifests parse and stay in sync.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

P="$ROOT/.claude-plugin/plugin.json"
M="$ROOT/.claude-plugin/marketplace.json"

# 1) Both manifests exist and parse as JSON.
for f in "$P" "$M"; do
  if [ ! -f "$f" ]; then fail "missing $f"
  elif ! python3 -m json.tool "$f" >/dev/null 2>&1; then fail "invalid JSON: $f"
  else ok; fi
done

# 2) plugin.json has required fields with expected values.
if [ -f "$P" ]; then
  name="$(python3 -c "import json;print(json.load(open('$P'))['name'])" 2>/dev/null)"
  ver="$(python3 -c "import json;print(json.load(open('$P'))['version'])" 2>/dev/null)"
  [ "$name" = "talpi" ] && ok || fail "plugin.json name != talpi"
  echo "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' && ok || fail "plugin.json version not semver: '$ver'"
fi

# 3) marketplace.json points at this plugin.
if [ -f "$M" ]; then
  mname="$(python3 -c "import json;print(json.load(open('$M'))['plugins'][0]['name'])" 2>/dev/null)"
  [ "$mname" = "talpi" ] && ok || fail "marketplace.json plugin name != talpi"
fi

# 4) Hook wiring: hooks.json parses, references an existing script,
#    and covers compact (the pslog lesson).
H="$ROOT/hooks/hooks.json"
if [ ! -f "$H" ]; then fail "missing hooks/hooks.json"
elif ! python3 -m json.tool "$H" >/dev/null 2>&1; then fail "invalid JSON: $H"
else
  ok
  grep -q 'compact' "$H" && ok || fail "hooks.json matcher does not cover compact"
  [ -f "$ROOT/hooks/session-start.sh" ] && ok || fail "missing hooks/session-start.sh"
  sh -n "$ROOT/hooks/session-start.sh" 2>/dev/null && ok || fail "session-start.sh has syntax errors"
fi

# 5) Hook behavior: resolves the project root (works from subdirs),
#    surfaces unfinished runs with a position snapshot, reports done
#    runs as no work, and stays quiet when no .talpi/ exists.
S="$ROOT/hooks/session-start.sh"
if [ -f "$S" ]; then
  T="$(mktemp -d)"
  mkdir -p "$T/proj/.talpi" "$T/proj/sub"
  printf 'run_status: building\ncurrent_phase: 1\nphases_total: 2\nupdated: x\n' > "$T/proj/.talpi/state.md"
  out="$(cd "$T/proj/sub" && CLAUDE_PROJECT_DIR="$T/proj" sh "$S")"
  echo "$out" | grep -q 'run_status: building' && ok || fail "hook missed run from subdir via CLAUDE_PROJECT_DIR"
  # Snapshot injection: the status script's next: line rides along,
  # framed as orientation (not a direct instruction), and the skill
  # pointer survives.
  echo "$out" | grep -q 'next: ' && ok || fail "hook did not inject a next: snapshot line"
  echo "$out" | grep -q 'snapshot' && ok || fail "hook did not frame the position as a snapshot"
  echo "$out" | grep -q 'not an instruction' && ok || fail "hook snapshot missing not-an-instruction framing"
  echo "$out" | grep -q 'talpiresume' && ok || fail "hook lost the talpiresume pointer"
  printf 'run_status: done\ncurrent_phase: 2\nphases_total: 2\nupdated: x\n' > "$T/proj/.talpi/state.md"
  printf -- '- [2026-08-19T00:00:00Z] run done\n' > "$T/proj/.talpi/journal.md"
  out="$(cd "$T/proj" && CLAUDE_PROJECT_DIR="$T/proj" sh "$S")"
  echo "$out" | grep -q 'run_status: done' && ok || fail "hook did not report done run"
  echo "$out" | grep -qi 'no work' && ok || fail "hook did not say done run has no work"
  out="$(cd "$T" && CLAUDE_PROJECT_DIR="$T" sh "$S")"
  [ -z "$out" ] && ok || fail "hook not quiet without .talpi/"
  # Fallback: status script unavailable — hook still surfaces the run.
  H="$T/hooks-only/hooks"; mkdir -p "$H"; cp "$S" "$H/session-start.sh"
  printf 'run_status: building\ncurrent_phase: 1\nphases_total: 2\nupdated: x\n' > "$T/proj/.talpi/state.md"
  out="$(CLAUDE_PROJECT_DIR="$T/proj" sh "$H/session-start.sh")"
  echo "$out" | grep -q 'run_status: building' && ok || fail "hook fallback lost the run status"
  echo "$out" | grep -q 'talpiresume' && ok || fail "hook fallback lost the talpiresume pointer"
  rm -rf "$T"
fi

echo "manifest.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
