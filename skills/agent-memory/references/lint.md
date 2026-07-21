# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report
findings; fix only what is safe, and never change user content without
confirmation. Semantic promotion/pruning belongs to `/agent-memory consolidate`
— not `lint --fix`.

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

   # Required headings for hooks
   grep -q '^## In progress' current.md || echo "missing-heading: current.md ## In progress"
   find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     grep -q '^## Task' "$f" || echo "missing-heading: $f ## Task"
     grep -q '^## Touched files' "$f" || echo "missing-heading: $f ## Touched files"
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

   # Stale per-branch active-work: a file whose branch no longer exists
   # (skipped when git lists no branches — no commits yet / not a git repo)
   branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
   [ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"
   done
   ````

   Also report if `.agents/memory/.version` is missing — the memory was likely
   installed manually without the skill, so `update` cannot track its version.

   From the **project root**, check links in `index.md` that point outside
   memory (e.g. `../../AGENTS.md`, `../../docs/...`) and report missing targets
   as warnings.

   **Exact-duplication candidates (deterministic warning, never auto-fix).**
   From the project root, extract non-placeholder lines ≥ 60 characters from
   `.agents/memory/**/*.md` and look for exact matches in common canonical
   sources (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md`, `docs/`). Report
   each match as `dup-exact: <memory-file> ↔ <source-file>`. Judgment paraphrase
   duplication still belongs in the semantic section below.

   **Instruction wiring checks** — run from the **project root** (not from
   `.agents/memory/`). Detect agent-memory blocks via `<!-- <agent-memory> -->`
   … `<!-- </agent-memory> -->` or legacy plain tags.

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

   Report each finding as a **warning** with the suggested fix (remove redundant
   block from the delegating file or from `AGENTS.md` when not a shared
   carrier). `--fix` may offer to remove the block from the delegating file in
   case (b) (**sensitive** — show diff, confirm per file). `--fix` never removes
   blocks from `AGENTS.md` when it is a shared carrier for codex/opencode/delegation.

3. **Soft budgets (warnings only).** Count non-empty lines:
   - `current.md` > 40 → warn bloat.
   - each `active-work/*.md` (except TEMPLATE) > 60 → warn bloat.
   - `index.md` > 100 → warn bloat.
   - `log.md` > 30 session headings (`^## \[`) → suggest consolidate.
   - `decisions.md` or `learnings.md` > 200 → suggest topic splits (do not
     auto-split).

4. **Semantic checks (judgment — report as warnings to review).** These need
   reading, not grepping; surface them for the user to confirm rather than
   auto-fixing:
   - **Stale `current.md`** — does _In progress_ still match open active-work?
   - **Duplication** — paraphrased facts also in AGENTS/README/docs/ADR
     (exact long-line overlap is handled deterministically above).
   - **Local decision with ADR** — local fallback body that should be a pointer.
   - **Learning without evidence / use trigger.**
   - **Stale `pending-doc` learnings.**
   - **Contradictions** — memory vs canonical source or code.
   - **Path-only bullets in closed sessions** — candidates for consolidate.
   - **Legacy mirrors** — `vision.md`, `architecture.md`, `patterns.md`,
     `domains/*`, `features/*` with bodies that should be pointers in
     `index.md` / `decisions.md` / `learnings.md`.
   - **Bloat** — always-loaded files grown long or verbose entries.

5. **Report.** Group findings as **errors** (broken links, missing required
   headings, orphans, stale per-branch files) and **warnings** (semantic,
   budgets, legacy). For each, name the file and the problem.

6. **Fix offer.** Offer to fix only safe issues (e.g. remove a dead link, add an
   orphan recall file to `index.md`). Any fix that edits user content
   (`current.md`, `decisions.md`, `learnings.md`, …) must be confirmed first —
   show the diff. For stale `current.md` / active-work / `log.md`, suggest
   `/agent-memory sync` rather than editing by hand. For promotion/pruning /
   converting legacy mirrors / removing path-only bullets, suggest
   `/agent-memory consolidate` — **do not** do that work in `lint --fix`.

   `--fix` — with this flag, also offer to **delete stale per-branch
   `active-work/<branch>.md` files** (files whose branch no longer exists) and,
   for **delegation-canary** findings (step 2), offer to remove the redundant
   block from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` (each
   removal sensitive — show diff, confirm). Each deletion is still confirmed one
   by one (it removes a file, so it is sensitive) unless combined with an
   explicit "delete all stale" approval. `--fix` never deletes anything other
   than stale `active-work` files, never touches `TEMPLATE.md`, never deletes
   legacy mirror files. Delegation-canary block removal edits only the
   agent-memory delimiters in `CLAUDE.md`/`GEMINI.md` (with confirmation).

## Notes

- Soft budgets and structural scripts above are canonical for lint. Keep
  `instructions.md` → _Memory lint boundaries_ aligned at the summary level
  only (no duplicated budget numbers there).
- No `markdownlint` here — Markdown style is the concern of the source repo, not
  of the installed memory in a user's project.
