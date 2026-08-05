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

echo "manifest.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
