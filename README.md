# Agent Memory

**Agent Memory** is a project-local **Workspace Memory** for AI coding agents —
a versioned **recall layer** in `.agents/memory/`. It points at the project's
canonical sources (AGENTS, README, specs, ADRs, code) and keeps only what agents
need to continue work across sessions: active state, recent deltas, decision
pointers, and evidenced learnings that have no better home. No chat history
dependency and **no external infrastructure** (no server, vector DB, or
embeddings).

Agents **read and write** that memory. A manual skill (`/agent-memory`)
bootstraps and maintains it; optional lifecycle hooks add deterministic git
checkpoints while you work.

Supported harnesses: Cursor, Claude Code, Codex, OpenCode, Copilot, Gemini CLI.

## Why

- **Project recall, not a docs mirror.** Files in Git beat paste-from-yesterday
  chats. Canonical docs stay canonical; memory stores links and deltas.
- **Plain Markdown.** Searchable with `grep`, reviewable in PRs, no new runtime.
- **Progressive disclosure.** Always-load files stay short; detail lives in
  canonical sources or on-demand recall (`learnings.md`, …).
- **Inspired by Karpathy's [llm-wiki][llm-wiki]** (index, log, lint, small
  cross-linked files), adapted from source ingestion to _project_ memory.

## How it works

Memory lives at `.agents/memory/` and separates **canonical project sources**
from **operational recall** and **durable recall**:

| File                      | Role                                                                 |
| ------------------------- | -------------------------------------------------------------------- |
| `instructions.md`         | Method: how agents read and maintain the memory.                     |
| `index.md`                | Map of canonical sources + recall files (loading policy).            |
| `current.md`              | Shared **active** state (in progress / blockers / handoff).          |
| `active-work/<branch>.md` | Per-branch scratchpad (no merge conflicts across branches).          |
| `decisions.md`            | Decision **pointers** (or local fallback when no ADR system).        |
| `log.md`                  | Recent session deltas (append at the bottom; prune via consolidate). |

Optional on demand: `learnings.md` — evidenced, reusable facts with no better
source. Do **not** create parallel vision/architecture/patterns/domains copies;
link the project's own docs instead.

**Workflow:** before a task, agents read `index.md`, `current.md`, and their
branch's `active-work` file; while working they keep those current and write
links/deltas (not copies); at checkpoints they flush with `/agent-memory sync`;
periodically they run `/agent-memory consolidate` to promote useful facts and
prune closed-session noise.

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
/agent-memory bootstrap            # optional: inventory sources + gaps
/agent-memory install hooks cursor # print hook-install commands (skill never runs them)
```

Install lifecycle hooks with the `npx` CLI:

```bash
npx @dosx/agent-memory install hooks cursor
# interactive menu (skill + hooks / skill only / hooks only):
npx @dosx/agent-memory install cursor
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

| Command                       | Does                                                             |
| ----------------------------- | ---------------------------------------------------------------- |
| `/agent-memory help`          | List commands.                                                   |
| `/agent-memory init`          | Create `.agents/memory/`; wire native instruction file(s).       |
| `/agent-memory install hooks` | Print how to install/refresh hooks (user-run installer).         |
| `/agent-memory update`        | Migrate scaffolding; never overwrites your content blindly.      |
| `/agent-memory bootstrap`     | Inventory canonical sources and gaps; populate pointers.         |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md`.      |
| `/agent-memory lint`          | Broken links, orphans, duplication, stale branches, consistency. |
| `/agent-memory consolidate`   | Promote useful facts; prune closed-session noise (guided).       |

## Hooks

Optional lifecycle hooks keep `.agents/memory/` current **during** agent work
with deterministic checkpoints (no LLM loops): session binding, _Touched files_,
`log.md` path bullets on full checkpoints, `current.md` _In progress_ on session
start. Hooks never copy docs and never consolidate.

**Semantic** content stays agent-owned (or `/agent-memory sync` /
`consolidate`): decision pointers, progress notes, log outcomes, learnings.

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
