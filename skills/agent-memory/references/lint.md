# `/agent-memory lint`

Check `.agents/memory/` for structural and consistency problems. Report findings;
fix only what is safe, and never change user content without confirmation.

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

3. **Semantic checks (judgment — report as warnings to review).** These need
   reading, not grepping; surface them for the user to confirm rather than
   auto-fixing:
   - **Stale `current.md`** — does it still match the actual codebase state?
   - **Duplication** — the same fact recorded in more than one file.
   - **Contradictions** — files (or a file and the code) that disagree.
   - **Bloat** — always-loaded files (`current.md`, active-work) grown long, or
     verbose entries that waste tokens; suggest trimming.

4. **Report.** Group findings as **errors** (broken links, orphans, stale
   per-branch files) and **warnings** (semantic). For each, name the file and the
   problem.

5. **Fix offer.** Offer to fix only safe issues (e.g. remove a dead link, add an
   orphan to `index.md`). Any fix that edits user content (`current.md`,
   `decisions.md`, `domains/*`, …) must be confirmed first — show the diff.
   For stale `current.md` / active-work / `log.md`, suggest `/agent-memory sync`
   rather than editing by hand.

## Notes

- This mirrors the "Memory lint" section of `instructions.md`; keep them aligned.
- No `markdownlint` here — Markdown style is the concern of the source repo, not
  of the installed memory in a user's project.
