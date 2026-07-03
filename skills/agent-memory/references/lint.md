# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report
findings; fix only what is safe, and never change user content without
confirmation.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, suggest `/agent-memory init`.

2. **Structural checks (deterministic).** Run from `.agents/memory/`:

   ```bash
   # Broken cross-references: relative links pointing to files that no longer exist
   grep -rhoE '\]\(\./[^)]+\)' . | sed -E 's/^\]\(\.\/([^)]+)\)$/\1/' \
     | sort -u | while read -r f; do test -e "$f" || echo "missing: $f"; done

   # Orphaned files: domains/features not referenced from index.md
   find domains features -name '*.md' 2>/dev/null | while read -r f; do
     grep -q "$(basename "$f")" index.md || echo "orphan: $f"
   done

   # Stale per-branch active-work: a file whose branch no longer exists
   # (skipped when git lists no branches — no commits yet / not a git repo)
   branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
   [ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
     printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"
   done
   ```

   Also report if `.agents/memory/.version` is missing — the memory was likely
   installed manually without the skill, so `update` cannot track its version.

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
   blocks from `AGENTS.md` when it is a shared carrier for
   codex/opencode/delegation.

3. **Semantic checks (judgment — report as warnings to review).** These need
   reading, not grepping; surface them for the user to confirm rather than
   auto-fixing:
   - **Stale `current.md`** — does it still match the actual codebase state?
   - **Duplication** — the same fact recorded in more than one file.
   - **Contradictions** — files (or a file and the code) that disagree.
   - **Bloat** — always-loaded files (`current.md`, active-work) grown long, or
     verbose entries that waste tokens; suggest trimming.

4. **Report.** Group findings as **errors** (broken links, orphans, stale
   per-branch files) and **warnings** (semantic). For each, name the file and
   the problem.

5. **Fix offer.** Offer to fix only safe issues (e.g. remove a dead link, add an
   orphan to `index.md`). Any fix that edits user content (`current.md`,
   `decisions.md`, `domains/*`, …) must be confirmed first — show the diff. For
   stale `current.md` / active-work / `log.md`, suggest `/agent-memory sync`
   rather than editing by hand.

   `--fix` — with this flag, also offer to **delete stale per-branch
   `active-work/<branch>.md` files** (files whose branch no longer exists) and,
   for **delegation-canary** findings (step 2), offer to remove the redundant
   block from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` (each
   removal sensitive — show diff, confirm). Each deletion is still confirmed one
   by one (it removes a file, so it is sensitive) unless combined with an
   explicit "delete all stale" approval. `--fix` never deletes anything other
   than stale `active-work` files, never touches `TEMPLATE.md`.
   Delegation-canary block removal edits only the agent-memory delimiters in
   `CLAUDE.md`/`GEMINI.md` (with confirmation). For other user content, fallback
   to `sync` or a manual edit.

## Notes

- This mirrors the "Memory lint" section of `instructions.md`; keep them
  aligned.
- No `markdownlint` here — Markdown style is the concern of the source repo, not
  of the installed memory in a user's project.
