#!/usr/bin/env bash
# Static invariant checks for the reference-first + ephemeral-hooks contract.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
instructions="$repo_root/skills/agent-memory/vendor/memory/instructions.md"
bootstrap="$repo_root/skills/agent-memory/references/bootstrap.md"
lint="$repo_root/skills/agent-memory/references/lint.md"
lint_structural="$repo_root/skills/agent-memory/references/lint-structural.md"
sync="$repo_root/skills/agent-memory/references/sync.md"
consolidate="$repo_root/skills/agent-memory/references/consolidate.md"
learn="$repo_root/skills/agent-memory/references/learn.md"
agent_block="$repo_root/skills/agent-memory/references/agent-block.md"
session_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-session.sh"
sync_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-sync.sh"
skeleton="$repo_root/skills/agent-memory/vendor/memory"
aw_template="$repo_root/skills/agent-memory/references/active-work-template.md"
common_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-common.sh"
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
                .gitignore gitignore; do
  [[ -e "$skeleton/$required" ]] || fail "skeleton missing $required"
done
[[ ! -e "$skeleton/active-work/TEMPLATE.md" ]] ||
  fail "project skeleton must not ship active-work/TEMPLATE.md"
[[ -f "$aw_template" ]] || fail "skill missing references/active-work-template.md"
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
assert_absent "$skeleton/current.md" '## Blockers / attention' \
  "idle current omits empty Blockers heading"
assert_absent "$skeleton/current.md" '## Handoff' \
  "idle current omits empty Handoff heading"
assert_contains "$aw_template" '## Task' "active-work keeps Task"
if grep -qE '^## Progress$' "$aw_template"; then
  fail "TEMPLATE does not ship empty Progress heading"
fi
assert_contains "$aw_template" '## Next step' "active-work keeps Next step"
assert_contains "$aw_template" '## Validation' "active-work keeps Validation"
assert_contains "$aw_template" 'Checkpoint:' "active-work has Checkpoint"
assert_contains "$aw_template" 'Checkpoint: YYYY-MM-DD @ SHORT-SHA' \
  "TEMPLATE Checkpoint uses plain SHORT-SHA placeholder"
assert_absent "$aw_template" 'Checkpoint: `' \
  "TEMPLATE Checkpoint must not use backtick wrappers"
assert_absent "$aw_template" 'Checkpoint: YYYY-MM-DD @ SHORT-SHA —' \
  "TEMPLATE Checkpoint line has no trailing prose"
assert_absent "$aw_template" 'Progress is optional' \
  "copy rules stay in instructions, not TEMPLATE"
assert_absent "$aw_template" 'strip section blurbs' \
  "TEMPLATE is a copy scaffold, not a method file"
assert_absent "$aw_template" 'Assumptions / open questions' \
  "optional sections are not pre-created in TEMPLATE"
awk '
  /^## Next step/ { in_ns=1; next }
  /^## / { in_ns=0 }
  in_ns && /\/agent-memory/ { found=1 }
  END { exit found ? 0 : 1 }
' "$aw_template" &&
  fail "TEMPLATE ## Next step section must not contain /agent-memory guidance"
assert_absent "$aw_template" '## Touched files' \
  "Touched files must be removed from template"
assert_contains "$instructions" 'semantic bullets' "log documents semantic-only"
assert_contains "$instructions" 'Status, Source, Relevance' "decisions pointer fields"
assert_contains "$instructions" 'Supersedes / Superseded by' "decisions supersession"
assert_contains "$instructions" 'Rejected alternatives' \
  "decisions format lists Rejected alternatives"
assert_contains "$instructions" 'references/active-work-template.md' \
  "method points at skill copy scaffold"
assert_absent "$skeleton/log.md" '## Format' \
  "installed log.md is entries only, not a format template"
assert_absent "$skeleton/decisions.md" '## Format' \
  "installed decisions.md is entries only, not a format template"

# --- Hot-path size ceiling (always-on: injected block + index + current; instructions on write) ---
# Method file is on-demand. Ceiling is a regression guard with margin, not exact equality.
hot_path_ceiling=3500
template_ceiling=400
block_body=$(
  awk '
    /^```md$/ { inb=1; next }
    /^```$/ && inb { exit }
    inb { printf "%s\n", $0 }
  ' "$agent_block"
)
block_bytes=$(printf '%s' "$block_body" | wc -c)
hot_path_bytes=$(( block_bytes + $(wc -c <"$skeleton/index.md") + $(wc -c <"$skeleton/current.md") ))
template_bytes=$(wc -c <"$aw_template")
[[ "$hot_path_bytes" -le "$hot_path_ceiling" ]] ||
  fail "always-on hot-path bytes $hot_path_bytes exceed ceiling $hot_path_ceiling"
[[ "$template_bytes" -le "$template_ceiling" ]] ||
  fail "TEMPLATE.md bytes $template_bytes exceed ceiling $template_ceiling"
assert_contains "$instructions" 'short map' \
  "instructions keep index as a short map not a catalog"
assert_contains "$instructions" 'rolling window' \
  "instructions keep log.md as a rolling window"
assert_contains "$instructions" '**One Task**' \
  "instructions require one live Task in active-work"
assert_contains "$agent_block" 'not a catalog' \
  "always-on block keeps index a map not a catalog"
assert_contains "$agent_block" '**Write floor**' \
  "always-on block names the write floor"
assert_contains "$agent_block" 'Resume rotten' \
  "always-on write floor includes resume rotten"
assert_contains "$agent_block" 'Status `load:`' \
  "always-on follows Status load with one Read"
assert_contains "$agent_block" '**Status**' \
  "always-on points at session Status"
assert_contains "$instructions" '## Write floor' \
  "instructions define write floor as SoT"
assert_contains "$instructions" 'Resume rotten' \
  "write floor includes resume rotten"
assert_contains "$instructions" 'User constraint' \
  "write floor includes user constraint"
assert_contains "$instructions" 'Reusable lesson' \
  "write floor includes reusable lesson"
assert_contains "$instructions" '**Fail closed** on Reusable lesson' \
  "reusable lesson fails closed without incident or paths"
assert_contains "$instructions" 'write learnings only' \
  "reusable lesson tie-break writes learnings only"
assert_contains "$instructions" 'Path-scoped capture without a usable' \
  "path-scoped learning without index hint is a failed write"
assert_contains "$instructions" 'never dual-write learnings with `active-work`' \
  "learnings never dual-write with active-work or log"
assert_contains "$instructions" 'write `decisions.md` only' \
  "user constraint tie-break writes decisions only"
assert_contains "$instructions" '**Exception (approach):**' \
  "live user decision beats code for approach"
assert_contains "$instructions" '**Not** a conflicting append' \
  "HUMAN_CHECKPOINT carves out this-turn decisions supersede"
assert_contains "$instructions" 'exactly one `Status: live` per identity' \
  "decisions keep one live entry per identity"
assert_contains "$agent_block" 'User constraint' \
  "always-on write floor includes user constraint"
assert_contains "$agent_block" 'Reusable lesson' \
  "always-on write floor includes reusable lesson"
assert_contains "$agent_block" 'Load learnings only via Status' \
  "always-on does not always-read learnings"
assert_contains "$agent_block" 'beats code for **approach**' \
  "always-on live decision beats code for approach"
assert_contains "$learn" 'write-floor `decisions.md`' \
  "learn gate failure points at user constraint floor"
assert_contains "$learn" 'Reusable lesson' \
  "learn treats reusable lesson as a write-floor row"
assert_contains "$learn" 'do not write a hidden lesson' \
  "path-scoped learn requires an index hint"
assert_contains "$consolidate" 'Two `Status: live`' \
  "consolidate finds duplicate live decisions"
assert_contains "$instructions" 'Read **that linked file**' \
  "always-load follows matching when-editing with one Read"
assert_contains "$instructions" '**Hold:** max **3** bullets' \
  "Hold cap lives in how-to-write"
assert_absent "$aw_template" '## Hold' \
  "TEMPLATE does not pre-create Hold"
assert_contains "$lint" 'hold-overflow:' \
  "lint flags Hold over 3 bullets"
assert_contains "$lint_structural" "'## Hold'" \
  "lint treats Hold as optional empty-section heading"
assert_contains "$agent_block" '_Recall hop_' \
  "always-on block points at Recall hop for durable why"
assert_contains "$agent_block" 'Path hit' \
  "always-on hop stop is path hit"
assert_contains "$agent_block" 'failing test' \
  "always-on block names failing test as path hit"
assert_contains "$agent_block" 'Durable why' \
  "always-on hop trigger is durable why"
assert_contains "$agent_block" 'Do not require verb names' \
  "always-on block does not require closed verb tokens"
assert_contains "$instructions" '## Recall hop' \
  "instructions define Recall hop"
assert_contains "$instructions" 'Depth **h = 2**' \
  "Recall hop depth is 2"
assert_contains "$instructions" '**4 extra** recall files' \
  "Recall hop budget is 4 extra files"
assert_contains "$instructions" '**not** hop neighbors' \
  "index and instructions are not hop neighbors"
assert_contains "$instructions" '**When to hop:**' \
  "Recall hop has an affirmative intent trigger"
assert_contains "$instructions" '**durable why**' \
  "Recall hop triggers on durable why"
assert_contains "$instructions" '**path hit**' \
  "Recall hop defines path hit as stop"
assert_contains "$instructions" 'failing test' \
  "Recall hop counterexample is failing test / this diff"
assert_contains "$instructions" 'Closed verbs match **edges**' \
  "closed verbs match edges not the hop trigger"
assert_contains "$instructions" "rg -nE 'Relates:|caused_by:" \
  "hop 1 inbound search uses Relates/caused_by grep"
assert_contains "$instructions" 'also update the matching `index.md` recall line' \
  "one-file exception allows learning plus index when-editing hint"
assert_contains "$instructions" 'not dual-write of active-work+log' \
  "learning plus index hint is not active-work/log dual-write"
assert_contains "$instructions" 'Listing `log.md` / `decisions.md` / `learnings.md` on the index is **not** a stop' \
  "index listing log.md is not a hop stop"
assert_contains "$instructions" '{caused_by, supersedes, superseded_by}' \
  "hop 2 follows the causal verb set"
assert_contains "$instructions" 'caused_by` / `contradicts` / `see' \
  "instructions close the typed-edge verb list"

# --- Contract invariants in instructions.md ---
assert_contains "$instructions" '## Always load' "always-load policy present"
assert_contains "$instructions" 'Skip is the default' "skip-default when write floor is all no"
assert_contains "$instructions" 'One write target per event' "one write target"
assert_contains "$instructions" 'never dual-write' "no dual-write on stop"
assert_contains "$instructions" 'Progress is optional' "Progress optional in method"
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
assert_contains "$instructions" 'Omit empty optional sections' \
  "instructions omit empty optional active-work sections"
assert_contains "$instructions" 'record them when discovered' \
  "instructions require capturing optional sections when found"
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
assert_contains "$update" 'optional sections' \
  "update documents optional active-work sections"
assert_contains "$update" 'delete leftover `active-work/TEMPLATE.md`' \
  "update deletes leftover TEMPLATE even when versions match"
assert_contains "$init" 'Do **not** copy `references/active-work-template.md`' \
  "init does not install the skill copy scaffold into memory"
assert_contains "$update" 'same carriers and rules as `references/init.md`' \
  "update delegates carrier table to init"
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
assert_contains "$bootstrap" 'omit empty optional sections' \
  "bootstrap omits empty optional active-work sections"
assert_contains "$bootstrap" 'Put memory-command suggestions in the Report' \
  "bootstrap keeps skill commands out of Next step"
assert_contains "$bootstrap" 'Do not list every config' \
  "bootstrap keeps index a short map"
assert_contains "$bootstrap" 'rewrite the synthesis heading' \
  "bootstrap supersedes same-day inventory headings"
assert_contains "$bootstrap" 'Do **not** open a second `[ingest]`' \
  "bootstrap avoids same-day ingest duplicate heading"
assert_contains "$bootstrap" 'Leave `active-work/` empty' \
  "bootstrap does not plant TEMPLATE in project memory"

# --- Lint ---
assert_contains "$lint" 'Legacy mirrors' "lint identifies mirrors"
assert_contains "$lint" 'never deletes' "lint does not delete user files"
assert_contains "$lint" 'graph-tree:' \
  "lint flags graph-tree folders"
assert_contains "$lint" '## Progress' \
  "lint treats Progress as optional when present"
assert_contains "$lint" '## Next step' "lint checks Next step"
assert_contains "$lint" '## Validation' "lint checks Validation"
assert_contains "$lint" 'empty-optional-section:' \
  "lint warns on empty optional active-work sections"
assert_contains "$lint" 'hold-overflow:' \
  "lint names hold-overflow finding"
assert_contains "$lint" 'Required headings for resume (agent-owned) — core only' \
  "lint requires core resume headings only"
assert_contains "$lint" 'same-day-dup-log:' \
  "lint flags duplicate same-day same-type log headings"
assert_contains "$lint" 'index-catalog:' \
  "lint flags oversized canonical source maps"
assert_contains "$lint" 'empty-log:' "lint warns when log has no session headings"
assert_contains "$lint" 'empty-log-after-scaffold:' \
  "lint warns when scaffold recall exists but log is empty"
assert_contains "$lint" 'legacy-path-bullet' "lint checks legacy path bullets"
assert_contains "$lint" 'Soft budgets (warnings only)' "soft budgets live in lint"
assert_contains "$lint" 'stale-resume:' "lint checks checkpoint freshness vs HEAD"
assert_contains "$lint" 'template-in-memory:' \
  "lint flags leftover TEMPLATE.md in project memory"
assert_contains "$lint_structural" 'branch=$(printf '\''%s'\'' "$branch" | tr -c' \
  "lint sanitizes branch without piping git newline into tr"
assert_contains "$lint_structural" 'rev-parse --verify' \
  "lint resolves Checkpoint SHA with rev-parse --verify"
assert_absent "$lint" 'rev-parse --end-of-options' \
  "lint must not use rev-parse --end-of-options (Git 2.55)"
assert_absent "$lint_structural" 'rev-parse --end-of-options' \
  "lint structural must not use rev-parse --end-of-options (Git 2.55)"
assert_contains "$lint" 'checkpoint-backticks:' \
  "lint warns on backtick Checkpoint form"
assert_contains "$lint" 'checkpoint-prose:' \
  "lint warns on Checkpoint trailing TEMPLATE prose"
assert_contains "$lint" 'stale-next-step:' \
  "lint warns when Next step cites /agent-memory"
assert_contains "$lint_structural" 'in_ns && /^-/ && /\/agent-memory' \
  "lint stale-next-step matches action bullets only"
assert_contains "$lint" 'dup-progress-log' \
  "lint warns when Progress replays log"
assert_contains "$lint" 'skills/agent-memory/vendor/memory/' \
  "lint skips dogfood instructions↔vendor dup-exact"
assert_contains "$lint_structural" 'file) continue' \
  "lint skips when-editing placeholder ./file link"
assert_contains "$lint_structural" "grep -q '<'" \
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
assert_contains "$lint" 'unknown-relates-verb:' \
  "lint flags Relates verbs outside the closed list"
assert_contains "$lint" 'relates-missing:' \
  "lint flags typed-edge links whose target file is missing"
assert_contains "$lint" '#fragment' \
  "lint relates-missing checks markdown #fragment anchors"
assert_contains "$lint" 'learning-missing-relates' \
  "lint flags H2 learnings whose Evidence is recall without Relates"
assert_contains "$lint" 'current-stale-branch:' \
  "lint flags current.md In progress citing missing active-work"
assert_contains "$lint" 'learning-missing-evidence' \
  "lint names missing Evidence on learnings"
assert_contains "$lint" 'contradicts-unlinked' \
  "lint names unlinked contradictory insights"
assert_contains "$lint" 'supersede-cycle' \
  "lint names supersede cycles"
assert_contains "$lint" 'references/lint-structural.md' \
  "lint discloses structural scripts"
assert_contains "$lint" 'typo-heading:' \
  "lint flags required-heading misspellings"
assert_contains "$lint" 'typo-token:' \
  "lint flags method-token misspellings"
assert_contains "$lint" 'method-stale:' \
  "lint flags installed instructions missing write floor / hop"
assert_contains "$lint" 'carrier-stale:' \
  "lint flags stale agent-memory blocks"
assert_contains "$lint" 'hook-incomplete:' \
  "lint flags incomplete five-script hook installs"
assert_contains "$lint" 'opencode-legacy-plugin:' \
  "lint flags leftover OpenCode singular plugin path"
assert_contains "$lint" 'learning-hidden:' \
  "lint flags path-scoped learnings without when editing"
assert_contains "$lint" 'quality-unanswerable:' \
  "lint names cold-session quality gaps"
assert_contains "$lint" 'live-dup-identity:' \
  "lint flags two live decisions on the same identity"
assert_contains "$lint" '**Agent quality (cold session).**' \
  "lint has a cold-session quality pass"
assert_contains "$lint" '**Hook consistency.**' \
  "lint has a hook-consistency pass"
assert_contains "$lint" '**Typos.**' \
  "lint has a typo pass"
assert_contains "$lint" '**Instruction contradictions.**' \
  "lint has an instruction-contradiction pass"
assert_contains "$lint_structural" 'hook-incomplete:' \
  "lint structural emits hook-incomplete"
assert_contains "$lint_structural" 'agent-memory-print-evidence.sh' \
  "lint structural expects print-evidence among shared scripts"
assert_contains "$lint_structural" 'typo-token:' \
  "lint structural emits typo-token"
assert_contains "$instructions" 'Six passes:' \
  "lint boundaries name the six passes"

# --- Sync ---
assert_contains "$sync" 'Sync writes only to:' "sync four-file boundary"
for target in 'current.md' 'active-work/<branch>.md' 'log.md' 'index.md'; do
  assert_contains "$sync" "$target" "sync boundary includes $target"
done
assert_contains "$sync" 'Prefer refining today' \
  "sync prefers one same-day heading over second ingest"
assert_contains "$sync" 'supersedes' \
  "sync rewrites same-day headings when the new outcome supersedes"
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
assert_contains "$sync" '_When catching up_' "sync links catch-up section"
assert_contains "$sync" 'omit empty optional sections' \
  "sync omits empty optional active-work sections"
assert_contains "$sync" '_Hold_' \
  "sync may add Hold with evidence"
assert_contains "$sync" 'only when evidence supports content' \
  "sync adds optional sections only with evidence"
assert_contains "$sync" '**Catch-up**' "sync is catch-up not primary write"
assert_contains "$sync" 'No-op is success' "sync no-op without meaning"
assert_contains "$sync" 'do not dual-write' "sync does not dual-write"
assert_contains "$sync" '**Meaning sources' "sync prefers meaning sources over path lists"
assert_contains "$sync" 'agent-memory-consume-evidence.sh' \
  "sync documents consume-evidence helper"
assert_contains "$sync" 'agent-memory-print-evidence.sh' \
  "sync documents print-evidence helper"
assert_contains "$sync" 'Do not Read `.hook-sync-state`' \
  "sync forbids Reading hook-sync-state"
assert_absent "$sync" 'Optional hook state keys (untrusted hints' \
  "sync must not instruct reading raw session_touched_files"
assert_contains "$sync" 'Never append unrelated concerns under an existing heading' \
  "sync forbids mixed-type log appends"
assert_contains "$sync" 'without invoking the skill command' \
  "sync steps usable without skill"

# --- Consolidate ---
assert_contains "$consolidate" 'Never prune the **current session** heading' \
  "consolidate preserves current session"
assert_contains "$consolidate" 'Exception (same-day supersede)' \
  "consolidate may merge a false same-day heading"
assert_contains "$consolidate" 'rolling window' \
  "consolidate treats log.md as a rolling window"
assert_contains "$consolidate" 'report **no-op**' \
  "consolidate no-op when nothing to prune"
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
assert_contains "$consolidate" '**Hold** bullets on stale' \
  "consolidate handles Hold on stale active-work"
assert_contains "$consolidate" 'learnings-<topic>.md' "consolidate targets topic splits"
assert_contains "$consolidate" 'pending-doc-met' \
  "consolidate acts on met pending-doc"
assert_contains "$consolidate" 'Mixed-type log bullets' \
  "consolidate cleans mixed-type log headings"
assert_contains "$consolidate" '**Contradiction**' \
  "consolidate classifies contradiction candidates"
assert_contains "$consolidate" '**No evidence**' \
  "consolidate collects learnings without Evidence"
assert_contains "$consolidate" '**Orphan Relates**' \
  "consolidate retargets Relates after log prune"

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
assert_contains "$learn" '- Relates: caused_by [target](path)' \
  "learn H2 may include Relates"
assert_contains "$learn" 'Evidence is already a recall file' \
  "learn Relates is required when Evidence is recall"
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
assert_absent "$index" 'when editing:' \
  "index is a map; when-editing contract lives in instructions"
assert_contains "$instructions" 'learnings-<topic>.md' "topic splits named in method"
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
assert_contains "$agent_block" 'Before writing' \
  "agent-block loads instructions on write, not always-on"
assert_absent "$agent_block" '@.agents/memory/instructions.md' \
  "agent-block must not always-on @-import instructions.md"
assert_contains "$agent_block" 'untrusted recall' \
  "agent-block frames memory as untrusted recall"
assert_contains "$instructions" 'Untrusted recall' \
  "instructions frames memory as untrusted recall"
assert_contains "$agent_block" 'Skip is the default' "agent-block skip default"
assert_contains "$agent_block" 'at most **one** file' "agent-block one-file write"
assert_contains "$agent_block" 'Never dual-write' "agent-block no dual-write"
assert_contains "$agent_block" 'Status `load:`' \
  "agent-block defers hint follow to Status load"
assert_contains "$agent_block" '_How to write_' "agent-block points at concise writing guidance"
assert_contains "$agent_block" '_Harness parity — memory contract_' \
  "agent-block links harness parity"
assert_contains "$skill" 'agent-memory-consume-evidence.sh' \
  "skill allows consume-evidence helper"
assert_contains "$skill" 'agent-memory-print-evidence.sh' \
  "skill allows print-evidence helper"
assert_contains "$session_sh" 'build_session_context_msg' \
  "session uses contextual status builder"
consume_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-consume-evidence.sh"
[[ -f "$consume_sh" ]] || fail "consume-evidence script missing"
assert_contains "$consume_sh" 'consume_pending_path_evidence' \
  "consume-evidence clears pending paths"
print_sh="$repo_root/hooks/agent-memory-hooks/agent-memory-print-evidence.sh"
[[ -f "$print_sh" ]] || fail "print-evidence script missing"
assert_contains "$print_sh" 'print_sanitized_hook_evidence' \
  "print-evidence emits sanitized fields"
assert_contains "$common_sh" 'print_sanitized_hook_evidence' \
  "common.sh defines print-evidence helper"
assert_contains "$instructions" 'do not Read `.hook-sync-state`' \
  "instructions forbids Reading hook-sync-state"
assert_contains "$common_sh" \
  'build_session_context_msg' "common.sh defines contextual session msg"
assert_contains "$common_sh" \
  'write floor' "session action cites write floor"
assert_contains "$common_sh" 'reusable lesson needs incident+paths' \
  "session action walks reusable lesson row"
assert_contains "$common_sh" 'amc_index_hint_loads' \
  "session Status matches when-editing hints"
assert_contains "$common_sh" 'amc_active_work_next_step' \
  "session Status can surface Next step"
assert_contains "$common_sh" 'resolve_hex_commit' \
  "common.sh resolves Checkpoint SHA via helper"
assert_absent "$common_sh" 'rev-parse --end-of-options' \
  "hooks must not use rev-parse --end-of-options (Git 2.55)"
assert_contains "$sync_sh" 'no Markdown writes' "sync script header documents no Markdown"
pre_commit="$repo_root/hooks/git/pre-commit"
assert_contains "$pre_commit" 'env -u AGENT_MEMORY_SESSION_ID' \
  "pre-commit unsets stale session-binding env"
assert_contains "$pre_commit" 'Checkpoint' "pre-commit reminds when Checkpoint behind HEAD"
assert_contains "$pre_commit" 'rev-parse --verify' \
  "pre-commit resolves Checkpoint SHA with rev-parse --verify"
assert_absent "$pre_commit" 'rev-parse --end-of-options' \
  "pre-commit must not use rev-parse --end-of-options (Git 2.55)"
post_commit="$repo_root/hooks/git/post-commit"
[[ -f "$post_commit" ]] || fail "git post-commit hook missing"
assert_contains "$post_commit" 'apply_post_commit_ephemeral_state' \
  "post-commit stamps ephemeral state after commit"
assert_contains "$post_commit" 'unset AGENT_MEMORY_SESSION_ID' \
  "post-commit unsets stale session-binding env"
assert_contains "$post_commit" 'Never writes Markdown' \
  "post-commit header documents no Markdown"
assert_contains "$common_sh" 'apply_post_commit_ephemeral_state' \
  "common.sh defines post-commit stamp helper"

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
