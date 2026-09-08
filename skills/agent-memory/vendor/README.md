# Agent Memory

A local workspace memory method for AI coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, and others).

The memory is a small set of versioned Markdown files in `.agents/memory/`: a recall layer. Project docs stay on `AGENTS.md`. Memory keeps operational state plus evidenced learnings that have no better home. It is not a second copy of project documentation.

The method borrows the discipline of the [llm-wiki pattern][llm-wiki] (index, log, lint, small cross-referenced files). It is built for project memory. It does not ingest external sources.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Use it on a project where AI agents work across sessions, and where humans and agents need a shared record of where things stand without copying existing docs.

## How agents use it

Agents read and write the memory. Method (write floor, **cold session**, **done signal**, hop, catch-up): [`memory/instructions.md`](./memory/instructions.md) — load it before writing. Keep `index.md` a short map. Project docs live on `AGENTS.md` (standing context). Catch up with `/agent-memory sync` only when there is meaning. Run `agent-memory-print-evidence.sh` for hook fields. Do not Read `.hook-sync-state`. Hooks write only `.hook-sync-state`. They do not write Markdown.

## What's inside (`.agents/memory/`)

| File              | Role                                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `instructions.md` | Canonical method: write floor + **cold session** (read before writing memory). Validation is the **done signal**.                                                                            |
| `index.md`        | Recall-file map (not a docs catalog).                                                                                                                     |
| `current.md`      | Shared active state (in progress / blockers handoff).                                                                                                     |
| `active-work/`    | Per-branch resume scratchpad (create when resumable). Copy from the skill `references/active-work-template.md`; do not keep a TEMPLATE in this directory. |
| `decisions.md`    | Short local fallback or pointer; live user constraints (one live entry per identity). Not an ADR wiki.                                                    |
| `log.md`          | Rolling semantic deltas (Git is the archive).                                                                                                             |
| `.gitignore`      | Ignores hook-local state.                                                                                                                                 |

Optional on demand: `learnings.md` / `learnings-<topic>.md`. Path-scoped files need `when editing:` on `index.md`. In-turn write-floor captures a reusable lesson; `/agent-memory learn` is explicit capture. Do not add parallel vision or architecture copies; `/agent-memory update` deletes leftover mirrors. Docs maps belong on `AGENTS.md`, not `index.md`.

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

Hooks are user-installed (the skill only prints commands). See the [hooks README](https://github.com/diegoos/agent-memory/blob/HEAD/hooks/README.md).

### Manual

```bash
mkdir -p .agents
cp -R memory .agents/memory
# npm omits files named `.gitignore`. Copy the pack-safe template explicitly:
cp memory/gitignore .agents/memory/.gitignore
```

Paste the agent-memory block from [`../references/agent-block.md`](../references/agent-block.md) into your agent file(s), or run `/agent-memory update instructions` when memory already exists and `AGENTS.md` lost the block. On Cursor/Copilot, `init` wires the native instruction file when the harness root exists; install hooks separately.
