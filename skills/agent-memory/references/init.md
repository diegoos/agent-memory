# `/agent-memory init`

Create the agent-memory structure in the target project and wire it into the
agent instruction file(s) and harness-specific config. Idempotent: never
duplicate or overwrite existing memory or harness files.

## Invocation

```text
/agent-memory init                  # auto-detect harnesses from the project
/agent-memory init <harness>        # wire one harness only
```

Accepted `<harness>` values (aliases in parentheses):

| Harness    | Aliases       | Agent instruction file | Harness dir required for extras      |
| ---------- | ------------- | ---------------------- | ------------------------------------ |
| `cursor`   | —             | `AGENTS.md`            | `.cursor/` — lifecycle hooks         |
| `claude`   | `claude-code` | `CLAUDE.md`            | `.claude/` — lifecycle hooks         |
| `codex`    | —             | `AGENTS.md`            | `.codex/` — lifecycle hooks          |
| `opencode` | —             | `AGENTS.md`            | `.opencode/` — plugin + sync script  |
| `copilot`  | `github`      | `AGENTS.md`            | `.github/` — lifecycle hooks         |
| `gemini`   | —             | `GEMINI.md`            | — (agent file only; `@import` works) |

If `<harness>` is missing, **auto-detect** (see step 5). If it is unknown, stop
and list the accepted values.

Canonical sources live under `skills/agent-memory/` in the agent-memory repo:

- Agent block: [`references/agent-block.md`](./agent-block.md)
- Harness hooks/plugin: [`references/install-hooks.md`](./install-hooks.md)

## Steps

1. **Guard.** If `.agents/memory/` already exists, stop and tell the user the
   project is already initialized — suggest `/agent-memory update` or
   `/agent-memory install hooks <harness>` to refresh hooks. Do not overwrite
   anything.

2. **Copy the skeleton.** Obtain the repository (see `SKILL.md` → Repository
   source) and copy its `agent-memory/memory/` directory into the project as
   `.agents/memory/` (the entire directory, including `active-work/TEMPLATE.md`
   and `.gitignore` for hook-local state files).

3. **Write the version anchor.** Create `.agents/memory/.version` containing the
   latest version — the newest version section in the repository's
   `agent-memory/UPDATE.md`, e.g. `0.0.7`.

4. **Parse the harness target.** From the invocation, read optional `<harness>`.
   Normalize aliases (`claude-code` → `claude`, `github` → `copilot`). If
   omitted, set mode to `auto`.

5. **Wire agent instruction file(s).** Use the **canonical block** from
   [`references/agent-block.md`](./agent-block.md) — copy it verbatim (the
   `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` delimiters and
   everything between them).

   **Targeted mode** (`init <harness>`): wire **only** that harness's agent file
   (table above). If the file does not exist, create it at the project root with
   the canonical block.

   **Auto mode** (`init`): wire the canonical block into **each** of
   `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` that already exists at the project
   root. Do not create agent files in auto mode.

   **Idempotency:** if a file already contains a delimited agent-memory block
   (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain
   `<agent-memory>` … `</agent-memory>` from 0.0.4–0.0.5), skip it — do not add
   a second one.

6. **Wire harness-specific config.** Follow
   [`references/install-hooks.md`](./install-hooks.md) for each harness that
   applies (targeted: that harness only; auto: every row whose prerequisite dir
   exists). In `init`, run the install-hooks steps **without** the memory guard
   (step 1 of that reference).

7. **Fallback agent file (auto mode only).** If mode is `auto` and none of
   `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` exist, create `AGENTS.md` at the
   project root with the canonical block.

8. **Report.** List: mode (auto or targeted harness), skeleton created, agent
   file(s) wired or skipped, harness extras installed or skipped (and why —
   especially missing harness dirs), and suggest `bootstrap` / `sync` next
   steps. For Cursor, note that **hooks are the recommended integration**.

## Notes

- Do not populate the memory here — `init` only scaffolds. To fill it from the
  codebase, the user runs `/agent-memory bootstrap`. If product vision is
  unclear, ask the user before writing `vision.md` (same rule as `bootstrap` /
  `sync`).
- Optional git `pre-commit` hook is **not** wired by `init` — see
  [`hooks/README.md`](../hooks/README.md).
