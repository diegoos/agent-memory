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
- Harness hooks/plugin: [`../hooks/`](../hooks/) (see per-harness table below)

## Steps

1. **Guard.** If `.agents/memory/` already exists, stop and tell the user the
   project is already initialized — suggest `/agent-memory update` instead. Do
   not overwrite anything.

2. **Copy the skeleton.** Obtain the repository (see `SKILL.md` → Repository
   source) and copy its `agent-memory/memory/` directory into the project as
   `.agents/memory/` (the entire directory, including
   `active-work/TEMPLATE.md` and `.gitignore` for hook-local state files).

3. **Write the version anchor.** Create `.agents/memory/.version` containing the
   latest version — the newest version section in the repository's
   `agent-memory/UPDATE.md`, e.g. `0.0.6`.

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

6. **Wire harness-specific config.** Never create harness root directories
   (`.cursor/`, `.claude/`, etc.) — only install into directories that **already
   exist**. If a harness dir is missing, skip its extras and say so in the
   report (targeted mode: tell the user to create the dir first or run `init`
   without a harness after adding it).

   Run **only** the rows that apply (targeted: that harness only; auto: every
   row whose harness dir exists). Copy shared scripts from
   [`hooks/shared/`](../hooks/shared/) (`agent-memory-sync.sh`,
   `agent-memory-session.sh` where the host uses session start), `chmod +x`.

   | Harness    | Prerequisite dir | What to install (idempotent)                                                                                                                                           |
   | ---------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | `cursor`   | `.cursor/`       | Copy shared scripts → `.cursor/hooks/`. Merge [`hooks/cursor/hooks.json`](../hooks/cursor/hooks.json) into `.cursor/hooks.json`. **Never create `.cursor/`.**          |
   | `claude`   | `.claude/`       | Copy shared scripts → `.claude/hooks/`. Merge [`hooks/claude-code/settings.json`](../hooks/claude-code/settings.json) into `.claude/settings.json`.                    |
   | `codex`    | `.codex/`        | Copy shared scripts → `.codex/hooks/`. Merge [`hooks/codex/hooks.json`](../hooks/codex/hooks.json) into `.codex/hooks.json`. Remind user to run `/hooks` in Codex TUI. |
   | `opencode` | `.opencode/`     | Copy `agent-memory-sync.sh` → `.opencode/hooks/`. Copy [`hooks/opencode/agent-memory.ts`](../hooks/opencode/agent-memory.ts) → `.opencode/plugin/agent-memory.ts`.     |
   | `copilot`  | `.github/`       | Copy shared scripts → `.github/hooks/`. Copy [`hooks/copilot/agent-memory.json`](../hooks/copilot/agent-memory.json) → `.github/hooks/agent-memory.json` if missing.   |

   Hooks run a **deterministic git checkpoint** (Touched files + optional
   `log.md` append) — see [`hooks/README.md`](../hooks/README.md).

7. **Fallback agent file (auto mode only).** If mode is `auto` and none of
   `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` exist, create `AGENTS.md` at the
   project root with the canonical block.

8. **Report.** List: mode (auto or targeted harness), skeleton created, agent
   file(s) wired or skipped, harness extras installed or skipped (and why —
   especially missing harness dirs), and suggest `bootstrap` / `sync` next
   steps. For Cursor, note that **hooks are the recommended integration**.

## Notes

- Do not populate the memory here — `init` only scaffolds. To fill it from the
  codebase, the user runs `/agent-memory bootstrap`.
- Optional git `pre-commit` hook is **not** wired by `init` — see
  [`hooks/README.md`](../hooks/README.md).
