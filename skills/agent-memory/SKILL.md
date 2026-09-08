---
name: agent-memory
description: >-
  Manual orchestrator for Workspace Memory in `.agents/memory/` — invoke only
  via `/agent-memory <command>`.
metadata:
  invocation: manual
  version: "0.2.1-rc.7"
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
  Edit(AGENTS.md) Write(AGENTS.md)
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
  Bash(.agents/skills/agent-memory/scripts/lint-structural-from-memory.sh)
  Bash(.agents/skills/agent-memory/scripts/lint-structural-from-root.sh)
  Bash(skills/agent-memory/scripts/lint-structural-from-memory.sh)
  Bash(skills/agent-memory/scripts/lint-structural-from-root.sh)
disable-model-invocation: true
---

# agent-memory

Manual-only orchestrator for Workspace Memory. Skeleton and migrations are **vendor-only** (`vendor/memory/`, `vendor/UPDATE.md` beside this file). Installed copy: `.agents/memory/` (`.version` = this skill's `metadata.version`; last `## <version>` in `vendor/UPDATE.md` must match).

Run the loaded command in this agent. Hooks are print-only (`references/install-hooks.md`); `update` prints installer commands only when the stamp is stale.

## Boundary

`allowed-tools` is host-specific ([spec](https://agentskills.io/specification#allowed-tools-field)). The loaded reference is the write list when the host ignores the frontmatter.

| Tool                         | Used for                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Read`, `Grep`, `Glob`       | Analysis, `references/*`, `vendor/`, `scripts/`.                                                                                                                                                                                                                                                                                              |
| `Task`                       | Optional read-only `bootstrap` subagents.                                                                                                                                                                                                                                                                                                     |
| `Edit`, `Write`              | Frontmatter paths. Sync: `current` / `index` / `log` / `active-work` / `.version` / `.gitignore`. Update also: `decisions.md` and mirrors in `references/update-graph.md`. Init/update/consolidate: `AGENTS.md` **docs map** (`references/docs-map.md`, outside the block). Init/update: delimited agent-memory block (tokens `instructions` / `agents.md` / `rules` write `AGENTS.md` only). Host prompts: learnings, `instructions.md`, other carriers, hooks. |
| `Bash(git …)`                | Exact `branch --show-current` / `status` / `status -sb`.                                                                                                                                                                                                                                                                                      |
| `Bash(…consume-evidence.sh)` | Clear `session_touched_files` after covering sync.                                                                                                                                                                                                                                                                                            |
| `Bash(…print-evidence.sh)`   | Allowlisted hook fields (stdout only).                                                                                                                                                                                                                                                                                                        |
| `Bash(…lint-structural-from-*.sh)` | `/agent-memory lint` structural emitters (`references/lint-structural.md`).                                                                                                                         |

### Write scope

Edit the `allowed-tools` memory paths. Read the rest of the workspace.

- **Harness carriers** (files in `references/init.md`): **Never edit harness instruction carriers except** (1) `/agent-memory init` or `/agent-memory update` — **only the agent-memory block** (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain tags; for `.mdc`/`.instructions.md`, frontmatter plus delimited body; tokens `instructions` / `agents.md` / `rules` write **`AGENTS.md` only**), or (2) `/agent-memory consolidate` to **delete a redundant copy** of that block (`double-injection:` / `delegation-canary:` — confirm). On `init` / `update` / `consolidate`, also patch the `AGENTS.md` **docs map** outside that block (`references/docs-map.md`). Create a harness root only on explicit user request; subdirs inside an existing harness dir are allowed when wiring natives.
- **`instructions.md`:** **Never edit `instructions.md` except** during `/agent-memory update` (show the diff; host prompts).
- **Hooks:** print-only — the user-run installer owns hook dirs, `hooks.json`, and harness `settings.json`.
- **Update mirrors:** after deleting leftover mirrors (`references/update-graph.md`), leave their docs links on `AGENTS.md`. Leave app code and ADR/spec **bodies** as they are.

### Confirm

User-authored recall is confirm-before-edit unless the loaded command says otherwise.

**Exception:** primary write in-turn and `bootstrap` follow `instructions.md` directly (gated learnings/decisions when discovered, without this skill's per-entry confirmation). Write-floor **User constraint** supersedes a live `decisions.md` entry in place. Write-floor **Reusable lesson** appends a new H2 (Duplicate rule skip writes nothing). Per-diff confirmation: `learn`, `consolidate`, `lint --fix` / `lint fix`, `update` graph reshape, `init`/`update` AGENTS.md block tokens.

Sync writes `current` / `active-work` / `log` / `index` (recall links, not a docs catalog). `update` may insert `Status: live` on existing decision headings, delete mirrors, and patch the `AGENTS.md` docs map. Learnings stay on learn / consolidate / gated in-turn.

### Host fallback

When the host ignores `allowed-tools`, Write scope still holds. Extra: vendor-only skeleton (local skill paths; no network fetch); print-only hooks. Sync still **never** write `decisions.md` / `learnings.md` / `learnings-*.md` (including when following `references/sync.md` without the skill command).

### Vendor source

`init` and `update` resolve the skeleton relative to this skill directory:

- Skeleton: `vendor/memory/`
- Active-work copy scaffold: `references/active-work-template.md` (not installed into project memory)
- Migrations: `vendor/UPDATE.md`

Upstream SoT in this repo: `skills/agent-memory/vendor/`.

Project paths are relative to the target project root unless stated otherwise; vendor paths are relative to this skill directory.

## Routing

Read the subcommand from the invocation, load **only** the matching reference, and follow it exactly:

| Command         | Does                                                                                           | Reference                     |
| --------------- | ---------------------------------------------------------------------------------------------- | ----------------------------- |
| `init`          | Scaffold memory; wire carrier; `instructions`/`agents.md`/`rules` → `AGENTS.md` block; patch AGENTS docs map; print-only hooks | `references/init.md`                 |
| `install hooks` | Print-only hook installer instructions                                                         | `references/install-hooks.md`        |
| `update`        | Migrate scaffolding; `instructions`/`agents.md`/`rules` → `AGENTS.md` block only; delete leftover mirrors; refresh block; AGENTS docs map; hook stamp check | `references/update.md`        |
| `bootstrap`     | Inventory sources; pointers, not copies                                                        | `references/bootstrap.md`     |
| `sync`          | Catch-up for current / active-work / log / index                                               | `references/sync.md`          |
| `lint`          | Six-pass health (consistency, dead paths, typos, contradictions, cold-session quality, hooks)  | `references/lint.md`          |
| `consolidate`   | Pass A Apply; same-run slim if `decisions.md` non-empty > 200; redundant block delete; Pass B prior-day Trim; confirm; no `--auto` / `auto` | `references/consolidate.md`   |
| `learn`         | One gated learning (confirm; no `--auto` / `auto`)                                             | `references/learn.md`         |
| `help`          | Print the guide below                                                                          | _Help_ section below          |

If no subcommand is given, or it is not one of those above, run `help` (below) and stop.

When the loaded command finishes, its **Report** is done. Last assistant line: `Memory: skip` (skill writes are not a write-floor row).

For `init`, an optional second token selects one harness (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`) **or** an AGENTS.md block token (`instructions`, `agents.md`, `rules` — `references/init.md` → **AGENTS.md block**). Load `references/init.md`.

For `install hooks` (or `install hook`), a `<harness>` token is **required** (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/install-hooks.md`.

For `update`, an optional second token that is an AGENTS.md block token (`instructions`, `agents.md`, `rules`) loads `references/update.md` and takes the **AGENTS.md block** path only.

**Flag tokens:** a leading `--` is optional, not forbidden. `--fix` and `fix` are the same; `--auto` and `auto` are the same; `--force` and `force` are the same. `learn` and `consolidate` reject both `--auto` and `auto`.

## Help

For `/agent-memory help` (and for any empty or unknown invocation), output the following Markdown exactly — nothing else:

---

**agent-memory** — local Workspace Memory.

**Commands**

| Command                       | Does                                                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory help`          | Show this guide.                                                                                                                                                    |
| `/agent-memory init`          | Create `.agents/memory/`; auto-detect harnesses and write the native instruction file (`.mdc`, `.instructions.md`, or agent `*.md`), or `init <harness>` for one (re-wires that native if memory already exists). `init instructions` / `init agents.md` / `init rules` insert or refresh the block in `AGENTS.md`.   |
| `/agent-memory install hooks` | Print how to install or refresh hooks for one harness — `cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini` (memory must exist).                           |
| `/agent-memory bootstrap`     | Inventory canonical sources and gaps (up to 3 subagents); populate pointers — not doc copies.                                                                       |
| `/agent-memory update`        | Migrate scaffolding; delete leftover mirrors; refresh the harness block; patch the AGENTS.md docs map; print hook installer commands only when stamps are stale. `update instructions` / `update agents.md` / `update rules` insert or refresh the block in `AGENTS.md` only.    |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. `--auto` / `auto` applies all diffs without per-file prompts.                                    |
| `/agent-memory lint`          | Check consistency, dead paths, typos, instruction contradictions, cold-session quality, and hook wiring. `--fix` / `fix` also deletes stale per-branch `active-work` files and closed-placeholder resumes (not the current git branch), refreshes Checkpoint, and trims Progress / Validation >5. |
| `/agent-memory consolidate`   | Pass A (decisions/index/learnings/redundant harness block) even when Pass B log prune is empty; default Apply; if `decisions.md` non-empty stays >200, keep collapsing live wiki bodies in the same run (Report `decisions.md non-empty N (budget 200)`); prior-day log Trim (not Retain); confirm each diff; no `--auto` / `auto`. `lint --fix` / `lint fix` and `sync` do not replace this. |
| `/agent-memory learn`         | Capture one gated learning/pitfall (`learn [>topic] <clue>`). Confirm before write; no `--auto` / `auto`.                                                                    |

**Getting started**

- New project? `init` (or `init <harness>` — e.g. `init cursor` when `.cursor/` already exists), then optional `bootstrap` (pointers, not doc copies). Install hooks with the printed command. Then **one** `sync` so Status catches up.
- Block gone from `AGENTS.md`? `update instructions` (or `init instructions` / `agents.md` / `rules`). Hooks missing or stale? `install hooks <harness>`, or re-run the installer from the release tag. OpenCode: files under `.opencode/plugins/` (with `safe-script.ts`); restart; state on `session.idle` / native `/compact` — not DCP-only (`/dcp-compact`).
- Daily write lives in `.agents/memory/instructions.md` (write floor; skip when all no; **cold session** four questions; Validation is the **done signal**). `sync` when Status is stale **and** there is meaning (`sync --auto` / `sync auto` for routine flushes; **must consume** pending paths when meaning covers them). `learn [>topic] <clue>` only for explicit capture. `consolidate` to slim (Pass A always; Report `decisions.md non-empty N (budget 200)`; same-day after bootstrap is report-only for Pass B; `lint --fix` / `lint fix` and `sync` do not slim `decisions.md`). `lint` for health; `update` for scaffolding and leftover `vision.md` / `domains/*` mirrors (docs stay on `AGENTS.md`). Hook installer commands print only when `$hooksDir/.version` is missing, differs from this skill, or scripts are incomplete.

Method & conventions: `.agents/memory/instructions.md`
