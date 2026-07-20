# The agent-memory block

The exact block `init` writes into harness instruction files and `update`
refreshes in place. **Single source of truth** for the block content — both
`init` and `update` read it from here; never duplicate the block text in those
references.

**Write targets** (body identical everywhere; see `references/init.md` for
carrier resolution and which file receives the block):

| Harness  | File                                                                     |
| -------- | ------------------------------------------------------------------------ |
| cursor   | `.cursor/rules/agent-memory.mdc` (with `alwaysApply: true` frontmatter)  |
| copilot  | `.github/instructions/agent-memory.instructions.md`                      |
| claude   | `CLAUDE.md` (or `AGENTS.md` when `CLAUDE.md` delegates via `@AGENTS.md`) |
| codex    | `AGENTS.md`                                                              |
| opencode | `AGENTS.md`                                                              |
| gemini   | `GEMINI.md` (or delegated carrier — same rules as claude)                |

## The block

```md
<!-- <agent-memory> -->

## Agent Memory

Local **recall** layer in `.agents/memory/` — not a docs mirror. **Before any
task**, Read `.agents/memory/instructions.md`, then `index.md`, `current.md`,
and your branch file under `active-work/`. Write **links and deltas**, not
copies. At checkpoints run `/agent-memory sync`. Delete branch active-work on
merge; periodically run `/agent-memory consolidate`.

@.agents/memory/instructions.md

<!-- </agent-memory> -->
```

## Cursor `.mdc` wrapper

For Cursor, prepend this frontmatter to the block above (body unchanged):

```yaml
---
description: Agent Memory workspace memory workflow
alwaysApply: true
---
```

`update` compares only the delimited body; preserve frontmatter when refreshing.

## Copilot `.instructions.md` wrapper

For Copilot, prepend this frontmatter to the block above (body unchanged):

```yaml
---
applyTo: "**"
---
```

Copilot path-specific files under `.github/instructions/**/*.instructions.md`
are applied only to files matching an `applyTo` glob. `**` makes the block
**always-on** (every file, every session) — required so the agent receives the
agent-memory workflow before any task. Without `applyTo`, the file may not apply
at all. `update` compares only the delimited body; preserve frontmatter when
refreshing.

## Why the delimiters

`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` mark the block so
`update` can find and replace **only** it, without touching anything else in the
file. HTML comments are invisible in rendered Markdown (no raw tags in the
preview) but remain machine-identifiable in the source. Never edit content
outside the delimiters.

## Why both the read list and `@import`

- The explicit "Read `.agents/memory/instructions.md`" line is the load path for
  plain-Markdown harnesses and Cursor rules (`.cursor/rules/agent-memory.mdc`
  with `alwaysApply: true`). `@import` in `AGENTS.md` is a no-op on Cursor.
  Hooks are the **checkpoint** layer (user-run installer); `.mdc` / agent files
  are the **context** layer — see `instructions.md` →
  _Harness parity — memory contract_ and the
  [hooks README](https://github.com/diegoos/agent-memory/blob/0.0.13/hooks/README.md).
- `@.agents/memory/instructions.md` is honored by harnesses that follow the
  AGENTS.md `@import` convention (Claude Code, Gemini CLI, Codex).

Including both is intentional — a harness that loads `@import` still gets
`instructions.md` once. Keep this block short; do not duplicate the method.

## How to compare

`update` decides whether to refresh by comparing the block currently in the
instruction file (text between the delimiters, inclusive) against the block
above, byte-for-byte. Identical → nothing to do. Different → propose the unified
diff and confirm before replacing (sensitive). Legacy installs may still use
plain `<agent-memory>` … `</agent-memory>` tags (0.0.4–0.0.5); `update` treats
those as the same block and replaces them with the comment-delimited canonical
form. For `.cursor/rules/agent-memory.mdc`, compare the delimited body only —
ignore YAML frontmatter.
