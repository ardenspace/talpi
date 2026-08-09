#!/bin/sh
# Contract test: every skill satisfies the Claude Code skill format
# and its references/ files are wired both ways.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

[ -d "$ROOT/skills" ] || { echo "FAIL: no skills/ directory"; exit 1; }

for dir in "$ROOT"/skills/*/; do
  s="$dir/SKILL.md"
  base="$(basename "$dir")"
  if [ ! -f "$s" ]; then fail "$base: missing SKILL.md"; continue; fi
  # 1) Frontmatter: first line ---, has name: and description:.
  [ "$(head -1 "$s")" = "---" ] && ok || fail "$base: SKILL.md missing frontmatter"
  grep -q "^name: $base$" "$s" && ok || fail "$base: frontmatter name != dir name"
  grep -q "^description: ." "$s" && ok || fail "$base: missing description"
  # 2) Every references/ file is mentioned in SKILL.md...
  if [ -d "$dir/references" ]; then
    for r in "$dir"/references/*.md; do
      rn="$(basename "$r")"
      grep -q "$rn" "$s" && ok || fail "$base: references/$rn never mentioned in SKILL.md"
    done
  fi
  # 3) ...and every references/*.md mention resolves to a real file.
  for rn in $(grep -oE 'references/[a-z-]+\.md' "$s" | sort -u); do
    [ -f "$dir/$rn" ] && ok || fail "$base: SKILL.md mentions missing $rn"
  done
done

# 4) Channel-neutrality: skill prose never names a specific chat product.
hits="$(grep -rniE 'telegram|slack|discord' "$ROOT/skills" 2>/dev/null)" || true
[ -z "${hits:-}" ] && ok || fail "channel-specific terms in skills:
$hits"

# 5) Step vocabulary: work units are "steps", never "tasks" — avoids
#    collision with the harness's own Task/subagent naming.
hits="$(grep -rniE '\btasks?\b' "$ROOT/skills" 2>/dev/null)" || true
[ -z "${hits:-}" ] && ok || fail "\"task\" wording in skills (use \"step\"):
$hits"

# 6) No repo-relative doc paths: a skill runs inside the target
#    project, where this repo's docs/ does not exist.
hits="$(grep -rn 'docs/' "$ROOT/skills" 2>/dev/null)" || true
[ -z "${hits:-}" ] && ok || fail "repo-relative docs/ path in skills:
$hits"

# 7) State-model invariants: acceptance rejection reopens the loop as
#    a real phase, and a halt ruling doesn't bounce between skills.
R="$ROOT/skills/talpirun/SKILL.md"
grep -q 'Acceptance fixes' "$R" && ok || fail "talpirun: rejection must append an Acceptance fixes phase"
grep -q 'bouncing back' "$R" && ok || fail "talpirun: guard missing the halt-ruling exception"

# 8) Phase-loop hardening: mechanical tripwire before step commits,
#    unconditional intra-phase carry of created files.
grep -q 'tripwire' "$R" && ok || fail "talpirun: no mechanical tripwire before step commits"
grep -q 'Prior work this phase' "$R" && ok || fail "talpirun: no Prior-work-this-phase carry block"

# 9) The hook injects guidance; it cannot invoke a skill. Prose must
#    not overclaim "automatic" routing.
hits="$(grep -rniE 'routes? automatically' "$ROOT/skills" "$ROOT/README.md" 2>/dev/null)" || true
[ -z "${hits:-}" ] && ok || fail "\"routes automatically\" overclaim:
$hits"

echo "skills.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
