#!/bin/sh
# Runs every scripts/test/*.test.sh; exits non-zero if any fail.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS=0
for t in "$ROOT"/scripts/test/*.test.sh; do
  echo "== $(basename "$t")"
  sh "$t" || STATUS=1
done
exit $STATUS
