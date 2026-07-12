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

This project uses Agent Memory (a local Workspace Memory). **Before starting any
task**, Read `.agents/memory/instructions.md` (it defines the workflow), then
read `.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
file in `.agents/memory/active-work/`.

This memory is **read AND written** by agents — it is not chat history. While
you work and when you finish a task, keep it current per `instructions.md`:
update your branch's `active-work/<branch>.md` (Task, progress, touched files,
blockers), append bullets to the **current session** heading in `log.md`,
**record architecture and design decisions in `decisions.md`**, keep `index.md`
aligned with lazy and domain/feature files, and refresh `current.md` when
project state changes (list open active-work files in _In progress_; move
completed work to _Done_). Ask the user before changing `vision.md` when
uncertain. Delete your `active-work/` file when the branch merges. At
checkpoints (end of task, before commit, before compaction, end of session), run
`/agent-memory sync` to flush `current.md`, active-work, `log.md`, and
`index.md` from repo state.

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
applyTo: '**'
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

- The explicit "Read `.agents/memory/instructions.md`" line makes the agent load
  the method file directly. This is the load path for harnesses that treat agent
  files as plain Markdown or load context via rules — **Cursor** receives the
  block through `.cursor/rules/agent-memory.mdc` (`alwaysApply: true`);
  `@import` in `AGENTS.md` is a no-op there. The "Read …" line is the active
  path on Cursor. For hooks (checkpoint layer), print user-run install commands
  from `/agent-memory install hooks <harness>` — the skill never installs hooks;
  see `instructions.md` → _Plain-Markdown harnesses_ (hooks = checkpoint; `.mdc` =
  context).
- The `@.agents/memory/instructions.md` line is honored by harnesses that follow
  the AGENTS.md `@import` convention (Claude Code, Gemini CLI, Codex),
  auto-loading `instructions.md`.

Including both is intentional and harmless — a harness that loads `@import`
simply gets `instructions.md` once.

## How to compare

`update` decides whether to refresh by comparing the block currently in the
instruction file (text between the delimiters, inclusive) against the block
above, byte-for-byte. Identical → nothing to do. Different → propose the unified
diff and confirm before replacing (sensitive). Legacy installs may still use
plain `<agent-memory>` … `</agent-memory>` tags (0.0.4–0.0.5); `update` treats
those as the same block and replaces them with the comment-delimited canonical
form. For `.cursor/rules/agent-memory.mdc`, compare the delimited body only —
ignore YAML frontmatter.
