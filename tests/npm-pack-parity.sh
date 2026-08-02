#!/usr/bin/env bash
# Assert npm pack ships the pack-safe memory ignore template (npm omits .gitignore)
# and that package/bin/cli.js matches a fresh private rebuild (prepack / publish integrity).

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

TMP=$(mktemp -d)
trap 'rm -f "$TMP"/*.tgz; rm -rf "$TMP"' EXIT

tarball=$(npm pack --ignore-scripts=false --pack-destination "$TMP" 2>/dev/null | tail -1)
[[ -n "$tarball" && -f "$TMP/$tarball" ]] || fail "npm pack did not produce a tarball"

tar -tzf "$TMP/$tarball" >"$TMP/list.txt"
grep -qx 'package/skills/agent-memory/vendor/memory/gitignore' "$TMP/list.txt" ||
  fail "npm pack must include vendor/memory/gitignore (pack-safe hook-state ignore)"
! grep -E 'package/skills/agent-memory/vendor/memory/\.gitignore$' "$TMP/list.txt" ||
  fail "unexpected: npm pack included vendor/memory/.gitignore (document if intentional)"

tar -xOf "$TMP/$tarball" package/skills/agent-memory/vendor/memory/gitignore >"$TMP/packed-gitignore"
grep -qx '.hook-sync-state' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state"
grep -qx '.hook-sync-state.lock' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state.lock"
grep -qx '.hook-sync-state.*' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state.* temp siblings"

grep -qx 'package/bin/cli.js' "$TMP/list.txt" ||
  fail "npm pack must include bin/cli.js"

rebuild=$(mktemp)
trap 'rm -f "$rebuild" "$TMP"/*.tgz; rm -rf "$TMP"' EXIT
bun build ./install.ts --outfile "$rebuild" --target node --format cjs \
  --banner '#!/usr/bin/env node' >/dev/null
tar -xOf "$TMP/$tarball" package/bin/cli.js >"$TMP/packed-cli.js"
cmp -s "$rebuild" "$TMP/packed-cli.js" ||
  fail "packed bin/cli.js must match a fresh build (tamper/stale gate)"

printf 'ok - npm pack parity (vendor/memory/gitignore + bin/cli.js)\n'
