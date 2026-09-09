# agent-memory hooks (optional)

Hooks store a deterministic git checkpoint in `.agents/memory/.hook-sync-state` (gitignored). No LLM call, no Markdown, no `followup_message`.

The agent owns Markdown. Write floor, Status, and consume live in `instructions.md` → _Harness parity — memory contract_. Catch up with `/agent-memory sync` (or `references/sync.md`). After meaning is written, clear pending paths with `agent-memory-consume-evidence.sh`. Promotion and prune: `/agent-memory consolidate` only. `sessionStart` injects a short Status line (branch, Checkpoint, pending count, Action). It does not write Markdown.

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

Per-tool events are unused. Path evidence comes from git at full checkpoints. Cursor `stop` plus `followup_message` is unused because it starts another LLM turn.

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

Copy all five files from `hooks/agent-memory-hooks/`. Sync and session alone are incomplete. Re-run the installer when hook scripts change.

SessionStart Status reports Checkpoint, an optional Next line from active-work, `load:` files whose `index.md` `when editing:` globs match pending or dirty paths, and an Action (write floor / consume). `/agent-memory sync` runs `agent-memory-print-evidence.sh` for allowlisted fields (it does not Read `.hook-sync-state`). After meaning covers pending paths, run `agent-memory-consume-evidence.sh` (or let sync do it) to clear `session_touched_files`.

Optional git hooks (not copied by `install-hooks.sh`): `cp hooks/git/pre-commit hooks/git/post-commit .git/hooks/` and copy the five shared scripts beside them. `post-commit` stamps `last_processed_head` and drops pending paths that are in the new commit and no longer dirty.

Trust: hooks run scripts from your project directory, same as git hooks. Install only when you trust the project and the `@dosx/agent-memory` package version. See [SECURITY.md](../SECURITY.md).

State is `.hook-sync-state` only (session, branch, paths, HEAD): short portable lock, atomic replace, fail-open on lock contention. Stale-lock steal trusts the `pid` file inside the lock dir ([SECURITY.md](../SECURITY.md)). Delayed Stop prefers canonical `session_binding` when it matches `current_session_id` but harness stdin or inherited env is stale. Detached HEAD caches `branch=detached`.

Git `pre-commit` reminds on stderr (non-blocking) when Checkpoint is behind HEAD or staged work has no `.agents/memory/` change. End-of-turn `sync` may print the same class of reminder when pending paths, Checkpoint is behind, or the tree is dirty with no `active-work`. `post-commit` then stamps HEAD and subtracts committed-and-clean paths from the pending list.

OpenCode uses a Bun plugin under `.opencode/plugins/` (not the legacy singular `.opencode/plugin/`). It spawns the sync script on `session.idle`, `experimental.session.compacting`, and `session.compacted` with an allowlisted env. The installer copies `agent-memory.ts` and `safe-script.ts` together and removes leftover singular-path files on refresh. Third-party DCP commands (`/dcp-compact`, `/dcp-compress`, and similar) prune LLM context through another plugin and do not fire agent-memory PreCompact. Use native `/compact` or end-of-turn idle. Project dir and session id resolution: shared scripts and `instructions.md` → _Harness parity_.
