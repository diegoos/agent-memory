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

### Harness parity — memory contract

All supported harnesses (Cursor, Claude Code, Codex, Copilot, Gemini CLI,
OpenCode) target the **same memory shape**. Shared hook scripts in the
agent-memory repo (`hooks/agent-memory-hooks/`) define **what** is written;
harness config only defines **when** checkpoints run. If outcomes differ, treat
it as a bug — not a harness feature.

**Two layers (every harness):**

| Layer          | Role                                 | Mechanism                          |
| -------------- | ------------------------------------ | ---------------------------------- |
| **Context**    | Obligation to read and update memory | Native instruction file (`.mdc`,   |
|                |                                      | `*.instructions.md`, agent `*.md`) |
| **Checkpoint** | Deterministic git + session sync     | Lifecycle hooks or OpenCode plugin |

**Hooks write (identical outcome everywhere hooks are installed):**

| Target                           | Content                                             | When                      |
| -------------------------------- | --------------------------------------------------- | ------------------------- |
| `active-work/` → _Touched files_ | Session-cumulative repo paths (`git` + stdin on     | Between-turn + end-of-    |
|                                  | harnesses with post-tool events)                    | turn checkpoints          |
| `active-work/` → _Task_ stub     | Branch-name placeholder when still generic          | Same checkpoints          |
| `log.md` → session heading       | `## [YYYY-MM-DD] [session-id]` (see OpenCode below) | Session start / first     |
|                                  |                                                     | checkpoint of the period  |
| `log.md` → file-path bullets     | ``- `path` `` or `changed N files…` summary (>8)    | **Full checkpoints only** |
|                                  | — evidence from `git`, never semantic text          | (end-of-turn, compact,    |
|                                  |                                                     | pre-commit)               |
| `current.md` → _In progress_     | Links to open `active-work/*.md` + one-line goal    | Session start             |
| `.hook-sync-state`               | Session IDs, dedupe sets (not committed)            | Internal                  |

Hooks **never** write: semantic `log.md` bullets, `[type]` / summary in
headings, `decisions.md`, `active-work` _Progress_ / _Blockers_ / _Notes_,
`current.md` _Done_ / _Next steps_, lazy file bodies, or `index.md` link prose.

**Agent (or `/agent-memory sync`) writes — same on every harness:**

| Target         | Content                                                   |
| -------------- | --------------------------------------------------------- |
| `log.md`       | Semantic bullets; `[type]` and session summary in         |
|                | heading when the goal is clear                            |
| `active-work/` | **Task** (meaning), **Progress**, **Blockers**, **Notes** |
| `decisions.md` | ADR entries on every design/architecture change           |
| `current.md`   | _Done_, _Next steps_ (when evidence exists), milestone    |
| `index.md`     | Lazy and domain/feature links                             |
| Lazy files     | Bodies when triggers fire (`architecture.md`, etc.)       |

`/agent-memory sync` refreshes `current.md`, active-work, `log.md`, and
`index.md` from `git` — it does **not** replace the agent's obligation to update
`decisions.md` or lazy-file bodies.

**Evidence vs meaning (always split this way):**

```md
## [2026-07-05] [abc-123] [feat] interview list page

- changed 12 files (see active-work Touched files) ← hook (git evidence)
- `src/app/tag/entrevista/page.tsx` ← hook (≤8 new paths)
- added canonical /tag/entrevista/ route ← agent (semantic)
- recorded URL decision in decisions.md ← agent (semantic)
```

**Harness timing (same writes, different schedule):**

| Checkpoint     | Cursor             | Claude / Codex | Copilot / Gemini | OpenCode          |
| -------------- | ------------------ | -------------- | ---------------- | ----------------- |
| Session start  | native             | native         | native           | first idle / sync |
| Mid-turn paths | postToolUse +      | PostToolUse    | postToolUse      | — (git at idle)   |
|                | afterFileEdit      |                |                  |                   |
| End of turn    | afterAgentResponse | Stop           | agentStop        | session.idle      |
| Before compact | preCompact         | PreCompact     | preCompact       | compacting        |

**OpenCode heading rule:** `ses_*` IDs rotate often. Hooks coalesce to **one
`log.md` heading per calendar day** (bound in `.hook-sync-state` as
`opencode_log_heading_id`). Bullets and semantic text still append under that
single heading — same contract, different session-key granularity.

**Without hooks:** run `/agent-memory sync` at the same checkpoints; the agent
must supply both evidence (from `git`) and semantic bullets manually.

See the [hooks README](https://github.com/diegoos/agent-memory/blob/v0.0.12/hooks/README.md)
for per-host wiring. Do not duplicate this contract elsewhere — link to this
section.

### Obligations by file

#### `log.md` — session log (hooks + agent)

See **Harness parity — memory contract** above. Hooks maintain the session
**heading** and append **file-path bullets** from `git` (evidence only). You add
semantic bullets (fixes, features, outcomes) and refine the heading
type/summary.

- **One heading per session** (date + session ID). OpenCode: **one heading per
  calendar day** when `ses_*` IDs rotate (same bullets, coalesced key).
- Hooks open `## [YYYY-MM-DD] [session-id]` on session start or first
  checkpoint; you add `[type]` and a one-line summary when the session goal is
  clear.
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
regression: it can appear as "requestable" instead of "always applied"), so an
`AGENTS.md`-only block may never reach the model.

**On Cursor:** run `/agent-memory init cursor` when `.cursor/` already exists.
`init` creates `.cursor/rules/agent-memory.mdc` with `alwaysApply: true` — this
is the **context layer** (always-on rules that inject the agent-memory
workflow). Install lifecycle hooks (checkpoint layer) with the user-run
installer — `/agent-memory install hooks cursor` **prints** the `npx` / shell
commands; run them yourself (or use `init cursor` for the printed instructions
on first setup). Hooks keep `active-work/` (session-cumulative _Touched files_,
Task stub), `log.md` (session heading; file-path bullets on full checkpoints
only), and `current.md` _In progress_ on session start — you own **semantic**
log text, Task meaning, `decisions.md`, _Done_, and `index.md`. See the
[hooks README](https://github.com/diegoos/agent-memory/blob/v0.0.12/hooks/README.md).

**Context vs checkpoint:** `.mdc` puts the obligation to Read `instructions.md`
into every session context; hooks run deterministic git checkpoints without an
LLM. Both are recommended on Cursor — neither replaces the other.

If you are on Cursor and have not yet Read `instructions.md` in the current
session, Read it now before continuing. Harnesses that honor `@import` (Claude
Code, Gemini CLI, Codex) get `instructions.md` auto-loaded via their agent files
and need no `.mdc`.

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

## Git commit rules for the memory

The pre-commit hook runs an **evidence** checkpoint (touched files, file-path
`log.md` bullets from `git`). Run **`/agent-memory sync`** before committing so
semantic memory (progress, decisions, log meaning) stays current. Commit memory
changes with the rest of the repo, using the project's commit message rules (50
characters for the title when practical).

Example:

```text
chore(memory): update memory on [CONCISE DESCRIPTION OF THE CHANGES]
```

## When in doubt

Prioritize: `current.md`, your active-work file, `log.md`, `decisions.md`.
