# Agent Memory

A small, project-local **Workspace Memory** that keeps AI coding agents — Claude
Code, Cursor, Codex, OpenCode, Gemini, and others — **on the same page** across
sessions, tools, and teammates, with no external infrastructure.

## Quick start

```bash
npx skills add diegoos/agent-memory --skill agent-memory
```

Then, in your agent:

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
/agent-memory sync              # at checkpoints: keep current.md / active-work / log.md / index.md fresh
```

Without a harness name, `init` **auto-detects** harnesses from project markers
(`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, Copilot markers, `.claude/`,
`.gemini/`, `AGENTS.md` + `.codex/` or `.opencode/`) and wires each harness's
**native instruction file** — `.cursor/rules/agent-memory.mdc` for Cursor,
`.github/instructions/agent-memory.instructions.md` for Copilot, or the
harness's agent file (`AGENTS.md`/`CLAUDE.md`/`GEMINI.md`) for the rest. It asks
you when detection is inconclusive. It does not create `.cursor/`, `.claude/`,
`.github/`, etc. by default — those must already exist, unless you explicitly
ask `init` to create them. Use `init <harness>` when you know which agent you
use.

## Why

- **Project memory, not chat memory.** A versioned set of small Markdown files
  in `.agents/memory/` is the shared source of truth between humans and agents.
  Any agent can pick up the work from the files alone, without chat history.
- **No external tooling.** No vector database, no server, no CLI, no embeddings
  — just Markdown in your repo and `grep`. It runs inside whatever agent you
  already use.
- **Concise but context-rich.** Tokens cost, so entries are short and
  high-signal, and agents load only what a task needs (progressive disclosure).
- **Based on Karpathy's [llm-wiki][llm-wiki]** discipline (an index, a
  chronological log, periodic linting, small cross-referenced files), adapted
  from source ingestion to _project memory_.

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## How it works

The memory lives at `.agents/memory/` and separates **permanent knowledge** from
**operational state**:

| File                      | Role                                                            |
| ------------------------- | --------------------------------------------------------------- |
| `instructions.md`         | The method: how agents read and maintain the memory.            |
| `index.md`                | Map of the memory + loading policy (always-load vs on-demand).  |
| `current.md`              | Shared, durable project state.                                  |
| `active-work/<branch>.md` | Per-branch ephemeral scratchpad (no merge conflicts).           |
| `decisions.md`            | Important decisions and **why** (the reasoning).                |
| `log.md`                  | Chronological activity log (append at the bottom, `grep`-able). |

Other files (`vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`,
`known-issues.md`, `domains/*`, `features/*`) are created **on demand**, only
when there is real content. See
[`agent-memory/README.md`](./agent-memory/README.md) for the full method.

Agents **read AND write** the memory: before a task they read `index.md`,
`current.md`, and their branch's `active-work` file; as they work they keep
those current; at checkpoints they flush with `/agent-memory sync`. The full
workflow is in [`instructions.md`](./agent-memory/memory/instructions.md).

## The skill

[`/agent-memory`](./skills/agent-memory) is a **manual-only** Agent Skill (it
never auto-triggers) with six subcommands:

| Command                   | Does                                                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory help`      | List the commands and how to use them.                                                                                    |
| `/agent-memory init`      | Create `.agents/memory/`; auto-detect harnesses and wire each native instruction file, or `init <harness>` for one agent. |
| `/agent-memory update`    | Migrate an existing memory to the latest structure; never touches your content.                                           |
| `/agent-memory bootstrap` | Analyze the project (up to 3 subagents) and populate the memory.                                                          |
| `/agent-memory sync`      | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state.                                               |
| `/agent-memory lint`      | Check for broken links, orphan files, stale per-branch files, consistency.                                                |

## Hooks

Optional lifecycle hooks keep `.agents/memory/` current **during** agent work
with deterministic git checkpoints — no LLM call, no `followup_message` loops.

On **session start**, hooks bind the session ID, refresh `current.md` _In
progress_ from `active-work/`, and open the `log.md` session heading. After
writes and at end-of-turn / compaction / pre-commit, they update
`active-work/<branch>.md` (_Touched files_, Task stub from the branch name) and
append file-path bullets under the current `log.md` heading.

Semantic content stays **agent-owned** (or `/agent-memory sync`): log
summary/type and bullets, `decisions.md`, active-work Progress/Blockers/Notes,
`current.md` _Done_ / _Next steps_, and lazy files.

**Supported harnesses:** Cursor, Claude Code, Codex, Copilot, OpenCode (Bun
plugin spawns the same shell scripts), plus an optional git `pre-commit` hook.
Wire with `/agent-memory init <harness>` when the harness directory already
exists.

**Cursor** uses two complementary layers: `.cursor/rules/agent-memory.mdc`
(`alwaysApply: true`) injects the agent-memory workflow into every session
context, and lifecycle hooks run deterministic git checkpoints. `init cursor`
wires both when `.cursor/` exists. **Copilot** uses
`.github/instructions/agent-memory.instructions.md` (`applyTo: "**"`, always-on)
as its context layer, plus hooks under `.github/hooks/`.

Full install steps, event matrix, and harness-agnostic session/project-dir
resolution:
[`skills/agent-memory/hooks/README.md`](./skills/agent-memory/hooks/README.md).

## Keeping the memory current

The memory only helps if agents keep it current. The agent-memory block that
`init` wires into your agent file tells them to **read and write** it — and to
run `/agent-memory sync` at checkpoints (end of a task, before a commit, before
compaction).

## Install

### Recommended — via the skill

```bash
npx skills add diegoos/agent-memory --skill agent-memory
```

Then run `init` (and optionally `bootstrap`) as in _Quick start_. The skill
pulls the canonical skeleton from this repository, so it stays in sync, and also
handles `sync`, `update`, `lint`, and `help`. See its
[`SKILL.md`](./skills/agent-memory/SKILL.md).

### Manual

```bash
git clone https://github.com/diegoos/agent-memory /tmp/agent-memory
mkdir -p .agents
cp -R /tmp/agent-memory/agent-memory/memory .agents/memory
```

Commit `.agents/memory/` to Git, then wire it into your agent instructions file
(`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or any agent file) by pasting the
canonical agent-memory block.

The block is the **single source of truth** at
[`skills/agent-memory/references/agent-block.md`](./skills/agent-memory/references/agent-block.md)
— copy it verbatim from there (don't retype it here, so it never drifts). It is
wrapped in `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` HTML comments
so `/agent-memory update` can refresh **only** that block later (comments are
invisible in rendered Markdown). It tells the agent to **Read**
`instructions.md` and to **write** the memory as it works, and adds `@import`,
so harnesses that follow the AGENTS.md `@import` convention (Claude Code, Gemini
CLI, Codex) auto-load `instructions.md`. For Cursor, run
`/agent-memory init cursor` when `.cursor/` exists — it wires
`.cursor/rules/agent-memory.mdc` (context layer) plus hooks. For Copilot, run
`/agent-memory init copilot` to wire
`.github/instructions/agent-memory.instructions.md` plus hooks.

## Repository layout

```text
agent-memory/
├── agent-memory/        # the method: canonical memory skeleton + docs
│   ├── README.md
│   ├── UPDATE.md        # migration log (drives `/agent-memory update`)
│   └── memory/          # the skeleton installed to .agents/memory/
└── skills/
    └── agent-memory/    # the manual-only skill (SKILL.md + references/ + hooks/)
```

## License

MIT. See `LICENSE`.
