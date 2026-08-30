#!/usr/bin/env bash
# Run the full agent-memory test suite (shell fixtures + bun unit tests).
# Invoked by `bun run test` / `npm test`.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

# Integrity before any fixture that may rebuild bin/cli.js (cli-install).
bun run build:check

bash tests/reference-first-contract.sh
bash tests/hooks-checkpoint.sh
bash tests/json-escape.sh
bash tests/version-parity.sh
bash tests/hooks-merge.sh
bash tests/cli-install.sh
bash tests/lockfile-only.sh
bash tests/migration-smoke.sh
bash tests/npm-pack-parity.sh
bun test tests/opencode-safe-script.test.ts tests/env-allowlist-parity.test.ts tests/semver.test.ts
