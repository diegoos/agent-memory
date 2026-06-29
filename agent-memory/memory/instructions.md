# Agent Memory — Instructions

A persistent **Workspace Memory** in `.agents/memory/`, versioned in Git: the
shared source of truth between humans and agents. Read it before any task and
keep it current as you work. **Goal: any human or agent can continue the work
from these files alone — without chat history.**

## Principles

- The Memory belongs to the **project**, not the agent; keep it human-readable.
- Prefer small, focused files; prefer **updating** one over creating one; never
  duplicate content.
- Record decisions and learnings **as they happen**, not only at the end.
- Never remove knowledge without an explicit reason; no temporary notes in
  permanent files.
- Write **concise but context-rich**: one fact per line, no preamble, link
  instead of repeating. Tokens cost — keep the always-loaded files
  (`current.md`, your active-work file) short and push detail into
  load-on-demand files.

## Structure

Single root `.agents/memory/`; sub-areas (services, packages, contexts) go under
`domains/`.

**Core files (always present):**

| File              | Purpose                                                | Update     |
| ----------------- | ------------------------------------------------------ | ---------- |
| `instructions.md` | This method.                                           | rare       |
| `index.md`        | Map of the Memory + loading policy.                    | occasional |
| `current.md`      | Shared project state (version, done, in progress).     | frequent   |
| `active-work/`    | Per-branch ephemeral scratchpad (one file per branch). | very freq. |
| `decisions.md`    | Important decisions + the reasoning.                   | frequent   |
| `log.md`          | Chronological activity record.                         | frequent   |

**Lazy files** — create only when there is real content, then link from
`index.md`: `vision.md` (purpose/scope), `architecture.md`
(components/tech/flows), `patterns.md` (conventions), `mistakes.md` (pitfalls to
avoid), `known-issues.md` (bugs/limitations/debt), and `domains/*.md` /
`features/*.md`. Each `domains/*` or `features/*` file: purpose, rules, key
flows/dependencies, and the related source files.

### Per-branch active work

`active-work/` holds one scratchpad **per branch**, so parallel work never
collides. The current file is `active-work/<branch>.md`, where `<branch>` is the
branch name (`git branch --show-current`; `local` if none) with every character
outside `[A-Za-z0-9._-]` replaced by `-` (e.g. `feat/login` → `feat-login.md`).
On a branch's first task, copy `active-work/TEMPLATE.md` and set its `Branch:`
header to the real name (so the lossy filename is never reversed). **Delete the
file when the branch merges** — conflict-free, since no other branch touches it;
`lint` flags files whose branch is gone.

## Workflow

**Before any task:** read `index.md`, `current.md`, and your branch's
active-work file (create from `active-work/TEMPLATE.md` if missing). Consult on
demand: `decisions.md`, `log.md`, and the lazy files.

**During:** keep your active-work file current (task, progress, touched files,
blockers); append events to `log.md`; record decisions (with reasoning) in
`decisions.md` and pitfalls in `mistakes.md`.

**After:** update `current.md` if the project state changed; finalize entries in
`decisions.md` / `mistakes.md` / `log.md`; create lazy files only when a new
domain or significant feature emerges; delete your active-work file when the
branch merges.

**Flush early:** before the context grows long or is compacted, and before
ending a session, write the essentials to your active-work file (and `log.md`).
The next agent must continue from the files, never from chat history. Run
`/agent-memory sync` as the executable form of the _During_ / _After_ / _Flush
early_ steps — it refreshes `current.md`, your branch's active-work file,
`log.md`, and `index.md` from repo state (`git`) and confirms each change before
writing. Use `/agent-memory sync --auto` at routine checkpoints to apply all
proposed diffs without the per-file prompt, keeping the flush low-friction.

### Plain-Markdown harnesses (Cursor, for example)

Some harnesses treat `AGENTS.md` as plain Markdown and do **not** honor
`@import` — in Cursor, `@.agents/memory/instructions.md` in the agent-memory
block is a no-op. `AGENTS.md` may also fail to auto-inject (known Cursor
regression: it can appear as "requestable" instead of "always applied"), so the
agent-memory block alone may never reach the model.

**On Cursor:** run `/agent-memory init cursor` when `.cursor/` already exists to
wire lifecycle hooks (recommended). `@import` in `AGENTS.md` is a no-op, and
`AGENTS.md` may not auto-inject reliably. Hooks update Touched files from `git`
between turns; you still own task/progress text and `current.md`. See
`skills/agent-memory/hooks/README.md`.

The agent-memory block in `AGENTS.md` still spells out "Read
`.agents/memory/instructions.md`" for harnesses that do load it — and remains
the cross-tool stub for Claude Code, Codex, Gemini, etc. If you are on Cursor
and have not yet Read `instructions.md` in the current session, Read it now
before continuing. Harnesses that honor `@import` (Claude Code, Gemini CLI,
Codex) get `instructions.md` auto-loaded and need no extra step beyond the
block.

## Multi-developer rules

- **`current.md`** is shared/global; change it in the PR that changes project
  state. Conflicts are rare, resolved like any doc.
- **`active-work/`** is per-branch — zero conflicts, no reset ritual; delete on
  merge (see above).
- **`log.md` / `decisions.md`** are append-only, **oldest first / newest at the
  bottom** (appending is safe; recent entries come out with `tail`). On
  conflict, **keep both**.

## Searching the log

`log.md` and `decisions.md` have parseable headers, so `grep` suffices:

```bash
grep "^## \[" log.md | tail -5         # last 5 entries (newest at bottom)
grep "^## \[2026-06" log.md            # by date / month
grep "^## \[.*\] fix " log.md          # by type
grep -A3 "^## \[2026-06-20\]" log.md   # one entry with its body
```

## Memory lint (anti-rot)

Run on request or at PR review — an out-of-date Memory is worse than none.
Check: contradictions with the code; stale `current.md`; orphaned `domains/*` /
`features/*`; stale per-branch files (branch gone); broken cross-references;
duplication; bloat (trim or move detail out of the always-loaded files). Partly
mechanizable (run from `.agents/memory/`):

```bash
# Broken cross-references
grep -rhoE '\]\(\./[^)]+\)' . | sed -E 's/^\]\(\.\/([^)]+)\)$/\1/' \
  | sort -u | while read -r f; do test -e "$f" || echo "missing: $f"; done
# Orphaned domains/features (not linked from index.md)
find domains features -name '*.md' 2>/dev/null | while read -r f; do
  grep -q "$(basename "$f")" index.md || echo "orphan: $f"; done
# Stale per-branch files (skipped if git lists no branches)
branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
[ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
  printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"; done
```

## When in doubt

Prioritize: `current.md`, your active-work file, `log.md`, `decisions.md`.
