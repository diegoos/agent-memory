# agent-memory — agent hooks (optional)

Optional hooks that keep agent-memory current during real work. They run a
**deterministic git checkpoint** — no LLM call, no `followup_message` loops:

- **`sessionStart` / NewSession** — session ID, `current.md` _In progress_ from
  `active-work/`, ensure active-work file + `log.md` session heading
- **`postToolUse` / end-of-turn / compact / pre-commit** — refresh
  `active-work/<branch>.md` (_Touched files_, Task stub) and append new file
  bullets under the current `log.md` session heading

**Still manual (agent or `/agent-memory sync`):** semantic `log.md` bullets and
summary/type, `decisions.md` (required when decisions change), active-work
Progress/Blockers/Notes, `current.md` _Done_ / _Next steps_, `index.md` lazy
links, `architecture.md`, `patterns.md`, `vision.md` (ask user if uncertain).

## TL;DR

Copy the shared scripts plus host config (paths from repo root):

| Host            | Scripts                                                     | Config                                  |
| --------------- | ----------------------------------------------------------- | --------------------------------------- |
| **Any agent**   | `hooks/shared/*.sh` → `.git/hooks/` (with `git/pre-commit`) | `hooks/git/pre-commit`                  |
| **Cursor**      | → `.cursor/hooks/`                                          | merge `hooks/cursor/hooks.json`         |
| **Claude Code** | → `.claude/hooks/`                                          | merge `hooks/claude-code/settings.json` |
| **Codex**       | → `.codex/hooks/`                                           | merge `hooks/codex/hooks.json`          |
| **Copilot**     | → `.github/hooks/`                                          | `hooks/copilot/agent-memory.json`       |
| **OpenCode**    | plugin → `.opencode/hooks/*.sh`                             | `.opencode/plugin/agent-memory.ts`      |

Or run `/agent-memory init <harness>` when the harness directory already exists.

**Cursor:** hooks are the recommended integration — `@import` in `AGENTS.md` is
a no-op and `AGENTS.md` may not auto-inject. See root `README.md`.

## Events (all hosts)

| Checkpoint        | Cursor                        | Claude / Codex | Copilot        | OpenCode       |
| ----------------- | ----------------------------- | -------------- | -------------- | -------------- |
| Session start     | `sessionStart`                | `SessionStart` | `sessionStart` | —              |
| After Write/Shell | `postToolUse`                 | `PostToolUse`  | `postToolUse`  | —              |
| End of turn       | `afterAgentResponse`          | `Stop`         | `agentStop`    | `session.idle` |
| Before compact    | `preCompact`                  | `PreCompact`   | `preCompact`   | `compacting`   |
| Git commit        | `precommit` (pre-commit hook) | same           | same           | same           |

**Not used on Cursor:** `stop` + `followup_message` (always starts another LLM
turn).

## Layout

```text
hooks/
├── shared/
│   ├── agent-memory-common.sh    # shared helpers (sourced by sync + session)
│   ├── agent-memory-sync.sh      # checkpoint after tools / end of turn
│   └── agent-memory-session.sh   # sessionStart / NewSession
├── cursor/hooks.json
├── claude-code/settings.json
├── codex/hooks.json
├── codex/config.toml.snippet
├── copilot/agent-memory.json
├── opencode/agent-memory.ts
└── git/pre-commit
```

## Requirements

- `git` on `$PATH`
- POSIX `sh` / `bash` for command hooks
- OpenCode: Bun plugin loader

## Install (per project)

Copy **all three** files from `hooks/shared/` into the harness hooks directory
(`agent-memory-common.sh` must sit beside the other two — sync/session source
it). **Never copy only sync + session** — partial installs fail at runtime
(sync/session print a stderr hint and exit 0 so the harness is not blocked).
Re-copy all three on `/agent-memory update` when hook scripts change.

### Cursor (recommended)

```bash
mkdir -p .cursor/hooks
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .cursor/hooks/
chmod +x .cursor/hooks/agent-memory-*.sh
# merge hooks/cursor/hooks.json into .cursor/hooks.json
```

### Claude Code

```bash
mkdir -p .claude/hooks
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .claude/hooks/
chmod +x .claude/hooks/agent-memory-*.sh
# merge hooks/claude-code/settings.json into .claude/settings.json
```

### Codex

```bash
mkdir -p .codex/hooks
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .codex/hooks/
chmod +x .codex/hooks/agent-memory-*.sh
# merge hooks/codex/hooks.json into .codex/hooks.json
# then run /hooks in the Codex TUI to trust project hooks
```

### Copilot (CLI + cloud agent)

```bash
mkdir -p .github/hooks
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .github/hooks/
chmod +x .github/hooks/agent-memory-*.sh
cp skills/agent-memory/hooks/copilot/agent-memory.json .github/hooks/agent-memory.json
```

### OpenCode

```bash
mkdir -p .opencode/hooks .opencode/plugin
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .opencode/hooks/
chmod +x .opencode/hooks/agent-memory-*.sh
cp skills/agent-memory/hooks/opencode/agent-memory.ts .opencode/plugin/agent-memory.ts
```

The TypeScript plugin spawns the same shell scripts on `session.idle` and
`experimental.session.compacting` — see [OpenCode vs hooks](#opencode-vs-hooks)
below.

### Git (host-agnostic baseline)

```bash
cp skills/agent-memory/hooks/git/pre-commit .git/hooks/pre-commit
cp skills/agent-memory/hooks/shared/agent-memory-*.sh .git/hooks/
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

| Field                         | Hook updates?                                |
| ----------------------------- | -------------------------------------------- |
| `active-work` → Touched files | Yes (from `git`)                             |
| `active-work` → Task stub     | Yes (from branch name when placeholder)      |
| `log.md` → session heading    | Yes (on session start)                       |
| `log.md` → file bullets       | Yes (new paths per session, from `git`)      |
| `log.md` → semantic bullets   | **No** — agent                               |
| `current.md` → In progress    | Yes (on session start from `active-work/`)   |
| `current.md` → Done / Next    | **No** — agent or `/agent-memory sync`       |
| `decisions.md`                | **No** — agent (required on decision change) |
| `.hook-sync-state`            | Yes (session ID, logged files, debounce)     |

### Log format

One heading per session; hooks + agent append bullets:

```md
## [2026-06-30] [effad5d5-…] [chore] session work

- `lib/rate-limit.ts`
- fixed rate-limit edge case in auth middleware
```

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
6. `cwd` or `workspace_roots[0]` from hook stdin JSON
7. `$PWD`

**Session ID** (`resolve_session_id`):

1. `AGENT_MEMORY_SESSION_ID` — set by `sessionStart` via hook `env` output
   (Cursor, Claude, Copilot) or export (Codex, OpenCode plugin)
2. `CURSOR_SESSION_ID` — legacy fallback only
3. `session_id`, `conversation_id`, or `sessionId` from hook stdin JSON (Cursor,
   Claude, Copilot, Codex on every lifecycle event)
4. `current_session_id` in `.hook-sync-state` (last sessionStart)

Cursor `afterAgentResponse` omits `session_id` on stdin — sync relies on (1) or
(4). Claude `PostToolUse` / `Stop` include `session_id` on stdin — sync parses
it on every run.

## OpenCode vs hooks

OpenCode does **not** use `hooks.json`. The Bun plugin
(`.opencode/plugin/agent-memory.ts`) is a thin adapter that spawns the same
shell scripts:

| OpenCode plugin event             | Spawns                          | Maps to      |
| --------------------------------- | ------------------------------- | ------------ |
| First sync/compaction (once)      | `agent-memory-session.sh`       | sessionStart |
| `session.idle`                    | `agent-memory-sync.sh` (`Stop`) | end of turn  |
| `experimental.session.compacting` | `agent-memory-sync.sh`          | `PreCompact` |

Logic lives in the shared `.sh` files; the plugin only passes
`AGENT_MEMORY_PROJECT_DIR`, `AGENT_MEMORY_SESSION_ID`, and stdin JSON. Install
all three scripts under `.opencode/hooks/`.
