---
name: agent-memory
description: >-
  Orchestrates the local agent-memory Workspace Memory in `.agents/memory/` (a
  recall layer that points at project sources of truth). Use ONLY when the user
  explicitly runs the `/agent-memory` command with a subcommand — `init` (create
  the memory structure; wire the harness-native instruction file — `init`
  auto-detects harnesses from project markers, or `init cursor` / `init claude`
  / `init codex` / `init opencode` / `init copilot` / `init gemini` for one
  harness; prints manual hook-install instructions), `install hooks` (print how
  to install or refresh lifecycle hooks for one harness when memory already
  exists — does not copy scripts), `update` (migrate an existing memory to the
  latest structure without project memory, refresh the agent-memory block in
  harness instruction files, and instruct the user to refresh installed harness
  hooks), `bootstrap` (inventory canonical sources and gaps; populate pointers,
  not doc copies), `sync` (refresh `current.md`, the branch's
  `active-work/<branch>.md`, `log.md`, and `index.md` from repo state; accepts
  `--auto` to apply all proposed diffs without the per-file prompt), `lint`
  (check the memory for broken links, orphans, duplication, and consistency;
  accepts `--fix` to also delete stale per-branch `active-work` files),
  `consolidate` (guided promotion/pruning of closed-session noise — no `--auto`),
  or `help` (list the commands and how to use them). Never trigger automatically;
  this skill must be invoked on demand only.
metadata:
  invocation: manual
  version: "0.0.15"
compatibility: >-
  Works offline from the skill package vendor skeleton. Hook installation is
  user-run (shell script or npx CLI), not performed by this skill.
allowed-tools: >-
  Read Grep Glob Task Edit(.agents/memory/**) Write(.agents/memory/**)
  Edit(AGENTS.md) Edit(CLAUDE.md) Edit(GEMINI.md) Write(AGENTS.md)
  Write(CLAUDE.md) Write(GEMINI.md) Edit(.cursor/rules/agent-memory.mdc)
  Write(.cursor/rules/agent-memory.mdc)
  Edit(.github/instructions/agent-memory.instructions.md)
  Write(.github/instructions/agent-memory.instructions.md)
  Bash(git branch:*) Bash(git status:*) Bash(git diff:*) Bash(git log:*)
disable-model-invocation: true
---

# agent-memory

Manual-only orchestrator for the local **agent-memory** method. The canonical memory skeleton and migration log are **vendored with this skill** under `vendor/` (`vendor/memory/` and `vendor/UPDATE.md`). This skill installs and migrates from there — **no remote clone or fetch**. The installed copy lives at the target project root in `.agents/memory/`, with its version recorded in `.agents/memory/.version` (taken from the newest entry in `vendor/UPDATE.md`).

**Lifecycle hooks are not installed by this skill.** `init`, `update`, and `install hooks` print user-run instructions (shell script or `npx` CLI). See `references/install-hooks.md`.

**Do not act unless the user explicitly invoked `/agent-memory <command>`.** This skill never runs on its own.

## Enabled tools

Pre-approved via the `allowed-tools` frontmatter — a space-separated, host-specific, **experimental** field ([spec](https://agentskills.io/specification#allowed-tools-field)). Hosts that do not support it simply ignore it. Names follow the Agent Skills / Claude Code convention; adapt them if your host differs.

| Tool                     | Used for                                                                                                                                                                                                                    |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Read`, `Grep`, `Glob`   | Read-only project analysis (`bootstrap`), lint structural checks, migration diffs (`update`), reading `references/*.md` and `vendor/`.                                                                                      |
| `Task`                   | Parallel read-only subagents in `bootstrap`. Optional — fall back to sequential analysis.                                                                                                                                   |
| `Edit`, `Write` (scoped) | `.agents/memory/**`, harness instruction files per `references/init.md` (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/rules/agent-memory.mdc`, `.github/instructions/agent-memory.instructions.md`). **Not** hook paths. |
| `Bash(git …)`            | Read-only git used by `sync` / `lint`: `branch`, `status`, `diff`, `log`. **Never** `git clone` / `fetch` / `pull` / `push`.                                                                                                |

**Deliberately not pre-approved** (the host should still prompt): file deletion (`rm`, used only on confirmed `update`/cleanup) and any other shell. This keeps the "confirm sensitive changes" rule intact. The skill never writes harness hook scripts or configs — the user runs the installer.

### Write boundary

Create, edit, or delete **only** under `.agents/memory/**`, plus harness instruction files listed in `references/init.md` (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/rules/agent-memory.mdc`, `.github/instructions/agent-memory.instructions.md`) — and in those **only the agent-memory block** (between `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain tags — to wire it in `init` and refresh it in `update`; for `.mdc`/`.instructions.md`, frontmatter plus delimited body). Creating a **subdirectory** inside an existing harness dir (e.g. `.cursor/rules/`, `.github/instructions/`) is allowed when wiring native instruction files; never create the harness root itself unless the user explicitly requests it. **Never** write under `.cursor/hooks/`, `.claude/hooks/`, `.codex/hooks/`, `.opencode/hooks/`, `.opencode/plugin/`, `.github/hooks/`, `.gemini/hooks/`, or merge `hooks.json` / harness `settings.json` for hooks. Never touch content outside those scopes, application code, other configs, or other docs. Read the rest of the workspace freely.

### Repository source (vendor)

`init` and `update` read the canonical skeleton and migration log **only** from this skill package:

- Skeleton: `vendor/memory/` (next to this `SKILL.md`)
- Migrations: `vendor/UPDATE.md`

Resolve paths relative to the installed skill directory (the folder that contains `SKILL.md`). Do **not** `git clone`, do **not** use `raw.githubusercontent.com`, and do **not** use `WebFetch` for the skeleton.

In the upstream git repository, the skeleton SoT is `skills/agent-memory/vendor/` (next to this skill).

## Routing

Read the subcommand from the invocation, load **only** the matching reference, and follow it exactly:

| Command         | Does                                                                                             | Reference                     |
| --------------- | ------------------------------------------------------------------------------------------------ | ----------------------------- |
| `init`          | Create `.agents/memory/`; wire harness-native instruction file; print hook-install instructions. | `references/init.md`          |
| `install hooks` | Print how to install or refresh lifecycle hooks for one harness (user-run installer).            | `references/install-hooks.md` |
| `update`        | Migrate memory; refresh agent-memory block; instruct user to refresh installed hooks.            | `references/update.md`        |
| `bootstrap`     | Inventory canonical sources and gaps; populate pointers (not doc copies).                        | `references/bootstrap.md`     |
| `sync`          | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state.                      | `references/sync.md`          |
| `lint`          | Check the memory for structural and consistency problems.                                        | `references/lint.md`          |
| `consolidate`   | Guided promotion/pruning of closed-session noise (confirm each diff; no `--auto`).               | `references/consolidate.md`   |
| `help`          | List the commands and how to use them.                                                           | _Help_ section below          |

If no subcommand is given, or it is not one of those above, run `help` (below) and stop. Do not guess the user's intent.

For `init`, an optional second token selects one harness (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/init.md` and follow its harness table.

For `install hooks` (or `install hook`), a `<harness>` token is **required** (`cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini`). Load `references/install-hooks.md`.

## Help

For `/agent-memory help` (and for any empty or unknown invocation), output the following Markdown exactly — nothing else:

---

**agent-memory** — a local Workspace Memory that keeps AI agents on the same page.

**Commands**

| Command                       | Does                                                                                                                                                              |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agent-memory init`          | Create `.agents/memory/`; auto-detect harnesses and write the native instruction file (`.mdc`, `.instructions.md`, or agent `*.md`), or `init <harness>` for one. |
| `/agent-memory install hooks` | Print how to install or refresh hooks for one harness — `cursor`, `claude`, `codex`, `opencode`, `copilot`, `gemini` (memory must exist).                         |
| `/agent-memory bootstrap`     | Inventory canonical sources and gaps (up to 3 subagents); populate pointers — not doc copies.                                                                     |
| `/agent-memory update`        | Migrate memory; refresh agent-memory block in harness instruction files; instruct hook refresh.                                                                   |
| `/agent-memory sync`          | Refresh `current.md` / active-work / `log.md` / `index.md` from repo state. `--auto` applies all diffs without per-file prompts.                                  |
| `/agent-memory lint`          | Check for broken links, orphans, duplication, stale branches, and consistency. `--fix` also deletes stale per-branch `active-work` files.                         |
| `/agent-memory consolidate`   | Promote useful facts and prune closed-session noise (guided; confirm each diff; no `--auto`).                                                                     |
| `/agent-memory help`          | Show this guide.                                                                                                                                                  |

**Getting started**

- New project? Run `init` (or `init <harness>` — e.g. `init cursor` if you use Cursor and already have a `.cursor/` directory), then optionally `bootstrap` to index sources (not copy docs). Install hooks with the printed `npx` or shell command.
- Memory exists but hooks missing or stale? Run `install hooks <harness>` for instructions, or re-run the installer from the release tag.
- Keeping the memory current? Write resume fields + semantic `log.md` in the turn (primary); run `sync` at checkpoints for catch-up (or follow `references/sync.md` without invoking the skill). Use `sync --auto` for low-friction routine flushes.
- Pruning noise? Run `consolidate` periodically (guided; never automatic).
- Already set up? Use `lint` to check health (`lint --fix` also removes stale per-branch files), `update` to upgrade memory scaffolding, then refresh hooks with the user-run installer if needed.

Method & conventions: `.agents/memory/instructions.md`

---

## Shared rules (apply to every command)

- **Never modify project memory content** — `current.md`, `active-work/*`, `decisions.md`, `log.md`, `learnings.md`, legacy `domains/*` / `features/*`, and other user-authored recall — unless a command explicitly says so, and only after the user confirms. Never edit project docs/ADRs outside `.agents/memory/`.
- Run memory/orchestration steps inside the user's current agent. **Do not download, clone, or execute hook installers** — only print instructions for the user to run.
- If the host ignores `allowed-tools` granularity: still **never** run `git clone`, `git fetch`, `git pull`, or any network fetch for this skill.
- All paths are relative to the target project root unless stated otherwise (vendor paths are relative to this skill directory).
