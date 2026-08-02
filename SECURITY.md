# Security

This document explains intentional capabilities in `@dosx/agent-memory`, the trust boundary for hooks, and how to audit the published package.

## Intentional capabilities

The CLI and OpenCode plugin use Node.js APIs that security scanners often flag:

| Capability                                 | Where                                                    | Why                                                                                                                                                                                             |
| ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Filesystem** (`node:fs`)                 | `install.ts`, `lib/cli/`, `hooks/opencode/`              | Install the skill and hooks; check for `.agents/memory` and hook scripts under the project.                                                                                                     |
| **Child processes** (`node:child_process`) | `lib/cli/hooks-run.ts`, `hooks/opencode/agent-memory.ts` | Run the hook installer (`install-hooks.sh`) and shared sync scripts. Always **argv form** — `spawnSync` / `execFileSync` with `shell: false` (no shell metachar parsing).                       |
| **Environment variables**                  | CLI + OpenCode plugin                                    | Forward an **allowlisted** subset of the parent env to hook children (`ENV_ALLOWLIST_EXACT` in `lib/cli/constants.ts`); set `AGENT_MEMORY_*` for project dir, host, event, and session binding. |

Hooks write only gitignored `.agents/memory/.hook-sync-state` (ephemeral evidence). They **never** edit Markdown under `.agents/memory/`.

## Trust boundary

Installing agent-memory hooks is equivalent to trusting the project directory — the same model as **git hooks**:

- Hook scripts are copied into harness paths (e.g. `.cursor/hooks/`, `.opencode/hooks/`) under the consumer project.
- Cursor, Claude Code, Codex, Copilot, Gemini, and OpenCode all run those local scripts on lifecycle events.
- Anyone who can modify hook scripts or the project working directory already has local code execution in that project.

The OpenCode plugin spawns the same shared bash sync script as other harnesses; it adds runtime checks (regular file only, `realpath` confinement under `.opencode/hooks`, binding ID charset validation) before `execFileSync`. Shared bash hooks also validate external session binding IDs, prefer project env / install-site root over harness stdin `cwd`, prefer a valid harness stdin session id over conflicting inherited `AGENT_MEMORY_SESSION_ID` / `CURSOR_SESSION_ID` / `GEMINI_SESSION_ID`, refuse symlink memory paths, and require `realpath` or `python3` to resolve paths (no weak fallback that skips symlink resolution). The hooks installer (`install-hooks.sh`) fails closed the same way when neither resolver is available.

## What we do not do

- No network calls from the CLI or hook scripts.
- No `shell: true` on child processes.
- No Markdown writes from hooks (semantic memory is agent-owned only).
- No trusting harness stdin `cwd` alone to select the project root (env or install-site anchor first).

## Environment forwarding

- **CLI → `install-hooks.sh` and OpenCode → bash hooks:** only `ENV_ALLOWLIST_EXACT` (exact keys; locale via named `LC_*` entries, not a prefix). See `lib/cli/constants.ts` (mirrored in the OpenCode plugin; parity tested).
- **Stock Cursor / Claude / Codex / Copilot / Gemini:** the harness invokes the script directly, so the child **inherits the full parent environment** (same model as ordinary git hooks). Stock scripts do not dump or forward secrets to logs or Markdown. When stdin carries a valid session id that disagrees with inherited session-binding env, hooks prefer stdin.
- **Git `pre-commit`:** also inherits the parent environment, except it **unsets** `AGENT_MEMORY_SESSION_ID`, `CURSOR_SESSION_ID`, and `GEMINI_SESSION_ID` before sync (pre-commit has no harness stdin session id; stale shell bindings must not rebind `.hook-sync-state`).
- **`PATH` and `GIT_CONFIG*`** on the filtered path are intentional so git/locale tooling works under a restricted env. Treat a compromised parent env as already inside the project trust boundary.

`.hook-sync-state` is gitignored ephemeral evidence. Hooks own writes under the method contract; agents with Write access to `.agents/memory/` can still edit it on disk — treat forged state as untrusted and validate hex SHAs before passing them to git (hooks and `/agent-memory sync`).

## Publish

Prefer `bun run check` before publish (`prepublishOnly` runs it — `build:check` validates the committed `bin/cli.js` before tests rebuild and before the final `build`). Do not publish with `npm publish --ignore-scripts` — that skips the rebuild/`check` gate and can ship a stale or tampered `bin/cli.js`.

## How to audit

1. **CLI source** — `install.ts` and `lib/cli/` (TypeScript).
2. **Published CLI** — `bin/cli.js` is a Bun bundle (CJS, **not minified**) generated by `bun run build`; verify with `bun run build:check`.
3. **Hook scripts** — `hooks/agent-memory-hooks/*.sh` and `hooks/install-hooks.sh`.
4. **OpenCode plugin** — `hooks/opencode/agent-memory.ts` and `hooks/opencode/safe-script.ts`.
5. **Tests** — `bun run test` includes security fixtures (`tests/opencode-safe-script.test.ts`, symlink refusal in `tests/hooks-checkpoint.sh`).

Report vulnerabilities via GitHub issues on the repository. Do not open public issues for undisclosed critical findings without coordination.

## See also

- [hooks/README.md](./hooks/README.md) — hook install and events
- [CHANGELOG.md](./CHANGELOG.md) — security-related release notes
