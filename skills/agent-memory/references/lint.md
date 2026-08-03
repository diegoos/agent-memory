# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report findings; fix only what is safe, and never change user content without confirmation. Semantic promotion/pruning belongs to `/agent-memory consolidate` — not `lint --fix`.

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
            vision.md architecture.md patterns.md mistakes.md known-issues.md; do
     [ -f "$f" ] || continue
     grep -q "$(basename "$f")" index.md || echo "orphan: $f"
   done
   find . -maxdepth 1 -name 'learnings-*.md' 2>/dev/null | while read -r f; do
     grep -q "$(basename "$f")" index.md || echo "orphan: $f"
   done
   for d in domains features; do
     [ -d "$d" ] || continue
     find "$d" -name '*.md' 2>/dev/null | while read -r f; do
       grep -q "$(basename "$f")" index.md || echo "orphan: $f"
     done
   done

   # Required headings for resume (agent-owned)
   grep -q '^## In progress' current.md || echo "missing-heading: current.md ## In progress"
   find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     for h in '## Task' '## Progress' '## Next step' '## Validation' \
              '## Assumptions / open questions' '## Blockers' \
              '## Rejected approaches' '## References'; do
       grep -q "^${h}" "$f" || echo "missing-heading: $f $h"
     done
     # Allow optional backticks around date/sha (legacy); prefer plain form
     if ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}' "$f"; then
       echo "missing-checkpoint: $f"
     elif grep -qE '^Checkpoint: `' "$f"; then
       echo "checkpoint-backticks: $f — prefer Checkpoint: YYYY-MM-DD @ SHORT-SHA without backticks"
     elif ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}[`"]?[[:space:]]*$' "$f"; then
       echo "checkpoint-prose: $f — Checkpoint line must be only date @ sha (no trailing TEMPLATE instructions)"
     fi
     # Next step must not be a memory skill command (product work only)
     awk '
       /^## Next step/ { in_ns=1; next }
       /^## / { in_ns=0 }
       in_ns && /\/agent-memory[[:space:]]/ {
         print "stale-next-step: '"$f"' — Next step cites /agent-memory; use a product action (skill cmds → Validation or report)"
         exit
       }
     ' "$f"
     grep -q '^## Touched files' "$f" && echo "legacy-touched-files: $f"
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
   branch=$(git branch --show-current 2>/dev/null | tr -c 'A-Za-z0-9._-' '-')
   [ -n "$branch" ] || branch=local
   aw=".agents/memory/active-work/${branch}.md"
   head_full=$(git rev-parse HEAD 2>/dev/null || true)
   head_short=$(git rev-parse --short HEAD 2>/dev/null || true)
   if [ -f "$aw" ] && [ -n "$head_full" ]; then
     ck_line=$(grep -E '^Checkpoint:' "$aw" | head -1 || true)
     # Strip optional backticks around date/sha (legacy TEMPLATE copies)
     ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint:[[:space:]]*[`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]?[[:space:]]*@[[:space:]]*[`"]?([0-9a-fA-F]{4,40})[`"]?.*/\1/')
     if ! printf '%s' "$ck_sha" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
       echo "stale-resume: $aw Checkpoint missing, placeholder, or non-hex (HEAD $head_short)"
     else
       ck_full=$(git rev-parse --end-of-options "$ck_sha" 2>/dev/null || true)
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
         echo "evidence-pending: $n path(s) in .hook-sync-state — confirm active-work/log reflect meaning (sync is catch-up); then consume via agent-memory-consume-evidence.sh"
         # Uncleared after meaning likely written: Checkpoint matches HEAD and tree clean
         dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
         ck_fresh=false
         if [ -f "$aw" ] && [ -n "$head_full" ]; then
           ck_line=$(grep -E '^Checkpoint:' "$aw" | head -1 || true)
           ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint:[[:space:]]*[`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]?[[:space:]]*@[[:space:]]*[`"]?([0-9a-fA-F]{4,40})[`"]?.*/\1/')
           if printf '%s' "$ck_sha" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
             ck_full=$(git rev-parse --end-of-options "$ck_sha" 2>/dev/null || true)
             [ -n "$ck_full" ] && [ "$ck_full" = "$head_full" ] && ck_fresh=true
           fi
         fi
         if $ck_fresh && [ "${dirty:-1}" -eq 0 ]; then
           echo "evidence-stale-uncleared: $n path(s) remain with Checkpoint@HEAD and clean tree — run consume-evidence (sync step)"
         fi
       fi
     fi
   fi
   ```

   **`pending-doc` invalidate check (warning).** For each H2 learning/pitfall with a `- pending-doc:` (or `- pending-doc`) line, read sibling `- Invalidate when:` / Evidence paths. If the named canonical file already documents the Insight (judgment — or exact phrase overlap ≥ 40 chars in `AGENTS.md` / `README.md` / Evidence target), report `pending-doc-met: <heading> — suggest consolidate promote/remove`.
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
   - `current.md` > 40 → warn bloat.
   - each `active-work/*.md` (except TEMPLATE) > 60 → warn bloat.
   - `index.md` > 100 → warn bloat.
   - `log.md` > 30 session headings (`^## \[`) → suggest consolidate.
   - `decisions.md` or any `learnings.md` / `learnings-*.md` > 200 → suggest topic splits or consolidate merge (do not auto-split).

4. **Semantic checks (judgment — report as warnings to review).** These need reading, not grepping; surface them for the user to confirm rather than auto-fixing:
   - **Stale `current.md`** — does _In progress_ still match open active-work?
   - **Missing resume quality** — active-work without a concrete _Next step_ or _Validation_ when _Task_ is non-placeholder.
   - **Stale Next step (`stale-next-step`)** — _Next step_ cites `/agent-memory …` (especially the command just run); replace with a product action and suggest sync. Deterministic grep above; confirm in judgment when the command already completed this session.
   - **Duplicated Progress (`dup-progress-log`)** — Progress bullets that merely replay the current `log.md` session (bootstrap/init copy); prefer a one-line pointer to log/learnings.
   - **Hypothesis as fact** — assumptions phrased as certainties outside _Assumptions / open questions_.
   - **Duplication** — paraphrased facts also in AGENTS/README/docs/ADR (exact long-line overlap is handled deterministically above; ignore instructions↔vendor dogfood mirrors).
   - **Local decision with ADR** — local fallback body that should be a pointer.
   - **Superseded without link** — `Status: superseded` without `Superseded by:`, or a newer decision that should mark an older one superseded.
   - **Learning/pitfall without evidence / use trigger / verified** — missing fields on H2 entries or legacy one-liners.
   - **Legacy learning one-liner** — `- [YYYY-MM-DD] [learning|pitfall] …` without an H2 heading; suggest migrating to the H2 form when editing (do not auto-rewrite).
   - **Invalid or stale `when editing:`** — per the contract in `instructions.md` → _Always load_: glob that matches no repo path, non-repo-root-relative glob, or a topic split with no hint when evidence paths are obvious. Cross-cutting `learnings.md` without a hint is fine.
   - **Overbroad `when editing:`** — reject **any** near-always-on glob in the hint list (companions do not redeem it). Normalize first: run **to fixpoint** — repeat until stable: strip a leading `./`, strip a leading `/`, and collapse `//` empty segments (so `/./hooks/**`, `/.//hooks/**`, `.//./hooks/**`, `././hooks/**`, `./hooks/**`, `.//hooks/**`, and `/hooks/**` all become `hooks/**`); reject any glob that still starts with `/` after normalize; then iteratively collapse `**/**` → `**`. Then reject (1) **structural** — two or more slash-separated segments that are each only `*`, `?*`, or `**` (e.g. `*/*`, `*/*/*`, `*/*/*/*`, `?*/*`, `?*/*/*`, `*/*/**`); also any glob with **no literal path segment** whose parts are only pure wildcards and/or `*.*` / `*.<ext>` at any depth (e.g. `*/*.*`, `*/*.<ext>`, `*/*/*.ts`, `*/*/*/*.json`, `?*/*/*.sh`, `*/*/*.*`); (2) **any** `**/*.<ext>` or `**/*.*`; (3) **any** `<top-level-dir>/**` and near-equivalents (`dir/**/*`, `dir/*/**`, `**/dir/**`) including `hooks/**`, `tests/**`, `docs/**`, `.agents/**`; (4) **explicit denylist** — including `**`, `**/*`, `**/**`, `**/**/*`, `*/**`, `*/*`, `?*/*`, `*/*/*`, `*/*/**`, `**/*/**`, `**/*/*`, `*`, `*.*`, `*.md`, `**/*.md`, `**/*.*`, `*/*.*`, `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx`, `**/*.py`, `**/**/*.ts`, `**/*/*.ts`, `*/**/*.ts`, `src/**`, `src/**/*`, `src/**/**`, `lib/**`, `app/**`, or `packages/**`. Prefer path-scoped globs with evidence.
   - **Stale `pending-doc` learnings** — `Invalidate when` already true, or canonical doc now covers the Insight (`pending-doc-met` above); consolidate should promote/remove.
   - **Contradictions** — memory vs canonical source or code.
   - **Legacy path-only bullets / empty headings / Touched files** — candidates for consolidate.
   - **Legacy mirrors** — `vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*` with bodies that should be pointers in `index.md` / `decisions.md` / `learnings.md`.
   - **Mixed log heading** — bullets under a `[type]` / outcome that clearly belong to another concern (e.g. consolidate notes under `[docs] bootstrap`); suggest split heading on next sync.
   - **Empty log after scaffold (`empty-log` / `empty-log-after-scaffold`)** — zero `## [date]` headings while learnings/index show bootstrap recall; suggest restoring a short founding session heading (consolidate must not empty current session).
   - **Bloat** — always-loaded files grown long or verbose entries.
   - **Quality smoke (optional checklist)** — with only memory open, can you answer: (1) next concrete step, (2) what must not break, (3) where to edit, (4) how to prove it worked?

5. **Report.** Group findings as **errors** (broken links, missing required headings, orphans, stale per-branch files) and **warnings** (semantic, budgets, legacy). For each, name the file and the problem.

6. **Fix offer.** Offer to fix only safe issues (e.g. remove a dead link, add an orphan recall file to `index.md`). Any fix that edits user content (`current.md`, `decisions.md`, `learnings.md`, `learnings-*.md`, …) must be confirmed first — show the diff. For stale `current.md` / active-work / `log.md` / `stale-next-step`, suggest `/agent-memory sync` (or a direct Next-step edit) rather than inventing product work. For `empty-log` / `empty-log-after-scaffold`, offer to restore one short founding session heading (do not re-run consolidate Discard). For `evidence-stale-uncleared` / covered `evidence-pending`, offer to run `agent-memory-consume-evidence.sh` after confirming meaning coverage. For promotion/pruning / converting legacy mirrors / removing path-only bullets / learnings split-merge, suggest `/agent-memory consolidate` — **do not** do that work in `lint --fix`. For capturing a new gated learning now, suggest `/agent-memory learn`.

   `--fix` — with this flag, also offer to **delete stale per-branch `active-work/<branch>.md` files** (files whose branch no longer exists) and, for **delegation-canary** findings (step 2), offer to remove the redundant block from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` (each removal sensitive — show diff, confirm). Each deletion is still confirmed one by one (it removes a file, so it is sensitive) unless combined with an explicit "delete all stale" approval. `--fix` never deletes anything other than stale `active-work` files, never touches `TEMPLATE.md`, never deletes legacy mirror files. Delegation-canary block removal edits only the agent-memory delimiters in `CLAUDE.md`/`GEMINI.md` (with confirmation).

## Notes

- Soft budgets and structural scripts above are canonical for lint. Keep `instructions.md` → _Memory lint boundaries_ aligned at the summary level only (no duplicated budget numbers there).
- No `markdownlint` here — Markdown style is the concern of the source repo, not of the installed memory in a user's project.
