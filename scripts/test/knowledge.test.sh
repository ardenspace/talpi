#!/bin/sh
# Contract test: knowledge distillation — entry grammar, content-
# addressed provenance (surviving the archive move), the replay gate,
# staleness demotion, the journal append-only guard, and lane isolation
# (the verification lane never sees knowledge.md).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

K="$ROOT/scripts/talpi-knowledge.sh"
J="$ROOT/scripts/talpi-journal.sh"
STATUS="$ROOT/scripts/talpi-status.sh"

for s in "$K" "$J"; do
  [ -f "$s" ] || { fail "missing $(basename "$s")"; continue; }
  sh -n "$s" 2>/dev/null && ok || fail "$(basename "$s") has syntax errors"
done

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Fixture: a git project with a committed .talpi run. --------------------
P="$T/proj"
mkdir -p "$P/.talpi"
git -C "$P" init -q
git -C "$P" config user.email t@t
git -C "$P" config user.name t
cat > "$P/.talpi/spec.md" <<'EOF'
status: approved
# Spec: demo
## Reversibility Ledger
### Decided (hard to change)
- The export format is CSV, not JSON
  because the CFO tooling only ingests CSV
EOF
printf -- '- [2026-08-19T00:00:00Z] spec approved\n' > "$P/.talpi/journal.md"
echo "hello scope" > "$P/scoped.txt"
git -C "$P" add -A
git -C "$P" commit -qm init
HASH="$(git -C "$P" rev-parse --short HEAD)"

mkknowledge() { # mkknowledge <as-of-hash>
  cat > "$P/.talpi/knowledge.md" <<EOF
# Knowledge

## Decisions

- quote: The export format is CSV, not JSON
  rationale: because the CFO tooling only ingests CSV
  source: spec.md Ledger
  date: 2026-08-19

## Verified facts

- fact: scoped-greets
  command: cat scoped.txt
  expect: hello scope
  as of: $1
  scope: scoped.txt

## Open questions

- question: does the CSV export hold under multi-currency rows?
  source: journal.md
EOF
}
mkknowledge "$HASH"

# 1) No knowledge.md → both commands are a clean no-op.
mkdir -p "$T/empty/.talpi"
out="$(sh "$K" check "$T/empty")" && ok || fail "check without knowledge.md should exit 0"
echo "$out" | grep -q 'no knowledge.md' && ok || fail "check without knowledge.md: wrong message"

# 2) Valid file → check and replay both clean, exit 0.
out="$(sh "$K" check "$P")" && ok || fail "valid knowledge.md: check should exit 0"
echo "$out" | grep -q 'decision ok:' && ok || fail "valid: no decision ok line"
echo "$out" | grep -q 'fact ok:' && ok || fail "valid: no fact ok line"
echo "$out" | grep -q 'question ok:' && ok || fail "valid: no question ok line"
out="$(sh "$K" replay "$P")" && ok || fail "valid knowledge.md: replay should exit 0"
echo "$out" | grep -q 'replay pass: scoped-greets' && ok || fail "valid: replay did not pass the fact"

# 3) Archive move: spec.md moves to archive/<date>/ (talpirefactor's
#    new-run-over-done-run move) — content-addressed provenance survives.
mkdir -p "$P/.talpi/archive/2026-09-01"
mv "$P/.talpi/spec.md" "$P/.talpi/archive/2026-09-01/spec.md"
out="$(sh "$K" check "$P")" && ok || fail "archive move: check should still pass"
echo "$out" | grep -q 'decision ok:' && ok || fail "archive move: quote no longer resolves"
mv "$P/.talpi/archive/2026-09-01/spec.md" "$P/.talpi/spec.md"

# 4) Distorted quote (model paraphrase) → decision fail, exit 1.
sed 's/CSV, not JSON/TSV, not JSON/' "$P/.talpi/knowledge.md" > "$T/k.tmp"
mv "$T/k.tmp" "$P/.talpi/knowledge.md"
out="$(sh "$K" check "$P")" && fail "distorted quote: check should exit 1" || ok
echo "$out" | grep -q 'decision fail: quote not found verbatim' && ok || fail "distorted quote: wrong failure"
mkknowledge "$HASH"

# 5) Statement-form question → fail; grammar violations → fail.
cat > "$P/.talpi/knowledge.md" <<'EOF'
# Knowledge

## Decisions

## Verified facts

## Open questions

- question: the CSV export is probably safe for multi-currency
EOF
out="$(sh "$K" check "$P")" && fail "statement question: check should exit 1" || ok
echo "$out" | grep -q 'question fail: statement form banned' && ok || fail "statement question: wrong failure"
printf '# Knowledge\n\n## Decisions\n\n## Open questions\n' > "$P/.talpi/knowledge.md"
out="$(sh "$K" check "$P")" && fail "missing section: check should exit 1" || ok
echo "$out" | grep -q 'structure fail:' && ok || fail "missing section: no structure failure"
mkknowledge "$HASH"

# 6) Replay gate: a fact whose command fails (or whose output diverges)
#    is reported per entry and fails the gate.
cat > "$P/.talpi/knowledge.md" <<EOF
# Knowledge

## Decisions

## Verified facts

- fact: scoped-greets
  command: cat scoped.txt
  expect: hello scope
  as of: $HASH
  scope: scoped.txt

- fact: broken-claim
  command: cat scoped.txt
  expect: text that is not in the file
  as of: $HASH
  scope: scoped.txt

## Open questions
EOF
out="$(sh "$K" replay "$P")" && fail "broken fact: replay should exit 1" || ok
echo "$out" | grep -q 'replay pass: scoped-greets' && ok || fail "broken fact: healthy fact should still pass"
echo "$out" | grep -q 'replay fail: broken-claim' && ok || fail "broken fact: no per-entry failure"
mkknowledge "$HASH"

# 7) Staleness: scope file changed since `as of` → flagged for demotion.
echo "drift" >> "$P/scoped.txt"
git -C "$P" add -A
git -C "$P" commit -qm drift
out="$(sh "$K" check "$P")" && fail "stale fact: check should exit 1" || ok
echo "$out" | grep -q 'stale — demote to question' && ok || fail "stale fact: no demotion flag"

# 8) An unresolvable `as of` hash is a failure, not a silent pass.
mkknowledge deadbeef
out="$(sh "$K" check "$P")" && fail "bogus hash: check should exit 1" || ok
echo "$out" | grep -q "fact fail: 'as of' hash" && ok || fail "bogus hash: wrong failure"

# 9) Journal append-only guard: normal appends fine; editing a committed
#    line refuses further appends, and status surfaces a warning.
sh "$J" 'phase 1 started (base: abc1234)' "$P" >/dev/null && ok || fail "append onto clean journal refused"
sed 's/spec approved/spec REWRITTEN/' "$P/.talpi/journal.md" > "$T/j.tmp"
mv "$T/j.tmp" "$P/.talpi/journal.md"
sh "$J" 'another event' "$P" 2>/dev/null && fail "append onto tampered journal accepted" || ok
sh "$STATUS" "$P" | grep -q 'warning: journal.md tampered' && ok || fail "status: no tamper warning"
git -C "$P" checkout -q -- .talpi/journal.md
sh "$STATUS" "$P" | grep -q 'warning: journal.md tampered' && fail "status: tamper warning on clean journal" || ok

# 10) Lane isolation: the verification lane's prompts never reference
#     knowledge.md — verifier, run reviewer, and spec panel prompts.
for p in \
  "$ROOT/skills/talpirun/references/verifier-prompt.md" \
  "$ROOT/skills/talpirun/references/run-reviewer-prompt.md" \
  "$ROOT/skills/talpispec/references/panel-reviewers.md"; do
  if grep -qi 'knowledge' "$p"; then
    fail "$(basename "$p") references knowledge — the verification lane must stay blind"
  else
    ok
  fi
done

# 11) talpirun carries the write rule and the isolation prohibition:
#     distill → gate → journal `knowledge distilled` before `run done`,
#     and knowledge.md never enters a verifier/reviewer dispatch nor
#     launders into conventions.md.
R="$ROOT/skills/talpirun/SKILL.md"
oneline="$(tr '\n' ' ' < "$R")"
grep -q 'talpi-knowledge.sh' "$R" && ok || fail "talpirun: never calls the knowledge gate script"
grep -q 'knowledge distilled' "$R" && ok || fail "talpirun: no 'knowledge distilled' journal event"
echo "$oneline" | grep -q 'never enters a verifier or run-reviewer dispatch' && ok \
  || fail "talpirun: no prohibition on passing knowledge.md into verifier/reviewer dispatches"
echo "$oneline" | grep -q 'never merged into `.talpi/conventions.md`' && ok \
  || fail "talpirun: no conventions-laundering rule"

# 12) The implementation lane reads knowledge.md by type — spec and
#     refactor recon replay before trusting, mark knowledge-derived
#     spec items with their origin, and keep the panel blind; refactor
#     conventions stay this-run-mined.
SPEC="$ROOT/skills/talpispec/SKILL.md"
REF="$ROOT/skills/talpirefactor/SKILL.md"
for f in "$SPEC" "$REF"; do
  grep -q 'talpi-knowledge.sh' "$f" && ok || fail "$(basename "$(dirname "$f")"): never gates inherited facts through talpi-knowledge.sh"
  grep -q '(from knowledge.md)' "$f" && ok || fail "$(basename "$(dirname "$f")"): no origin mark for knowledge-derived spec items"
done
tr '\n' ' ' < "$SPEC" | grep -q 'panel never sees knowledge.md' && ok \
  || fail "talpispec: panel blindness to knowledge.md not stated"
tr '\n' ' ' < "$REF" | tr -s ' ' | grep -q 'never copied from knowledge.md' && ok \
  || fail "talpirefactor: conventions not fenced off from knowledge.md"

echo "knowledge.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
