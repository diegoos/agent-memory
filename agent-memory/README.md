# Agent Memory

A local **Workspace Memory** method for AI coding agents (Claude Code, Cursor,
OpenCode, Gemini, and others).

The Memory is a small set of versioned Markdown files that act as the shared
source of truth between humans and agents. It separates **permanent knowledge**
(architecture, decisions, patterns) from **operational memory** (current state,
in-flight work), so any agent can pick up the project without relying on chat
history.

The method borrows the _discipline_ of the [llm-wiki pattern][llm-wiki] (an
index, a chronological log, periodic linting, small cross-referenced files) but
its identity is **project memory**, not external-source ingestion.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Any project where AI agents do meaningful work across multiple sessions, and
where humans and agents need a single, trustworthy account of "where things
stand" and "why".

## Install

**Recommended — via the skill.** Install the `agent-memory` skill (in
[`../skills/agent-memory`](../skills/agent-memory)) into your agent's skills
directory, then run:

```text
/agent-memory init        # create .agents/memory/ and wire your agent file(s)
/agent-memory bootstrap   # (optional) analyze the project and fill the memory
/agent-memory sync        # keep current.md / active-work / log.md / index.md fresh
```

The skill installs from this repository's canonical skeleton
(`agent-memory/memory/`) and also handles `sync`, `update`, `lint`, and `help`.
See its `SKILL.md` for details.

**Manual.** Copy the skeleton and add the stub yourself:

```bash
mkdir -p .agents
cp -R agent-memory/memory .agents/memory
```

Then commit `.agents/memory/` to Git and attach the Memory to your agent file(s)
by pasting the stub below into `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or any
other agent instructions file. The instructions stay in a single source of truth
(`.agents/memory/instructions.md`); the stub only points to it.

### Stub (use in `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or any agent file)

The same stub works everywhere. It spells out the always-load files **and**
adds `@import`, so harnesses that follow the AGENTS.md `@import` convention
(Claude Code, Gemini CLI, Codex) get `instructions.md` auto-loaded, while
plain-Markdown readers (Cursor, plain text) still load the memory from the
explicit list. Including both is harmless.

```md
## Agent Memory

This project uses Agent Memory (a local Workspace Memory). Before starting any
task, open and follow `.agents/memory/instructions.md`, then read
`.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
active-work file (`.agents/memory/active-work/<branch>.md`).

@.agents/memory/instructions.md
```

## What's inside the memory (`.agents/memory/`)

| File              | Role                                    |
| ----------------- | --------------------------------------- |
| `instructions.md` | The canonical method (read this first). |
| `index.md`        | Map of the Memory.                      |
| `current.md`      | Shared, durable project state.          |
| `active-work/`    | Per-branch ephemeral task scratchpad.   |
| `decisions.md`    | Decisions and their reasoning.          |
| `log.md`          | Chronological activity log.             |

Other files (`vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`,
`known-issues.md`, `domains/*`, `features/*`) are created **on demand** — only
when there is real content to record. See `.agents/memory/instructions.md` for
the full workflow and the multi-developer rules.
