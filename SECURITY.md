# Security

This document explains intentional capabilities in `@dosx/agent-memory`, the trust boundary for hooks, and how to audit the published package.

## Intentional capabilities

The CLI and OpenCode plugin use Node.js APIs that security scanners often flag:

| Capability                                 | Where                                                    | Why                                                                                                                                                                                             |
| ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Filesystem** (`node:fs`)                 | `src/`, `hooks/opencode/`                                | Install the skill and hooks; check for `.agents/memory` and hook scripts under the project.                                                                                                     |
| **Child processes** (`node:child_process`) | `src/hooks-run.ts`, `hooks/opencode/agent-memory.ts`     | Run the hook installer (`install-hooks.sh`) and shared sync scripts. Always **argv form**: `spawnSync` / `execFileSync` with `shell: false` (no shell metachar parsing).                       |
| **Environment variables**                  | CLI + OpenCode plugin                                    | Forward an **allowlisted** subset of the parent env to hook children (`ENV_ALLOWLIST_EXACT` in `src/constants.ts`); set `AGENT_MEMORY_*` for project dir, host, event, and session binding.    |

Hooks write only gitignored `.agents/memory/.hook-sync-state` (ephemeral evidence). They never edit Markdown under `.agents/memory/`.

## Trust boundary

Installing agent-memory hooks means trusting the project directory, the same model as git hooks:

- Hook scripts are copied into harness paths (for example `.cursor/hooks/`, `.opencode/hooks/`) under the consumer project.
- Cursor, Claude Code, Codex, Copilot, Gemini, and OpenCode all run those local scripts on lifecycle events.
- Anyone who can modify hook scripts or the project working directory already has local code execution in that project.

The OpenCode plugin spawns the same shared bash sync script as other harnesses. Before `execFileSync` it checks that the script is a regular file, confines `realpath` under both the project cwd and `.opencode/hooks`, and validates binding ID charset (it skips invalid candidates until it finds a valid one). Session binding comes only from the OpenCode event payload. There is no parent `AGENT_MEMORY_SESSION_ID` fallback.

Shared bash hooks validate external session binding IDs and take the first valid among `session_id` / `conversation_id` / `sessionId` / `conversationId` / `composer_id`. They prefer the project env or install-site root over harness stdin `cwd`. They fail closed and write nowhere when the env workspace's harness hooks resolve into another project, or when env has a divergent wrapper or entrypoint. Otherwise they prefer install-site over a mismatched env that has no retarget.

When a valid harness stdin session id conflicts with inherited `AGENT_MEMORY_SESSION_ID` / `CURSOR_SESSION_ID` / `GEMINI_SESSION_ID`, hooks prefer stdin. Delayed Stop on sync/Stop is the exception: if inherited session env, `session_binding`, and `current_session_id` already agree on the live id, canonical binding wins over stale stdin. When stdin has no valid id, they prefer canonical `session_binding` in `.hook-sync-state` over inherited session env. Invalid `session_binding` falls through to `current_session_id`. `sessionStart` ignores session env entirely.

Sync rebind plus path merge, and sessionStart bind, each run under one state lock. Fail-open skips writes. sessionStart exports session env only when bind succeeded. Hooks refuse a symlink on `.hook-sync-state.lock` before lock acquire and before `rm -rf` during lock steal or cleanup. They refuse symlink memory paths, including `.agents` and `.agents/memory` as symlinks, and re-check on write. Path resolution requires `realpath` or `python3`. There is no weak fallback that skips symlink resolution.

The hooks installer (`install-hooks.sh`) fails closed the same way when neither resolver is available. When `package.json` is present, it prefers that version over `AGENT_MEMORY_VERSION`.

## What we do not do

- No network calls from the CLI or hook scripts.
- No `shell: true` on child processes.
- No Markdown writes from hooks (semantic memory is agent-owned only).
- No trusting harness stdin `cwd` alone to select the project root (env or install-site anchor first).
- No feeding `.hook-sync-state` path lists into the model. `/agent-memory sync` and consolidate run `agent-memory-print-evidence.sh` (allowlisted `pending_count` / hex HEAD / validated session id / sanitized branch). They do not Read the state file.

## Environment forwarding

- CLI to `install-hooks.sh` and OpenCode to bash hooks: only `ENV_ALLOWLIST_EXACT` (exact keys; locale via named `LC_*` entries, not a prefix). See `src/constants.ts` (mirrored in the OpenCode plugin; parity tested).
- Stock Cursor / Claude / Codex / Copilot / Gemini: the harness invokes the script directly, so the child inherits the full parent environment (the same model as ordinary git hooks). Stock scripts do not dump or forward secrets to logs or Markdown. When stdin carries a valid session id that disagrees with inherited session-binding env, hooks prefer stdin.
- Git `pre-commit` and `post-commit` also inherit the parent environment, except they unset `AGENT_MEMORY_SESSION_ID`, `CURSOR_SESSION_ID`, and `GEMINI_SESSION_ID` and set `AGENT_MEMORY_HOST=git`. That drops inherited host labels such as stale `opencode`. Those git hooks have no harness stdin session id; stale shell state must not rebind `.hook-sync-state`. `post-commit` only stamps `last_processed_head` and subtracts committed-and-clean paths from `session_touched_files`.
- `PATH` and `GIT_CONFIG*` on the filtered path are intentional so git/locale tooling works under a restricted env. Treat a compromised parent env as already inside the project trust boundary.

`.hook-sync-state` is gitignored ephemeral evidence. Hooks write it mode `0600` (including a heal on no-op writes) so path lists are not world-readable on multi-user machines. Treat `chmod` failure as best-effort, and still treat forged state as untrusted. Agents with Write access to `.agents/memory/` can still edit it on disk. The print-evidence helper is the agent-facing surface: it omits `session_touched_files` and drops non-hex SHAs and invalid session ids. Validate hex SHAs before passing them to git (hooks already do; sync uses the helper output).

## Publish

Prefer `bun run check` before publish. `prepublishOnly` runs it: it starts with `bun audit`, then `build:check` validates the committed `bin/cli.js` via a private `mktemp` outfile before tests and before the final `build`. `prepack` also runs `bun audit` plus `build:check`, so `npm pack` cannot ship without those gates. Still prefer not to `npm publish ./*.tgz` from a laptop; tarball publish skips `prepublishOnly`. CI installs with `--ignore-scripts` and also runs `bun audit`. Local Bun installs pin the same default via `bunfig.toml` `[install] ignoreScripts`. Do not check in a repo-root `.npmrc` with `ignore-scripts`. That makes `npm pack` / `npm publish` skip `prepack` / `prepublishOnly` by default. Do not publish with `npm publish --ignore-scripts`.

Preferred path: npm [Trusted Publishing](https://docs.npmjs.com/trusted-publishers) (OIDC). `.github/workflows/publish.yml` publishes on SemVer tags (no `v` prefix, e.g. `0.1.2`) or `workflow_dispatch`, using GitHub Environment `npm-publish` and `permissions.id-token: write` (no `NPM_TOKEN`). Provenance is automatic with Trusted Publishing. One-time human setup: create the `npm-publish` Environment on GitHub (optional required reviewers), then on npmjs.com for `@dosx/agent-memory` add a Trusted Publisher with org/user `diegoos`, repository `agent-memory`, workflow filename `publish.yml`, and environment `npm-publish`. Laptop `npm publish` remains a temporary human-gated fallback only.

The published skill ships `vendor/memory/gitignore` (not `.gitignore`) because npm omits `.gitignore` files from tarballs. `init`/`update` copy that template to `.agents/memory/.gitignore` (must ignore `.hook-sync-state`, `.hook-sync-state.lock`, and `.hook-sync-state.*`).

## How to audit

1. CLI source: `src/` (TypeScript; entry `src/cli.ts`).
2. Published CLI: `bin/cli.js` is a Bun bundle (CJS, not minified) generated by `bun run build`; verify with `bun run build:check`.
3. Hook scripts: `hooks/agent-memory-hooks/*.sh` and `hooks/install-hooks.sh`.
4. OpenCode plugin: `hooks/opencode/agent-memory.ts` and `hooks/opencode/safe-script.ts`.
5. Tests: `bun run test` includes security fixtures (`tests/opencode-safe-script.test.ts`, `tests/json-escape.sh`, symlink refusal in `tests/hooks-checkpoint.sh`).

Report vulnerabilities via GitHub issues on the repository. Do not open public issues for undisclosed critical findings without coordination.

## See also

- [hooks/README.md](./hooks/README.md): hook install and events
- [CHANGELOG.md](./CHANGELOG.md): security-related release notes
