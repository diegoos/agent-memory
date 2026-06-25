# agent-memory — Update migrations

Migration log for `/agent-memory update`. One section per released version, newest
at the bottom. Each line is a single change tagged `safe` or `sensitive`:

- `safe` — pure addition or a scaffolding change with no user content at risk.
  `update` may apply it automatically.
- `sensitive` — touches a file that can hold user content, or renames/moves/
  deletes anything. `update` must show a diff and get confirmation first.

Format:

```md
## <version>
- safe: <change>
- sensitive: <change>
```

---

## 0.0.1

- safe: initial baseline — no migrations.

## 0.0.2

- safe: add `sync` command (`references/sync.md`) — refreshes `current.md`,
  the branch's `active-work/<branch>.md`, `log.md`, and the Domains/Features
  lists of `index.md` from repo state. New command in the skill only; no
  existing memory file is renamed or moved.
- safe: `SKILL.md` routing and help updated to list `sync`.
- sensitive: `instructions.md` — the _Workflow_ section now names
  `/agent-memory sync` as the executable trigger for the _During_ / _After_ /
  _Flush early_ steps. `update` must show the diff and confirm.

## 0.0.3

- safe: unify the agent-file stub in `references/init.md` — `AGENTS.md` now
  gets the same stub as `CLAUDE.md` / `GEMINI.md`, with both the explicit
  always-load list and `@.agents/memory/instructions.md`. Covers harnesses that
  read `AGENTS.md` via `@import` (Claude Code, Gemini CLI, Codex) and those
  that read it as plain Markdown (Cursor).
- safe: `agent-memory/README.md` and root `README.md` — the documented stub is
  now the single unified one.

## 0.0.4

- safe: wrap the memory block in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` with
  `<agent-memory>` … `</agent-memory>` delimiters (`references/init.md`), so
  the block is machine-identifiable.
- sensitive: `references/update.md` — `update` now refreshes **only** the
  `<agent-memory>` block in the root agent files (replacing it with the
  canonical block), and migrates legacy `## Agent Memory` sections into the
  delimited block. Never touches content outside the delimiters. Show the diff
  and confirm before applying.
- safe: `agent-memory/README.md` and root `README.md` — the documented stub is
  now the delimited block.
- safe: extract the canonical `<agent-memory>` block into a new reference,
  `references/agent-block.md`, as the single source of truth.
- safe: `references/init.md` and `references/update.md` now reference
  `agent-block.md` instead of inlining the block text. `update` compares the
  installed block against the canonical block byte-for-byte and skips when
  identical.
