#!/usr/bin/env bash
# Fail if non-Bun lockfiles appear in the repo (Bun is the sole package manager).

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -f "$repo_root/bun.lock" ]] || fail "bun.lock missing"

for forbidden in package-lock.json yarn.lock pnpm-lock.yaml; do
  if [[ -e "$repo_root/$forbidden" ]]; then
    fail "forbidden lockfile present: $forbidden"
  fi
done

printf 'ok - bun lockfile only\n'
