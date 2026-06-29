# `/agent-memory update`

Migrate an existing `.agents/memory/` to the latest structure from the
agent-memory repository — **without ever altering the project's memory
content.** It also refreshes the memory **block** inside the root agent files
(`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`), **only** between the
`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` delimiters (or legacy
plain `<agent-memory>` … `</agent-memory>` tags, which `update` migrates to the
comment form).

## Boundary (read before doing anything)

- **Project memory (NEVER touch):** `current.md`, `active-work/*`,
  `decisions.md`, `log.md`, `domains/*`, `features/*`, and any user-authored
  content.
- **Scaffolding (may change, see rules):** `instructions.md`, the structural
  sections of `index.md`, the `.version` file, brand-new core files, and the
  agent-memory block in the root agent files.
- **Outside the block (NEVER touch):** any content in `AGENTS.md`, `CLAUDE.md`,
  or `GEMINI.md` outside the agent-memory delimiters (`<!-- <agent-memory> -->`
  … `<!-- </agent-memory> -->`, or legacy plain tags).

## Canonical memory block

The exact block `init` writes and `update` refreshes is defined in
[`references/agent-block.md`](./agent-block.md) — read it from there; do not
inline the block text here. The agent file's block is **replaced verbatim** with
that canonical block during update (single source of truth).

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init`.

2. **Read versions.** Installed = `.agents/memory/.version`. Latest = the newest
   version section in the repository's `agent-memory/UPDATE.md`. If equal, still
   run step 5 (refresh the agent-file block) before reporting "already up to
   date".

3. **Select migrations.** Read the repository's `agent-memory/UPDATE.md` (see
   `SKILL.md` → Repository source) and collect every entry with a version
   greater than the installed version, up to the latest. Each change is tagged
   `safe` or `sensitive`.

4. **Apply, conservatively:**
   - **Automatic (no prompt):**
     - Create new core files that are missing.
   - **Always confirm with a diff before applying:**
     - `instructions.md` when the installed copy differs from the repository's
       current `agent-memory/memory/instructions.md` (identical → nothing to
       do).
     - Any change to a file that can hold user content — including `index.md`
       (merge structural sections, **preserve the user's Domains/Features
       lists**).
     - Any rename, move, or deletion.
   - Present each sensitive change as a unified diff and ask the user to
     approve, skip, or abort. Apply only what is approved.

5. **Refresh the agent-file block.** Read the canonical block from
   [`references/agent-block.md`](./agent-block.md). Then, for each of
   `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` at the project root, decide what
   changed and whether it needs updating:
   - **A delimited block exists** (`<!-- <agent-memory> -->` …
     `<!-- </agent-memory> -->`, or legacy plain `<agent-memory>` …
     `</agent-memory>`): compare its current text (between the delimiters,
     inclusive) against the canonical block, byte-for-byte. **Identical → skip
     (already current).** Different → replace its entire content with the
     canonical block (comment delimiters). **Sensitive** — show the unified
     diff, confirm first. Never touch anything outside the delimiters.
   - **No block yet, but a legacy `## Agent Memory` section exists** (installed
     by an older `init` without delimiters): replace that section with the
     canonical block (delimiters and content). **Sensitive** — show the diff,
     confirm first.
   - **No block and no legacy section:** skip (the file was never wired by
     `init`). Do not create a block here — that is `init`'s job. Mention it in
     the report so the user can run `init` if they want the file wired.

   Apply only what is approved. If every wired file's block is already
   byte-identical to the canonical block, report "agent-file blocks already
   current" and move on.

6. **Finalize.** Update `.agents/memory/.version` to the latest. Append one
   entry to `log.md`:
   `## [YYYY-MM-DD] chore | agent-memory update to <version>`.

7. **Report.** Summarize what was applied automatically, what was confirmed, and
   what was skipped — including which agent files had their block refreshed,
   which had a legacy section migrated, and which files were left untouched.

   If `.cursor/rules/agent-memory.mdc` exists (legacy — use hooks instead),
   mention that the user may delete it manually after wiring hooks via
   `init cursor`.

## Gotchas

- Never resolve a sensitive change silently. When in doubt, treat it as
  sensitive and confirm.
- The block refresh edits only between the agent-memory delimiters (comment form
  or legacy plain tags). If no delimiters are found, do **not** guess where the
  block starts — treat it as the legacy-section case above, or skip and report.
- The skeleton source of truth is the repository's `agent-memory/memory/`;
  `UPDATE.md` only describes _how_ to migrate between versions, not the file
  contents.
