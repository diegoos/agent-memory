# agent-memory — agent hooks (optional)

Optional hooks that keep agent-memory current during real work. They run a
**deterministic git checkpoint** — no LLM call, no `followup_message` loops:

- **`sessionStart` / NewSession** — session ID, `current.md` _In progress_ from
  `active-work/`, ensure active-work file + `log.md` session heading
- **`postToolUse` / `afterFileEdit` (Cursor)** — accumulate _Touched files_ from
  harness stdin paths (git-free; no `log.md` bullets)
- **`afterAgentResponse` / end-of-turn / compact / pre-commit** — full git
  reconciliation: session-cumulative _Touched files_ + new file bullets under
  the current `log.md` session heading

**Still manual (agent or `/agent-memory sync`):** semantic `log.md` bullets and
summary/type, `decisions.md` (required when decisions change), active-work
Progress/Blockers/Notes, `current.md` _Done_ / _Next steps_, `index.md` lazy
links, `architecture.md`, `patterns.md`, `vision.md` (ask user if uncertain).

## TL;DR

Install with the user-run installer (review first):

```bash
npx @dosx/agent-memory install hooks <harness>
# or: bash hooks/install-hooks.sh <harness>
```

The installer creates the harness directory (e.g. `.cursor/`) if it is missing.
It refuses destination or parent-directory symlinks and requires an existing
`PROJECT_DIR` (resolved with `realpath`). Set `AGENT_MEMORY_PROJECT_DIR` to
install into a project other than the current working directory.

| Host            | Scripts                                                                 | Config                                  |
| --------------- | ----------------------------------------------------------------------- | --------------------------------------- |
| **Any agent**   | `hooks/agent-memory-hooks/*.sh` → `.git/hooks/` (with `git/pre-commit`) | `hooks/git/pre-commit`                  |
| **Cursor**      | → `.cursor/hooks/`                                                      | merge `hooks/cursor/hooks.json`         |
| **Claude Code** | → `.claude/hooks/`                                                      | merge `hooks/claude-code/settings.json` |
| **Codex**       | → `.codex/hooks/`                                                       | merge `hooks/codex/hooks.json`          |
| **Copilot**     | → `.github/hooks/`                                                      | `hooks/copilot/agent-memory.json`       |
| **OpenCode**    | plugin → `.opencode/hooks/*.sh`                                         | `.opencode/plugin/agent-memory.ts`      |
| **Gemini CLI**  | → `.gemini/hooks/`                                                      | merge `.gemini/settings.json`           |

`/agent-memory init <harness>` wires the **context** layer when the harness
directory already exists; it **prints** hook-install commands and does not copy
scripts.

**Cursor:** `init cursor` wires `.cursor/rules/agent-memory.mdc`
(`alwaysApply: true`) as the **context layer**. Install hooks separately as the
**checkpoint layer**. `@import` in `AGENTS.md` is a no-op and `AGENTS.md` may
not auto-inject, so the `.mdc` is the reliable context path. See root
`README.md`.

## Events (all hosts)

| Checkpoint     | Cursor                        | Claude / Codex | Copilot        | Gemini CLI     | OpenCode       |
| -------------- | ----------------------------- | -------------- | -------------- | -------------- | -------------- |
| Session start  | `sessionStart`                | `SessionStart` | `sessionStart` | `SessionStart` | —              |
| After Write    | `postToolUse` (`Write`)       | `PostToolUse`  | `postToolUse`  | `AfterTool`    | —              |
| After Edit     | `afterFileEdit`               | `PostToolUse`  | `postToolUse`  | `AfterTool`    | —              |
| End of turn    | `afterAgentResponse`          | `Stop`         | `agentStop`    | `AfterAgent`   | `session.idle` |
| Before compact | `preCompact`                  | `PreCompact`   | `preCompact`   | `PreCompress`  | `compacting`   |
| Git commit     | `precommit` (pre-commit hook) | same           | same           | same           | same           |

**Cursor `postToolUse` matchers** (per
[Cursor hooks docs](https://cursor.com/docs/hooks)): `Write`, `Shell`. Agent
**edits** (StrReplace) fire **`afterFileEdit`** instead — top-level `file_path`
on stdin, not `tool_input.file_path`.

**Copilot / Gemini matchers:** `edit`, `write`, `apply_patch` (Copilot);
`write_file`, `edit`, `shell`, `bash`, `apply_patch` (Gemini). Copilot may send
`tool_input.path` instead of `file_path` — parsed by shared helpers.

**Codex:** `PostToolUse` matches `Bash|apply_patch` only; file paths from
`apply_patch` may be absent on stdin — end-of-turn git reconciliation covers
gaps.

**Not used on Cursor:** `stop` + `followup_message` (always starts another LLM
turn).

## Layout

```text
hooks/
├── install-hooks.sh              # user-run installer (also used by npx CLI)
├── agent-memory-hooks/
│   ├── agent-memory-common.sh    # shared helpers (sourced by sync + session)
│   ├── agent-memory-sync.sh      # checkpoint after tools / end of turn
│   └── agent-memory-session.sh   # sessionStart / NewSession
├── cursor/hooks.json
├── claude-code/settings.json
├── codex/hooks.json
├── codex/config.toml.snippet   # manual alternate only — not applied by installer
├── copilot/agent-memory.json
├── opencode/agent-memory.ts
├── gemini/settings.json
└── git/pre-commit
```

## Requirements

- `git` on `$PATH`
- POSIX `sh` / `bash` for command hooks
- OpenCode: Bun plugin loader

## Install (per project)

**Preferred:** run the installer from the project root (needs Node for JSON
merges):

```bash
npx @dosx/agent-memory install hooks cursor
```

Or from a checkout of the same tag:

```bash
bash hooks/install-hooks.sh cursor
```

The installer copies **all three** files from `hooks/agent-memory-hooks/` into
the harness hooks directory (`agent-memory-common.sh` must sit beside the other
two — sync/session source it). **Never copy only sync + session** — partial
installs fail at runtime (sync/session print a stderr hint and exit 0 so the
harness is not blocked). Re-run the installer when hook scripts change.

Manual copy examples (if you prefer not to use the installer):

### Cursor (recommended)

```bash
mkdir -p .cursor/hooks
cp hooks/agent-memory-hooks/agent-memory-*.sh .cursor/hooks/
chmod +x .cursor/hooks/agent-memory-*.sh
# merge hooks/cursor/hooks.json into .cursor/hooks.json
```

### Claude Code

```bash
mkdir -p .claude/hooks
cp hooks/agent-memory-hooks/agent-memory-*.sh .claude/hooks/
chmod +x .claude/hooks/agent-memory-*.sh
# merge hooks/claude-code/settings.json into .claude/settings.json
```

### Codex

```bash
mkdir -p .codex/hooks
cp hooks/agent-memory-hooks/agent-memory-*.sh .codex/hooks/
chmod +x .codex/hooks/agent-memory-*.sh
# merge hooks/codex/hooks.json into .codex/hooks.json
# then run /hooks in the Codex TUI to trust project hooks
```

`codex/config.toml.snippet` is a **manual alternate** for TOML-based wiring —
the installer only merges `hooks/codex/hooks.json` and does not apply the
snippet.

### Copilot (CLI + cloud agent)

```bash
mkdir -p .github/hooks
cp hooks/agent-memory-hooks/agent-memory-*.sh .github/hooks/
chmod +x .github/hooks/agent-memory-*.sh
cp hooks/copilot/agent-memory.json .github/hooks/agent-memory.json
```

### OpenCode

```bash
mkdir -p .opencode/hooks .opencode/plugin
cp hooks/agent-memory-hooks/agent-memory-*.sh .opencode/hooks/
chmod +x .opencode/hooks/agent-memory-*.sh
cp hooks/opencode/agent-memory.ts .opencode/plugin/agent-memory.ts
```

The TypeScript plugin spawns the same shell scripts on `session.idle` and
`experimental.session.compacting` — see [OpenCode vs hooks](#opencode-vs-hooks)
below.

### Git (host-agnostic baseline)

```bash
cp hooks/git/pre-commit .git/hooks/pre-commit
cp hooks/agent-memory-hooks/agent-memory-*.sh .git/hooks/
chmod +x .git/hooks/pre-commit .git/hooks/agent-memory-*.sh
```

## Verifying

- Cursor: **Hooks** settings tab / **Hooks** output channel; restart if needed.
- Claude Code: `/hooks` shows configured hooks.
- Codex: `/hooks` in the TUI to inspect and trust.
- OpenCode: plugin loads at startup; sync script must exist at
  `.opencode/hooks/`.
- Git: `sh .git/hooks/pre-commit` with staged non-memory changes.

## Safe write scope

Canonical **memory contract** (hooks vs agent, all harnesses): `instructions.md`
→ _Harness parity — memory contract_. The table below is a summary; do not drift
from the contract.

| Field                         | Hook updates?                                |
| ----------------------------- | -------------------------------------------- |
| `active-work` → Touched files | Yes (session-cumulative; git + stdin paths)  |
| `active-work` → Task stub     | Yes (from branch name when placeholder)      |
| `log.md` → session heading    | Yes (session start or first checkpoint)      |
| `log.md` → file bullets       | Yes (full checkpoints only — from `git`)     |
| `log.md` → semantic bullets   | **No** — agent or `/agent-memory sync`       |
| `current.md` → In progress    | Yes (on session start from `active-work/`)   |
| `current.md` → Done / Next    | **No** — agent or `/agent-memory sync`       |
| `decisions.md`                | **No** — agent (required on decision change) |
| `.hook-sync-state`            | Yes (session ID, logged/touched paths, etc.) |

### Log format

One heading per session; hooks + agent append bullets:

```md
## [2026-06-30] [effad5d5-…] [chore] session work

- changed 12 files (see active-work Touched files)
- fixed rate-limit edge case in auth middleware
```

When more than eight new paths land in one full checkpoint, hooks write the
summary line above instead of individual ``- `path` `` bullets. Semantic context
always comes from the agent. After a summary, later small batches in the same
session do not append stray path-only bullets.

Session ID from `AGENT_MEMORY_SESSION_ID` (set by `agent-memory-session.sh` when
the harness sends `session_id` on stdin). See `instructions.md` and `log.md`.

State is tracked in `.agents/memory/.hook-sync-state`. Listed in the skeleton
`.gitignore` and should not be committed.

## Harness-agnostic resolution

Scripts never assume a single harness. Shared helpers in
`agent-memory-common.sh` resolve context in this order:

**Project directory** (`resolve_project_dir`):

1. `AGENT_MEMORY_PROJECT_DIR` (generic — git pre-commit, OpenCode plugin)
2. `CURSOR_PROJECT_DIR` (Cursor hooks)
3. `CLAUDE_PROJECT_DIR` (Claude Code hooks)
4. `CODEX_PROJECT_DIR` (Codex hooks)
5. `GITHUB_WORKSPACE` (CI / Copilot cloud)
6. `GEMINI_PROJECT_DIR` (Gemini CLI)
7. `cwd` or `workspace_roots[0]` from hook stdin JSON
8. `$PWD`

**Session ID** (`resolve_session_id`):

1. `AGENT_MEMORY_SESSION_ID` — set by `sessionStart` via hook `env` output
   (Cursor, Claude, Copilot) or export (Codex, OpenCode plugin)
2. `CURSOR_SESSION_ID` — interop fallback (not Cursor-native; third-party hooks
   may export it via sessionStart env output)
3. `GEMINI_SESSION_ID` (Gemini CLI)
4. `session_id`, `conversation_id`, or `sessionId` from hook stdin JSON (Cursor,
   Claude, Copilot, Codex, Gemini on every lifecycle event)
5. `current_session_id` in `.hook-sync-state` (last sessionStart)

Cursor `afterAgentResponse` omits `session_id` on stdin — sync relies on (1) or
(4). Claude `PostToolUse` / `Stop` include `session_id` on stdin — sync parses
it on every run.

## OpenCode vs hooks

OpenCode does **not** use `hooks.json`. The Bun plugin
(`.opencode/plugin/agent-memory.ts`) is a thin adapter that spawns the same
shell scripts:

| OpenCode plugin event             | Spawns                      | Maps to      |
| --------------------------------- | --------------------------- | ------------ |
| First `session.idle` of the day   | `agent-memory-session.sh`   | sessionStart |
| `session.idle` (later same day)   | `agent-memory-sync.sh` only | end of turn  |
| `experimental.session.compacting` | `agent-memory-sync.sh` only | `PreCompact` |

**OpenCode log headings:** OpenCode emits a new `ses_*` session ID on many idle
and compaction events. Shell helpers bind **one `log.md` heading per calendar
day** (`opencode_log_heading_id` in `.hook-sync-state`) instead of one heading
per `ses_*`. Empty duplicate `ses_*` headings are pruned on sessionStart.
Semantic bullets remain agent-owned (`/agent-memory sync`).

Logic lives in the shared `.sh` files; the plugin only passes an **allowlisted**
environment (`PATH` / `HOME` / `TMP*` / `LANG` / `LC_*` / `TZ` plus
`AGENT_MEMORY_HOST` / `EVENT` / `PROJECT_DIR` / `SESSION_ID`),
`AGENT_MEMORY_SESSION_ID`, and minimal stdin JSON. Install all three scripts
under `.opencode/hooks/`.
