# The `<agent-memory>` block

The exact block `init` writes into the root agent files (`AGENTS.md`,
`CLAUDE.md`, `GEMINI.md`, or a host-specific agent `*.md`) and `update`
refreshes in place. **Single source of truth** for the block content — both
`init` and `update` read it from here; never duplicate the block text in those
references.

## The block

```md
<agent-memory>
## Agent Memory

This project uses Agent Memory (a local Workspace Memory). Before starting
any task, open and follow `.agents/memory/instructions.md`, then read
`.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
file in `.agents/memory/active-work/`.

@.agents/memory/instructions.md
</agent-memory>
```

## Why the delimiters

`<agent-memory>` … `</agent-memory>` mark the block so `update` can find and
replace **only** it, without touching anything else in the file. Never edit
content outside the delimiters.

## Why both the read list and `@import`

- The explicit read list covers harnesses that treat `AGENTS.md` as plain
  Markdown (Cursor, plain-text readers).
- The `@.agents/memory/instructions.md` line is honored by harnesses that
  follow the AGENTS.md `@import` convention (Claude Code, Gemini CLI, Codex),
  auto-loading `instructions.md`.

Including both is intentional and harmless — a harness that loads `@import`
simply gets `instructions.md` once.

## How to compare

`update` decides whether to refresh by comparing the block currently in the
agent file (text between the delimiters, inclusive) against the block above,
byte-for-byte. Identical → nothing to do. Different → propose the unified diff
and confirm before replacing (sensitive).
