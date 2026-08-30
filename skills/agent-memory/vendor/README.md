# Agent Memory

A local workspace memory method for AI coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini, and others).

The memory is a small set of versioned Markdown files in `.agents/memory/`: a recall layer that points at the project's canonical sources and keeps operational state plus evidenced learnings that have no better home. It is not a second copy of project documentation.

The method borrows the discipline of the [llm-wiki pattern][llm-wiki] (index, log, lint, small cross-referenced files). It is built for project memory. It does not ingest external sources.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Use it on a project where AI agents do meaningful work across sessions, and where humans and agents need a reliable account of where things stand without duplicating existing docs.

## How agents use it

Agents read and write the memory. Full workflow and multi-developer rules: [`memory/instructions.md`](./memory/instructions.md) (canonical method file; load it before writing memory).

Before a task, follow session Status (`load:` / Next / Checkpoint). Read `index.md` and `current.md`. Open branch `active-work` only if it exists. Status `load:` is one Read, not a hop, including `decisions.md` or a learnings file when a hint matches. Honor live user decisions for **approach** and loaded Insights before repeating a failed path. Path hit stays on hints and code. Durable why with no path hit follows _Recall hop_ in `instructions.md`. Skip writing when the write floor is all no. A commit in Git does not skip the floor. Keep `index.md` a short map. In the turn, write one file per event. Catch up with `/agent-memory sync` only when there is meaning. Hooks write only `.hook-sync-state`. They never write Markdown.

## What's inside (`.agents/memory/`)

| File              | Role                                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `instructions.md` | Canonical method (read before writing memory).                                                                                                            |
| `index.md`        | Short map of entry points + recall files.                                                                                                                 |
| `current.md`      | Shared active state (in progress / blockers handoff).                                                                                                     |
| `active-work/`    | Per-branch resume scratchpad (create when resumable). Copy from the skill `references/active-work-template.md`; do not keep a TEMPLATE in this directory. |
| `decisions.md`    | Decision pointers or local fallback; live user constraints for approach (one live entry per identity).                                                    |
| `log.md`          | Rolling semantic deltas (Git is the archive).                                                                                                             |
| `.gitignore`      | Ignores hook-local state.                                                                                                                                 |

Optional on demand: `learnings.md` / `learnings-<topic>.md`. Path-scoped files need `when editing:` on `index.md`. Do not create parallel vision or architecture copies; link project docs instead.

## Install

### Via the skill

Install the `agent-memory` skill ([skills.sh](https://www.skills.sh/diegoos/agent-memory/agent-memory) / [`SKILL.md`](../SKILL.md)), then:

```text
/agent-memory init              # auto-detect harnesses
/agent-memory init <harness>    # one harness (directory must exist)
/agent-memory bootstrap         # optional inventory
/agent-memory install hooks <harness>  # print hook install commands
/agent-memory update | sync | learn | consolidate
```

Hooks are user-installed (the skill only prints commands). See the [hooks README](https://github.com/diegoos/agent-memory/blob/0.2.0/hooks/README.md).

### Manual

```bash
mkdir -p .agents
cp -R memory .agents/memory
# npm omits files named `.gitignore` — copy the pack-safe template explicitly:
cp memory/gitignore .agents/memory/.gitignore
```

Paste the agent-memory block from [`../references/agent-block.md`](../references/agent-block.md) into your agent file(s). On Cursor/Copilot, `init` wires the native instruction file when the harness root exists; install hooks separately.
