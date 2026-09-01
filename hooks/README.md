# agent-memory hooks (optional)

Optional hooks that keep ephemeral evidence current during agent work. They run a deterministic git checkpoint into `.agents/memory/.hook-sync-state` (gitignored). No LLM call, no Markdown writes, no `followup_message` loops.

The agent still owns Markdown. In the turn, write at most one file per event: rotten resume → active-work; user constraint → `decisions.md`; reusable lesson → learnings plus an index hint; closed why missing from the commit → `log.md`; shared blocker → `current.md`; otherwise write nothing. Catch up with `/agent-memory sync` when Status shows a stale Checkpoint or pending paths and there is meaning, or follow `references/sync.md` without the skill. After meaning is written, consume pending paths with `agent-memory-consume-evidence.sh`. Full contract: `instructions.md` → _Harness parity (memory contract)_. Consolidation is `/agent-memory consolidate` only. `sessionStart` injects a short status (branch, Checkpoint freshness, pending path count, Action). It does not write Markdown.

## TL;DR

```bash
npx @dosx/agent-memory install hooks <harness>
# TTY multi-select: npx @dosx/agent-memory install hooks
# Skill only:       npx @dosx/agent-memory install skill
# Refresh:          npx @dosx/agent-memory update [--yes]
# or: bash hooks/install-hooks.sh <harness>
```

The installer creates the harness directory if missing, refuses destination and parent symlinks, and requires an existing `PROJECT_DIR` (`realpath`). Set `AGENT_MEMORY_PROJECT_DIR` to target another project.

| Host            | Scripts                                                                 | Config                                  |
| --------------- | ----------------------------------------------------------------------- | --------------------------------------- |
| **Any agent**   | `hooks/agent-memory-hooks/*.sh` → `.git/hooks/` (with `git/pre-commit` and `git/post-commit`) | `hooks/git/pre-commit`, `hooks/git/post-commit` |
| **Cursor**      | → `.cursor/hooks/`                                                      | merge `hooks/cursor/hooks.json`         |
| **Claude Code** | → `.claude/hooks/`                                                      | merge `hooks/claude-code/settings.json` |
| **Codex**       | → `.codex/hooks/`                                                       | merge `hooks/codex/hooks.json`          |
| **Copilot**     | → `.github/hooks/`                                                      | `hooks/copilot/agent-memory.json`       |
| **OpenCode**    | plugin → `.opencode/hooks/*.sh`                                         | `.opencode/plugins/agent-memory.ts` (+ `safe-script.ts`) |
| **Gemini CLI**  | → `.gemini/hooks/`                                                      | merge `.gemini/settings.json`           |

`/agent-memory init <harness>` wires the context layer when the harness directory already exists. It prints hook-install commands and does not copy scripts.

## Events

| Checkpoint     | Cursor               | Claude / Codex | Copilot        | Gemini CLI     | OpenCode          |
| -------------- | -------------------- | -------------- | -------------- | -------------- | ----------------- |
| Session start  | `sessionStart`       | `SessionStart` | `sessionStart` | `SessionStart` | (via AGENTS.md) |
| End of turn    | `afterAgentResponse` | `Stop`         | `agentStop`    | `AfterAgent`   | `session.idle`    |
| Before compact | `preCompact`         | `PreCompact`   | `preCompact`   | `PreCompress`  | `compacting`      |
| Git commit     | `precommit`          | same           | same           | same           | same              |
| After commit   | git `post-commit`    | same           | same           | same           | same              |

Per-tool events are not used. Path evidence comes from git at full checkpoints. Cursor `stop` plus `followup_message` is unused because it starts another LLM turn.

## Layout

```text
hooks/
├── install-hooks.sh
├── lib/merge-hooks.mjs
├── agent-memory-hooks/   # common + sync + session + consume + print-evidence (install all five)
├── <harness>/            # cursor, claude-code, codex, …
└── git/                  # optional: pre-commit + post-commit (copy yourself)
```

## Requirements

- `git` on `$PATH`; POSIX `sh` / `bash` for command hooks
- OpenCode: Bun plugin loader
- Node for JSON merges in the installer

## Install notes

Copy all five files from `hooks/agent-memory-hooks/`. Installing sync and session alone is incomplete. Re-run the installer when hook scripts change.

SessionStart Status reports Checkpoint, an optional Next line from active-work, `load:` files whose `index.md` `when editing:` globs match pending or dirty paths, and an Action (write floor walk / consume). `/agent-memory sync` runs `agent-memory-print-evidence.sh` for allowlisted fields (it does not Read `.hook-sync-state`). After meaning covers pending paths, run `agent-memory-consume-evidence.sh` (or let sync do it) to clear `session_touched_files`.

Optional git hooks (not copied by `install-hooks.sh`): `cp hooks/git/pre-commit hooks/git/post-commit .git/hooks/` and copy the five shared scripts beside them. `post-commit` stamps `last_processed_head` and drops pending paths that are in the new commit and no longer dirty.

Trust boundary: hooks run scripts from your project directory, same as git hooks. Only install when you trust the project and the `@dosx/agent-memory` package version you install. See [SECURITY.md](../SECURITY.md).

Hooks write only `.hook-sync-state` (session, branch, paths, HEAD). They do not edit Markdown, promote decisions or learnings, or consolidate. State uses a short portable lock and atomic replace. Lock contention is fail-open; stale-lock steal trusts the `pid` file inside the lock dir (see [SECURITY.md](../SECURITY.md)). Delayed Stop on sync/Stop prefers canonical `session_binding` when it matches `current_session_id` but harness stdin or inherited env is stale. Detached HEAD caches `branch=detached`.

The git `pre-commit` hook reminds on stderr (non-blocking) when Checkpoint is behind HEAD or staged work has no `.agents/memory/` change. End-of-turn `sync` (`afterAgentResponse` / `Stop` / idle) may print the same class of reminder when pending paths, Checkpoint is behind, or the tree is dirty with no `active-work`. That reminder is stderr only. It does not write Markdown or send `followup_message`. `post-commit` then stamps HEAD in `.hook-sync-state` and subtracts committed-and-clean paths from the pending list.

OpenCode uses a Bun plugin under `.opencode/plugins/` (OpenCode's auto-load path, not the legacy singular `.opencode/plugin/`). It spawns the sync script on `session.idle`, `experimental.session.compacting`, and `session.compacted` with an allowlisted env. The installer copies `agent-memory.ts` and `safe-script.ts` together and removes leftover singular-path files on refresh. Third-party DCP commands (`/dcp-compact`, `/dcp-compress`, and similar) are not covered: they prune LLM context via another plugin and do not fire agent-memory PreCompact. Use native `/compact` or end-of-turn idle for checkpoints. Details and resolution order for project dir and session id live in the shared scripts and in `instructions.md` → _Harness parity_.
