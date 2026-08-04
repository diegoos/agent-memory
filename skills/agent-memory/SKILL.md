---
name: agent-memory
description: >-
  Manual orchestrator for Workspace Memory in `.agents/memory/` — invoke only
  via `/agent-memory <command>`.
metadata:
  invocation: manual
  version: "0.2.0"
compatibility: >-
  Works offline from the skill package vendor skeleton. Hook installation is
  print-only (user-run shell script or npx CLI).
allowed-tools: >-
  Read Grep Glob Task
  Edit(.agents/memory/current.md) Write(.agents/memory/current.md)
  Edit(.agents/memory/index.md) Write(.agents/memory/index.md)
  Edit(.agents/memory/log.md) Write(.agents/memory/log.md)
  Edit(.agents/memory/active-work/**) Write(.agents/memory/active-work/**)
  Edit(.agents/memory/.version) Write(.agents/memory/.version)
  Edit(.agents/memory/.gitignore) Write(.agents/memory/.gitignore)
  Bash(git branch --show-current) Bash(git status) Bash(git status -sb)
  Bash(.cursor/hooks/agent-memory-consume-evidence.sh)
  Bash(.claude/hooks/agent-memory-consume-evidence.sh)
  Bash(.codex/hooks/agent-memory-consume-evidence.sh)
  Bash(.opencode/hooks/agent-memory-consume-evidence.sh)
  Bash(.github/hooks/agent-memory-consume-evidence.sh)
  Bash(.gemini/hooks/agent-memory-consume-evidence.sh)
  Bash(hooks/agent-memory-hooks/agent-memory-consume-evidence.sh)
disable-model-invocation: true
---

# agent-memory

Manual-only orchestrator for the local **agent-memory** method. Skeleton and migrations are **vendor-only** (`vendor/memory/`, `vendor/UPDATE.md` next to this `SKILL.md`) — install and migrate from those paths only. Installed copy: `.agents/memory/` with version in `.agents/memory/.version` (newest entry in `vendor/UPDATE.md`).

**Print-only hooks:** `init`, `update`, and `install hooks` print user-run installer instructions; see `references/install-hooks.md`. Act only when the user explicitly invoked `/agent-memory <command>`. Run orchestration in the user's current agent.

## Boundary

Pre-approved tools live in the `allowed-tools` frontmatter ([spec](https://agentskills.io/specification#allowed-tools-field); host-specific / experimental — unsupported hosts ignore it). Names follow Agent Skills / Claude Code; adapt if the host differs.

| Tool                         | Used for                                                                                                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Read`, `Grep`, `Glob`       | Read-only analysis, lint, migration diffs, `references/*`, `vendor/`.                                                                                                    |
| `Task`                       | Parallel read-only subagents in `bootstrap` (optional; sequential fallback).                                                                                             |
| `Edit`, `Write` (scoped)     | Hot path only (`current` / `index` / `log` / `active-work/**` / `.version` / `.gitignore`). Host prompts for decisions/learnings/instructions/carriers/hooks.           |
| `Bash(git …)`                | Read-only `branch --show-current` / `status` / `status -sb`. Host prompts for `git diff` / `git log`. Mutative git stays off.                                            |
| `Bash(…consume-evidence.sh)` | After sync meaning covers pending paths: clear `session_touched_files` only.                                                                                             |

### Write scope

Edit **only** under the memory content paths in `allowed-tools`. Read the rest of the workspace freely.

- **Harness carriers** (files in `references/init.md`): **Never edit harness instruction carriers except** during `/agent-memory init` or `/agent-memory update`, and then **only the agent-memory block** (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain tags; for `.mdc`/`.instructions.md`, frontmatter plus delimited body) — host prompts. Subdirectories inside an existing harness dir (e.g. `.cursor/rules/`, `.github/instructions/`) may be created when wiring natives; create the harness root only on explicit user request.
- **`instructions.md`:** **Never edit `instructions.md` except** during `/agent-memory update` (show the diff; host prompts).
- **Hooks:** print-only — the user-run installer owns `.cursor/hooks/`, `.claude/hooks/`, `.codex/hooks/`, `.opencode/hooks/`, `.opencode/plugins/`, `.github/hooks/`, `.gemini/hooks/`, `hooks.json`, and harness `settings.json`.
- **Project docs / ADRs / app code / other configs:** outside this skill's write surface.

### Confirm

User-authored recall (`current.md`, `active-work/*`, `decisions.md`, `log.md`, `learnings.md`, `learnings-*.md`, legacy `domains/*` / `features/*`) is confirm-before-edit unless the loaded command says otherwise.

**Exception:** primary write in-turn and `bootstrap` follow `instructions.md` directly (gated learnings/decisions when discovered, without this skill's per-entry confirmation). Per-diff confirmation applies to `/agent-memory learn`, `consolidate`, and `lint --fix`.

Durable recall (`decisions.md` / `learnings.md` / `learnings-*.md`) stays on learn / consolidate / gated in-turn — including when following `references/sync.md` without the skill.

### Host fallback

When the host ignores `allowed-tools` granularity, keep the same Boundary: vendor-only skeleton (local skill paths only — no `git clone` / `git fetch` / `git pull` / network fetch for this skill); print-only hooks (print instructions; user runs the installer); `instructions.md` only on `update`; harness carriers only on `init`/`update` (block-only); still **never** write `decisions.md` / `learnings.md` / `learnings-*.md` from `sync` (or when following `references/sync.md` without the skill) — those stay learn / consolidate / gated in-turn only.

### Vendor source

`init` and `update` resolve the skeleton relative to this skill directory:

- Skeleton: `vendor/memory/`
- Migrations: `vendor/UPDATE.md`

Upstream SoT in this repo: `skills/agent-memory/vendor/`.

Project paths are relative to the target project root unless stated otherwise; vendor paths are relative to this skill directory.

## Routing

Read the subcommand from the invocation, load **only** the matching reference, and follow it exactly:

| Command         | Does                                                   | Reference                     |
| --------------- | ------------------------------------------------------ | ----------------------------- |
| `init`          | Scaffold memory; wire carrier; print-only hooks        | `references/init.md`          |
| `install hooks` | Print-only hook installer instructions                 | `references/install-hooks.md` |
| `update`        | Migrate memory; refresh block; print-only hook refresh | `references/update.md`        |
| `bootstrap`     | Inventory sources; pointers, not copies                | `references/bootstrap.md`     |
| `sync`          | Catch-up for current / active-work / log / index       | `references/sync.md`          |
| `lint`          | Structural and consistency checks                      | `references/lint.md`          |
| `consolidate`   | Guided prune/promote (confirm; no `--auto`)            | `references/consolidate.md`   |
| `learn`         | One gated learning (confirm; no `--auto`)              | `references/learn.md`         |
| `help`          | Print the guide below                                  | _Help_ section below          |

If no subcommand is given, or it is not one of those above, run `help` (below) and stop.

For `init`, an optional second token selects one harness (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/init.md` and follow its harness table.

For `install hooks` (or `install hook`), a `<harness>` token is **required** (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/install-hooks.md`.

## Help

For `/agent-memory help` (and for any empty or unknown invocation), output the following Markdown exactly — nothing else:

---

**agent-memory** — a local Workspace Memory that keeps AI agents on the same page.

**Commands**

| Command                       | Does                                                                                                                                                              |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory help`          | Show this guide.                                                                                                                                                  |
| `/agent-memory init`          | Create `.agents/memory/`; auto-detect harnesses and write the native instruction file (`.mdc`, `.instructions.md`, or agent `*.md`), or `init <harness>` for one. |
| `/agent-memory install hooks` | Print how to install or refresh hooks for one harness — `cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini` (memory must exist).                         |
| `/agent-memory bootstrap`     | Inventory canonical sources and gaps (up to 3 subagents); populate pointers — not doc copies.                                                                     |
| `/agent-memory update`        | Migrate memory; refresh agent-memory block in harness instruction files; instruct hook refresh.                                                                   |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. `--auto` applies all diffs without per-file prompts.                                  |
| `/agent-memory lint`          | Check for broken links, orphans, duplication, stale branches, and consistency. `--fix` also deletes stale per-branch `active-work` files.                         |
| `/agent-memory consolidate`   | Promote useful facts and prune closed-session noise (guided; confirm each diff; no `--auto`).                                                                     |
| `/agent-memory learn`         | Capture one gated learning/pitfall (`learn [>topic] <clue>`). Confirm before write; no `--auto`.                                                                  |

**Getting started**

- New project? Run `init` (or `init <harness>` — e.g. `init cursor` if you use Cursor and already have a `.cursor/` directory), then optionally `bootstrap` to index sources (not copy docs). Install hooks with the printed `npx` or shell command, then **re-run `sync`** so blockers/evidence catch up.
- Memory exists but hooks missing or stale? Run `install hooks <harness>` for instructions, or re-run the installer from the release tag, then `/agent-memory sync`. OpenCode: files must be under `.opencode/plugins/` (with `safe-script.ts`); restart OpenCode; state appears on `session.idle` / native `/compact` — not from DCP-only commands (`/dcp-compact`).
- Keeping the memory current? Write resume fields + semantic `log.md` in the turn (primary); run `sync` at checkpoints for catch-up (or follow `references/sync.md` without invoking the skill). Use `sync --auto` for low-friction routine flushes — sync **must consume** pending hook paths when meaning covers them (dirty tree does not skip consume).
- Pruning noise? Run `consolidate` for **closed** sessions (guided; never automatic). Same-day after bootstrap is report-only — do not expect Discard of founding log headings.
- Capture a lesson now? Run `learn [>topic] <clue>` (retention gate; confirm).
- Already set up? Use `lint` to check health (`lint --fix` also removes stale per-branch files), `update` to upgrade memory scaffolding, then refresh hooks with the user-run installer if needed.

Method & conventions: `.agents/memory/instructions.md`

---
