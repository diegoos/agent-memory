#!/usr/bin/env bash
# Static invariant checks for the reference-first memory contract.
# Prefer stable headings / boundary phrases over incidental prose.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
instructions="$repo_root/skills/agent-memory/vendor/memory/instructions.md"
bootstrap="$repo_root/skills/agent-memory/references/bootstrap.md"
lint="$repo_root/skills/agent-memory/references/lint.md"
sync="$repo_root/skills/agent-memory/references/sync.md"
consolidate="$repo_root/skills/agent-memory/references/consolidate.md"
agent_block="$repo_root/skills/agent-memory/references/agent-block.md"
session_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-session.sh"
skeleton="$repo_root/skills/agent-memory/vendor/memory"

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
for required in instructions.md index.md current.md decisions.md log.md active-work/TEMPLATE.md; do
  [[ -e "$skeleton/$required" ]] || fail "skeleton missing $required"
done
assert_contains "$skeleton/current.md" '## In progress' "current keeps hook heading"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Task' "active-work keeps Task"
assert_contains "$skeleton/active-work/TEMPLATE.md" '## Touched files' "active-work keeps Touched files"
assert_contains "$skeleton/active-work/TEMPLATE.md" '_No active task._' "task placeholder intact"
assert_contains "$skeleton/active-work/TEMPLATE.md" '_none_' "none placeholders intact"

# --- Contract invariants in instructions.md ---
assert_contains "$instructions" '## Always load' "always-load policy present"
assert_contains "$instructions" '## Authority by information type' "authority section present"
assert_contains "$instructions" '## Retention gate and lifecycle' "retention gate present"
assert_contains "$instructions" 'Reusable in another session?' "gate asks reusability"
assert_contains "$instructions" 'link + delta/relevance' "pointer-over-copy gate"
assert_contains "$instructions" 'Minimum pointer line:' "minimum pointer format"
assert_contains "$instructions" '### Harness parity — memory contract' "harness parity SoT heading"
assert_contains "$instructions" 'Hooks never write:' "hooks write boundary"
assert_contains "$instructions" 'Agent owns meaning:' "agent ownership"
assert_contains "$instructions" '## Memory lint boundaries' "lint boundaries summary"
assert_contains "$instructions" \
  '- [YYYY-MM-DD] [topic] insight — evidence: path|link; use when: trigger.' \
  "learning entry format"
assert_contains "$instructions" 'pending-doc' "pending-doc lifecycle"
assert_absent "$instructions" 'Soft warning budgets:' \
  "soft budgets stay in lint reference, not always-load"

# --- Bootstrap: inventory, no mirrors, no invented vision ---
assert_contains "$bootstrap" 'A — Source inventory.' "bootstrap inventories sources"
assert_contains "$bootstrap" 'never paste' "bootstrap does not copy bodies"
assert_contains "$bootstrap" 'optional single pointer to ADR index/dir' "bootstrap ADR pointer"
assert_contains "$bootstrap" 'report the gap — do not write a vision file.' \
  "bootstrap does not invent vision"
assert_contains "$bootstrap" 'Create `learnings.md` only when at least one fact passes the gate' \
  "bootstrap gates learnings"
assert_contains "$bootstrap" 'Do **not** create `vision.md`' "bootstrap forbids vision mirrors"

# --- Lint: legacy mirrors reported, not auto-deleted ---
assert_contains "$lint" 'Legacy mirrors' "lint identifies mirrors"
assert_contains "$lint" 'never deletes' "lint does not delete user files"
assert_contains "$lint" 'legacy mirror files' "lint does not delete mirrors"
assert_contains "$lint" 'Soft budgets (warnings only)' "soft budgets live in lint"

# --- Sync: four-file boundary, no path duplication ---
assert_contains "$sync" 'Sync writes only to:' "sync four-file boundary"
for target in 'current.md' 'active-work/<branch>.md' 'log.md' 'index.md'; do
  assert_contains "$sync" "$target" "sync boundary includes $target"
done
assert_contains "$sync" 'It **never** touches `decisions.md`, `learnings.md`,' \
  "sync excludes durable recall"
assert_contains "$sync" '**do not repeat paths**' "sync does not duplicate paths"
assert_contains "$sync" '_Workflow_' "sync links live Workflow section"

# --- Consolidate: preserve active state; promote before prune ---
assert_contains "$consolidate" 'Never prune the **current session** heading' \
  "consolidate preserves current session"
assert_contains "$consolidate" "Never prune the **current branch's** active-work file." \
  "consolidate preserves current active-work"
assert_before "$consolidate" \
  'Additions/promotions first:' \
  'Only after a promotion is **approved**, propose removing its origin' \
  "consolidate promotes before pruning"
assert_contains "$consolidate" 'If promotion is declined, **keep** the' \
  "declined promotion keeps origin"

# --- Context layer stays short (no method duplication) ---
assert_contains "$agent_block" 'Read `.agents/memory/instructions.md`' \
  "agent-block requires Read instructions"
assert_contains "$agent_block" '_Harness parity — memory contract_' \
  "agent-block links harness parity (not removed Plain-Markdown section)"
assert_absent "$agent_block" 'Treat AGENTS/README/specs/ADRs/code' \
  "agent-block does not restate full method"
assert_contains "$session_sh" 'Write links/deltas, not copies' \
  "session msg keeps core obligation"
assert_absent "$session_sh" 'Prefer AGENTS/README/specs/ADRs/code as canonical' \
  "session msg does not restate full method"

printf 'ok - reference-first Markdown contracts\n'
