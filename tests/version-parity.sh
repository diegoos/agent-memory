#!/usr/bin/env bash
# Assert package / skill / installer / pins / UPDATE / CHANGELOG share one version.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

# npm / SemVer 2.0: MAJOR.MINOR.PATCH with optional -prerelease and +build.
semver_re='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

version=$(node -p 'require("./package.json").version')
[[ "$version" =~ $semver_re ]] || fail "invalid package.json version: $version"

prerelease=0
[[ "$version" == *-* ]] && prerelease=1

skill_v=$(grep -E '^\s+version:\s*"' skills/agent-memory/SKILL.md | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
[[ "$skill_v" == "$version" ]] || fail "SKILL.md version $skill_v != $version"

fallback=$(grep -E 'VERSION="\$\{VERSION:-' hooks/install-hooks.sh | sed -E 's/.*VERSION:-([^}]+)\}.*/\1/')
[[ "$fallback" == "$version" ]] || fail "install-hooks fallback $fallback != $version"

if [[ "$prerelease" -eq 0 ]]; then
  grep -Fq "## $version" skills/agent-memory/vendor/UPDATE.md ||
    fail "UPDATE.md missing ## $version"
  grep -Fq "## [$version]" CHANGELOG.md ||
    fail "CHANGELOG.md missing ## [$version]"
else
  grep -Fq "## [$version]" CHANGELOG.md || grep -Fq "## [Unreleased]" CHANGELOG.md ||
    fail "CHANGELOG.md missing ## [$version] or ## [Unreleased] for prerelease $version"
fi

# Sample pinned blob URLs / clone branch must match current version.
# Prerelease packages may keep pins on the last released tag (no RC git tag yet).
pin_re='blob/[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?|--branch [0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?|agent-memory#[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'
for f in \
  skills/agent-memory/vendor/memory/instructions.md \
  skills/agent-memory/references/agent-block.md \
  skills/agent-memory/references/install-hooks.md \
  skills/agent-memory/references/init.md \
  skills/agent-memory/vendor/README.md \
  README.md; do
  if grep -Eoq "$pin_re" "$f"; then
    if [[ "$prerelease" -eq 1 ]]; then
      continue
    fi
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
