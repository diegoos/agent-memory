# Skills

Skills that run the [Agent Memory](./agent-memory/vendor/README.md) method.

## `agent-memory`

Manual orchestrator for the recall layer. Routing: [`agent-memory/SKILL.md`](./agent-memory/SKILL.md). Method: [`agent-memory/vendor/memory/instructions.md`](./agent-memory/vendor/memory/instructions.md).

Commands: `init`, `install hooks`, `update`, `bootstrap`, `sync`, `lint`, `consolidate`, `learn`, `help`.

`init` writes harness-native instruction files (`.cursor/rules/*.mdc`, `.github/instructions/*.instructions.md`, or `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`). Restore a removed `AGENTS.md` block with `init instructions` or `update instructions` (`agents.md` / `rules` are the same). Hooks are a separate user-run install. Daily write is the installed `instructions.md`.
