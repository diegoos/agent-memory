# Skills

Skills that operate the [Agent Memory](./agent-memory/vendor/README.md) method.

## `agent-memory`

Manual-only skill that orchestrates the local recall layer. See [`agent-memory/SKILL.md`](./agent-memory/SKILL.md) for routing and [`agent-memory/vendor/memory/instructions.md`](./agent-memory/vendor/memory/instructions.md) for the method.

Commands: `init`, `install hooks`, `update`, `bootstrap`, `sync`, `lint`, `consolidate`, `help`.

`init` wires harness-native instruction files (`.cursor/rules/*.mdc`, `.github/instructions/*.instructions.md`, or `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`). Hooks are user-installed separately.
