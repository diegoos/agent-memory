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

**Before a task**, follow session **Status** (`load:` / Next / Checkpoint). Read `index.md` and `current.md`. Open `active-work/` only if it exists. Status `load:` → Read that file (one file; not a hop). Path hit (diff, named file, failing test) → Status hints and code. Durable why with no path hit: Read `.agents/memory/instructions.md` → _Recall hop_. Do not require verb names.

**Before writing**, Read `.agents/memory/instructions.md` → _How to write_. Do not keep `instructions.md` in always-on context.

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
- Session **Status** (hooks) is the face of the turn: Checkpoint, Next, `load:` from `when editing:` vs pending/dirty paths (including `decisions.md` / learnings when hinted). The injected block only names those triggers. Live user decisions loaded that way constrain **approach**; loaded Insights constrain a repeat of a failed path. Explicit **Read** of `index.md` / `current.md` stays the Markdown hot path. `instructions.md` is the method: load it **before writing** memory, and for _Recall hop_ on durable why with no path hit. _Write floor_ in `instructions.md` is the SoT. Catch-up consume lives in Status/`references/sync.md`, not in this block. Do not `@`-import `instructions.md`. Details including _Harness parity — memory contract_ stay in `instructions.md`.
- Compare installed vs canonical byte-for-byte (body only for `.mdc`); identical → skip; different → confirm before replace.
