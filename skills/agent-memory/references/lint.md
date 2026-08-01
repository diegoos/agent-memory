# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report findings; fix only what is safe, and never change user content without confirmation. Semantic promotion/pruning belongs to `/agent-memory consolidate` — not `lint --fix`.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, suggest `/agent-memory init`.

2. **Structural checks (deterministic).** Run from `.agents/memory/`:

   ````bash
   # Broken relative links inside memory
   grep -rhoE '\]\(\./[^)]+\)' . | sed -E 's/^\]\(\.\/([^)]+)\)$/\1/' \
     | sort -u | while read -r f; do test -e "$f" || echo "missing: $f"; done

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
     grep -qE '^Checkpoint: [0-9]{4}-[0-9]{2}-[0-9]{2} @ ' "$f" || \
       echo "missing-checkpoint: $f"
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

   Report if `.agents/memory/.gitignore` is missing or does not list `.hook-sync-state` — hooks will leave untracked state that may be committed by mistake. Suggest copying from the skill's `vendor/memory/.gitignore`.

   **Stale resume / evidence ahead of memory (warnings).** From the **project root**:

   ```bash
   branch=$(git branch --show-current 2>/dev/null | tr -c 'A-Za-z0-9._-' '-')
   [ -n "$branch" ] || branch=local
   aw=".agents/memory/active-work/${branch}.md"
   head_full=$(git rev-parse HEAD 2>/dev/null || true)
   head_short=$(git rev-parse --short HEAD 2>/dev/null || true)
   if [ -f "$aw" ] && [ -n "$head_full" ]; then
     ck_line=$(grep -E '^Checkpoint: [0-9]{4}-[0-9]{2}-[0-9]{2} @ ' "$aw" | head -1 || true)
     ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint: [0-9]{4}-[0-9]{2}-[0-9]{2} @ //' | tr -d '`"')
     # Only trust hex SHAs (align with hooks sessionStart / pre-commit).
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
   if [ -f "$state" ]; then
     paths=$(grep '^session_touched_files=' "$state" | cut -d= -f2- || true)
     if [ -n "$paths" ]; then
       n=$(printf '%s' "$paths" | tr '\036' '\n' | grep -c . || true)
       [ "${n:-0}" -gt 0 ] && echo "evidence-pending: $n path(s) in .hook-sync-state — confirm active-work/log reflect meaning (sync is catch-up)"
     fi
   fi
   ```

   From the **project root**, check links in `index.md` that point outside memory (e.g. `../../AGENTS.md`, `../../docs/...`) and report missing targets as warnings.

   **Exact-duplication candidates (deterministic warning, never auto-fix).** From the project root, extract non-placeholder lines ≥ 60 characters from `.agents/memory/**/*.md` and look for exact matches in common canonical sources (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md`, `docs/`). Report each match as `dup-exact: <memory-file> ↔ <source-file>`. Judgment paraphrase duplication still belongs in the semantic section below.

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
   - **Hypothesis as fact** — assumptions phrased as certainties outside _Assumptions / open questions_.
   - **Duplication** — paraphrased facts also in AGENTS/README/docs/ADR (exact long-line overlap is handled deterministically above).
   - **Local decision with ADR** — local fallback body that should be a pointer.
   - **Superseded without link** — `Status: superseded` without `Superseded by:`, or a newer decision that should mark an older one superseded.
   - **Learning/pitfall without evidence / use trigger / verified** — missing fields on H2 entries or legacy one-liners.
   - **Legacy learning one-liner** — `- [YYYY-MM-DD] [learning|pitfall] …` without an H2 heading; suggest migrating to the H2 form when editing (do not auto-rewrite).
   - **Invalid or stale `when editing:`** — per the contract in `instructions.md` → _Always load_: glob that matches no repo path, non-repo-root-relative glob, or a topic split with no hint when evidence paths are obvious. Cross-cutting `learnings.md` without a hint is fine.
   - **Stale `pending-doc` learnings.**
   - **Contradictions** — memory vs canonical source or code.
   - **Legacy path-only bullets / empty headings / Touched files** — candidates for consolidate.
   - **Legacy mirrors** — `vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*` with bodies that should be pointers in `index.md` / `decisions.md` / `learnings.md`.
   - **Bloat** — always-loaded files grown long or verbose entries.
   - **Quality smoke (optional checklist)** — with only memory open, can you answer: (1) next concrete step, (2) what must not break, (3) where to edit, (4) how to prove it worked?

5. **Report.** Group findings as **errors** (broken links, missing required headings, orphans, stale per-branch files) and **warnings** (semantic, budgets, legacy). For each, name the file and the problem.

6. **Fix offer.** Offer to fix only safe issues (e.g. remove a dead link, add an orphan recall file to `index.md`). Any fix that edits user content (`current.md`, `decisions.md`, `learnings.md`, `learnings-*.md`, …) must be confirmed first — show the diff. For stale `current.md` / active-work / `log.md`, suggest `/agent-memory sync` rather than editing by hand. For promotion/pruning / converting legacy mirrors / removing path-only bullets / learnings split-merge, suggest `/agent-memory consolidate` — **do not** do that work in `lint --fix`. For capturing a new gated learning now, suggest `/agent-memory learn`.

   `--fix` — with this flag, also offer to **delete stale per-branch `active-work/<branch>.md` files** (files whose branch no longer exists) and, for **delegation-canary** findings (step 2), offer to remove the redundant block from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` (each removal sensitive — show diff, confirm). Each deletion is still confirmed one by one (it removes a file, so it is sensitive) unless combined with an explicit "delete all stale" approval. `--fix` never deletes anything other than stale `active-work` files, never touches `TEMPLATE.md`, never deletes legacy mirror files. Delegation-canary block removal edits only the agent-memory delimiters in `CLAUDE.md`/`GEMINI.md` (with confirmation).

## Notes

- Soft budgets and structural scripts above are canonical for lint. Keep `instructions.md` → _Memory lint boundaries_ aligned at the summary level only (no duplicated budget numbers there).
- No `markdownlint` here — Markdown style is the concern of the source repo, not of the installed memory in a user's project.
