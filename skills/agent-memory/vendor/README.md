# Agent Memory

A local workspace memory method for AI coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, and others).

Versioned Markdown in `.agents/memory/`. Project docs stay on `AGENTS.md`. Memory keeps operational state and evidenced learnings that have no better home.

The shape follows the [llm-wiki pattern][llm-wiki] (index, log, lint, small cross-referenced files). It is for project memory, not external source ingestion.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Agents work across sessions, and you want a shared record of where things stand without copying existing docs.

## How agents use it

Method (write floor, cold session, done signal, hop, catch-up): [`memory/instructions.md`](./memory/instructions.md). Load it before writing. Keep `index.md` a short map. Catch up with `/agent-memory sync` only when there is meaning. Hook fields: `agent-memory-print-evidence.sh`. Do not Read `.hook-sync-state`. Hooks write that file only.

## What's inside (`.agents/memory/`)

| File              | Role                                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `instructions.md` | Method: write floor and cold session (read before writing). Validation is the done signal.                                                                |
| `index.md`        | Recall-file map (not a docs catalog).                                                                                                                     |
| `current.md`      | Shared active state (in progress / blockers handoff).                                                                                                     |
| `active-work/`    | Per-branch resume (create when resumable). Copy from the skill `references/active-work-template.md`; do not keep a TEMPLATE here.                         |
| `decisions.md`    | Short local fallback or pointer; live user constraints (one live entry per identity). Not an ADR wiki.                                                    |
| `log.md`          | Rolling semantic deltas (Git is the archive).                                                                                                             |
| `.gitignore`      | Ignores hook-local state.                                                                                                                                 |

Optional: `learnings.md` / `learnings-<topic>.md`. Path-scoped files need `when editing:` on `index.md`. In-turn write-floor captures a reusable lesson; `/agent-memory learn` is explicit capture. `/agent-memory update` deletes leftover vision or architecture copies. Docs maps belong on `AGENTS.md`.

## Install

### Via the skill

Install the `agent-memory` skill ([skills.sh](https://www.skills.sh/diegoos/agent-memory/agent-memory) / [`SKILL.md`](../SKILL.md)), then:

```text
/agent-memory init              # auto-detect harnesses
/agent-memory init <harness>    # one harness (directory must exist)
/agent-memory bootstrap         # optional inventory
/agent-memory install hooks <harness>  # print hook install commands
/agent-memory update | sync | lint | learn | consolidate
# block gone from AGENTS.md: update instructions | init agents.md | update rules
```

The skill prints hook commands; you run them. [hooks README](https://github.com/diegoos/agent-memory/blob/HEAD/hooks/README.md).

### Manual

```bash
mkdir -p .agents
cp -R memory .agents/memory
# npm omits files named `.gitignore`. Copy the pack-safe template explicitly:
cp memory/gitignore .agents/memory/.gitignore
```

Paste the agent-memory block from [`../references/agent-block.md`](../references/agent-block.md), or run `/agent-memory update instructions` when memory already exists and `AGENTS.md` lost the block. On Cursor/Copilot, `init` wires the native instruction file when the harness root exists; install hooks separately.
