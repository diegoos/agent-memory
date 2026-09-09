#!/usr/bin/env bash
# Verify committed bin/cli.js matches a fresh private rebuild (no minify).
# Invoked by `bun run build:check` / prepack / check / CI.
# Bun must match `.bun-version` (same pin as `.github/workflows/pr-checks.yml`).

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

expected=$(tr -d '[:space:]' < .bun-version)
got=$(bun --version)
if [[ "$got" != "$expected" ]]; then
  printf 'error: bun %s (need %s from .bun-version)\n' "$got" "$expected" >&2
  printf 'hint: install that Bun, then bun run build\n' >&2
  exit 1
fi

out=$(mktemp)
trap 'rm -f "$out"' EXIT

bun build ./src/cli.ts --outfile "$out" --target node --format cjs \
  --banner '#!/usr/bin/env node'
if ! cmp -s bin/cli.js "$out"; then
  printf 'error: bin/cli.js does not match bun build of src/cli.ts\n' >&2
  printf 'hint: bun run build\n' >&2
  exit 1
fi
