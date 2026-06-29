# agent-memory — Update migrations

Migration log for `/agent-memory update`. One section per released version,
newest at the bottom. Each line is a single change tagged `safe` or `sensitive`:

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

- safe: add `sync` command (`references/sync.md`) — refreshes `current.md`, the
  branch's `active-work/<branch>.md`, `log.md`, and the Domains/Features lists
  of `index.md` from repo state. New command in the skill only; no existing
  memory file is renamed or moved.
- safe: `SKILL.md` routing and help updated to list `sync`.
- sensitive: `instructions.md` — the _Workflow_ section now names
  `/agent-memory sync` as the executable trigger for the _During_ / _After_ /
  _Flush early_ steps. `update` must show the diff and confirm.

## 0.0.3

- safe: unify the agent-file stub in `references/init.md` — `AGENTS.md` now gets
  the same stub as `CLAUDE.md` / `GEMINI.md`, with both the explicit always-load
  list and `@.agents/memory/instructions.md`. Covers harnesses that read
  `AGENTS.md` via `@import` (Claude Code, Gemini CLI, Codex) and those that read
  it as plain Markdown (Cursor).
- safe: `agent-memory/README.md` and root `README.md` — the documented stub is
  now the single unified one.

## 0.0.4

- safe: wrap the memory block in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` with
  `<agent-memory>` … `</agent-memory>` delimiters (`references/init.md`), so the
  block is machine-identifiable.
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

## 0.0.5

- sensitive: `references/agent-block.md` — the canonical `<agent-memory>` block
  now instructs the agent to **Read** `.agents/memory/instructions.md` (not just
  "open and follow") and spells out the read-AND-write obligation (keep
  `active-work`, `log.md`, `decisions.md`, `current.md` current; delete
  `active-work` on merge; run `/agent-memory sync` at checkpoints). Fixes the
  case where plain-Markdown harnesses (Cursor) never load `instructions.md` via
  `@import` and so never maintain the memory. `update` compares the block
  byte-for-byte and will propose the refresh as a sensitive diff.
- safe: `references/agent-block.md` — "Why both the read list and `@import`"
  rewritten to explain the Cursor/plain-Markdown load path. No file rename or
  move.
- sensitive: `agent-memory/memory/instructions.md` — the _Flush early_ section
  now names `Read` as the load verb, calls out `sync --auto` for low-friction
  checkpoints, and adds a _Cursor and other plain-Markdown harnesses_ note.
- safe: `references/sync.md` — documents the `--auto` flag (apply all proposed
  diffs without per-file `AskQuestion`), plus an `--auto` steps variant. No
  existing file renamed or moved.
- safe: `references/lint.md` — documents `--fix` for the safe removal of stale
  per-branch `active-work` files (branch gone). Confirms each deletion.
- safe: `agent-memory/README.md` and root `README.md` — rewritten as clearer
  entry points (Quick start, "How agents use it", "Keeping the memory current"
  with a hooks link). They no longer inline the `<agent-memory>` stub; both
  point to `references/agent-block.md` as the single source, which removes the
  doc/canonical drift for good.
- safe: add `skills/agent-memory/hooks/` with opt-in flush-reminder hooks for
  Cursor, Claude Code, Codex, OpenCode, Copilot (CLI + cloud agent), plus a
  host-agnostic git `pre-commit` reminder and a shared reminder script. Hooks
  are non-blocking reminders only — they never write to the memory, never block
  the agent, and recommend `/agent-memory sync` (per-file confirmed), not
  `--auto`, so they cannot cause memory inconsistency or loops. Includes a
  `README.md` with a per-host matrix and install instructions. Optional, opt-in;
  not wired by `init`.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.5`; `help` text
  mentions `--auto` and `--fix`.
- sensitive: `references/agent-block.md` — delimiters changed from plain
  `<agent-memory>` … `</agent-memory>` tags to HTML comments
  `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` so the block is
  machine-identifiable but invisible in rendered Markdown. `update` compares the
  block byte-for-byte and will propose the refresh as a sensitive diff; it also
  migrates legacy plain-tag blocks to the comment form.
- safe: `references/init.md`, `references/update.md`, `SKILL.md`, root
  `README.md`, `agent-memory/README.md`, and `instructions.md` — documentation
  updated for the new delimiters and legacy migration path. No file rename or
  move.

## 0.0.6

- safe: `references/init.md` — `init` accepts an optional harness target
  (`init cursor`, `init claude`, `init codex`, `init opencode`, `init copilot`,
  `init gemini`) or auto-detects from existing agent files and harness dirs.
  Wires shared lifecycle hooks into existing harness dirs only (never creates
  `.cursor/`, `.claude/`, etc.).
- safe: add `hooks/shared/agent-memory-sync.sh` and
  `hooks/shared/agent-memory-session.sh` — deterministic git checkpoint (Touched
  files + conservative `log.md` append; no LLM). Replaces flush-reminder hooks
  (`agent-memory-flush.sh` removed).
- safe: unify harness hooks on the shared scripts — Cursor (`sessionStart`,
  `postToolUse`, `afterAgentResponse`, `preCompact`; no `stop` +
  `followup_message`), Claude Code (`SessionStart`, `PostToolUse`, `Stop`,
  `PreCompact`), Codex, Copilot, OpenCode plugin, git `pre-commit`.
- safe: Cursor integration is **hooks-only** — no `.cursor/rules/agent-memory.mdc`
  ( `@import` in `AGENTS.md` remains a no-op). Root `README.md` and
  `hooks/README.md` document hooks as the recommended Cursor path.
- sensitive: `agent-memory/memory/instructions.md` — _Plain-Markdown harnesses_
  section updated for hooks-only Cursor integration.
- safe: `references/update.md` — drop Cursor rule refresh step; note optional
  removal of legacy `.cursor/rules/agent-memory.mdc`.
- safe: `references/agent-block.md`, root `README.md`, `agent-memory/README.md`,
  `SKILL.md` help/routing/allowed-tools — aligned with harness `init` and unified
  hooks.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.6`.
- safe: add `agent-memory/memory/.gitignore` — ignores hook checkpoint state
  (`.hook-sync-state`, legacy `.cursor-hook-state`). Shipped with the skeleton;
  `init` copies it; `update` creates it when missing.
