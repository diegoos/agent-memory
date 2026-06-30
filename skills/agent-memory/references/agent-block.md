# The agent-memory block

The exact block `init` writes into the root agent files (`AGENTS.md`,
`CLAUDE.md`, `GEMINI.md`, or a host-specific agent `*.md`) and `update`
refreshes in place. **Single source of truth** for the block content — both
`init` and `update` read it from here; never duplicate the block text in those
references.

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

## Why the delimiters

`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` mark the block so
`update` can find and replace **only** it, without touching anything else in the
file. HTML comments are invisible in rendered Markdown (no raw tags in the
preview) but remain machine-identifiable in the source. Never edit content
outside the delimiters.

## Why both the read list and `@import`

- The explicit "Read `.agents/memory/instructions.md`" line makes the agent load
  the method file directly. This is the load path harnesses that treat
  `AGENTS.md` as plain Markdown (Cursor, plain-text readers) rely on — they do
  **not** honor `@import`, so the obligation to read `instructions.md` must be
  spelled out, or the agent never learns the maintain-the-memory workflow and
  the memory stops being updated. On **Cursor**, also wire lifecycle hooks via
  `init cursor` — see `instructions.md` → _Plain-Markdown harnesses_.
- The `@.agents/memory/instructions.md` line is honored by harnesses that follow
  the AGENTS.md `@import` convention (Claude Code, Gemini CLI, Codex),
  auto-loading `instructions.md`.

Including both is intentional and harmless — a harness that loads `@import`
simply gets `instructions.md` once.

## How to compare

`update` decides whether to refresh by comparing the block currently in the
agent file (text between the delimiters, inclusive) against the block above,
byte-for-byte. Identical → nothing to do. Different → propose the unified diff
and confirm before replacing (sensitive). Legacy installs may still use plain
`<agent-memory>` … `</agent-memory>` tags (0.0.4–0.0.5); `update` treats those
as the same block and replaces them with the comment-delimited canonical form.
