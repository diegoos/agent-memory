# Skills

Skills that operate the [Agent Memory](./agent-memory/vendor/README.md) method.

## `agent-memory`

Manual skill that orchestrates the local recall layer. Routing is in [`agent-memory/SKILL.md`](./agent-memory/SKILL.md). The method is in [`agent-memory/vendor/memory/instructions.md`](./agent-memory/vendor/memory/instructions.md).

Commands: `init`, `install hooks`, `update`, `bootstrap`, `sync`, `lint`, `consolidate`, `learn`, `help`.

`init` wires harness-native instruction files (`.cursor/rules/*.mdc`, `.github/instructions/*.instructions.md`, or `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`). Hooks are user-installed separately.
