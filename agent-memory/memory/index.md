# Memory Index

Map and entry point. Read this, `current.md`, and your branch's active-work file
before any task; see `instructions.md` for the full method.

**Keep this file aligned** with the memory tree: every lazy file and every
`domains/*.md` / `features/*.md` entry must be linked here; remove links when
files are deleted. `index.md` is updated at checkpoints and by
`/agent-memory sync` (domains/features discovery) — you must also update it when
you create or rename lazy files by hand.

## Loading policy

- **Always load** (before any task): this `index.md`, `current.md`, and your
  branch's `active-work/<branch>.md`. (`instructions.md` is attached via your
  agent file.) That is the minimal context.
- **Load on demand**: everything else — including `decisions.md` and `log.md` —
  when the task needs it. Use the lists below to find it.

## Core files

- [instructions.md](./instructions.md) — the method.
- [current.md](./current.md) — shared project state.
- `active-work/` — per-branch scratchpad (see `instructions.md` → _Per-branch
  active work_).
- [decisions.md](./decisions.md) — decisions + reasoning.
- [log.md](./log.md) — chronological activity (per-session headings + bullets).

## Lazy files (created on demand; link them here once real)

| File                                 | Purpose                                                       |
| ------------------------------------ | ------------------------------------------------------------- |
| [vision.md](./vision.md)             | Product purpose, scope, goals — ask the user if uncertain.    |
| [architecture.md](./architecture.md) | Components, stack, major flows — update on structural change. |
| [patterns.md](./patterns.md)         | Coding conventions — align with agent instruction files.      |
| [mistakes.md](./mistakes.md)         | Pitfalls to avoid.                                            |
| [known-issues.md](./known-issues.md) | Bugs, limitations, debt.                                      |

Also `domains/*.md` and `features/*.md` — one file per major area or user-facing
capability; link under _Domains_ / _Features_ below.

## Domains

Technical or structural areas (backend, API, infra, packages). Add a link when
you create `domains/<name>.md`; remove when the file is deleted.

_None yet._

## Features

User-facing or product capabilities. Add a link when you create
`features/<name>.md`; remove when the file is deleted. If the project has no
feature-level docs, leave this section as _None yet._

_None yet._
