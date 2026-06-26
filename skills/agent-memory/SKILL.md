---
name: agent-memory
description: >-
  Orchestrates the local agent-memory Workspace Memory in `.agents/memory/`. Use
  ONLY when the user explicitly runs the `/agent-memory` command with a
  subcommand — `init` (create the memory structure and wire
  AGENTS.md/CLAUDE.md/GEMINI.md), `update` (migrate an existing memory to the
  latest structure without touching project memory, and refresh the agent-memory
  block in the root agent files), `bootstrap` (analyze the project and populate
  the memory),   `sync` (refresh `current.md`, the branch's
  `active-work/<branch>.md`, `log.md`, and `index.md` from repo state; accepts
  `--auto` to apply all proposed diffs without the per-file prompt), `lint`
  (check the memory for broken links, orphan files, and consistency problems;
  accepts `--fix` to also delete stale per-branch `active-work` files), or
  `help` (list the commands and how to use them). Never trigger automatically;
  this skill must be invoked on demand only.
metadata:
  invocation: manual
  version: '0.0.5'
compatibility: >-
  Requires network access for WebFetch when installing from a remote
  agent-memory repository URL.
allowed-tools: >-
  Read Grep Glob WebFetch Task Edit(.agents/memory/**) Write(.agents/memory/**)
  Edit(AGENTS.md) Edit(CLAUDE.md) Edit(GEMINI.md) Write(AGENTS.md)
  Write(CLAUDE.md) Write(GEMINI.md) Bash(git:*)
disable-model-invocation: true
---

# agent-memory

Manual-only orchestrator for the local **agent-memory** method. The canonical
memory skeleton and migration log live in the **agent-memory repository**
(`agent-memory/memory/` and `agent-memory/UPDATE.md`); this skill installs and
migrates from there. The installed copy lives at the target project root in
`.agents/memory/`, with its version recorded in `.agents/memory/.version` (taken
from the newest entry in the repository's `UPDATE.md`).

**Do not act unless the user explicitly invoked `/agent-memory <command>`.**
This skill never runs on its own.

## Enabled tools

Pre-approved via the `allowed-tools` frontmatter — a space-separated,
host-specific, **experimental** field
([spec](https://agentskills.io/specification#allowed-tools-field)). Hosts that
do not support it simply ignore it. Names follow the Agent Skills / Claude Code
convention; adapt them if your host differs.

| Tool                     | Used for                                                                                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `Read`, `Grep`, `Glob`   | Read-only project analysis (`bootstrap`), lint structural checks, migration diffs (`update`), reading `references/*.md` and a local repo clone. |
| `WebFetch`               | Fetch the skeleton / `UPDATE.md` via raw URLs when `git` is unavailable (network; see `compatibility`).                                         |
| `Task`                   | Parallel read-only subagents in `bootstrap`. Optional — fall back to sequential analysis.                                                       |
| `Edit`, `Write` (scoped) | Create/edit files **only** under `.agents/memory/**` and the root agent files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`).                          |
| `Bash(git:*)`            | `git clone` (install) and `git branch` (lint stale-branch check).                                                                               |

**Deliberately not pre-approved** (the host should still prompt): file deletion
(`rm`, used only on confirmed `update`/cleanup) and any other shell. This keeps
the "confirm sensitive changes" rule intact.

### Write boundary

Create, edit, or delete **only** under `.agents/memory/**`, plus the root agent
instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or a host-specific
agent `*.md`) — and in those **only the agent-memory block** (between
`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain tags —
to wire it in `init` and refresh it in `update`). Never touch content outside
that block, application code, configs, or other docs. Read the rest of the
workspace freely.

`init` and `update` read the canonical skeleton and migration log from the
public agent-memory repository:

- Repository: <https://github.com/diegoos/agent-memory>
- Skeleton: `agent-memory/memory/`
- Migrations: `agent-memory/UPDATE.md`

**How to access it**, in order of preference:

1. If the user already has a local clone, read from it (no network).
2. Otherwise shallow-clone to a temp dir:
   `git clone --depth 1 https://github.com/diegoos/agent-memory "$TMP"`.
3. No `git`? Fetch raw files with `WebFetch` from
   `https://raw.githubusercontent.com/diegoos/agent-memory/main/...`.

## Routing

Read the subcommand from the invocation, load **only** the matching reference,
and follow it exactly:

| Command     | Does                                                                        | Reference                 |
| ----------- | --------------------------------------------------------------------------- | ------------------------- |
| `init`      | Create `.agents/memory/` and wire the agent file(s).                        | `references/init.md`      |
| `update`    | Migrate the memory; refresh the agent-memory block in the root agent files. | `references/update.md`    |
| `bootstrap` | Analyze the project and populate the memory.                                | `references/bootstrap.md` |
| `sync`      | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. | `references/sync.md`      |
| `lint`      | Check the memory for structural and consistency problems.                   | `references/lint.md`      |
| `help`      | List the commands and how to use them.                                      | _Help_ section below      |

If no subcommand is given, or it is not one of those above, run `help` (below)
and stop. Do not guess the user's intent.

## Help

For `/agent-memory help` (and for any empty or unknown invocation), output the
following Markdown exactly — nothing else:

---

**agent-memory** — a local Workspace Memory that keeps AI agents on the same
page.

**Commands**

| Command                   | Does                                                                                                                              |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory init`      | Create `.agents/memory/` and wire `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`.                                                        |
| `/agent-memory bootstrap` | Analyze the project (up to 3 subagents) and populate the memory.                                                                  |
| `/agent-memory update`    | Migrate the memory and refresh the agent-memory block — never touches your content outside the block.                             |
| `/agent-memory sync`      | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. `--auto` applies all diffs without per-file prompts.  |
| `/agent-memory lint`      | Check for broken links, orphan files, stale branches, and consistency. `--fix` also deletes stale per-branch `active-work` files. |
| `/agent-memory help`      | Show this guide.                                                                                                                  |

**Getting started**

- New project? Run `init`, then optionally `bootstrap`.
- Keeping the memory current? Run `sync` at checkpoints (end of task, before
  commit, before compaction). Use `sync --auto` for low-friction routine
  flushes.
- Already set up? Use `lint` to check health (`lint --fix` also removes stale
  per-branch files) and `update` to upgrade.
- On Cursor? The maintenance workflow is prose in `instructions.md`, which
  Cursor does not auto-load. Optional flush-reminder hooks for Cursor, Claude
  Code, Codex, OpenCode, Copilot, and a host-agnostic git pre-commit hook live
  in `skills/agent-memory/hooks/` (see its `README.md`).

Method & conventions: `.agents/memory/instructions.md`

---

## Shared rules (apply to every command)

- **Never modify project memory content** — `current.md`, `active-work/*`,
  `decisions.md`, `log.md`, `domains/*`, `features/*` — unless a command
  explicitly says so, and only after the user confirms.
- Run everything inside the user's current agent. **Do not create or depend on
  external scripts.**
- All paths are relative to the target project root unless stated otherwise.
