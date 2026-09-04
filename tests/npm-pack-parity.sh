#!/usr/bin/env bash
# Assert npm pack ships the pack-safe memory ignore template (npm omits .gitignore),
# package/bin/cli.js matches a fresh private rebuild (prepack / publish integrity),
# and published-pack CLI semantics differ from a local checkout (no src/ →
# same-SemVer update skips unless --force).

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

TMP=$(mktemp -d)
PROJ=""
trap 'rm -f "$TMP"/*.tgz; rm -rf "$TMP" ${PROJ:+"$PROJ"}' EXIT

tarball=$(npm pack --ignore-scripts=false --pack-destination "$TMP" 2>/dev/null | tail -1)
[[ -n "$tarball" && -f "$TMP/$tarball" ]] || fail "npm pack did not produce a tarball"

tar -tzf "$TMP/$tarball" >"$TMP/list.txt"
grep -qx 'package/skills/agent-memory/vendor/memory/gitignore' "$TMP/list.txt" ||
  fail "npm pack must include vendor/memory/gitignore (pack-safe hook-state ignore)"
! grep -E 'package/skills/agent-memory/vendor/memory/\.gitignore$' "$TMP/list.txt" ||
  fail "unexpected: npm pack included vendor/memory/.gitignore (document if intentional)"

# Published pack must omit src/ — CLI uses src/cli.ts to detect local checkout.
! grep -E 'package/src/' "$TMP/list.txt" ||
  fail "npm pack must not include src/ (would mis-detect published pack as local checkout)"

tar -xOf "$TMP/$tarball" package/skills/agent-memory/vendor/memory/gitignore >"$TMP/packed-gitignore"
grep -qx '.hook-sync-state' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state"
grep -qx '.hook-sync-state.lock' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state.lock"
grep -qx '.hook-sync-state.*' "$TMP/packed-gitignore" ||
  fail "packed gitignore must ignore .hook-sync-state.* temp siblings"

grep -qx 'package/bin/cli.js' "$TMP/list.txt" ||
  fail "npm pack must include bin/cli.js"
grep -qx 'package/skills/agent-memory/SKILL.md' "$TMP/list.txt" ||
  fail "npm pack must include skills/agent-memory for install skill"
grep -qx 'package/hooks/install-hooks.sh' "$TMP/list.txt" ||
  fail "npm pack must include hooks/install-hooks.sh"

rebuild=$(mktemp)
trap 'rm -f "$rebuild" "$TMP"/*.tgz; rm -rf "$TMP" ${PROJ:+"$PROJ"}' EXIT
bun build ./src/cli.ts --outfile "$rebuild" --target node --format cjs \
  --banner '#!/usr/bin/env node' >/dev/null
tar -xOf "$TMP/$tarball" package/bin/cli.js >"$TMP/packed-cli.js"
cmp -s "$rebuild" "$TMP/packed-cli.js" ||
  fail "packed bin/cli.js must match a fresh build (tamper/stale gate)"

# --- Published pack install/update semantics (npx shape) ---
tar -xzf "$TMP/$tarball" -C "$TMP"
packed_cli="$TMP/package/bin/cli.js"
[[ -f "$packed_cli" ]] || fail "extracted packed cli missing"
[[ ! -e "$TMP/package/src" ]] || fail "extracted pack unexpectedly has src/"

PROJ=$(mktemp -d)
AGENT_MEMORY_PROJECT_DIR="$PROJ" node "$packed_cli" install skill >/dev/null
[[ -f "$PROJ/.agents/skills/agent-memory/SKILL.md" ]] ||
  fail "packed CLI failed to install skill from package tree"

marker="$PROJ/.agents/skills/agent-memory/PUBLISHED_NO_REFRESH_MARKER.md"
echo stale >"$marker"
upd=$(AGENT_MEMORY_PROJECT_DIR="$PROJ" node "$packed_cli" update --yes)
echo "$upd" | grep -qi 'Already up to date\|already at' ||
  fail "published pack same-SemVer update should skip refresh: $upd"
[[ -e "$marker" ]] ||
  fail "published pack update --yes must not refresh skill when SemVer matches"

force=$(AGENT_MEMORY_PROJECT_DIR="$PROJ" node "$packed_cli" update --force --yes)
echo "$force" | grep -qi 'Update complete\|skill ready\|refresh' ||
  fail "published pack update --force --yes unexpected: $force"
[[ ! -e "$marker" ]] ||
  fail "published pack update --force must refresh skill from package tree"

printf 'ok - npm pack parity (vendor/memory/gitignore + bin/cli.js + published install)\n'
