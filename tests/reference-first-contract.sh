#!/usr/bin/env bash
# Static invariant checks for the reference-first + ephemeral-hooks contract.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
instructions="$repo_root/skills/agent-memory/vendor/memory/instructions.md"
bootstrap="$repo_root/skills/agent-memory/references/bootstrap.md"
lint="$repo_root/skills/agent-memory/references/lint.md"
sync="$repo_root/skills/agent-memory/references/sync.md"
consolidate="$repo_root/skills/agent-memory/references/consolidate.md"
agent_block="$repo_root/skills/agent-memory/references/agent-block.md"
session_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-session.sh"
sync_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-sync.sh"
skeleton="$repo_root/skills/agent-memory/vendor/memory"
cursor_hooks="$repo_root/hooks/cursor/hooks.json"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file=$1
  local text=$2
  local scenario=$3

  grep -Fq -- "$text" "$file" || fail "$scenario"
}

assert_absent() {
  local file=$1
  local text=$2
  local scenario=$3

  grep -Fq -- "$text" "$file" && fail "$scenario" || true
}

assert_before() {
  local file=$1
  local first=$2
  local second=$3
  local scenario=$4
  local first_line
  local second_line

  first_line=$(grep -nFm1 -- "$first" "$file" | cut -d: -f1) || true
  second_line=$(grep -nFm1 -- "$second" "$file" | cut -d: -f1) || true
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] ||
    fail "$scenario"
}

# --- Skeleton shape ---
[[ ! -e "$skeleton/learnings.md" ]] || fail "learnings.md must stay out of the skeleton"
for required in instructions.md index.md current.md decisions.md log.md \
                active-work/TEMPLATE.md .gitignore; do
  [[ -e "$skeleton/$required" ]] || fail "skeleton missing $required"
done
assert_contains "$skeleton/.gitignore" '.hook-sync-state' \
  "skeleton .gitignore ignores hook state"
assert_contains "$skeleton/current.md" '## In progress' "current keeps In progress"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Task' "active-work keeps Task"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Next step' "active-work keeps Next step"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Validation' "active-work keeps Validation"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Assumptions / open questions' \
  "active-work keeps Assumptions"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Rejected approaches' \
  "active-work keeps Rejected approaches"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## References' "active-work keeps References"
assert_contains "$skeleton/active-work/TEMPLATE.md" 'Checkpoint:' "active-work has Checkpoint"
assert_absent "$skeleton/active-work/TEMPLATE.md" '## Touched files' \
  "Touched files must be removed from template"
assert_contains "$skeleton/log.md" 'semantic' "log documents semantic-only"
assert_contains "$skeleton/decisions.md" 'Status: active | superseded' "decisions Status field"
assert_contains "$skeleton/decisions.md" 'Superseded by:' "decisions supersession"
assert_contains "$skeleton/decisions.md" 'Rejected alternatives' \
  "decisions format lists Rejected alternatives"

# --- Contract invariants in instructions.md ---
assert_contains "$instructions" '## Always load' "always-load policy present"
assert_contains "$instructions" '## Authority by information type' "authority section present"
assert_contains "$instructions" '## Retention gate and lifecycle' "retention gate present"
assert_contains "$instructions" 'Reusable in another session?' "gate asks reusability"
assert_contains "$instructions" 'link + delta/relevance' "pointer-over-copy gate"
assert_contains "$instructions" 'Minimum pointer line:' "minimum pointer format"
assert_contains "$instructions" '### Harness parity — memory contract' "harness parity SoT heading"
assert_contains "$instructions" 'Hooks own ephemeral evidence only:' "hooks write boundary"
assert_contains "$instructions" 'Agent owns all versioned Markdown:' "agent ownership"
assert_contains "$instructions" 'never create or edit Markdown' "hooks never edit markdown"
assert_contains "$instructions" '## Memory lint boundaries' "lint boundaries summary"
assert_contains "$instructions" \
  '- [YYYY-MM-DD] [learning|pitfall] [topic] insight — evidence: path|link; use when: trigger; verified: YYYY-MM-DD; invalidate when: condition.' \
  "learning/pitfall entry format"
assert_contains "$instructions" 'pending-doc' "pending-doc lifecycle"
assert_absent "$instructions" 'Soft warning budgets:' \
  "soft budgets stay in lint reference, not always-load"

# --- Init / update ensure .gitignore (dotfile-safe) ---
init="$repo_root/skills/agent-memory/references/init.md"
update="$repo_root/skills/agent-memory/references/update.md"
assert_contains "$init" 'vendor/memory/.gitignore' "init names vendor .gitignore"
assert_contains "$init" 'explicitly' "init requires explicit .gitignore write"
assert_contains "$init" 'verify `.agents/memory/.gitignore` exists' \
  "init verifies .gitignore after copy"
assert_contains "$update" 'Ensure `.agents/memory/.gitignore` exists' \
  "update ensures .gitignore"
assert_contains "$update" 'do **not** rely on directory listings' \
  "update does not rely on Glob for .gitignore"
assert_contains "$lint" '.agents/memory/.gitignore' "lint checks .gitignore"

# --- Bootstrap ---
assert_contains "$bootstrap" 'A — Source inventory.' "bootstrap inventories sources"
assert_contains "$bootstrap" 'never paste' "bootstrap does not copy bodies"
assert_contains "$bootstrap" 'Do **not** create `vision.md`' "bootstrap forbids vision mirrors"
assert_contains "$bootstrap" '[learning]' "bootstrap mentions learning tag"

# --- Lint ---
assert_contains "$lint" 'Legacy mirrors' "lint identifies mirrors"
assert_contains "$lint" 'never deletes' "lint does not delete user files"
assert_contains "$lint" '## Next step' "lint checks Next step"
assert_contains "$lint" '## Validation' "lint checks Validation"
assert_contains "$lint" 'empty-log-heading' "lint checks empty headings"
assert_contains "$lint" 'legacy-path-bullet' "lint checks legacy path bullets"
assert_contains "$lint" 'Soft budgets (warnings only)' "soft budgets live in lint"

# --- Sync ---
assert_contains "$sync" 'Sync writes only to:' "sync four-file boundary"
for target in 'current.md' 'active-work/<branch>.md' 'log.md' 'index.md'; do
  assert_contains "$sync" "$target" "sync boundary includes $target"
done
assert_contains "$sync" 'It **never** touches `decisions.md`, `learnings.md`,' \
  "sync excludes durable recall"
assert_contains "$sync" 'Hooks never write Markdown' "sync documents ephemeral hooks"
assert_contains "$sync" '_Validation_' "sync fills Validation"
assert_contains "$sync" '_Workflow_' "sync links live Workflow section"

# --- Consolidate ---
assert_contains "$consolidate" 'Never prune the **current session** heading' \
  "consolidate preserves current session"
assert_contains "$consolidate" "Never prune the **current branch's** active-work file." \
  "consolidate preserves current active-work"
assert_before "$consolidate" \
  'Additions/promotions first:' \
  'Only after a promotion is **approved**, propose removing its origin' \
  "consolidate promotes before pruning"
assert_contains "$consolidate" 'Legacy `## Touched files`' \
  "consolidate cleans legacy Touched files"

# --- Context layer stays short ---
assert_contains "$agent_block" 'Read `.agents/memory/instructions.md`' \
  "agent-block requires Read instructions"
assert_contains "$agent_block" '_Harness parity — memory contract_' \
  "agent-block links harness parity"
assert_contains "$session_sh" 'Hooks store ephemeral evidence only' \
  "session msg keeps ephemeral obligation"
assert_contains "$sync_sh" 'no Markdown writes' "sync script header documents no Markdown"

# --- Harness configs omit per-tool events ---
assert_absent "$cursor_hooks" 'postToolUse' "cursor omits postToolUse"
assert_absent "$cursor_hooks" 'afterFileEdit' "cursor omits afterFileEdit"
for cfg in \
  "$repo_root/hooks/claude-code/settings.json" \
  "$repo_root/hooks/codex/hooks.json" \
  "$repo_root/hooks/copilot/agent-memory.json" \
  "$repo_root/hooks/gemini/settings.json"; do
  assert_absent "$cfg" 'PostToolUse' "no PostToolUse in $(basename "$cfg")"
  assert_absent "$cfg" 'postToolUse' "no postToolUse in $(basename "$cfg")"
  assert_absent "$cfg" 'AfterTool' "no AfterTool in $(basename "$cfg")"
done

printf 'ok - reference-first Markdown contracts\n'
