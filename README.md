# Agent Memory

**Agent Memory** is a project-local **Workspace Memory** for AI coding agents.
It is a small set of versioned Markdown files in `.agents/memory/` — the shared
source of truth between humans and agents — so work continues across sessions,
tools, and teammates **without chat history** and **without external
infrastructure** (no server, vector DB, or embeddings).

Agents **read and write** that memory. A manual skill (`/agent-memory`)
bootstraps and maintains it; optional lifecycle hooks add deterministic git
checkpoints while you work.

Supported harnesses: Cursor, Claude Code, Codex, OpenCode, Copilot, Gemini CLI.

## Why

- **Project memory, not chat memory.** Files in Git beat paste-from-yesterday
  chats. Anyone (human or agent) can pick up from `.agents/memory/` alone.
- **Plain Markdown.** Searchable with `grep`, reviewable in PRs, no new runtime.
- **Progressive disclosure.** Always-load files stay short; detail lives in
  on-demand files (`architecture.md`, `domains/*`, …).
- **Inspired by Karpathy's [llm-wiki][llm-wiki]** (index, log, lint, small
  cross-linked files), adapted from source ingestion to _project_ memory.

## How it works

Memory lives at `.agents/memory/` and separates **durable knowledge** from
**operational state**:

| File                      | Role                                                           |
| ------------------------- | -------------------------------------------------------------- |
| `instructions.md`         | Method: how agents read and maintain the memory.               |
| `index.md`                | Map + loading policy (always-load vs on-demand).               |
| `current.md`              | Shared project state (done / in progress / next).              |
| `active-work/<branch>.md` | Per-branch scratchpad (no merge conflicts across branches).    |
| `decisions.md`            | Decisions and **why**.                                         |
| `log.md`                  | Chronological activity log (append at the bottom).             |

Lazy files (`vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`,
`known-issues.md`, `domains/*`, `features/*`) appear only when there is real
content.

**Workflow:** before a task, agents read `index.md`, `current.md`, and their
branch's `active-work` file; while working they keep those current; at
checkpoints they flush with `/agent-memory sync`.

Full method:
[`skills/agent-memory/vendor/README.md`](./skills/agent-memory/vendor/README.md)
and
[`instructions.md`](./skills/agent-memory/vendor/memory/instructions.md).

## Quick start

```bash
# Skill (primary)
npx skills add diegoos/agent-memory --skill agent-memory
```

In your agent:

```text
/agent-memory init                 # auto-detect harnesses, or: init cursor
/agent-memory bootstrap            # optional: populate memory from the repo
/agent-memory install hooks cursor # print hook-install commands (skill never runs them)
```

Install lifecycle hooks with the `npx` CLI:

```bash
npx @dos/agent-memory install hooks cursor
# interactive menu (skill + hooks / skill only / hooks only):
npx @dos/agent-memory install cursor
# or from a checkout: bash hooks/install-hooks.sh cursor
```

`init` wires each harness's **native instruction file** (for example Cursor
`.cursor/rules/agent-memory.mdc`, Copilot
`.github/instructions/agent-memory.instructions.md`, or `AGENTS.md` /
`CLAUDE.md` / `GEMINI.md`). It does **not** create harness roots (`.cursor/`,
`.claude/`, …) unless you ask — and it never copies hook scripts. Use
`init <harness>` when you already know the agent.

## The skill

[`/agent-memory`](./skills/agent-memory) is **manual-only** (never auto-triggers):

| Command                       | Does                                                              |
| ----------------------------- | ----------------------------------------------------------------- |
| `/agent-memory help`          | List commands.                                                    |
| `/agent-memory init`          | Create `.agents/memory/`; wire native instruction file(s).        |
| `/agent-memory install hooks` | Print how to install/refresh hooks (user-run installer).          |
| `/agent-memory update`        | Migrate scaffolding; never overwrites your content blindly.       |
| `/agent-memory bootstrap`     | Analyze the project and populate the memory.                      |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md`.       |
| `/agent-memory lint`          | Broken links, orphans, stale per-branch files, consistency.       |

## Hooks

Optional lifecycle hooks keep `.agents/memory/` current **during** agent work
with deterministic checkpoints (no LLM loops): session binding, _Touched files_,
`log.md` path bullets on full checkpoints, `current.md` _In progress_ on session
start.

**Semantic** content stays agent-owned (or `/agent-memory sync`): decisions,
progress notes, log summary/type, lazy files.

Install steps, event matrix, and project-dir resolution:
[`hooks/README.md`](./hooks/README.md).

## Other install options

**Manual skeleton** (no skill CLI):

```bash
git clone --branch 0.0.13 --depth 1 \
  https://github.com/diegoos/agent-memory /tmp/agent-memory
mkdir -p .agents
cp -R /tmp/agent-memory/skills/agent-memory/vendor/memory .agents/memory
```

Then paste the agent-memory block from
[`skills/agent-memory/references/agent-block.md`](./skills/agent-memory/references/agent-block.md)
into your agent instructions file (keep the
`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` markers so `update` can
refresh only that block).

## Repository layout

```text
agent-memory/
├── bin/agent-memory.js         # npx CLI
├── package.json
├── hooks/                      # installer + harness configs (outside the skill)
└── skills/agent-memory/        # SKILL.md + vendor/ + references/
    └── vendor/                 # SoT: memory skeleton + UPDATE.md + method README
```

## License

MIT. See [LICENSE](./LICENSE).

[llm-wiki]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
