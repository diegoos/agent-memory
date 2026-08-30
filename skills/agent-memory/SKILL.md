---
name: agent-memory
description: >-
  Manual orchestrator for Workspace Memory in `.agents/memory/` — invoke only
  via `/agent-memory <command>`.
metadata:
  invocation: manual
  version: "0.2.1-rc.0"
compatibility: >-
  Works offline from the skill package vendor skeleton. Hook installation is
  print-only (user-run shell script or npx CLI).
allowed-tools: >-
  Read Grep Glob Task
  Edit(.agents/memory/current.md) Write(.agents/memory/current.md)
  Edit(.agents/memory/index.md) Write(.agents/memory/index.md)
  Edit(.agents/memory/log.md) Write(.agents/memory/log.md)
  Edit(.agents/memory/decisions.md) Write(.agents/memory/decisions.md)
  Edit(.agents/memory/active-work/**) Write(.agents/memory/active-work/**)
  Edit(.agents/memory/vision.md) Write(.agents/memory/vision.md)
  Edit(.agents/memory/architecture.md) Write(.agents/memory/architecture.md)
  Edit(.agents/memory/patterns.md) Write(.agents/memory/patterns.md)
  Edit(.agents/memory/project.md) Write(.agents/memory/project.md)
  Edit(.agents/memory/domains/**) Write(.agents/memory/domains/**)
  Edit(.agents/memory/features/**) Write(.agents/memory/features/**)
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
  Bash(.cursor/hooks/agent-memory-print-evidence.sh)
  Bash(.claude/hooks/agent-memory-print-evidence.sh)
  Bash(.codex/hooks/agent-memory-print-evidence.sh)
  Bash(.opencode/hooks/agent-memory-print-evidence.sh)
  Bash(.github/hooks/agent-memory-print-evidence.sh)
  Bash(.gemini/hooks/agent-memory-print-evidence.sh)
  Bash(hooks/agent-memory-hooks/agent-memory-print-evidence.sh)
disable-model-invocation: true
---

# agent-memory

Manual-only orchestrator for Workspace Memory. Skeleton and migrations are **vendor-only** (`vendor/memory/`, `vendor/UPDATE.md` beside this file). Installed copy: `.agents/memory/` (`.version` = newest `vendor/UPDATE.md` heading).

**Print-only hooks:** `init`, `update`, and `install hooks` print installer commands (`references/install-hooks.md`). Run the loaded command in this agent.

## Boundary

`allowed-tools` is host-specific ([spec](https://agentskills.io/specification#allowed-tools-field)). The loaded reference is the write list when the host ignores the frontmatter.

| Tool                         | Used for                                                                                                                                                                                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Read`, `Grep`, `Glob`       | Analysis, `references/*`, `vendor/`.                                                                                                                                                                                                    |
| `Task`                       | Optional read-only `bootstrap` subagents.                                                                                                                                                                                               |
| `Edit`, `Write`              | Frontmatter paths. Sync: `current` / `index` / `log` / `active-work` / `.version` / `.gitignore`. Update also: `decisions.md` and mirrors in `references/update-graph.md`. Host prompts: learnings, `instructions.md`, carriers, hooks. |
| `Bash(git …)`                | Exact `branch --show-current` / `status` / `status -sb`.                                                                                                                                                                                |
| `Bash(…consume-evidence.sh)` | Clear `session_touched_files` after covering sync.                                                                                                                                                                                      |
| `Bash(…print-evidence.sh)`   | Allowlisted hook fields (stdout). Skip `.hook-sync-state`.                                                                                                                                                                              |

### Write scope

Edit the `allowed-tools` memory paths. Read the rest of the workspace.

- **Harness carriers** (files in `references/init.md`): **Never edit harness instruction carriers except** during `/agent-memory init` or `/agent-memory update`, and then **only the agent-memory block** (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain tags; for `.mdc`/`.instructions.md`, frontmatter plus delimited body) — host prompts. Create a harness root only on explicit user request; subdirs inside an existing harness dir are allowed when wiring natives.
- **`instructions.md`:** **Never edit `instructions.md` except** during `/agent-memory update` (show the diff; host prompts).
- **Hooks:** print-only — the user-run installer owns hook dirs, `hooks.json`, and harness `settings.json`.
- **Update mirrors:** after folding links into `index.md`, delete the paths named in `references/update-graph.md`. Leave app code, ADRs, and project docs as they are.

### Confirm

User-authored recall is confirm-before-edit unless the loaded command says otherwise.

**Exception:** primary write in-turn and `bootstrap` follow `instructions.md` directly (gated learnings/decisions when discovered, without this skill's per-entry confirmation). Write-floor **User constraint** supersedes a live `decisions.md` entry in place. Write-floor **Reusable lesson** appends a new H2 (Duplicate rule skip writes nothing). Per-diff confirmation: `learn`, `consolidate`, `lint --fix`, `update` graph reshape.

Sync writes `current` / `active-work` / `log` / `index`. `update` may insert `Status: live` on existing decision headings and delete mirrors. Learnings stay on learn / consolidate / gated in-turn.

### Host fallback

Same Boundary when the host ignores `allowed-tools`: vendor-only skeleton (local skill paths; no network fetch for this skill); print-only hooks; `instructions.md` only on `update`; carriers only on `init`/`update` (block-only); still **never** write `decisions.md` / `learnings.md` / `learnings-*.md` from `sync` (or when following `references/sync.md` without the skill). **`update` graph reshape** may delete mirrors and insert `Status: live` on existing decision headings.

### Vendor source

`init` and `update` resolve the skeleton relative to this skill directory:

- Skeleton: `vendor/memory/`
- Active-work copy scaffold: `references/active-work-template.md` (not installed into project memory)
- Migrations: `vendor/UPDATE.md`

Upstream SoT in this repo: `skills/agent-memory/vendor/`.

Project paths are relative to the target project root unless stated otherwise; vendor paths are relative to this skill directory.

## Routing

Read the subcommand from the invocation, load **only** the matching reference, and follow it exactly:

| Command         | Does                                                                                                      | Reference                     |
| --------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `init`          | Scaffold memory; wire carrier; print-only hooks                                                           | `references/init.md`          |
| `install hooks` | Print-only hook installer instructions                                                                    | `references/install-hooks.md` |
| `update`        | Migrate scaffolding; collapse legacy mirrors into the index graph; refresh block; print-only hook refresh | `references/update.md`        |
| `bootstrap`     | Inventory sources; pointers, not copies                                                                   | `references/bootstrap.md`     |
| `sync`          | Catch-up for current / active-work / log / index                                                          | `references/sync.md`          |
| `lint`          | Six-pass health (consistency, dead paths, typos, contradictions, cold-session quality, hooks)             | `references/lint.md`          |
| `consolidate`   | Guided prune/promote (confirm; no `--auto`)                                                               | `references/consolidate.md`   |
| `learn`         | One gated learning (confirm; no `--auto`)                                                                 | `references/learn.md`         |
| `help`          | Print the guide below                                                                                     | _Help_ section below          |

If no subcommand is given, or it is not one of those above, run `help` (below) and stop.

For `init`, an optional second token selects one harness (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/init.md` and follow its harness table.

For `install hooks` (or `install hook`), a `<harness>` token is **required** (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/install-hooks.md`.

## Help

For `/agent-memory help` (and for any empty or unknown invocation), output the following Markdown exactly — nothing else:

---

**agent-memory** — a local Workspace Memory that keeps AI agents on the same page.

**Commands**

| Command                       | Does                                                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory help`          | Show this guide.                                                                                                                                                    |
| `/agent-memory init`          | Create `.agents/memory/`; auto-detect harnesses and write the native instruction file (`.mdc`, `.instructions.md`, or agent `*.md`), or `init <harness>` for one.   |
| `/agent-memory install hooks` | Print how to install or refresh hooks for one harness — `cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini` (memory must exist).                           |
| `/agent-memory bootstrap`     | Inventory canonical sources and gaps (up to 3 subagents); populate pointers — not doc copies.                                                                       |
| `/agent-memory update`        | Migrate scaffolding; collapse legacy mirrors into the index graph; refresh the harness block; instruct hook refresh.                                                |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. `--auto` applies all diffs without per-file prompts.                                    |
| `/agent-memory lint`          | Check consistency, dead paths, typos, instruction contradictions, cold-session quality, and hook wiring. `--fix` also deletes stale per-branch `active-work` files. |
| `/agent-memory consolidate`   | Promote useful facts and prune closed-session noise (guided; confirm each diff; no `--auto`).                                                                       |
| `/agent-memory learn`         | Capture one gated learning/pitfall (`learn [>topic] <clue>`). Confirm before write; no `--auto`.                                                                    |

**Getting started**

- New project? Run `init` (or `init <harness>` — e.g. `init cursor` if you use Cursor and already have a `.cursor/` directory), then optionally `bootstrap` to index sources (not copy docs). Install hooks with the printed `npx` or shell command. Then run **one** `sync` so Status and shared blockers catch up. After that, skip is the default when the write floor is all no.
- Memory exists but hooks missing or stale? Run `install hooks <harness>` for instructions, or re-run the installer from the release tag. Run `/agent-memory sync` once if Status is stale **and** there is meaning. OpenCode: files must be under `.opencode/plugins/` (with `safe-script.ts`); restart OpenCode; state appears on `session.idle` / native `/compact` — not from DCP-only commands (`/dcp-compact`).
- Keeping the memory current? Follow session Status (`load:` / Next / Checkpoint). Skip when the write floor is all no. Write **one** file when a floor row is yes (rotten resume → active-work; user constraint → `decisions.md` and supersede the old live entry; reusable lesson → learnings + index `when editing:` when there is an incident and 1–3 paths; closed why missing from the commit → `log.md`; shared blocker → `current.md`). Optional `## Hold` on active-work (max 3 bullets) is still that file. Run `sync` only when hook Status is stale **and** there is meaning (or follow `references/sync.md` without invoking the skill). Use `sync --auto` for low-friction flushes — sync **must consume** pending hook paths when meaning covers them (dirty tree does not skip consume).
- Pruning noise? Run `consolidate` for **closed** sessions (guided; never automatic). Same-day after bootstrap is report-only — do not expect Discard of founding log headings.
- Capture a lesson now? In-turn write-floor **Reusable lesson** (incident + 1–3 paths + index hint) is the daily path. Run `learn [>topic] <clue>` only for explicit capture (retention gate; confirm).
- Already set up? Use `lint` to check health (`lint --fix` also removes stale per-branch files), `update` to upgrade scaffolding **and** collapse leftover `vision.md` / `domains/*` mirrors into `index.md`, then refresh hooks with the user-run installer if needed.

Method & conventions: `.agents/memory/instructions.md`
