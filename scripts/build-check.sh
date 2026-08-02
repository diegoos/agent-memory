#!/usr/bin/env bash
# Verify committed bin/cli.js matches a fresh private rebuild (no minify).
# Invoked by `bun run build:check` / prepack / check / CI.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

out=$(mktemp)
trap 'rm -f "$out"' EXIT

bun build ./install.ts --outfile "$out" --target node --format cjs \
  --banner '#!/usr/bin/env node'
cmp -s bin/cli.js "$out"
