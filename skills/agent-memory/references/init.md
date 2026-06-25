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
   `GEMINI.md` exist at the project root and add the memory stub to **each** one
   that exists. The stub is the same for all of them — it points to
   `.agents/memory/instructions.md` via `@import` **and** spells out the
   always-load files, so harnesses that ignore `@import` (or only read
   `AGENTS.md` as plain Markdown) still load the memory:

   ```md
   ## Agent Memory

   This project uses Agent Memory (a local Workspace Memory). Before starting
   any task, open and follow `.agents/memory/instructions.md`, then read
   `.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
   file in `.agents/memory/active-work/`.

   @.agents/memory/instructions.md
   ```

   The `@import` line is honored by Claude Code, Gemini CLI, Codex, and any
   harness that follows the AGENTS.md `@import` convention; the explicit read
   list above it covers harnesses that treat `AGENTS.md` as plain Markdown
   (Cursor, plain-text readers). Including both is intentional and harmless — a
   harness that loads `@import` simply gets `instructions.md` once.

   **Idempotency:** if a file already contains an `## Agent Memory` section,
   skip it — do not add a second one.

5. **No agent file exists?** Create `AGENTS.md` at the project root with the
   plain stub above.

6. **Report.** List what was created and which agent file(s) were wired.

## Notes

- Do not populate the memory here — `init` only scaffolds. To fill it from the
  codebase, the user runs `/agent-memory bootstrap`.
