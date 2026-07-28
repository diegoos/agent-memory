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

Local **recall** layer in `.agents/memory/` — not a docs mirror. **Before any task**, Read `.agents/memory/instructions.md`, then `index.md`, `current.md`, and your branch `active-work/` when it exists. Write **links and deltas**, not copies. **Primary write:** when a turn has durable progress, update `active-work` (next step + validation) and a semantic `log.md` outcome before stopping. **Catch-up:** `/agent-memory sync` at checkpoints (or follow the skill's `references/sync.md` without invoking the skill). Delete branch active-work on merge; periodically `/agent-memory consolidate`.

@.agents/memory/instructions.md

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
- Explicit **Read** `instructions.md` covers plain-Markdown / Cursor rules; `@import` covers Claude/Gemini/Codex. Keep the block short — method details stay in `instructions.md` → _Harness parity — memory contract_ and the [hooks README](https://github.com/diegoos/agent-memory/blob/0.1.0/hooks/README.md).
- Compare installed vs canonical byte-for-byte (body only for `.mdc`); identical → skip; different → confirm before replace.
