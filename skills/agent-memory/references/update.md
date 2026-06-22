# `/agent-memory update`

Migrate an existing `.agents/memory/` to the latest structure from the
agent-memory repository — **without ever altering the project's memory content.**

## Boundary (read before doing anything)

- **Project memory (NEVER touch):** `current.md`, `active-work/*`, `decisions.md`,
  `log.md`, `domains/*`, `features/*`, and any user-authored content.
- **Scaffolding (may change, see rules):** `instructions.md`, the structural
  sections of `index.md`, the `.version` file, and brand-new core files.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init`.

2. **Read versions.** Installed = `.agents/memory/.version`. Latest = the newest
   version section in the repository's `agent-memory/UPDATE.md`. If equal, report
   "already up to date" and stop.

3. **Select migrations.** Read the repository's `agent-memory/UPDATE.md` (see
   `SKILL.md` → Repository source) and collect every entry with a version greater
   than the installed version, up to the latest. Each change is tagged `safe` or
   `sensitive`.

4. **Apply, conservatively:**
   - **Automatic (no prompt):**
     - Create new core files that are missing.
   - **Always confirm with a diff before applying:**
     - `instructions.md` when the installed copy differs from the repository's
       current `agent-memory/memory/instructions.md` (identical → nothing to do).
     - Any change to a file that can hold user content — including `index.md`
       (merge structural sections, **preserve the user's Domains/Features lists**).
     - Any rename, move, or deletion.
   - Present each sensitive change as a unified diff and ask the user to approve,
     skip, or abort. Apply only what is approved.

5. **Finalize.** Update `.agents/memory/.version` to the latest. Append one entry
   to `log.md`: `## [YYYY-MM-DD] chore | agent-memory update to <version>`.

6. **Report.** Summarize what was applied automatically, what was confirmed, and
   what was skipped.

## Gotchas

- Never resolve a sensitive change silently. When in doubt, treat it as sensitive
  and confirm.
- The skeleton source of truth is the repository's `agent-memory/memory/`;
  `UPDATE.md` only describes *how* to migrate between versions, not the file
  contents.
