# agent-memory — agent hooks (optional)

Optional hooks that keep **ephemeral evidence** current during real work. They run a **deterministic git checkpoint** into `.agents/memory/.hook-sync-state` (gitignored) — no LLM call, no Markdown writes, no `followup_message` loops.

**Still manual (agent owns Markdown):** **primary write** is in-turn (resume fields + semantic `log.md` — after commit / before compact / when Status shows stale Checkpoint or pending paths); **catch-up** via `/agent-memory sync` or by following the skill's `references/sync.md` without invoking the skill; **consume** pending paths with `agent-memory-consume-evidence.sh` after meaning is written. Full contract: `instructions.md` → _Harness parity — memory contract_. Consolidation is `/agent-memory consolidate` only. `sessionStart` injects a short status (branch, Checkpoint freshness, pending path count, Action) — never Markdown.

## TL;DR

```bash
npx @dosx/agent-memory install hooks <harness>
# TTY multi-select: npx @dosx/agent-memory install hooks
# Skill only:       npx @dosx/agent-memory install skill
# Refresh:          npx @dosx/agent-memory update [--yes]
# or: bash hooks/install-hooks.sh <harness>
```

The installer creates the harness directory if missing, refuses destination / parent symlinks, and requires an existing `PROJECT_DIR` (`realpath`). Set `AGENT_MEMORY_PROJECT_DIR` to target another project.

| Host            | Scripts                                                                 | Config                                  |
| --------------- | ----------------------------------------------------------------------- | --------------------------------------- |
| **Any agent**   | `hooks/agent-memory-hooks/*.sh` → `.git/hooks/` (with `git/pre-commit`) | `hooks/git/pre-commit`                  |
| **Cursor**      | → `.cursor/hooks/`                                                      | merge `hooks/cursor/hooks.json`         |
| **Claude Code** | → `.claude/hooks/`                                                      | merge `hooks/claude-code/settings.json` |
| **Codex**       | → `.codex/hooks/`                                                       | merge `hooks/codex/hooks.json`          |
| **Copilot**     | → `.github/hooks/`                                                      | `hooks/copilot/agent-memory.json`       |
| **OpenCode**    | plugin → `.opencode/hooks/*.sh`                                         | `.opencode/plugin/agent-memory.ts`      |
| **Gemini CLI**  | → `.gemini/hooks/`                                                      | merge `.gemini/settings.json`           |

`/agent-memory init <harness>` wires the **context** layer when the harness directory already exists; it **prints** hook-install commands and does not copy scripts.

## Events

| Checkpoint     | Cursor               | Claude / Codex | Copilot        | Gemini CLI     | OpenCode          |
| -------------- | -------------------- | -------------- | -------------- | -------------- | ----------------- |
| Session start  | `sessionStart`       | `SessionStart` | `sessionStart` | `SessionStart` | — (via AGENTS.md) |
| End of turn    | `afterAgentResponse` | `Stop`         | `agentStop`    | `AfterAgent`   | `session.idle`    |
| Before compact | `preCompact`         | `PreCompact`   | `preCompact`   | `PreCompress`  | `compacting`      |
| Git commit     | `precommit`          | same           | same           | same           | same              |

Per-tool events are **not** used — path evidence comes from git at full checkpoints. Cursor `stop` + `followup_message` is unused (starts another LLM turn).

## Layout

```text
hooks/
├── install-hooks.sh
├── lib/merge-hooks.mjs
├── agent-memory-hooks/   # common + sync + session + consume-evidence (install all four)
├── <harness>/            # cursor, claude-code, codex, …
└── git/pre-commit
```

## Requirements

- `git` on `$PATH`; POSIX `sh` / `bash` for command hooks
- OpenCode: Bun plugin loader
- Node for JSON merges in the installer

## Install notes

Copy **all four** files from `hooks/agent-memory-hooks/` — never sync+session alone. Re-run the installer when hook scripts change. After `/agent-memory sync` writes meaning that covers pending paths, run `agent-memory-consume-evidence.sh` (or let sync do it) to clear `session_touched_files`.

**Trust boundary:** hooks run scripts from your project directory (same trust model as git hooks). Only install when you trust the project and the `@dosx/agent-memory` package version you install. See [SECURITY.md](../SECURITY.md).

Hooks write **only** `.hook-sync-state` (session, branch, paths, HEAD). They never edit Markdown, promote decisions/learnings, or consolidate. State uses a short portable lock and atomic replace; lock contention is fail-open (stale-lock steal trusts the `pid` file inside the lock dir — see [SECURITY.md](../SECURITY.md)). Delayed Stop on sync/Stop prefers canonical `session_binding` when it matches `current_session_id` but harness stdin (or inherited env) is stale; detached HEAD caches `branch=detached`. The git `pre-commit` hook reminds (stderr, non-blocking) when Checkpoint is behind HEAD or staged work has no `.agents/memory/` change.

OpenCode uses a Bun plugin (not `hooks.json`) that spawns the sync script on `session.idle` / `experimental.session.compacting` with an allowlisted env. Details and resolution order for project dir / session id live in the shared scripts and in `instructions.md` → _Harness parity_.
