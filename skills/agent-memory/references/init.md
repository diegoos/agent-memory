# `/agent-memory init`

Create the agent-memory structure in the target project and wire it into the
agent instruction file(s). Idempotent: never duplicate or overwrite existing
memory.

## Steps

1. **Guard.** If `.agents/memory/` already exists, stop and tell the user the
   project is already initialized — suggest `/agent-memory update` instead. Do
   not overwrite anything.

2. **Copy the skeleton.** Obtain the repository (see `SKILL.md` → Repository
   source) and copy its `agent-memory/memory/` directory into the project as
   `.agents/memory/` (the entire directory, including
   `active-work/TEMPLATE.md`).

3. **Write the version anchor.** Create `.agents/memory/.version` containing the
   latest version — the newest version section in the repository's
   `agent-memory/UPDATE.md`, e.g. `0.0.1`.

4. **Wire the agent file(s).** Detect which of `AGENTS.md`, `CLAUDE.md`,
   `GEMINI.md` exist at the project root and add the memory block to **each**
   one that exists. Use the **canonical block** defined in
   [`references/agent-block.md`](./agent-block.md) — copy it verbatim (the
   `<agent-memory>` … `</agent-memory>` delimiters and everything between them).
   The delimiters let `/agent-memory update` later find and refresh **only**
   that block, without touching the rest of the file; the block points to
   `.agents/memory/instructions.md` via `@import` **and** spells out the
   always-load files, so harnesses that ignore `@import` (or only read
   `AGENTS.md` as plain Markdown) still load the memory.

   **Idempotency:** if a file already contains a `<agent-memory>` block, skip it
   — do not add a second one. (A legacy `## Agent Memory` section without the
   delimiters is migrated, not duplicated — see `references/update.md`.)

5. **No agent file exists?** Create `AGENTS.md` at the project root with the
   canonical block above.

6. **Report.** List what was created and which agent file(s) were wired.

## Notes

- Do not populate the memory here — `init` only scaffolds. To fill it from the
  codebase, the user runs `/agent-memory bootstrap`.
