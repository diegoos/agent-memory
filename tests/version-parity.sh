#!/usr/bin/env bash
# Assert package / skill / installer / pins / UPDATE / CHANGELOG share one version.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

version=$(node -p 'require("./package.json").version')
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid package.json version: $version"

skill_v=$(grep -E '^\s+version:\s*"' skills/agent-memory/SKILL.md | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/')
[[ "$skill_v" == "$version" ]] || fail "SKILL.md version $skill_v != $version"

fallback=$(grep -E 'VERSION="\$\{VERSION:-' hooks/install-hooks.sh | sed -E 's/.*VERSION:-([0-9.]+)\}.*/\1/')
[[ "$fallback" == "$version" ]] || fail "install-hooks fallback $fallback != $version"

grep -Fq "## $version" skills/agent-memory/vendor/UPDATE.md ||
  fail "UPDATE.md missing ## $version"

grep -Fq "## [$version]" CHANGELOG.md ||
  fail "CHANGELOG.md missing ## [$version]"

# Sample pinned blob URLs / clone branch must match current version
for f in \
  skills/agent-memory/vendor/memory/instructions.md \
  skills/agent-memory/references/agent-block.md \
  skills/agent-memory/references/install-hooks.md \
  skills/agent-memory/references/init.md \
  skills/agent-memory/vendor/README.md \
  README.md; do
  if grep -Eoq 'blob/[0-9]+\.[0-9]+\.[0-9]+|--branch [0-9]+\.[0-9]+\.[0-9]+|agent-memory#[0-9]+\.[0-9]+\.[0-9]+' "$f"; then
    grep -Eq "blob/${version}|--branch ${version}|agent-memory#${version}|e\.g\. \`${version}\`|e\.g\. ${version}" "$f" ||
      fail "$f pins do not include $version"
  fi
done

# No stray older pin that is not historical changelog/update text
if grep -RnE 'blob/0\.0\.14|--branch 0\.0\.14|agent-memory#0\.0\.14' \
  README.md skills/agent-memory/references skills/agent-memory/vendor/README.md \
  skills/agent-memory/vendor/memory hooks/README.md 2>/dev/null |
  grep -v UPDATE.md | grep -v 'e\.g\. 0\.0\.14 removal'; then
  fail "found stale 0.0.14 pins outside historical notes"
fi

printf 'ok - version parity %s\n' "$version"
