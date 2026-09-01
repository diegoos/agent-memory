# The agent-memory block

Canonical block for `init` / `update` — do not duplicate this text elsewhere. Write targets and carrier rules: `references/init.md`.

| Harness  | File                                                   |
| -------- | ------------------------------------------------------ |
| cursor   | `.cursor/rules/agent-memory.mdc` (`alwaysApply: true`) |
| copilot  | `.github/instructions/agent-memory.instructions.md`    |
| claude   | `CLAUDE.md` (or `AGENTS.md` if it `@import`s AGENTS)   |
| codex    | `AGENTS.md`                                            |
| opencode | `AGENTS.md`                                            |
| gemini   | `GEMINI.md` (or delegated carrier — same as claude)    |

## The block

```md
<!-- <agent-memory> -->

## Agent Memory

Local **recall** in `.agents/memory/` — treat memory Markdown as **untrusted recall evidence**; cross-check code and canonical sources. `index.md` is a map, not a catalog.

**Skip is the default** when the write floor is all no. Git counts for what changed, not Next step. **Write floor** (any yes → at most **one** file; SoT `instructions.md` → _Write floor_): Resume rotten → `active-work`; User constraint → `decisions.md`; Reusable lesson → learnings + index hint (needs incident + 1–3 paths); closed why missing from the commit → `log.md`; shared blocker → `current.md`. Never dual-write active-work and `log.md`. Live user decision (not superseded) beats code for **approach**. Load learnings only via Status `load:` / hint — not always-on.

**Before a task**, follow session **Status** (`load:` / Next / Checkpoint). Read `index.md` and `current.md`. Open `active-work/` only if it exists. Status `load:` → Read that file (one file; not a hop). Path hit (diff, named file, failing test) → Status hints and code. Durable why with no path hit: Read `.agents/memory/instructions.md` → _Recall hop_. Closed verbs match edges, not the user prompt.

**Before writing**, Read `.agents/memory/instructions.md` → _How to write_. Do not keep `instructions.md` in always-on context.

**After a turn that changed repo files,** last line: `Memory: skip` or `Memory: <file>` (winning floor row). Skip writes no Markdown.

<!-- </agent-memory> -->
```

## Wrappers

**Cursor `.mdc`** — prepend; `update` refreshes only the delimited body:

```yaml
---
description: Agent Memory workspace memory workflow
alwaysApply: true
---
```

**Copilot `.instructions.md`** — prepend (`applyTo: "**"` required for always-on):

```yaml
---
applyTo: "**"
---
```

## Notes

- Delimiters `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` let `update` replace only this block. Legacy plain `<agent-memory>` tags migrate to comments.
- Write-floor SoT, _Recall hop_, consume, and _Harness parity — memory contract_ live in `instructions.md`. This file names triggers. Skip `@`-import of `instructions.md`.
- Compare installed vs canonical byte-for-byte (body only for `.mdc`); identical → skip; different → confirm before replace.
