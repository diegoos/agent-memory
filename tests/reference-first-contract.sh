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
assert_contains "$instructions" '**Primary write path (agent, in the turn):**' \
  "workflow names primary write path"
assert_contains "$instructions" '**Catch-up (`/agent-memory sync`):**' \
  "workflow names sync as catch-up"
assert_contains "$instructions" 'without invoking the skill command' \
  "sync may be followed without skill invoke"
assert_contains "$instructions" '## Memory lint boundaries' "lint boundaries summary"
assert_contains "$instructions" '## [YYYY-MM-DD] [learning|pitfall] Short topic' \
  "learning/pitfall H2 entry format"
assert_contains "$instructions" '- Insight: reusable pattern in one or two sentences.' \
  "learning Insight field"
assert_contains "$instructions" 'learnings-<topic>.md' "topic split convention"
assert_contains "$instructions" 'when editing:' "scope hint convention"
assert_contains "$instructions" 'prefer what to do' "learning writing guidance"
assert_contains "$instructions" 'pending-doc' "pending-doc lifecycle"
assert_contains "$instructions" '/agent-memory learn' "learn command named in method"
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
assert_contains "$update" '`when editing:` scope hints' \
  "update preserves when-editing hints on index merge"
assert_contains "$lint" '.agents/memory/.gitignore' "lint checks .gitignore"

# --- Bootstrap ---
assert_contains "$bootstrap" 'A — Source inventory.' "bootstrap inventories sources"
assert_contains "$bootstrap" 'never paste' "bootstrap does not copy bodies"
assert_contains "$bootstrap" 'Do **not** create `vision.md`' "bootstrap forbids vision mirrors"
assert_contains "$bootstrap" 'H2 learning/pitfall format' "bootstrap uses H2 learning format"

# --- Lint ---
assert_contains "$lint" 'Legacy mirrors' "lint identifies mirrors"
assert_contains "$lint" 'never deletes' "lint does not delete user files"
assert_contains "$lint" '## Next step' "lint checks Next step"
assert_contains "$lint" '## Validation' "lint checks Validation"
assert_contains "$lint" 'empty-log-heading' "lint checks empty headings"
assert_contains "$lint" 'legacy-path-bullet' "lint checks legacy path bullets"
assert_contains "$lint" 'Soft budgets (warnings only)' "soft budgets live in lint"
assert_contains "$lint" 'stale-resume:' "lint checks checkpoint freshness vs HEAD"
assert_contains "$lint" 'evidence-pending:' "lint checks pending hook path evidence"
assert_contains "$lint" 'Legacy learning one-liner' "lint warns on legacy learning one-liners"
assert_contains "$lint" 'when editing:' "lint mentions scope hints"

# --- Sync ---
assert_contains "$sync" 'Sync writes only to:' "sync four-file boundary"
for target in 'current.md' 'active-work/<branch>.md' 'log.md' 'index.md'; do
  assert_contains "$sync" "$target" "sync boundary includes $target"
done
assert_contains "$sync" 'It **never** touches `decisions.md`, `learnings.md`,' \
  "sync excludes durable recall"
assert_contains "$sync" 'learnings-*.md' "sync excludes topic splits"
assert_contains "$sync" 'Hooks never write Markdown' "sync documents ephemeral hooks"
assert_contains "$sync" '^[0-9a-fA-F]{4,40}$' \
  "sync validates last_processed_head as hex before git"
assert_contains "$sync" '--end-of-options' \
  "sync prefers end-of-options for last-log-sha diff"
assert_contains "$sync" '_Validation_' "sync fills Validation"
assert_contains "$sync" '_Workflow_' "sync links live Workflow section"
assert_contains "$sync" '**Catch-up**' "sync is catch-up not primary write"
assert_contains "$sync" 'without invoking the skill command' \
  "sync steps usable without skill"

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
assert_contains "$consolidate" '**Split**' "consolidate can propose topic splits"
assert_contains "$consolidate" 'learnings-<topic>.md' "consolidate targets topic splits"

# --- Learn ---
learn="$repo_root/skills/agent-memory/references/learn.md"
assert_contains "$learn" 'retention gate' "learn applies retention gate"
assert_contains "$learn" 'learnings-<topic>.md' "learn supports topic splits"
assert_contains "$learn" 'Does **not** accept `--auto`' "learn has no auto"
assert_contains "$learn" 'when editing:' "learn may set scope hints"
assert_contains "$learn" 'merge conflict markers' "learn guards on conflicts"
assert_contains "$learn" 'uncommitted changes' "learn warns on dirty memory"
assert_contains "$learn" 'sanitized' "learn sanitizes topic slug"
assert_contains "$learn" 'do not guess' "learn does not guess ambiguous target"
assert_contains "$learn" 'already listed **without** a `when editing:` hint' \
  "learn updates existing index line"
assert_contains "$learn" '## [YYYY-MM-DD] [learning|pitfall] Short topic' \
  "learn uses canonical H2 entry"
skill="$repo_root/skills/agent-memory/SKILL.md"
assert_contains "$skill" '`learn`' "SKILL routes learn"
assert_contains "$skill" 'references/learn.md' "SKILL points at learn reference"
assert_contains "$skill" '| `/agent-memory learn`' "SKILL help lists learn"
assert_contains "$skill" '**Exception:** primary write in-turn' \
  "SKILL allows in-turn gated capture"
index="$repo_root/skills/agent-memory/vendor/memory/index.md"
assert_contains "$index" 'when editing:' "index documents scope hints"
assert_contains "$index" 'learnings-<topic>.md' "index documents topic splits"
assert_contains "$index" 'shape only' "index example marked as shape placeholder"
assert_absent "$index" 'learnings-hooks.md' \
  "index skeleton has no repo-specific example file"
assert_contains "$instructions" 'gitignore-style' \
  "when-editing glob dialect pinned"
assert_contains "$instructions" 'Match rule: load the file when any task path' \
  "when-editing match rule pinned"
assert_contains "$instructions" '**Duplicate rule**' "duplicate rule in SoT"
assert_contains "$instructions" '**Legacy one-liner**' "legacy one-liner documented in SoT"
assert_contains "$sync" 'never remove or reformat `when editing:` hints' \
  "sync preserves existing hints"
assert_contains "$consolidate" 'duplicate rule' \
  "consolidate applies duplicate rule"
assert_contains "$consolidate" 'Convert moved entries to the H2 form' \
  "consolidate converts on split"

# --- Context layer stays short ---
assert_contains "$agent_block" 'Read `.agents/memory/instructions.md`' \
  "agent-block requires Read instructions"
assert_contains "$agent_block" '**Primary write:**' "agent-block names primary write"
assert_contains "$agent_block" '**Catch-up:**' "agent-block names sync catch-up"
assert_contains "$agent_block" '_Harness parity — memory contract_' \
  "agent-block links harness parity"
assert_contains "$session_sh" 'build_session_context_msg' \
  "session uses contextual status builder"
assert_contains "$repo_root/hooks/agent-memory-hooks/agent-memory-common.sh" \
  'build_session_context_msg' "common.sh defines contextual session msg"
assert_contains "$sync_sh" 'no Markdown writes' "sync script header documents no Markdown"
pre_commit="$repo_root/hooks/git/pre-commit"
assert_contains "$pre_commit" 'Checkpoint' "pre-commit reminds when Checkpoint behind HEAD"

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
