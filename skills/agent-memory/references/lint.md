# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report findings; fix only what is safe, and never change user content without confirmation. Semantic promotion/pruning belongs to `/agent-memory consolidate` — not `lint --fix`.

**Severity (report only what needs action):**

| Band | Meaning | Fix offer? |
| --- | --- | --- |
| **errors** | Broken structure (links, required headings, orphans, stale `active-work` files) | Yes — safe/`--fix` as below |
| **warnings** | Actionable drift (stale Checkpoint, uncovered hook evidence, `pending-doc-met`, wiring, budgets, semantic defects) | Yes — sync / consume / consolidate / confirm edit |
| **info** | Expected or ephemeral noise (missing hook state file, dirty-tree evidence re-queue when meaning already covers, open valid `pending-doc` backlog) | **No** — do not list under Fix offer |

Do **not** invent warnings for healthy bootstrap output (open `pending-doc` whose `Invalidate when` is still false) or for hook path lists that merely mirror an already-documented dirty tree.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, suggest `/agent-memory init`.

2. **Structural checks (deterministic).** Run from `.agents/memory/`:

   ````bash
   # Broken relative links inside memory (skip method placeholders)
   grep -rhoE '\]\(\./[^)]+\)' . | sed -E 's/^\]\(\.\/([^)]+)\)$/\1/' \
     | sort -u | while read -r f; do
       case "$f" in
         file) continue ;; # when editing: contract placeholder
       esac
       # Shape examples in index.md — e.g. learnings-<topic>.md
       printf '%s' "$f" | grep -q '<' && continue
       test -e "$f" || echo "missing: $f"
     done

   # Recall / legacy files present but not linked from index.md
   for f in decisions.md log.md learnings.md \
            vision.md architecture.md patterns.md mistakes.md known-issues.md project.md; do
     [ -f "$f" ] || continue
     grep -q "$(basename "$f")" index.md || echo "orphan: $f"
   done
   find . -maxdepth 1 -name 'learnings-*.md' 2>/dev/null | while read -r f; do
     grep -q "$(basename "$f")" index.md || echo "orphan: $f"
   done
   for d in architecture domains components features episodes changes timeline; do
     [ -d "$d" ] || continue
     echo "graph-tree: $d/ — do not scaffold graph folders; pointer in index.md instead"
   done
   for d in domains features; do
     [ -d "$d" ] || continue
     find "$d" -name '*.md' 2>/dev/null | while read -r f; do
       grep -q "$(basename "$f")" index.md || echo "orphan: $f"
     done
   done

   # Required headings for resume (agent-owned) — core only
   grep -q '^## In progress' current.md || echo "missing-heading: current.md ## In progress"
   # In progress cites a missing active-work file (do not require listing every local active-work)
   awk '
     /^## In progress/ { in_ip=1; next }
     /^## / { in_ip=0 }
     in_ip && /^- / && $0 !~ /^- _none_$/ { print }
   ' current.md | while IFS= read -r bullet; do
     printf '%s\n' "$bullet" | grep -oE 'active-work/[A-Za-z0-9._-]+(\.md)?' | while IFS= read -r p; do
       name=$(basename "$p" .md)
       [ "$name" = "TEMPLATE" ] && continue
       test -e "active-work/${name}.md" || echo "current-stale-branch: current.md In progress -> active-work/${name}.md"
     done
   done
   for h in '## Blockers / attention' '## Handoff'; do
     grep -q "^${h}" current.md || continue
     awk -v heading="$h" '
       $0 == heading { in_sec=1; next }
       /^## / { in_sec=0 }
       in_sec && /^- / && $0 !~ /^- _none_$/ { has=1 }
       END {
         if (!has) print "empty-optional-section: current.md " heading " — omit empty optional sections (add only with content)"
       }
     ' current.md
   done
   [ -f active-work/TEMPLATE.md ] && echo "template-in-memory: active-work/TEMPLATE.md — delete; copy scaffold is the skill references/active-work-template.md"
   find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     for h in '## Task' '## Next step' '## Validation'; do
       grep -q "^${h}" "$f" || echo "missing-heading: $f $h"
     done
     # Optional sections: validate shape when present; empty (_none_ only) → suggest strip
     for h in '## Progress' '## Assumptions / open questions' '## Blockers' \
              '## Rejected approaches' '## References' '## Hold'; do
       grep -q "^${h}" "$f" || continue
       awk -v heading="$h" '
         $0 == heading { in_sec=1; next }
         /^## / { in_sec=0 }
         in_sec && /^- / && $0 !~ /^- _none_$/ { has=1 }
         END {
           if (!has) print "empty-optional-section: '"$f"' " heading " — omit empty optional sections (add only with content)"
         }
       ' "$f"
     done
     # Allow optional backticks around date/sha (legacy); prefer plain form
     if ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}' "$f"; then
       echo "missing-checkpoint: $f"
     elif grep -qE '^Checkpoint: `' "$f"; then
       echo "checkpoint-backticks: $f — prefer Checkpoint: YYYY-MM-DD @ SHORT-SHA without backticks"
     elif ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}[`"]?[[:space:]]*$' "$f"; then
       echo "checkpoint-prose: $f — Checkpoint line must be only date @ sha (no trailing TEMPLATE instructions)"
     fi
     # Next step action bullets must not be a memory skill command (ignore section blurbs)
     awk '
       /^## Next step/ { in_ns=1; next }
       /^## / { in_ns=0 }
       in_ns && /^-/ && /\/agent-memory[[:space:]]/ {
         print "stale-next-step: '"$f"' — Next step cites /agent-memory; use a product action (skill cmds → Validation or report)"
         exit
       }
     ' "$f"
     grep -q '^## Touched files' "$f" && echo "legacy-touched-files: $f"
     awk '
       /^## Hold$/ { in_h=1; next }
       /^## / { in_h=0 }
       in_h && /^- / && $0 !~ /^- _none_$/ { n++ }
       END {
         if (n > 3)
           print "hold-overflow: '"$f"' — Hold max 3 bullets (branch scratch; not learnings)"
       }
     ' "$f"
   done

   # Session headings in log.md (ignore fenced examples, title, and Format docs)
   # Real entries: ## [YYYY-MM-DD] … — warn on other ## headings outside fences
   awk '
     /^```/ { fence = !fence; next }
     fence { next }
     /^# / { next }
     /^## Format($| )/ { next }
     /^## / && $0 !~ /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
       print "bad-log-heading: " $0
     }
   ' log.md

   # Same calendar day + same [type] more than once (stale inventory left behind)
   awk '
     /^```/ { fence = !fence; next }
     fence { next }
     /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
       date = substr($0, 5, 10)
       type = "unknown"
       if ($0 ~ /\[feat\]/) type = "feat"
       else if ($0 ~ /\[fix\]/) type = "fix"
       else if ($0 ~ /\[chore\]/) type = "chore"
       else if ($0 ~ /\[review\]/) type = "review"
       else if ($0 ~ /\[docs\]/) type = "docs"
       else if ($0 ~ /\[refactor\]/) type = "refactor"
       else if ($0 ~ /\[test\]/) type = "test"
       else if ($0 ~ /\[perf\]/) type = "perf"
       else if ($0 ~ /\[security\]/) type = "security"
       else if ($0 ~ /\[release\]/) type = "release"
       else if ($0 ~ /\[ingest\]/) type = "ingest"
       else if ($0 ~ /\[improve\]/) type = "improve"
       key = date " " type
       n[key]++
     }
     END {
       for (k in n) if (n[k] > 1)
         print "same-day-dup-log: " k " has " n[k] " headings — update today'\''s heading in place when the new outcome supersedes"
     }
   ' log.md

   # Canonical source catalog (index is a short map, not a bibliography)
   awk '
     /^## Canonical project sources/ { in_src = 1; next }
     /^## / { in_src = 0 }
     in_src && /^- / && $0 !~ /_None yet/ { n++ }
     END {
       if (n > 8)
         print "index-catalog: " n " canonical source bullets — keep a short map; extra docs stay in Git or when editing:"
     }
   ' index.md

   # Typed Relates: verbs (closed list — unknown-relates-verb) + dead targets (relates-missing)
   grep -rnE --include='*.md' \
     '[[:space:]]*- Relates:|[[:space:]]*- caused_by:|^Caused by:|^Contradicts:|^See:|^Supersedes:|^Superseded by:' . 2>/dev/null |
   while IFS= read -r line; do
     case "$line" in
       ./instructions.md:*) continue ;;
     esac
     path=$(printf '%s\n' "$line" | cut -d: -f1)
     body=$(printf '%s\n' "$line" | cut -d: -f3-)
     case "$path" in
       ./decisions.md) ;;
       *)
         printf '%s' "$body" | grep -qE '[[:space:]]*- Relates:|[[:space:]]*- caused_by:' || continue
         ;;
     esac
     verb=""
     if printf '%s' "$body" | grep -qE '[[:space:]]*- Relates:'; then
       verb=$(printf '%s\n' "$body" | sed -E 's/.*- Relates:[[:space:]]*//; s/[[:space:]].*$//; s/\[.*//; s/:.*//')
     elif printf '%s' "$body" | grep -qE '[[:space:]]*- caused_by:'; then
       verb=caused_by
     elif printf '%s' "$body" | grep -qE '^Caused by:'; then
       verb=caused_by
     elif printf '%s' "$body" | grep -qE '^Contradicts:'; then
       verb=contradicts
     elif printf '%s' "$body" | grep -qE '^See:'; then
       verb=see
     elif printf '%s' "$body" | grep -qE '^Supersedes:'; then
       verb=supersedes
     elif printf '%s' "$body" | grep -qE '^Superseded by:'; then
       verb=superseded_by
     fi
     printf '%s' "$verb" | grep -q '<' && continue
     [ -n "$verb" ] || continue
     printf '%s' "$verb" | grep -qE '^(supersedes|superseded_by|caused_by|contradicts|see)$' \
       || echo "unknown-relates-verb: $line"
     printf '%s' "$body" | grep -oE '\[[^]]+\]\([^)]+\)' | while IFS= read -r md; do
       url=$(printf '%s' "$md" | sed -E 's/^[^]]*\]\(//; s/\)$//')
       case "$url" in
         http*|https*|'#'*) continue ;;
       esac
       file_part=$(printf '%s' "$url" | sed 's/#.*//')
       [ -n "$file_part" ] || continue
       printf '%s' "$file_part" | grep -q '<' && continue
       target="$(dirname "$path")/$file_part"
       if [ ! -e "$target" ]; then
         echo "relates-missing: $line -> $file_part"
         continue
       fi
       # If the markdown link has #fragment, require it in the target (heading or fragment string)
       case "$url" in
         *'#'*) ;;
         *) continue ;;
       esac
       frag=$(printf '%s' "$url" | sed 's/^[^#]*#//')
       [ -n "$frag" ] || continue
       printf '%s' "$frag" | grep -q '<' && continue
       grep -qF "$frag" "$target" && continue
       slug_words=$(printf '%s' "$frag" | tr '-' ' ')
       grep -qiF "$slug_words" "$target" || echo "relates-missing: $line -> ${file_part}#${frag}"
     done
   done

   # H2 learning/pitfall: Evidence names a recall file but no Relates (learning-missing-relates)
   find . -maxdepth 1 \( -name 'learnings.md' -o -name 'learnings-*.md' \) 2>/dev/null | while read -r f; do
     awk -v file="$f" '
       /^```/ { fence = !fence; next }
       fence { next }
       /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\] \[(learning|pitfall)\]/ {
         flush()
         heading = $0
         in_h2 = 1
         evidence_recall = 0
         has_relates = 0
         next
       }
       /^## / {
         flush()
         in_h2 = 0
         next
       }
       in_h2 && /^- Evidence:/ && /(^|[^A-Za-z0-9_-])(decisions\.md|log\.md|learnings\.md|learnings-[A-Za-z0-9._-]+\.md)/ {
         evidence_recall = 1
       }
       in_h2 && /^- Relates:/ { has_relates = 1 }
       END { flush() }
       function flush() {
         if (in_h2 && evidence_recall && !has_relates)
           print "learning-missing-relates: " file " " heading
       }
     ' "$f"
   done

   # Empty closed-session headings (no bullets under heading)
   awk '
     /^```/ { fence = !fence; next }
     fence { next }
     /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
       if (heading && !has_bullet) print "empty-log-heading: " heading
       heading = $0; has_bullet = 0; next
     }
     heading && /^- / { has_bullet = 1 }
     END {
       if (heading && !has_bullet) print "empty-log-heading: " heading
     }
   ' log.md

   # No session headings (scaffold / over-prune)
   if ! grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' log.md 2>/dev/null; then
     echo "empty-log: no session headings — primary write or /agent-memory sync after durable work"
     if grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' learnings.md 2>/dev/null \
        || grep -qE 'learnings\.md' index.md 2>/dev/null; then
       echo "empty-log-after-scaffold: recall exists (learnings/index) but log has zero sessions — likely consolidate over-pruned current session; restore a short founding heading"
     fi
   fi

   # Legacy path-only bullets
   grep -nE '^- `[^`]+`$|^- changed [0-9]+ files' log.md 2>/dev/null | \
     while read -r line; do echo "legacy-path-bullet: $line"; done

   # Stale per-branch active-work: a file whose branch no longer exists
   # (skipped when git lists no branches — no commits yet / not a git repo)
   branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
   [ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"
   done
   ````

   Also report if `.agents/memory/.version` is missing — the memory was likely installed manually without the skill, so `update` cannot track its version.

   Report if `.agents/memory/.gitignore` is missing or does not list **all** of `.hook-sync-state`, `.hook-sync-state.lock`, and `.hook-sync-state.*` — hooks will leave untracked state (including lock/temp siblings from `mktemp`) that may be committed by mistake. Suggest copying from the skill's `vendor/memory/gitignore` (pack-safe name; Write destination as `.agents/memory/.gitignore`).

   **Stale resume / evidence ahead of memory (warnings).** From the **project root**:

   ```bash
   branch=$(git branch --show-current 2>/dev/null || true)
   branch=$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-')
   [ -n "$branch" ] || branch=local
   aw=".agents/memory/active-work/${branch}.md"
   head_full=$(git rev-parse HEAD 2>/dev/null || true)
   head_short=$(git rev-parse --short HEAD 2>/dev/null || true)
   ck_sha=""
   if [ -f "$aw" ] && [ -n "$head_full" ]; then
     ck_line=$(grep -E '^Checkpoint:' "$aw" | head -1 || true)
     # Strip optional backticks around date/sha (legacy TEMPLATE copies)
     ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint:[[:space:]]*[`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]?[[:space:]]*@[[:space:]]*[`"]?([0-9a-fA-F]{4,40})[`"]?.*/\1/')
     if ! printf '%s' "$ck_sha" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
       echo "stale-resume: $aw Checkpoint missing, placeholder, or non-hex (HEAD $head_short)"
       ck_sha=""
     else
       ck_full=$(git rev-parse --verify "${ck_sha}^{commit}" 2>/dev/null || true)
       if [ -z "$ck_full" ] || [ "$ck_full" != "$head_full" ]; then
         echo "stale-resume: $aw Checkpoint@$ck_sha != HEAD@$head_short — suggest /agent-memory sync"
       fi
     fi
   fi
   state=".agents/memory/.hook-sync-state"
   if [ ! -f "$state" ]; then
     echo "hook-state-absent: .agents/memory/.hook-sync-state missing — hooks unused or not installed (info; not the same as evidence cleared)"
   else
     paths=$(grep '^session_touched_files=' "$state" | cut -d= -f2- || true)
     if [ -n "$paths" ]; then
       n=$(printf '%s' "$paths" | tr '\036' '\n' | grep -c . || true)
       if [ "${n:-0}" -gt 0 ]; then
         dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
         ck_fresh=false
         if [ -n "$ck_sha" ] && [ -n "$head_full" ]; then
           ck_full=$(git rev-parse --verify "${ck_sha}^{commit}" 2>/dev/null || true)
           [ -n "$ck_full" ] && [ "$ck_full" = "$head_full" ] && ck_fresh=true
         fi
         if $ck_fresh && [ "${dirty:-1}" -eq 0 ]; then
           # Warning — consume was skipped after a covering sync
           echo "evidence-stale-uncleared: $n path(s) remain with Checkpoint@HEAD and clean tree — run consume-evidence (sync step)"
         elif $ck_fresh && [ "${dirty:-0}" -gt 0 ]; then
           # Info by default — hooks re-list dirty paths until commit; escalate in judgment only if meaning is missing
           echo "evidence-dirty-requeue: $n path(s) with Checkpoint@HEAD and dirty tree (info) — expected until commit when Task/Progress/log already cover those paths; escalate to evidence-pending only if meaning is missing"
         else
           # Warning — Checkpoint behind or no active-work; need catch-up meaning
           echo "evidence-pending: $n path(s) in .hook-sync-state — active-work/log lack covering meaning or Checkpoint behind HEAD; run /agent-memory sync then consume"
         fi
       fi
     fi
   fi
   # Memory claims hooks/state absent while FS shows otherwise
   if grep -qiE 'hooks? (not |never )?installed|\.hook-sync-state.*(absent|missing)|checkpoint path evidence unavailable' \
     .agents/memory/current.md .agents/memory/log.md 2>/dev/null; then
     carrier=false
     { test -f .cursor/hooks.json || test -f .claude/hooks/agent-memory-sync.sh || \
       test -f .opencode/plugins/agent-memory.ts || test -f .opencode/plugin/agent-memory.ts || \
       test -f .codex/hooks/agent-memory-sync.sh || test -f .gemini/hooks/agent-memory-sync.sh || \
       test -f .github/hooks/agent-memory-sync.sh || test -f .github/hooks/agent-memory.json; } && carrier=true
     if [ -f "$state" ] || $carrier; then
       echo "blocker-hooks-contradiction: current.md/log claim hooks or .hook-sync-state absent, but state and/or harness carrier exists — suggest /agent-memory sync"
     fi
   fi
   # Scaffold placeholder left after real session headings exist
   if grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' .agents/memory/log.md 2>/dev/null && \
     grep -q '_No entries yet\._' .agents/memory/log.md 2>/dev/null; then
     echo "log-placeholder-stale: _No entries yet._ coexists with a session heading — remove placeholder (bootstrap/sync)"
   fi
   ```

   **`pending-doc` invalidate check (warning only when met).** For each H2 learning/pitfall with a `- pending-doc:` (or `- pending-doc`) line, read sibling `- Invalidate when:` / Evidence paths. **Only if** the named canonical file already documents the Insight (judgment — or exact phrase overlap ≥ 40 chars in `AGENTS.md` / `README.md` / Evidence target), report `pending-doc-met: <heading> — suggest consolidate promote/remove`. Open `pending-doc` whose invalidate condition is still false is **healthy backlog** — do **not** report it as a warning, info row, or Fix offer item.
   From the **project root**, check links in `index.md` that point outside memory (e.g. `../../AGENTS.md`, `../../docs/...`) and report missing targets as warnings.

   **Exact-duplication candidates (deterministic warning, never auto-fix).** From the project root, extract non-placeholder lines ≥ 60 characters from `.agents/memory/**/*.md` and look for exact matches in common canonical sources (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md`, `docs/`). Report each match as `dup-exact: <memory-file> ↔ <source-file>`. **Skip** when the memory file is `.agents/memory/instructions.md` and the match is under `skills/agent-memory/vendor/memory/` (meta-repo dogfood mirror of the skeleton — expected). Do not treat `skills/agent-memory/vendor/memory/**` as a canonical source for this scan. Judgment paraphrase duplication still belongs in the semantic section below.

   **Instruction wiring checks** — run from the **project root** (not from `.agents/memory/`). Detect agent-memory blocks via `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` or legacy plain tags.

   ```bash
   # Helper: true if file contains an agent-memory block
   has_block() { grep -q '<agent-memory>' "$1" 2>/dev/null; }

   # (a) Potential double-injection — block in AGENTS.md AND a harness-native file
   # when AGENTS.md is not needed as a shared carrier
   agents_block=false; has_block AGENTS.md && agents_block=true
   codex_or_opencode=false
   { test -d .codex || test -d .opencode; } && codex_or_opencode=true
   claude_delegates=false
   test -f CLAUDE.md && grep -qE '@(\./)?AGENTS\.md' CLAUDE.md && claude_delegates=true
   gemini_delegates=false
   test -f GEMINI.md && grep -qE '@(\./)?AGENTS\.md' GEMINI.md && gemini_delegates=true
   shared_carrier=false
   { $codex_or_opencode || $claude_delegates || $gemini_delegates; } && shared_carrier=true

   if $agents_block; then
     has_block .cursor/rules/agent-memory.mdc && \
       ! $shared_carrier && echo "double-injection: AGENTS.md + .cursor/rules/agent-memory.mdc"
     has_block .github/instructions/agent-memory.instructions.md && \
       ! $shared_carrier && echo "double-injection: AGENTS.md + agent-memory.instructions.md"
   fi

   # (b) Delegation canary — block in BOTH delegator and AGENTS.md
   for f in CLAUDE.md GEMINI.md; do
     test -f "$f" || continue
     grep -qE '@(\./)?AGENTS\.md' "$f" || continue
     has_block "$f" && has_block AGENTS.md && \
       echo "delegation-canary: block in $f and AGENTS.md (remove from $f)"
   done
   ```

   Report each finding as a **warning** with the suggested fix (remove redundant block from the delegating file or from `AGENTS.md` when not a shared carrier). `--fix` may offer to remove the block from the delegating file in case (b) (**sensitive** — show diff, confirm per file). `--fix` never removes blocks from `AGENTS.md` when it is a shared carrier for codex/opencode/delegation.

3. **Soft budgets (warnings only).** Count non-empty lines:
   - `current.md` > 30 → warn bloat.
   - each `active-work/*.md` (except TEMPLATE) > 45 → warn bloat.
   - `index.md` > 80 → warn bloat.
   - `log.md` > 30 session headings (`^## \[`) → suggest consolidate.
   - `decisions.md` or any `learnings.md` / `learnings-*.md` > 200 → suggest topic splits or consolidate merge (do not auto-split).

4. **Semantic checks (judgment — report as warnings to review).** These need reading, not grepping; surface them for the user to confirm rather than auto-fixing:
   - **Stale `current.md`** — does _In progress_ still match open active-work? Deterministic `current-stale-branch:` when an In progress bullet links or names `active-work/FOO.md` (or `active-work/FOO`) and that file is missing. Do not warn merely because a local active-work file is unlisted (do not mirror this branch's Task).
   - **Missing resume quality** — active-work without a concrete _Next step_ or _Validation_ when _Task_ is non-placeholder. Optional sections (`Assumptions / open questions`, `Blockers`, `Rejected approaches`, `References`, `Hold`) are not required; when evidence exists and the section is missing, suggest adding it (do not invent content).
   - **Hold overflow (`hold-overflow`)** — more than three content bullets under `## Hold` (deterministic awk above). Trim to three, or promote a durable fact with `/agent-memory learn` / consolidate. Hold is branch scratch, not `learnings.md`.
   - **Stale Next step (`stale-next-step`)** — an action bullet under _Next step_ cites `/agent-memory …` (especially the command just run); replace with a product action and suggest sync. Deterministic check matches `-` bullets only (TEMPLATE/section blurbs that mention the ban do not count). Confirm in judgment when the command already completed this session.
   - **Duplicated Progress (`dup-progress-log`)** — Progress bullets that merely replay the current `log.md` session (bootstrap/init copy); prefer a one-line pointer to log/learnings.
   - **Hypothesis as fact** — assumptions phrased as certainties outside _Assumptions / open questions_.
   - **Duplication** — paraphrased facts also in AGENTS/README/docs/ADR (exact long-line overlap is handled deterministically above; ignore instructions↔vendor dogfood mirrors).
   - **Local decision with ADR** — local fallback body that should be a pointer.
   - **Superseded without link** — `Status: superseded` without `Superseded by:`, or a newer decision that should mark an older one superseded.
   - **Unknown Relates verb (`unknown-relates-verb`)** — `- Relates:` / `- caused_by:` / decisions aliases (`Caused by:`, `Contradicts:`, `See:`, `Supersedes:`, `Superseded by:`) use a verb outside `supersedes` / `superseded_by` / `caused_by` / `contradicts` / `see` (deterministic grep above). Suggest replacing the verb; do not invent a new type.
   - **Relates missing target (`relates-missing`)** — typed-edge markdown link whose file does not exist, or whose `#fragment` is missing from the target (deterministic grep above; skip placeholders with `<`, http(s), empty `#`). Suggest retarget, drop the line, or consolidate — not `lint --fix`.
   - **Learning missing Relates (`learning-missing-relates`)** — H2 learning/pitfall whose Evidence names a recall file (`decisions.md`, `log.md`, `learnings.md`, `learnings-*.md`) and the entry has no `- Relates:` line (deterministic awk above). Suggest adding one `- Relates:` (confirm). Prefer that confirm edit over consolidate.
   - **Learning missing evidence (`learning-missing-evidence`)** — H2 learning/pitfall without an Evidence bullet (or legacy one-liner missing evidence). Suggest `/agent-memory learn` rewrite or consolidate Discard/pointer — not `lint --fix`.
   - **Learning/pitfall without use trigger / verified** — missing Use when or Verified on H2 entries or legacy one-liners.
   - **Contradicts unlinked (`contradicts-unlinked`)** — two Insights (or a decision pair) that conflict with no `contradicts` / `Contradicts:` edge. Suggest a typed line or consolidate Contradiction — do not auto-merge.
   - **Supersede cycle (`supersede-cycle`)** — A supersedes B and B supersedes A. Break the cycle; keep the live successor.
   - **Legacy learning one-liner** — `- [YYYY-MM-DD] [learning|pitfall] …` without an H2 heading; suggest migrating to the H2 form when editing (do not auto-rewrite).
   - **Invalid or stale `when editing:`** — per the contract in `instructions.md` → _Always load_: glob that matches no repo path, non-repo-root-relative glob, or a topic split with no hint when evidence paths are obvious. Cross-cutting `learnings.md` without a hint is fine.
   - **Overbroad `when editing:`** — reject **any** near-always-on glob in the hint list (companions do not redeem it). Normalize first: run **to fixpoint** — repeat until stable: strip a leading `./`, strip a leading `/`, and collapse `//` empty segments (so `/./hooks/**`, `/.//hooks/**`, `.//./hooks/**`, `././hooks/**`, `./hooks/**`, `.//hooks/**`, and `/hooks/**` all become `hooks/**`); reject any glob that still starts with `/` after normalize; then iteratively collapse `**/**` → `**`. Then reject (1) **structural** — two or more slash-separated segments that are each only `*`, `?*`, or `**` (e.g. `*/*`, `*/*/*`, `*/*/*/*`, `?*/*`, `?*/*/*`, `*/*/**`); also any glob with **no literal path segment** whose parts are only pure wildcards and/or `*.*` / `*.<ext>` at any depth (e.g. `*/*.*`, `*/*.<ext>`, `*/*/*.ts`, `*/*/*/*.json`, `?*/*/*.sh`, `*/*/*.*`); (2) **any** `**/*.<ext>` or `**/*.*`; (3) **any** `<top-level-dir>/**` and near-equivalents (`dir/**/*`, `dir/*/**`, `**/dir/**`) including `hooks/**`, `tests/**`, `docs/**`, `.agents/**`; (4) **explicit denylist** — including `**`, `**/*`, `**/**`, `**/**/*`, `*/**`, `*/*`, `?*/*`, `*/*/*`, `*/*/**`, `**/*/**`, `**/*/*`, `*`, `*.*`, `*.md`, `**/*.md`, `**/*.*`, `*/*.*`, `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx`, `**/*.py`, `**/**/*.ts`, `**/*/*.ts`, `*/**/*.ts`, `src/**`, `src/**/*`, `src/**/**`, `lib/**`, `app/**`, or `packages/**`. Prefer path-scoped globs with evidence.
   - **Stale `pending-doc` learnings (`pending-doc-met` only)** — `Invalidate when` already true, or canonical doc now covers the Insight; consolidate should promote/remove. **Never** warn on open valid `pending-doc` (bootstrap/learn backlog waiting on external docs).
   - **`evidence-dirty-requeue` escalate** — when step 2 emitted `evidence-dirty-requeue` and Task / Progress / current-session `log.md` do **not** cover the pending paths, re-report as **warning** `evidence-pending` (need sync meaning). When they do cover, leave it as **info** only — no Fix offer.
   - **Contradictions** — memory vs canonical source or code (distinct from `contradicts-unlinked` inside recall).
   - **Legacy path-only bullets / empty headings / Touched files** — candidates for consolidate.
   - **Legacy mirrors** — `vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*`, plus graph-tree folders (`architecture/`, `components/`, `episodes/`, `changes/`, `timeline/`, `project.md`) with bodies that should be pointers in `index.md` / `decisions.md` / `learnings.md`.
   - **Mixed log heading** — bullets under a `[type]` / outcome that clearly belong to another concern (e.g. consolidate notes under `[docs] bootstrap`); suggest split heading on next sync.
   - **Malformed log heading shape** — session line uses `type | title` pipes or unbracketed type instead of `## [YYYY-MM-DD] [session-id?] [type] outcome`; suggest sync rewrite.
   - **Empty log after scaffold (`empty-log` / `empty-log-after-scaffold`)** — zero `## [date]` headings while learnings/index show bootstrap recall; suggest restoring a short founding session heading (consolidate must not empty current session).
   - **Stale log placeholder (`log-placeholder-stale`)** — `_No entries yet._` still present after a real session heading exists (deterministic grep above).
   - **Same-day duplicate log (`same-day-dup-log`)** — two-plus headings share a date and `[type]`; rewrite today's heading when the new outcome supersedes (deterministic awk above).
   - **Index catalog (`index-catalog`)** — more than eight `_Canonical project sources_` bullets; trim to entry points a cold session needs (deterministic awk above).
   - **Hooks/state blocker contradiction (`blocker-hooks-contradiction`)** — memory claims hooks or `.hook-sync-state` absent while state/carrier exists (deterministic above); suggest sync.
   - **Bloat** — always-loaded files grown long or verbose entries.
   - **Quality smoke (optional checklist)** — with only memory open, can you answer: (1) next concrete step, (2) what must not break, (3) where to edit, (4) how to prove it worked?

5. **Report.** Group findings as **errors**, **warnings**, and **info** (see Severity above). For each, name the file and the problem. Omit empty bands. Do not promote info into warnings. Do not list open valid `pending-doc` anywhere in the report.

6. **Fix offer.** Offer fixes **only** for errors and warnings — never for info. Safe issues (e.g. remove a dead link, add an orphan recall file to `index.md`) may be applied with confirmation when they edit user content. For stale `current.md` / `current-stale-branch` / active-work / `log.md` / `stale-next-step` / uncovered `evidence-pending`, suggest `/agent-memory sync` or drop the stale In progress bullet rather than inventing product work. For `hold-overflow`, offer to keep at most 3 Hold bullets and promote or drop the rest (confirm; not `lint --fix` silent rewrite). For `same-day-dup-log`, offer to merge into one heading (rewrite the live outcome; drop false earlier bullets). For `index-catalog`, offer to drop sources a cold session can skip (keep agent file + README + docs/ADR index). For `empty-log` / `empty-log-after-scaffold`, offer to restore one short founding session heading (do not re-run consolidate Discard). For `evidence-stale-uncleared` only, offer to run `agent-memory-consume-evidence.sh`. Do **not** offer consume or sync solely for `evidence-dirty-requeue` info. For `unknown-relates-verb`, offer to replace the verb with the closed list (confirm). For `learning-missing-relates`, offer to add one `- Relates:` line (confirm); prefer that confirm edit over consolidate — do not invent this in `lint --fix` as a silent rewrite. For `relates-missing` / `learning-missing-evidence` / `contradicts-unlinked` / `supersede-cycle` / `pending-doc-met` / promotion/pruning / legacy mirrors / path-only bullets / learnings split-merge / rolling closed log, suggest `/agent-memory consolidate` — **do not** do that work in `lint --fix`. For capturing a new gated learning now, suggest `/agent-memory learn`.

   `--fix` — with this flag, also offer to **delete stale per-branch `active-work/<branch>.md` files** (files whose branch no longer exists), **delete leftover `active-work/TEMPLATE.md`** (`template-in-memory`; scaffold SoT is this skill's `references/active-work-template.md`), and, for **delegation-canary** findings (step 2), offer to remove the redundant block from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` (each stale-branch and delegation removal sensitive — show diff, confirm). `TEMPLATE.md` deletion is safe. `--fix` never deletes anything other than those stale `active-work` files, leftover `TEMPLATE.md`, and approved delegation-canary blocks. Delegation-canary block removal edits only the agent-memory delimiters in `CLAUDE.md`/`GEMINI.md` (with confirmation).

## Notes

- Soft budgets and structural scripts above are canonical for lint (including the full _Overbroad `when editing:`_ denylist). Keep `instructions.md` → _Memory lint boundaries_ and _Always load_ `when editing:` match rule at the summary level only (no duplicated budget numbers or denylist there).
- No `markdownlint` here — Markdown style is the concern of the source repo, not of the installed memory in a user's project.
