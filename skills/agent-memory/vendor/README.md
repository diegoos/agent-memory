# Agent Memory

A local **Workspace Memory** method for AI coding agents — Claude Code, Cursor, Codex, OpenCode, Gemini, and others.

The Memory is a small set of versioned Markdown files in `.agents/memory/`: a **recall layer** that points at the project's canonical sources and keeps operational state plus evidenced learnings that have no better home. It is **not** a second copy of project documentation.

The method borrows the _discipline_ of the [llm-wiki pattern][llm-wiki] (index, log, lint, small cross-referenced files) but its identity is **project memory**, not external-source ingestion.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## When to use it

Any project where AI agents do meaningful work across multiple sessions, and where humans and agents need a trustworthy account of "where things stand" without duplicating existing docs.

## How agents use it

Agents **read AND write** the memory. Full workflow and multi-developer rules: [`memory/instructions.md`](./memory/instructions.md) (canonical method file).

Short version: before a task read `index.md`, `current.md`, and the branch `active-work` when it exists; **primary write** is in-turn (resume fields + semantic `log.md`); **catch-up** via `/agent-memory sync` (or follow `references/sync.md` without the skill); periodically `/agent-memory consolidate`. Hooks write only `.hook-sync-state` — never Markdown.

## What's inside (`.agents/memory/`)

| File              | Role                                                    |
| ----------------- | ------------------------------------------------------- |
| `instructions.md` | Canonical method (read first).                          |
| `index.md`        | Map of canonical sources + recall files.                |
| `current.md`      | Shared active state (in progress / blockers handoff).   |
| `active-work/`    | Per-branch resume scratchpad (create when resumable).   |
| `decisions.md`    | Decision pointers or local fallback ADRs.               |
| `log.md`          | Recent semantic session deltas.                         |
| `.gitignore`      | Ignores hook-local state.                               |

Optional on demand: `learnings.md`. Do not create parallel vision/architecture copies — link project docs instead.

## Install

### Via the skill

Install the `agent-memory` skill ([skills.sh](https://www.skills.sh/diegoos/agent-memory/agent-memory) / [`SKILL.md`](../SKILL.md)), then:

```text
/agent-memory init              # auto-detect harnesses
/agent-memory init <harness>    # one harness (directory must exist)
/agent-memory bootstrap         # optional inventory
/agent-memory install hooks <harness>  # print hook install commands
/agent-memory update | sync | consolidate
```

Hooks are **user-installed** (skill only prints commands) — see the [hooks README](https://github.com/diegoos/agent-memory/blob/0.0.15/hooks/README.md).

### Manual

```bash
mkdir -p .agents && cp -R memory .agents/memory
```

Paste the agent-memory block from [`../references/agent-block.md`](../references/agent-block.md) into your agent file(s). On Cursor/Copilot, `init` wires the native instruction file when the harness root exists; install hooks separately.
