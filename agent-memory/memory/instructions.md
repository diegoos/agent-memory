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
| `log.md`          | Chronological activity record (per session).           | frequent   |

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

**During:** keep your active-work file current; append to the **current
session's** `log.md` entry; record decisions in `decisions.md`; update lazy
files when their triggers fire (below).

**After:** update `current.md` if project state changed; finalize `decisions.md`
/ `mistakes.md` / `log.md`; keep `index.md` aligned; delete your active-work
file when the branch merges.

**Flush early:** before the context grows long or is compacted, and before
ending a session, write the essentials to your active-work file and `log.md`.
The next agent must continue from the files, never from chat history. Run
`/agent-memory sync` as the executable form of the _During_ / _After_ / _Flush
early_ steps — it refreshes `current.md`, your branch's active-work file,
`log.md`, and `index.md` from repo state (`git`) and confirms each change before
writing. Use `/agent-memory sync --auto` at routine checkpoints to apply all
proposed diffs without the per-file prompt, keeping the flush low-friction.

### Obligations by file

#### `log.md` — session log (hooks + agent)

Hooks maintain the session **heading** and append **file-path bullets** from
`git` (evidence only). You add semantic bullets (fixes, features, outcomes) and
refine the heading type/summary.

- **One heading per session** (date + session ID). Hooks open
  `## [YYYY-MM-DD] [session-id] [chore] session work` on session start; you
  change `[chore]` and the summary when the session goal is clear.
- Append your bullets under the same heading — do not open a new heading per
  checkpoint.
- Session ID: `AGENT_MEMORY_SESSION_ID` (from sessionStart `env`), harness stdin
  (`session_id` / `conversation_id`), or `.hook-sync-state`.

#### `decisions.md` — required; update when decisions change

**You MUST** append an ADR-style entry when you **make, confirm, or change** a
design, architecture, or convention choice (see `decisions.md`). When you
reverse or supersede a decision, add a new entry that references the old one. Do
not rely on chat or `log.md` alone.

#### `active-work/<branch>.md` — hooks + agent

- Hooks: ensure the file exists, refresh _Touched files_ from `git`, and seed
  _Task_ from the branch name when still a placeholder.
- **You:** refine **Task** from branch + request + `log.md`; keep **Progress**,
  **Blockers**, and **Notes** current.

#### `current.md` — shared snapshot

- **In progress:** hooks refresh this list on **session start** from open
  `active-work/*.md`; you refine summaries when branch goals change.
- **Done:** when a branch merges and its active-work file is removed, add a
  one-line summary of what landed here.
- **Next steps:** **only** when an explicit roadmap or user-recorded plan exists
  in the project — never infer or invent upcoming work.

#### `index.md` — keep the map aligned

Whenever you create, rename, or delete a lazy file or a `domains/*` /
`features/*` file, update the matching section in `index.md` (add link, remove
stale link). `/agent-memory sync` can add missing domain/feature links from
`git`, but you must maintain lazy-file links and remove dead entries.

#### `vision.md` — ask when uncertain

During `init`, `bootstrap`, or `sync` (without `--force` / `--auto`): if product
purpose or scope is unclear from existing docs, **ask the user** before writing
or changing `vision.md`. If vision may need updating after your session, tell
the user at the end — do not silently rewrite goals.

#### `architecture.md` — update on structural change

Create or update when any of these occur:

- Major dependency or runtime version change (language, framework, DB, Node,
  etc.).
- New service, package, or top-level module; removal or merge of one.
- Page/app routing or layout architecture change.
- New external integration or deployment topology change.

Keep components, stack, and key flows accurate; link from `index.md`.

#### `patterns.md` — update on convention change

Create or update when coding conventions change or when you establish patterns
that should hold across the repo. Stay aligned with `AGENTS.md`, `CLAUDE.md`,
`GEMINI.md`, and project linters — record project-specific rules here, do not
duplicate the full agent files.

Triggers: new error-handling pattern, API client pattern, test layout, naming
scheme, or anything you would want the next agent to follow consistently.

### Plain-Markdown harnesses (Cursor, for example)

Some harnesses treat `AGENTS.md` as plain Markdown and do **not** honor
`@import` — in Cursor, `@.agents/memory/instructions.md` in the agent-memory
block is a no-op. `AGENTS.md` may also fail to auto-inject (known Cursor
regression: it can appear as "requestable" instead of "always applied"), so the
agent-memory block alone may never reach the model.

**On Cursor:** run `/agent-memory init cursor` when `.cursor/` already exists to
wire lifecycle hooks (recommended). `@import` in `AGENTS.md` is a no-op, and
`AGENTS.md` may not auto-inject reliably. Hooks keep `active-work/` (Touched
files, Task stub), `log.md` (session heading + file bullets), and `current.md`
_In progress_ on session start — you own semantic log text, Task meaning,
`decisions.md`, _Done_, and `index.md`. See
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

> When available, use ripgrep (`rg`) instead of `grep` for better performance.
> To check if you have ripgrep installed, run `rg --version`.

```bash
grep "^## \[" log.md | tail -5              # last 5 session headings
grep "^## \[2026-06" log.md                 # by date / month
grep "^## \[.*\] \[fix\]" log.md            # by type tag
grep -A5 "^## \[2026-06-20\]" log.md       # heading + bullets
```

If you have ripgrep installed, you can use the following commands instead:

```bash
rg "^## \[" log.md | tail -5              # last 5 session headings
rg "^## \[2026-06" log.md                 # by date / month
rg "^## \[.*\] \[fix\]" log.md            # by type tag
rg -A5 "^## \[2026-06-20\]" log.md       # heading + bullets
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
  printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"
done
```

## When in doubt

Prioritize: `current.md`, your active-work file, `log.md`, `decisions.md`.
