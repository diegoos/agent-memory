# Skills

Skills that operate the [Agent Memory](./agent-memory/vendor/README.md) method.

## `agent-memory`

A manual-only skill that orchestrates the local memory. Invoke it on demand with a
subcommand:

- `/agent-memory init` — create `.agents/memory/` and wire `AGENTS.md` /
  `CLAUDE.md` / `GEMINI.md` (prints hook-install instructions; does not install
  hooks).
- `/agent-memory install hooks` — print how to install or refresh hooks for one
  harness (user-run `npx` or `install-hooks.sh`).
- `/agent-memory update` — migrate an existing memory to the latest structure,
  without touching project memory content; instruct hook refresh.
- `/agent-memory bootstrap` — analyze the project (up to three subagents) and
  populate the memory.
- `/agent-memory sync` — refresh `current.md`, the branch's
  `active-work/<branch>.md`, `log.md`, and `index.md` from repo state.
- `/agent-memory lint` — check the memory for broken links, orphan files, and
  consistency problems.
- `/agent-memory help` — list the commands and how to use them.

The skill is thin: it installs and migrates from the **vendored** skeleton
([`agent-memory/vendor/memory/`](./agent-memory/vendor/memory)) and migration log
([`agent-memory/vendor/UPDATE.md`](./agent-memory/vendor/UPDATE.md)). See
[`agent-memory/SKILL.md`](./agent-memory/SKILL.md) for the full method.
