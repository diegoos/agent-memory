# `/agent-memory init`

Create the agent-memory structure in the target project and wire it into the
agent instruction file(s). Idempotent: never duplicate or overwrite existing
memory.

## Steps

1. **Guard.** If `.agents/memory/` already exists, stop and tell the user the
   project is already initialized — suggest `/agent-memory update` instead. Do not
   overwrite anything.

2. **Copy the skeleton.** Obtain the repository (see `SKILL.md` → Repository
   source) and copy its `agent-memory/memory/` directory into the project as
   `.agents/memory/` (the entire directory, including `active-work/TEMPLATE.md`).

3. **Write the version anchor.** Create `.agents/memory/.version` containing the
   latest version — the newest version section in the repository's
   `agent-memory/UPDATE.md`, e.g. `0.0.1`.

4. **Wire the agent file(s).** Detect which of `AGENTS.md`, `CLAUDE.md`,
   `GEMINI.md` exist at the project root and add the Brain stub to **each** one
   that exists. Pick the variant per file:

   - `CLAUDE.md`, `GEMINI.md` (support `@import`):

     ```md
     ## Agent Memory

     This project uses Agent Memory (a local Workspace Memory). Before any task,
     read and follow `.agents/memory/instructions.md`.

     @.agents/memory/instructions.md
     ```

   - `AGENTS.md` (plain Markdown):

     ```md
     ## Agent Memory

     This project uses Agent Memory (a local Workspace Memory). Before starting
     any task, open and follow `.agents/memory/instructions.md`, then read
     `.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
     file in `.agents/memory/active-work/`.
     ```

   **Idempotency:** if a file already contains an `## Agent Memory` section, skip
   it — do not add a second one.

5. **No agent file exists?** Create `AGENTS.md` at the project root with the plain
   stub above.

6. **Report.** List what was created and which agent file(s) were wired.

## Notes

- Do not populate the memory here — `init` only scaffolds. To fill it from the
  codebase, the user runs `/agent-memory bootstrap`.
