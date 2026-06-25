# Agent Memory

A small, project-local **Workspace Memory** that keeps AI coding agents (Claude
Code, Cursor, OpenCode, Gemini, and others) **on the same page** — across
sessions, tools, and teammates — without any external infrastructure.

## Premise

- **Project memory, not chat memory.** A versioned set of small Markdown files
  in `.agents/memory/` is the shared source of truth between humans and agents.
  Any agent can pick up the work from the files alone, without the chat history.
- **No external tooling.** No vector database, no server, no CLI, no embeddings.
  Just Markdown in your repo and `grep`. It runs directly inside whatever agent
  you already use.
- **Concise but context-rich.** Tokens are a cost — instructions and memory
  entries are kept short and high-signal, and agents load only what a task needs
  (progressive disclosure).
- **Based on Karpathy's [llm-wiki][llm-wiki]** discipline (an index, a
  chronological log, periodic linting, small cross-referenced files), adapted
  from source ingestion to _project memory_.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## How it works

The memory lives at `.agents/memory/` and separates **permanent knowledge** from
**operational state**:

| File                      | Role                                                                   |
| ------------------------- | ---------------------------------------------------------------------- |
| `instructions.md`         | The method: how agents read and maintain the memory.                   |
| `index.md`                | Map of the memory + loading policy (what to always load vs on demand). |
| `current.md`              | Shared, durable project state.                                         |
| `active-work/<branch>.md` | Per-branch ephemeral scratchpad (no merge conflicts).                  |
| `decisions.md`            | Important decisions and **why** (the reasoning).                       |
| `log.md`                  | Chronological activity log (append at the bottom, `grep`-able).        |

Other files (`vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`,
`known-issues.md`, `domains/*`, `features/*`) are created **on demand**, only
when there is real content. See
[`agent-memory/README.md`](./agent-memory/README.md) for the full method.

## The skill

[`/agent-memory`](./skills/agent-memory) is a **manual-only** Agent Skill (it
never auto-triggers) that operates the memory with five subcommands:

| Command                   | Does                                                                             |
| ------------------------- | -------------------------------------------------------------------------------- |
| `/agent-memory help`      | List the commands and how to use them.                                           |
| `/agent-memory init`      | Create `.agents/memory/` and wire `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`.       |
| `/agent-memory update`    | Migrate an existing memory to the latest structure, never touching your content. |
| `/agent-memory bootstrap` | Analyze the project (up to 3 subagents) and populate the memory.                 |
| `/agent-memory sync`      | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state.      |
| `/agent-memory lint`      | Check for broken links, orphan files, stale per-branch files, and consistency.   |

## Install

### Recommended — via the skill

1. With `npx skills add`:

   ```bash
   npx skills add https://github.com/diegoos/agent-memory --skill agent-memory
   ```

2. Then run:

   ```text
   /agent-memory init        # create .agents/memory/ and wire your agent file(s)
   /agent-memory bootstrap   # (optional) analyze the project and fill the memory
   /agent-memory sync        # keep current.md / active-work / log.md / index.md fresh
   ```

The skill pulls the canonical skeleton from this repository, so it stays in
sync.

### Manual

```bash
git clone https://github.com/diegoos/agent-memory /tmp/agent-memory
mkdir -p .agents
cp -R /tmp/agent-memory/agent-memory/memory .agents/memory
```

Then commit `.agents/memory/` and add this stub to your `AGENTS.md`,
`CLAUDE.md`, or `GEMINI.md` (the same stub works in all of them — it lists the
always-load files and adds `@import`, so harnesses that follow the AGENTS.md
`@import` convention — Claude Code, Gemini CLI, Codex — auto-load
`instructions.md`, while plain-Markdown readers still load the memory from the
explicit list):

```md
## Agent Memory

This project uses Agent Memory (a local Workspace Memory). Before starting any
task, open and follow `.agents/memory/instructions.md`, then read
`.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
active-work file (`.agents/memory/active-work/<branch>.md`).

@.agents/memory/instructions.md
```

## Repository layout

```text
agent-memory/
├── agent-memory/        # the method: canonical memory skeleton + docs
│   ├── README.md
│   ├── UPDATE.md        # migration log (drives `/agent-memory update`)
│   └── memory/          # the skeleton installed to .agents/memory/
└── skills/
    └── agent-memory/    # the manual-only skill (SKILL.md + references/)
```

## License

MIT. See `LICENSE`.
