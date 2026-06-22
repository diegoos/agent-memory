# Skills

Skills that operate the [Agent Memory](../agent-memory/README.md) method.

## `agent-memory`

A manual-only skill that orchestrates the local memory. Invoke it on demand with a
subcommand:

- `/agent-memory init` — create `.agents/memory/` and wire `AGENTS.md` /
  `CLAUDE.md` / `GEMINI.md`.
- `/agent-memory update` — migrate an existing memory to the latest structure,
  without touching project memory content.
- `/agent-memory bootstrap` — analyze the project (up to three subagents) and
  populate the memory.
- `/agent-memory lint` — check the memory for broken links, orphan files, and
  consistency problems.
- `/agent-memory help` — list the commands and how to use them.

The skill is thin: it installs and migrates from this repository's canonical
skeleton ([`../agent-memory/memory/`](../agent-memory/memory)) and migration log
([`../agent-memory/UPDATE.md`](../agent-memory/UPDATE.md)). Set the repository
path in [`agent-memory/SKILL.md`](./agent-memory/SKILL.md) (Repository source)
before use; see it for the full method.
