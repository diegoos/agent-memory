#!/usr/bin/env bash
# Static invariant checks for the reference-first + ephemeral-hooks contract.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
instructions="$repo_root/skills/agent-memory/vendor/memory/instructions.md"
bootstrap="$repo_root/skills/agent-memory/references/bootstrap.md"
lint="$repo_root/skills/agent-memory/references/lint.md"
sync="$repo_root/skills/agent-memory/references/sync.md"
consolidate="$repo_root/skills/agent-memory/references/consolidate.md"
learn="$repo_root/skills/agent-memory/references/learn.md"
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
                active-work/TEMPLATE.md .gitignore gitignore; do
  [[ -e "$skeleton/$required" ]] || fail "skeleton missing $required"
done
assert_contains "$skeleton/.gitignore" '.hook-sync-state' \
  "skeleton .gitignore ignores hook state"
assert_contains "$skeleton/.gitignore" '.hook-sync-state.lock' \
  "skeleton .gitignore ignores hook state lock"
assert_contains "$skeleton/.gitignore" '.hook-sync-state.*' \
  "skeleton .gitignore ignores hook state temp siblings"
assert_contains "$skeleton/gitignore" '.hook-sync-state' \
  "skeleton pack-safe gitignore ignores hook state"
assert_contains "$skeleton/gitignore" '.hook-sync-state.lock' \
  "skeleton pack-safe gitignore ignores lock"
assert_contains "$skeleton/gitignore" '.hook-sync-state.*' \
  "skeleton pack-safe gitignore ignores temp siblings"
cmp -s "$skeleton/.gitignore" "$skeleton/gitignore" ||
  fail "skeleton .gitignore and gitignore must stay identical"
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
assert_contains "$skeleton/active-work/TEMPLATE.md" 'Checkpoint: YYYY-MM-DD @ SHORT-SHA' \
  "TEMPLATE Checkpoint uses plain SHORT-SHA placeholder"
assert_absent "$skeleton/active-work/TEMPLATE.md" 'Checkpoint: `' \
  "TEMPLATE Checkpoint must not use backtick wrappers"
# Machine line must not carry trailing guidance on the same line as Checkpoint:
assert_absent "$skeleton/active-work/TEMPLATE.md" 'Checkpoint: YYYY-MM-DD @ SHORT-SHA —' \
  "TEMPLATE Checkpoint line has no trailing prose"
assert_contains "$skeleton/active-work/TEMPLATE.md" 'product' \
  "TEMPLATE Next step is product work"
# Product /agent-memory ban lives off-section (Checkpoint-style), not under ## Next step
assert_contains "$skeleton/active-work/TEMPLATE.md" 'never `/agent-memory' \
  "TEMPLATE documents Next step product-only ban off-section"
awk '
  /^## Next step/ { in_ns=1; next }
  /^## / { in_ns=0 }
  in_ns && /\/agent-memory/ { found=1 }
  END { exit found ? 0 : 1 }
' "$skeleton/active-work/TEMPLATE.md" &&
  fail "TEMPLATE ## Next step section must not contain /agent-memory guidance"
assert_contains "$skeleton/active-work/TEMPLATE.md" 'strip section blurbs' \
  "TEMPLATE documents blurbs strip on copy"
assert_contains "$skeleton/active-work/TEMPLATE.md" 'not a replay of `log.md`' \
  "TEMPLATE Progress must not replay log"
assert_contains "$skeleton/active-work/TEMPLATE.md" 'full closure command' \
  "TEMPLATE Validation prefers full project closure"
assert_contains "$skeleton/active-work/TEMPLATE.md" '../../../' \
  "TEMPLATE documents repo-root link depth from active-work"
assert_absent "$skeleton/active-work/TEMPLATE.md" '## Touched files' \
  "Touched files must be removed from template"
assert_contains "$skeleton/log.md" 'semantic' "log documents semantic-only"
assert_contains "$skeleton/decisions.md" 'Status: active | superseded' "decisions Status field"
assert_contains "$skeleton/decisions.md" 'Superseded by:' "decisions supersession"
assert_contains "$skeleton/decisions.md" 'Rejected alternatives' \
  "decisions format lists Rejected alternatives"

# --- Contract invariants in instructions.md ---
assert_contains "$instructions" '## Always load' "always-load policy present"
assert_contains "$instructions" 'Authority: working rules' "authority map folded into Precedence"
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
assert_contains "$instructions" '**Primary-write triggers**' \
  "workflow lists primary-write triggers"
assert_contains "$instructions" '### How to write (concise)' \
  "instructions teach concise memory writing"
assert_contains "$instructions" '**Must consume** pending path evidence' \
  "workflow requires consuming pending path evidence when eligible"
assert_contains "$instructions" 'never `/agent-memory …`' \
  "Next step must not be a skill command"
assert_contains "$instructions" '**Catch-up (`/agent-memory sync`):**' \
  "workflow names sync as catch-up"
assert_contains "$instructions" 'without invoking the skill command' \
  "sync may be followed without skill invoke"
assert_contains "$instructions" '## Memory lint boundaries' "lint boundaries summary"
assert_contains "$instructions" 'when editing:' "scope hint convention"
assert_contains "$instructions" '## When starting or resuming work' "task-organized resume section"
assert_contains "$instructions" 'strip section blurbs' \
  "instructions require strip section blurbs when copying TEMPLATE"
assert_contains "$instructions" '## When stopping (primary write)' "task-organized primary write section"
assert_contains "$instructions" '## When catching up' "task-organized catch-up section"
assert_contains "$instructions" 'prefer what to do' "learning writing guidance"
assert_contains "$instructions" 'pending-doc' "pending-doc lifecycle"
assert_contains "$instructions" '/agent-memory learn' "learn command named in method"
assert_absent "$instructions" 'Soft warning budgets:' \
  "soft budgets stay in lint reference, not always-load"
assert_absent "$instructions" '**/**/*' \
  "overbroad denylist lives in lint, not always-load instructions"
assert_contains "$learn" '## [YYYY-MM-DD] [learning|pitfall] Short topic' \
  "learning/pitfall H2 entry format in learn reference"
assert_contains "$learn" '- Insight: reusable pattern in one or two sentences.' \
  "learning Insight field in learn reference"
assert_contains "$learn" 'learnings-<topic>.md' "topic split convention in learn reference"
assert_contains "$learn" '**Duplicate rule**' "duplicate rule SoT in learn reference"
assert_contains "$learn" '**Legacy one-liner**' "legacy one-liner SoT in learn reference"
# Overbroad when-editing denylist SoT is lint (not always-load instructions)
assert_contains "$lint" 'companions do not redeem' "lint overbroad rejects companions"
assert_contains "$lint" '?*/*' "lint overbroad includes ?*/*"
assert_contains "$lint" 'to fixpoint' "lint overbroad normalize runs to fixpoint"
assert_contains "$lint" '/./hooks/**' "lint overbroad normalize collapses /./"
assert_contains "$lint" './/./hooks/**' "lint overbroad normalize collapses .//./"
assert_contains "$lint" './/hooks/**' "lint overbroad normalize collapses .//"
assert_contains "$lint" 'still starts with `/`' "lint overbroad rejects absolute globs"
assert_contains "$lint" 'structural' "lint overbroad has structural reject"
assert_contains "$lint" 'hooks/**' "lint overbroad rejects hooks/**"
assert_contains "$lint" '*/*.<ext>' "lint overbroad rejects */*.<ext>"
assert_contains "$lint" '*/*/*.ts' "lint overbroad rejects */*/*.ts"
assert_contains "$lint" '*/*.*' "lint overbroad rejects */*.*"
assert_contains "$lint" '**/**/*' "lint overbroad denylist includes **/ **/* equivalent"
assert_contains "$lint" '*/**' "lint overbroad denylist includes */** equivalent"
assert_contains "$lint" '**/*.ts' "lint overbroad denylist includes **/*.ts"
assert_contains "$lint" '**/**/*.ts' "lint overbroad denylist includes **/**/*.ts"
assert_contains "$lint" 'src/**/*' "lint overbroad denylist includes src/**/*"
assert_contains "$lint" '*/*' "lint overbroad denylist includes */*"
assert_contains "$lint" '**/*/*' "lint overbroad denylist includes **/*/*"
assert_contains "$lint" '*/*/*' "lint overbroad denylist includes */*/*"
assert_contains "$lint" '**/*/**' "lint overbroad denylist includes **/*/**"
assert_contains "$lint" '*/*/*/*' "lint overbroad structural examples include */*/*/*"
assert_contains "$lint" 'no literal path segment' \
  "lint overbroad rejects wildcard-only+ext globs without literal prefix"
assert_contains "$lint" '**/*.<ext>' "lint overbroad rejects any **/ *.<ext>"
assert_contains "$lint" '<top-level-dir>/**' "lint overbroad rejects top-level dir/**"
assert_contains "$lint" 'src/**' "lint overbroad denylist includes src/**"

# --- Init / update ensure .gitignore (dotfile-safe) ---
init="$repo_root/skills/agent-memory/references/init.md"
update="$repo_root/skills/agent-memory/references/update.md"
assert_contains "$init" 'vendor/memory/gitignore' "init names pack-safe vendor gitignore"
assert_contains "$init" 'explicitly' "init requires explicit .gitignore write"
assert_contains "$init" 'verify `.agents/memory/.gitignore` exists' \
  "init verifies .gitignore after copy"
assert_contains "$init" '.hook-sync-state.lock' \
  "init requires lock sibling ignore"
assert_contains "$update" 'Ensure `.agents/memory/.gitignore` exists' \
  "update ensures .gitignore"
assert_contains "$update" 'vendor/memory/gitignore' \
  "update reads pack-safe vendor gitignore"
assert_contains "$update" 'do **not** rely on directory listings' \
  "update does not rely on Glob for .gitignore"
assert_contains "$update" '.hook-sync-state.lock' \
  "update merge requires lock sibling ignore"
assert_contains "$update" '.hook-sync-state.*' \
  "update merge requires temp sibling ignore"
assert_contains "$update" '`when editing:` scope hints' \
  "update preserves when-editing hints on index merge"
assert_contains "$lint" '.agents/memory/.gitignore' "lint checks .gitignore"
assert_contains "$lint" 'vendor/memory/gitignore' "lint remediation uses pack-safe gitignore"
assert_contains "$lint" '.hook-sync-state.lock' \
  "lint requires lock sibling ignore"
assert_contains "$lint" '.hook-sync-state.*' \
  "lint requires temp sibling ignore"

# --- Bootstrap ---
assert_contains "$bootstrap" 'A — Source inventory.' "bootstrap inventories sources"
assert_contains "$bootstrap" 'never paste' "bootstrap does not copy bodies"
assert_contains "$bootstrap" 'Do **not** create `vision.md`' "bootstrap forbids vision mirrors"
assert_contains "$bootstrap" 'H2 learning/pitfall format' "bootstrap uses H2 learning format"
assert_contains "$bootstrap" 'Put memory-command suggestions in the Report' \
  "bootstrap keeps skill commands out of Next step"
assert_contains "$bootstrap" 'Append **one** synthesis heading' \
  "bootstrap writes a single log heading"
assert_contains "$bootstrap" 'Do **not** open a second `[ingest]`' \
  "bootstrap avoids same-day ingest duplicate heading"

# --- Lint ---
assert_contains "$lint" 'Legacy mirrors' "lint identifies mirrors"
assert_contains "$lint" 'never deletes' "lint does not delete user files"
assert_contains "$lint" '## Next step' "lint checks Next step"
assert_contains "$lint" '## Validation' "lint checks Validation"
assert_contains "$lint" 'empty-log-heading' "lint checks empty headings"
assert_contains "$lint" 'empty-log:' "lint warns when log has no session headings"
assert_contains "$lint" 'empty-log-after-scaffold:' \
  "lint warns when scaffold recall exists but log is empty"
assert_contains "$lint" 'legacy-path-bullet' "lint checks legacy path bullets"
assert_contains "$lint" 'Soft budgets (warnings only)' "soft budgets live in lint"
assert_contains "$lint" 'stale-resume:' "lint checks checkpoint freshness vs HEAD"
assert_contains "$lint" 'checkpoint-backticks:' \
  "lint warns on backtick Checkpoint form"
assert_contains "$lint" 'checkpoint-prose:' \
  "lint warns on Checkpoint trailing TEMPLATE prose"
assert_contains "$lint" 'stale-next-step:' \
  "lint warns when Next step cites /agent-memory"
assert_contains "$lint" 'in_ns && /^-/ && /\/agent-memory' \
  "lint stale-next-step matches action bullets only"
assert_contains "$lint" 'dup-progress-log' \
  "lint warns when Progress replays log"
assert_contains "$lint" 'skills/agent-memory/vendor/memory/' \
  "lint skips dogfood instructions↔vendor dup-exact"
assert_contains "$lint" 'file) continue' \
  "lint skips when-editing placeholder ./file link"
assert_contains "$lint" "grep -q '<'" \
  "lint skips shape placeholders with angle brackets (learnings-<topic>.md)"
assert_contains "$lint" 'evidence-stale-uncleared:' \
  "lint distinguishes uncleared evidence after fresh Checkpoint"
assert_contains "$lint" 'evidence-dirty-requeue:' \
  "lint treats dirty-tree path re-queue as info when Checkpoint@HEAD"
assert_contains "$lint" 'hook-state-absent:' \
  "lint reports missing .hook-sync-state as info (not cleared evidence)"
assert_contains "$lint" 'pending-doc-met:' "lint flags pending-doc whose invalidate may be met"
assert_contains "$lint" 'Open `pending-doc`' \
  "lint must not warn on open valid pending-doc backlog"
assert_contains "$lint" 'never for info' \
  "lint Fix offer skips info band"
assert_contains "$lint" 'Legacy learning one-liner' "lint warns on legacy learning one-liners"
assert_contains "$lint" 'when editing:' "lint mentions scope hints"

# --- Sync ---
assert_contains "$sync" 'Sync writes only to:' "sync four-file boundary"
for target in 'current.md' 'active-work/<branch>.md' 'log.md' 'index.md'; do
  assert_contains "$sync" "$target" "sync boundary includes $target"
done
assert_contains "$sync" 'Prefer refining today' \
  "sync prefers one same-day heading over second ingest"
assert_contains "$sync" 'Suggest `/agent-memory consolidate` **only** when' \
  "sync suggests consolidate only for closed-session noise"
assert_contains "$sync" 'full closure command' \
  "sync Validation prefers full project closure"
assert_contains "$sync" 'Consume pending path evidence (required when eligible)' \
  "sync requires consume when eligible"
assert_contains "$sync" 'strip section blurbs' \
  "sync strips TEMPLATE section blurbs on create/refresh"
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
assert_contains "$sync" '**Meaning sources' "sync prefers meaning sources over path lists"
assert_contains "$sync" 'agent-memory-consume-evidence.sh' \
  "sync documents consume-evidence helper"
assert_contains "$sync" 'Never append unrelated concerns under an existing heading' \
  "sync forbids mixed-type log appends"
assert_contains "$sync" 'without invoking the skill command' \
  "sync steps usable without skill"

# --- Consolidate ---
assert_contains "$consolidate" 'Never prune the **current session** heading' \
  "consolidate preserves current session"
assert_contains "$consolidate" 'Current session (prune exclusion)' \
  "consolidate defines current-session rules"
assert_contains "$consolidate" 'Never propose a Discard set that would leave `log.md` with **zero** session headings' \
  "consolidate never empties log.md"
assert_contains "$consolidate" '**Trim**' \
  "consolidate can trim closed-session bullets"
assert_contains "$consolidate" 'Progress follow-up' \
  "consolidate Progress ask only after closed log removal"
assert_contains "$consolidate" 'retained: current-session founding log' \
  "consolidate Report names retained founding log"
assert_contains "$consolidate" "Never prune the **current branch's** active-work file." \
  "consolidate preserves current active-work"
assert_before "$consolidate" \
  'Additions/promotions first:' \
  'Only after a promotion is **approved**, and only for **closed** session origins' \
  "consolidate promotes before pruning"
assert_contains "$consolidate" 'Legacy `## Touched files`' \
  "consolidate cleans legacy Touched files"
assert_contains "$consolidate" '**Split**' "consolidate can propose topic splits"
assert_contains "$consolidate" 'learnings-<topic>.md' "consolidate targets topic splits"
assert_contains "$consolidate" 'pending-doc-met' \
  "consolidate acts on met pending-doc"
assert_contains "$consolidate" 'Mixed-type log bullets' \
  "consolidate cleans mixed-type log headings"

# --- Learn ---
assert_contains "$learn" 'retention gate' "learn applies retention gate"
assert_contains "$learn" 'learnings-<topic>.md' "learn supports topic splits"
assert_contains "$learn" 'Does **not** accept `--auto`' "learn has no auto"
assert_contains "$learn" 'when editing:' "learn may set scope hints"
assert_contains "$learn" 'do **not** silently no-op' "learn must report skips"
assert_contains "$learn" '1–3 concrete repo-relative paths' \
  "learn proposes when editing from Evidence paths"
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
assert_contains "$skill" 'Never edit `instructions.md` except' \
  "skill forbids editing instructions.md outside update"
assert_contains "$skill" 'Never edit harness instruction carriers except' \
  "skill forbids harness carrier edits outside init/update"
assert_absent "$skill" 'Edit(.agents/memory/**)' \
  "skill allowed-tools must not pre-approve all memory paths"
assert_absent "$skill" 'Edit(.agents/memory/instructions.md)' \
  "skill allowed-tools must not pre-approve instructions.md"
assert_absent "$skill" 'Edit(.agents/memory/decisions.md)' \
  "skill allowed-tools must not pre-approve decisions.md"
assert_absent "$skill" 'Edit(.agents/memory/learnings.md)' \
  "skill allowed-tools must not pre-approve learnings.md"
assert_absent "$skill" 'Edit(.agents/memory/learnings-*.md)' \
  "skill allowed-tools must not pre-approve learnings-*.md"
assert_absent "$skill" 'Edit(AGENTS.md)' \
  "skill allowed-tools must not pre-approve AGENTS.md"
assert_absent "$skill" 'Edit(.cursor/rules/agent-memory.mdc)' \
  "skill allowed-tools must not pre-approve cursor mdc"
assert_absent "$skill" 'Bash(git branch:*)' \
  "skill must not pre-approve mutative git branch:*"
assert_absent "$skill" 'Bash(git diff*)' \
  "skill must not pre-approve git diff* (covers --output)"
assert_absent "$skill" 'Bash(git log*)' \
  "skill must not pre-approve git log*"
assert_contains "$skill" 'Bash(git branch --show-current)' \
  "skill allows exact read-only git branch --show-current"
assert_contains "$skill" 'Bash(git status)' \
  "skill allows exact git status"
assert_contains "$sync" 'Boundary targets' \
  "sync scopes writes to Boundary targets only"
assert_contains "$sync" 'Do **not** write `decisions.md`' \
  "sync must not write decisions/learnings"
assert_contains "$sync" 'outside skill `allowed-tools` pre-approval' \
  "sync notes decisions/learnings are outside pre-approval"
assert_contains "$sync" 'adds or widens' \
  "sync --auto still confirms when-editing hint adds"
assert_absent "$sync" 'scoped to `.agents/memory/**`' \
  "sync must not re-open full memory/** write scope"
assert_contains "$skill" 'still **never** write `decisions.md`' \
  "skill host-ignores fallback keeps sync durable-recall ban"
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
assert_contains "$learn" '**Duplicate rule**' "duplicate rule in learn SoT"
assert_contains "$learn" '**Legacy one-liner**' "legacy one-liner documented in learn SoT"
assert_contains "$sync" 'never remove or reformat `when editing:` hints' \
  "sync preserves existing hints"
assert_contains "$consolidate" 'Duplicate rule' \
  "consolidate applies duplicate rule"
assert_contains "$consolidate" 'Convert moved entries to the H2 form' \
  "consolidate converts on split"

# --- Context layer stays short ---
assert_contains "$agent_block" 'Read `.agents/memory/instructions.md`' \
  "agent-block requires Read instructions"
assert_contains "$agent_block" 'untrusted recall' \
  "agent-block frames memory as untrusted recall"
assert_contains "$instructions" 'Untrusted recall' \
  "instructions frames memory as untrusted recall"
assert_contains "$agent_block" '**Primary write**' "agent-block names primary write"
assert_contains "$agent_block" '**Catch-up:**' "agent-block names sync catch-up"
assert_contains "$agent_block" 'run consume-evidence in the same turn' \
  "agent-block requires in-turn consume when pending covered"
assert_contains "$agent_block" 'sync **must** consume pending hook paths' \
  "agent-block requires sync consume when eligible"
assert_contains "$agent_block" '_How to write_' "agent-block points at concise writing guidance"
assert_contains "$agent_block" '_Harness parity — memory contract_' \
  "agent-block links harness parity"
assert_contains "$skill" 'agent-memory-consume-evidence.sh' \
  "skill allows consume-evidence helper"
assert_contains "$session_sh" 'build_session_context_msg' \
  "session uses contextual status builder"
consume_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-consume-evidence.sh"
[[ -f "$consume_sh" ]] || fail "consume-evidence script missing"
assert_contains "$consume_sh" 'consume_pending_path_evidence' \
  "consume-evidence clears pending paths"
assert_contains "$repo_root/hooks/agent-memory-hooks/agent-memory-common.sh" \
  'build_session_context_msg' "common.sh defines contextual session msg"
assert_contains "$repo_root/hooks/agent-memory-hooks/agent-memory-common.sh" \
  'untrusted recall' "session context includes untrusted-recall cue"
assert_contains "$sync_sh" 'no Markdown writes' "sync script header documents no Markdown"
pre_commit="$repo_root/hooks/git/pre-commit"
assert_contains "$pre_commit" 'env -u AGENT_MEMORY_SESSION_ID' \
  "pre-commit unsets stale session-binding env"
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
