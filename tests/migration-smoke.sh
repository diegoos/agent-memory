#!/usr/bin/env bash
# Migration smoke: 0.0.14-shaped memory → 0.1.0 contract expectations.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
skeleton="$repo_root/skills/agent-memory/vendor/memory"
update_md="$repo_root/skills/agent-memory/vendor/UPDATE.md"
hook_dir="$repo_root/hooks/agent-memory-hooks"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

grep -q '## 0.1.0' "$update_md" || fail "UPDATE.md missing 0.1.0"
grep -q 'graph reshape' "$update_md" || fail "UPDATE.md missing graph reshape"
grep -q 'update-graph.md' "$update_md" || fail "UPDATE.md missing update-graph.md"
grep -q 'Supersedes 0.0.14' "$update_md" || fail "UPDATE.md 0.2.1 must supersede 0.0.14 keep-mirrors"
grep -q 'safe:' "$update_md" || fail "UPDATE.md 0.1.0 missing safe items"
grep -q 'sensitive:' "$update_md" || fail "UPDATE.md 0.1.0 missing sensitive items"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

git init -q
git config user.email test@example.com
git config user.name test

mkdir -p .agents
cp -R "$skeleton" .agents/memory
printf '0.0.14\n' >.agents/memory/.version

# Plant legacy 0.0.14-style active-work noise
mkdir -p .agents/memory/active-work
cat >.agents/memory/active-work/legacy-branch.md <<'EOF'
# Active work — legacy-branch

## Task
Migrate fixture

## Progress
- Old progress

## Touched files
- `src/old.ts`

## Blockers
None
EOF

# Copy scaffold lives in the skill, not in project memory
aw_template="$repo_root/skills/agent-memory/references/active-work-template.md"
grep -q 'Next step' "$aw_template" || fail "skill template missing Next step"
grep -q 'Validation' "$aw_template" || fail "skill template missing Validation"
! grep -q 'Touched files' "$aw_template" || fail "skill template still has Touched files"
[[ ! -e .agents/memory/active-work/TEMPLATE.md ]] ||
  fail "init skeleton must not install active-work/TEMPLATE.md"
printf '0.1.0\n' >.agents/memory/.version

# Consumer semantic content preserved until confirmed prune
grep -q 'Touched files' .agents/memory/active-work/legacy-branch.md ||
  fail "consumer active-work should remain until confirmed migration"
grep -q 'Migrate fixture' .agents/memory/active-work/legacy-branch.md ||
  fail "consumer task content lost"

# Ensure .gitignore present (dotfile)
[[ -f .agents/memory/.gitignore ]] || fail "memory .gitignore missing after copy"
grep -q '\.hook-sync-state' .agents/memory/.gitignore ||
  fail ".gitignore must ignore .hook-sync-state"

# Hooks on migrated tree must not rewrite Markdown
cp "$hook_dir"/agent-memory-*.sh .
chmod +x agent-memory-*.sh
md_before=$(find .agents/memory -name '*.md' | sort | while read -r f; do cksum "$f"; done | cksum)
printf '{"session_id":"mig","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  ./agent-memory-session.sh >/dev/null
printf '{"session_id":"mig","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=mig \
  ./agent-memory-sync.sh >/dev/null
md_after=$(find .agents/memory -name '*.md' | sort | while read -r f; do cksum "$f"; done | cksum)
[[ "$md_before" == "$md_after" ]] || fail "hooks altered Markdown during migration smoke"

printf 'ok - migration 0.0.14→0.1.0 smoke\n'
