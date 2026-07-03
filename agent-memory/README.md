# Agent Memory

A local **Workspace Memory** method for AI coding agents — Claude Code, Cursor,
Codex, OpenCode, Gemini, and others.

The Memory is a small set of versioned Markdown files in `.agents/memory/` that
act as the shared source of truth between humans and agents. It separates
**permanent knowledge** (architecture, decisions, patterns) from **operational
memory** (current state, in-flight work), so any agent can pick up the project
without relying on chat history.

The method borrows the _discipline_ of the [llm-wiki pattern][llm-wiki] (an
index, a chronological log, periodic linting, small cross-referenced files) but
its identity is **project memory**, not external-source ingestion.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Any project where AI agents do meaningful work across multiple sessions, and
where humans and agents need a single, trustworthy account of "where things
stand" and "why".

## How agents use it

Agents **read AND write** the memory — it is not chat history.

- **Before a task:** read `index.md`, `current.md`, and the current branch's
  `active-work/<branch>.md`.
- **During:** keep that `active-work` file current (task, progress, touched
  files, blockers); append events to `log.md`; record decisions in
  `decisions.md`.
- **After / at checkpoints:** refresh `current.md` when project state changed;
  run `/agent-memory sync` to flush `current.md`, `active-work`, `log.md`, and
  `index.md` from repo state; delete the branch's `active-work` file when it
  merges.

The full workflow and multi-developer rules live in
[`memory/instructions.md`](./memory/instructions.md) — the canonical method file
agents load first.

## What's inside the memory (`.agents/memory/`)

| File              | Role                                    |
| ----------------- | --------------------------------------- |
| `instructions.md` | The canonical method (read this first). |
| `index.md`        | Map of the Memory.                      |
| `current.md`      | Shared, durable project state.          |
| `active-work/`    | Per-branch ephemeral task scratchpad.   |
| `decisions.md`    | Decisions and their reasoning.          |
| `log.md`          | Chronological activity log.             |
| `.gitignore`      | Ignores hook-local state (not content). |

Other files (`vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`,
`known-issues.md`, `domains/*`, `features/*`) are created **on demand** — only
when there is real content to record. See `memory/instructions.md` for the full
workflow and the multi-developer rules.

## Install

### Recommended — via the skill

Install the `agent-memory` skill (in
[`../skills/agent-memory`](../skills/agent-memory)) into your agent's skills
directory, then run:

```text
/agent-memory init              # auto-detect harnesses from project markers
/agent-memory init cursor       # Cursor only (.cursor/ must exist)
/agent-memory init claude       # Claude Code only
/agent-memory init codex        # Codex only
/agent-memory init opencode     # OpenCode only
/agent-memory init copilot      # Copilot only
/agent-memory init gemini       # Gemini only
/agent-memory bootstrap         # optional: analyze the project and fill the memory
/agent-memory install hooks <harness>  # install or refresh hooks (memory must exist)
/agent-memory update            # update agent-memory + refresh instruction blocks + installed harness hooks
/agent-memory sync              # keep current.md / active-work / log.md / index.md fresh
```

Without a harness name, `init` **auto-detects** harnesses from project markers
and wires each harness's **native instruction file** (`.cursor/rules/*.mdc` for
Cursor, `.github/instructions/*.instructions.md` for Copilot, or the harness's
agent file for the rest), asking you when detection is inconclusive. It never
creates `.cursor/`, `.claude/`, `.github/`, etc. by default — those must already
exist, unless you explicitly ask `init` to create them. Use `init <harness>`
when you know which agent you use.

The skill installs from this repository's canonical skeleton (`memory/`) and
also handles `sync`, `update`, `lint`, and `help`. See its
[`SKILL.md`](../skills/agent-memory/SKILL.md).

### Manual

```bash
mkdir -p .agents
cp -R agent-memory/memory .agents/memory
```

Commit `.agents/memory/` to Git, then attach the Memory to your agent file(s) by
pasting the canonical agent-memory block into `AGENTS.md`, `CLAUDE.md`,
`GEMINI.md`, or any agent instructions file. The instructions stay in a single
source of truth (`.agents/memory/instructions.md`); the block only points to it.

The block is the **single source of truth** at
[`../skills/agent-memory/references/agent-block.md`](../skills/agent-memory/references/agent-block.md)
— copy it verbatim from there. It is wrapped in `<!-- <agent-memory> -->` …
`<!-- </agent-memory> -->` HTML comments so `/agent-memory update` can refresh
**only** that block later (comments are invisible in rendered Markdown); it
tells the agent to **Read** `instructions.md` and to **write** the memory as it
works, and adds `@import`, so harnesses that follow the AGENTS.md `@import`
convention (Claude Code, Gemini CLI, Codex) auto-load `instructions.md`. On
Cursor, run `init cursor` when `.cursor/` exists — it wires
`.cursor/rules/agent-memory.mdc` (context layer) plus hooks. On Copilot, run
`init copilot` to wire `.github/instructions/agent-memory.instructions.md`
(context layer) plus hooks. See _Plain-Markdown harnesses_ in
`memory/instructions.md`.

## Keeping the memory current

The memory rots if agents only read it. The agent-memory block tells them to
write it too, and `/agent-memory sync` is the executable flush at checkpoints.

**On Cursor:** `init cursor` wires two complementary layers —
`.cursor/rules/agent-memory.mdc` (`alwaysApply: true`) as the **context layer**
(always-on rules that inject the agent-memory workflow into every session) and
lifecycle hooks as the **checkpoint layer** (deterministic git checkpoints). Run
it when `.cursor/` already exists. See
[`../skills/agent-memory/hooks/`](../skills/agent-memory/hooks/).

Lifecycle hooks (Cursor, Claude Code, Codex, OpenCode, Copilot, plus git
`pre-commit`) run a deterministic git checkpoint between turns — see
[`../skills/agent-memory/hooks/`](../skills/agent-memory/hooks/).
