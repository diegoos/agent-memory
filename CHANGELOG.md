# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Migration details for `/agent-memory update` live in [`skills/agent-memory/vendor/UPDATE.md`](skills/agent-memory/vendor/UPDATE.md) (machine-oriented `safe` / `sensitive` tags). This changelog is the human-oriented release history — keep both in sync on version bumps.

## [Unreleased]

### Changed

- Lint: severity bands **errors** / **warnings** / **info** — Fix offer only for errors and warnings; open valid `pending-doc` is backlog (not reported); hook evidence splits into `evidence-pending` (uncovered / Checkpoint behind), `evidence-dirty-requeue` (info when Checkpoint@HEAD + dirty tree and meaning covers), and `evidence-stale-uncleared` (consume on clean tree); escalate dirty-requeue to pending only when meaning is missing.
- Memory method: lint reuses one Checkpoint SHA parse; skips `index.md` Shape placeholders with `<…>` (e.g. `learnings-<topic>.md`); reports `hook-state-absent` when `.hook-sync-state` is missing (info).
- Memory method: consolidate never empties `log.md` (current-session / sole-heading / Trim-Defer); Report names retained founding headings; sync suggests consolidate only for **closed**-session noise; bootstrap writes **one** synthesis log heading; lint `empty-log` / `empty-log-after-scaffold`; Validation prefers full project closure (`check` over narrow `test` when defined).
- Memory method: close the write loop — Checkpoint plain `YYYY-MM-DD @ SHORT-SHA` (machine-only line; legacy backticks tolerated with lint warning); sync/primary-write **must** consume eligible pending paths; Next step is product work only; Progress must not replay `log.md`; lint `checkpoint-prose` / `stale-next-step` / `dup-progress-log` / `evidence-stale-uncleared` / `pending-doc-met`; skip dogfood `instructions.md`↔vendor `dup-exact`; active-work References use `../../../`; fenced `when editing:` shape.
- Hooks: sessionStart Status uses `parse_checkpoint_sha`, cheap tracked `dirty` (no full porcelain), and Action cites a repo-relative `bash …/agent-memory-consume-evidence.sh` when `script_dir` is under the project.
- CLI: install always from the package tree beside `bin/cli.js` (never clones GitHub); header prints `source`; source checkouts (`install.ts` present) refresh skill/hooks on `update` even when SemVer matches so unreleased dogfooding works; `update --force` does the same from a published pack; help lists local `node …/bin/cli.js` examples.
- Editorial pass on `SKILL.md` (no method semantics changed): user-invoked description trimmed to one line; Routing Does shortened (Help verbatim unchanged); Enabled tools + Write boundary + Shared rules folded under Boundary (`Write scope` / `Confirm` / `Host fallback`); leading words `vendor-only` / `print-only hooks` / `catch-up`; `init`/`update` pointers rename Repository source → Vendor source.
- Editorial pass on the skill (no method semantics changed): `instructions.md` always-load states the hot path / on-demand list once, untrusted-recall drops a duplicated override clause; `SKILL.md` write boundary points at `references/init.md` instead of repeating the harness-file list; `init` states the prerequisite-dirs rule once; `sync` reference wording aligned.
- Skill `allowed-tools`: sync/bootstrap hot path only (`current` / `index` / `log` / `active-work` / `.version` / `.gitignore`) — omit `decisions` / `learnings*` (host prompts on learn/consolidate), `instructions.md`, and harness carriers; Bash limited to exact `git branch --show-current` / `git status` / `git status -sb` (no `diff*`/`log*`/`branch:*` globs).
- `when editing:` contract: reject **any** near-always-on glob (companions do not redeem) — **structural** multi-segment wildcards, any glob with **no literal path segment** that is only wildcards/`*.*`/`*.<ext>` at any depth (`*/*.*`, `*/*/*.ts`, …), any `**/*.<ext>` / `**/*.*`, any `<top-level-dir>/**` (incl. `hooks/**`), plus explicit denylist; normalize **to fixpoint** (repeat `./` / leading `/` / `//` collapse until stable), then collapsing `**/**`; reject absolute globs after normalize; Always-load aligned with lint.
- `sync` reference: write only Boundary targets (`current` / `active-work` / `log` / `index`) — not `decisions` / `learnings` (outside `allowed-tools` pre-approval); `--auto` still AskQuestion for `index.md` diffs that add/widen `when editing:` hints.
- `sync` / `consolidate` / `learn` references: scope writes to command Boundary; durable recall expects host prompts; skill host-ignores fallback also bans sync writing decisions/learnings.
- Vendor README manual install: copy pack-safe `gitignore` → `.agents/memory/.gitignore` after `cp -R`.
- CI: `bun install --frozen-lockfile --ignore-scripts`; repo `bunfig.toml` defaults `ignoreScripts` for Bun installs to match; `bun audit` in both CI and `bun run check` / `prepublishOnly`; `prepack` runs `bun audit` + `build:check` so `npm pack` cannot skip integrity gates; `build:check` lives in `scripts/build-check.sh` (private `mktemp` outfile); `tests/test-runner.sh` runs `build:check` before fixtures; `cli-install.sh` no longer rebuilds `bin/cli.js`; bump `markdownlint-cli` to `0.49.1`.
- Hooks installer: when `package.json` is present, prefer its version over `AGENT_MEMORY_VERSION` (env remains fallback for standalone hooks-only checkouts).
- CI: pin `actions/checkout` v7.0.1, `actions/setup-node` v7.0.0, and `oven-sh/setup-bun` v2.2.0 (Node 24 action runtime; clears GitHub deprecation warnings forcing Node 20 actions onto 24).
- Memory skeleton: ship pack-safe `vendor/memory/gitignore` (identical to `.gitignore`); `init` / `update` / `lint` require `.hook-sync-state`, `.hook-sync-state.lock`, and `.hook-sync-state.*` (npm omits files named `.gitignore` from tarballs).
- Memory method: `instructions.md` harness parity documents four flat hook scripts, `current_session_id` in ephemeral evidence, atomic sync/sessionStart binds under `.hook-sync-state.lock`, and the delayed Stop exception to stdin-wins.
- Hooks: shared `agent-memory-common.sh` section index (maintainability; no runtime behavior change).

### Fixed

- Tests: chmod-heal assertion uses `uname` to pick BSD vs GNU `stat` (Linux `stat -f` dumps filesystem info with exit 0, so the old `stat -f || stat -c` probe never reached `%a`).
- OpenCode: install plugin to `.opencode/plugins/` (OpenCode auto-load path) with `safe-script.ts` beside it; migrate/remove legacy `.opencode/plugin/`; plugin uses harness `directory` for project root, logs spawn failures to stderr, and checkpoints on `session.compacted` as well as idle / `experimental.session.compacting` (DCP `/dcp-compact` is documented as out of scope).
- Memory method/skill: sync clears observably false hooks/state blockers; pending hook evidence counts as resumable; consume required when meaning covers paths even if the tree is dirty; bootstrap requires learnings `pending-doc` + `Invalidate when` for durable doc gaps; init/bootstrap/SKILL tell users to re-sync after hooks; lint warns `blocker-hooks-contradiction` and `log-placeholder-stale`; log headings must use bracketed `[type]` (no `type | title`); founding-day consolidate is report-only for prune; vendor `log.md` notes removing `_No entries yet._` on first heading.
- Hooks: OpenCode day rollover and ses\_\* path preserve key off `session_binding_host` in state, not inherited `AGENT_MEMORY_HOST`.
- Hooks: delayed Stop on sync/Stop prefers canonical `session_binding` when `session_binding` and `current_session_id` agree on the live id but harness stdin or inherited env is stale (including when stale env equals stale stdin); scans binding env vars before stdin wins when state is not canonical.
- Hooks: detached HEAD caches `branch=detached` instead of leaving a stale branch name in `.hook-sync-state`.
- Hooks: `sessionStart` runs resolve, rebind, and branch refresh under one state lock; exports `AGENT_MEMORY_SESSION_ID` only when bind succeeded under lock; ignores inherited env for delayed Stop (sync-only canonical preference gated on `allow_state_fallback`).
- Hooks: invalid `session_binding` in state falls through to `current_session_id` when stdin has no valid id (corrupted binding no longer blocks recovery).
- Hooks: refuse symlink or out-of-memory `.hook-sync-state.lock` before `rm -rf` during lock steal/cleanup.
- Hooks: `consume-evidence` skips clearing `session_touched_files` when the state lock is not held (fail-open parity with rebind/branch/checkpoint) and compare-and-swaps against the pre-lock snapshot so a concurrent sync cannot lose newly merged paths.
- Hooks installer: write `.version` via temp+`mv` with symlink refusal (same as `safe_install_file`) so a planted `.version` symlink cannot redirect the stamp outside the hooks dir.
- OpenCode: `isValidBindingId` rejects reserved `__no_id__` (parity with bash `is_valid_external_binding_id`).
- Publish: remove repo-root `.npmrc` `ignore-scripts` (it skipped `prepack` on `npm pack`); install-script suppression stays in `bunfig.toml` / CI only; `tests/npm-pack-parity.sh` runs `npm pack --ignore-scripts=false` so CI exercises `prepack`.
- `when editing:` normalize runs **to fixpoint** (repeat `./` / leading `/` / `//` collapse until stable) so `/./hooks/**` and `.//./hooks/**` cannot evade the denylist; reject absolute globs after normalize.
- Hooks: `parse_hook_stdin` always re-detects `jq` (ignore inherited `_AMC_HAVE_JQ`); sed fallback extracts only flat top-level JSON body so nested/`last-match` `session_id` cannot rebind `.hook-sync-state`.
- Hooks: no-op `write_state` still `chmod 600` on `.hook-sync-state` (heal world-readable leftover).
- Hooks: refuse install-site preference when the env workspace's harness hooks **resolve** into another project (parent/dir/file symlink) **or** when env has a divergent wrapper/entrypoint — **fail closed** (write nowhere) instead of keeping the mismatched env root (cross-project `.hook-sync-state` write).
- Hooks: sync runs `current_session_id` write, session rebind, branch refresh, and path merge under one state lock (`run_sync_ephemeral_checkpoint`, including `resolve_session_id` under lock) so concurrent syncs cannot mix `session_touched_files` across bindings (re-run hooks installer to pick up).
- Hooks: `resolve_session_id` prefers canonical `.hook-sync-state` binding over inherited session env when stdin has no valid id; `sessionStart` ignores session env entirely (stdin only).
- OpenCode: resolve session binding from harness payload only — no `process.env.AGENT_MEMORY_SESSION_ID` fallback (stale parent env cannot rebind another workspace).
- Hooks: `parse_hook_stdin` picks the first _valid_ `session_id` / `conversation_id` / `sessionId` (invalid first field no longer blocks a later valid one or falls through to stale env).
- OpenCode: `firstBindingId` skips invalid candidates instead of short-circuiting the list (parity with bash).
- Hooks: re-check `.agents` / `.agents/memory` symlinks on every state write (TOCTOU vs init).
- OpenCode: `assertSafeHookScript` requires resolved hooks dir under project cwd (dir-symlink escape).
- CLI skill install: after `mkdir`, ensure resolved parent stays under project root (parity with `install-hooks.sh`).
- Hooks: refuse `.agents` / `.agents/memory` when those paths are symlinks (before realpath under-project check).
- Hooks: `chmod 600` on `.hook-sync-state` after write.
- Hooks installer: `install-hooks.sh` fails closed when neither `realpath` nor `python3` is available (parity with shared hooks — weak `cd`/`pwd` fallback skipped symlink resolution on the under-project check).
- Hooks: `agent_memory_resolve_realpath` fails closed when neither `realpath` nor `python3` is available (weak `cd`/`pwd` fallback skipped symlink resolution and could write `.hook-sync-state` through an escaped `.agents/memory` symlink).
- Hooks: `resolve_session_id` prefers harness stdin over stale inherited `AGENT_MEMORY_SESSION_ID`, `CURSOR_SESSION_ID`, and `GEMINI_SESSION_ID` when both are valid and differ (re-run hooks installer to pick up).
- Hooks: git `pre-commit` unsets stale session env and sets `AGENT_MEMORY_HOST=git` before sync so inherited OpenCode host labels cannot trigger day-rollover path clears.
- Hooks: `parse_hook_stdin` falls back to sed field extraction when `jq` fails or returns empty for non-empty harness input (stdin session id not silently dropped to env).
- Hooks: `sessionStart` context message includes untrusted-recall framing aligned with agent block / `instructions.md`.
- CI / `bun run check`: run `build:check` before `test` and `build` so a tampered committed `bin/cli.js` cannot pass after `tests/cli-install.sh` rebuilds the artifact on the runner.
- `/agent-memory sync` reference: validate `current_session_id` charset/length (hooks parity) before embedding in `log.md` headings; omit bracket when invalid.
- Hooks: `_rebind_session_state_unlocked` preserves `session_binding_host` from `.hook-sync-state` when `AGENT_MEMORY_HOST` is unset; sync harness configs now set `AGENT_MEMORY_HOST` on checkpoint commands (re-run hooks installer to pick up).
- Hooks: `refresh_branch_cache` updates `branch` and clears `session_touched_files` under one lock; fail-open skips both (no path wipe without branch update).
- Hooks: project root prefers env / install-site (`<project>/.cursor/hooks` etc.) over harness stdin `cwd`; stdin alone no longer selects another workspace.
- Hooks: when install-site resolves, it wins over a mismatched inherited `*_PROJECT_DIR` (stale shell env cannot retarget `.hook-sync-state`).
- Hooks: external session binding IDs validated (charset + length; reject reserved `__no_id__` from stdin/env); `sessionStart` Status uses sanitized branch and hex-only Checkpoint SHAs.
- Hooks: git `pre-commit` and commit-range evidence ignore non-hex Checkpoint / `last_processed_head` values (no `git rev-parse` option smuggling); `lint` stale-resume snippet aligned.
- Hooks: `resolve_session_id` re-validates `session_binding` / `current_session_id` from state with the same charset rules as external IDs.
- `/agent-memory sync`: require hex-only `last_processed_head` before `git diff` (parity with hooks; forged state cannot option-smuggle).

### Security

- Hooks: delayed Stop preserves live `session_binding` when env and state agree (AuthZ — stale Stop payload cannot rewind session after `sessionStart` or OpenCode `ses_*` rotation).
- Hooks: lock steal refuses symlink lock path before `rm -rf` (Injection / confinement).
- Hooks: `sessionStart` exports session env only after successful bind under lock (AuthZ — fail-open cannot misalign env with `.hook-sync-state`).
- Hooks: consume-evidence never clears pending paths under lock fail-open; CAS clear avoids wiping paths merged by a concurrent sync (AuthZ / evidence integrity).
- Hooks installer: `.version` stamp refuses destination symlinks (Injection / confinement — parity with script install).
- OpenCode: reject `__no_id__` binding ids before spawn (AuthZ — parity with bash).
- Hooks: fail closed on hooks retarget (symlink or divergent entrypoint) — no `.hook-sync-state` write to a mismatched env or install-site (AuthZ / confinement).
- Skill: `allowed-tools` omits `instructions.md` and harness carriers; Bash git limited to exact read-only status/branch forms.
- Publish: forbid `npm publish --ignore-scripts` and hand-edited tarball publish; `build:check` uses private tempfile; `bun run test` runs `build:check` first.
- `bun run check` / `prepublishOnly` run `bun audit`; CI installs with `--ignore-scripts`.
- Hooks: ephemeral sync checkpoint is atomic under one lock (AuthZ — concurrent rebind cannot attach another session's accumulated paths).
- Hooks: sync prefers `session_binding` in state over inherited `AGENT_MEMORY_SESSION_ID` / `CURSOR_SESSION_ID` / `GEMINI_SESSION_ID` when stdin lacks a valid id; `sessionStart` never seeds from parent session env (AuthZ).
- npm pack: ship `vendor/memory/gitignore` so `init`/`update`/`lint` can always install `.agents/memory/.gitignore` ignoring `.hook-sync-state` (and lock/temp siblings; npm omits `.gitignore` files from tarballs).
- OpenCode: session binding from event payload only — no parent `AGENT_MEMORY_SESSION_ID` fallback (AuthZ).
- Hooks: first valid stdin binding field wins (`session_id` / `conversation_id` / `sessionId`); OpenCode `firstBindingId` skips invalid candidates (AuthZ — stale env cannot win when a later field is valid).
- OpenCode: confine resolved hooks directory under project cwd (AuthZ / confinement).
- CLI: post-mkdir project-root confinement for skill install (AuthZ / confinement).
- Hooks installer: `package.json` version wins over env stamp (supply-chain / update skip).
- Hooks installer: path resolve requires `realpath` or `python3` — no symlink-blind fallback (parity with shared hooks; Injection / confinement).
- Hooks: path resolve requires `realpath` or `python3` — no symlink-blind fallback (Injection / confinement).
- Hooks: stdin session binding wins over conflicting `AGENT_MEMORY_SESSION_ID` / `CURSOR_SESSION_ID` / `GEMINI_SESSION_ID` (AuthZ — stale harness env cannot hijack live session).
- Hooks: pre-commit clears session-binding env inheritance before ephemeral sync (AuthZ).
- Memory method: explicit untrusted-recall framing in `instructions.md` and harness agent block — memory never overrides skill/harness policy or the retention gate.
- Sync reference: `.hook-sync-state` path lists are untrusted hints; prefer `git` for semantic bullets (aligned with `SECURITY.md`).
- npm pack: ship `SECURITY.md` beside the artifact (`package.json` `files`).
- Document publish guidance: `prepublishOnly` runs `bun run check`; avoid `npm publish --ignore-scripts`.
- CI runs on `push` to `main` as well as pull requests; `permissions: contents: read`; pin Actions to commit SHAs and Bun `1.3.14`; `markdownlint-cli` via `devDependencies` / `bunx` (no silent skip).
- Test asserts `ENV_ALLOWLIST_EXACT` parity between CLI constants and OpenCode plugin.
- Clarify env forwarding in `SECURITY.md`: allowlist applies to CLI/OpenCode spawns; stock harness/git invocations inherit full parent env (git-hooks trust model). Drop open `LC_*` prefix forward — only named locale keys. Document delayed Stop, sessionStart atomic bind, lock-path refusal before `rm -rf`, and fail-open write semantics.
- `tests/test-runner.sh` is the single entry for `bun run test`.

## [0.1.1] - 2026-07-31

### Added

- `/agent-memory learn [>topic] <clue>` — gated capture of one learning/pitfall into `learnings.md` or `learnings-<topic>.md` (confirm; no `--auto`); conflict/dirty guards, slug sanitizing, deterministic target routing, and duplicate-rule skip.
- Topic-split convention for learnings (`learnings-<topic>.md`) with optional `when editing:` scope hints in `index.md` — normative match contract in `instructions.md` (_Always load_).
- H2 learning/pitfall entry format (aligned with decisions), legacy one-liner kept valid, duplicate rule across formats, and writing guidance (generalize; prefer correct patterns).

### Security

- OpenCode plugin: refuse symlink hook scripts, confine resolved paths under `.opencode/hooks`, and validate session/conversation binding IDs before env/stdin.
- Document trust boundary and intentional capabilities in `SECURITY.md`.

### Changed

- `instructions.md` slimmed for always-load: permission boundaries, numbered precedence, task-organized sections, observable turn closure, and formats linked to templates (`TEMPLATE.md`, `log.md`, `decisions.md`) instead of duplicated inventories.
- Learning/pitfall format and topic-split / scope-hint policy documented in `instructions.md` and `index.md`; `bootstrap` / `sync` / `lint` / `consolidate` aligned.
- CLI build publishes `bin/cli.js` without minify for supply-chain auditability.
- Cross-package docs pin `hooks/README.md` / examples to `0.1.1`.

## [0.1.0] - 2026-07-27

### Breaking

- Hooks no longer write any Markdown under `.agents/memory/`. Consumers that relied on hook-authored `log.md` headings/path bullets, `active-work` _Touched files_, Task stubs, or `current.md` _In progress_ refresh must reinstall hooks and treat all versioned memory as agent-owned (primary write in-turn; `/agent-memory sync` is catch-up only).
- Per-tool hook events (`postToolUse`, `afterFileEdit`, `PostToolUse`, `AfterTool`) are removed from all harness configs. Reinstall hooks so configs scrub legacy ours entries; path evidence comes only from full checkpoints via git into `.hook-sync-state`.
- Active-work drops the `Touched files` section. Path lists live only in gitignored `.hook-sync-state` for `/agent-memory sync` / agent evidence — existing branch files should migrate via `/agent-memory update` + `consolidate`.
- OpenCode plugin no longer synthesizes sessionStart / day-coalesced `log.md` headings. Context is the AGENTS.md carrier; idle/compact only update ephemeral state. Reinstall the OpenCode plugin + scripts.

### Added

- Resumable active-work sections: `Next step`, `Validation`, `Assumptions / open questions`, `Rejected approaches`, `References`, and a `Checkpoint: date @ sha` freshness line.
- Decision format fields: `Status`, `Supersedes` / `Superseded by`, and `Rejected` alternatives.
- Optional `learnings.md` pitfall entries with `evidence`, `use when`, `verified`, and `invalidate when`.
- Portable lock + atomic writes for `.hook-sync-state`.
- Commit-range evidence collection (`last_processed_head..HEAD`) with rewrite fallback.
- Expanded test matrix: version parity, installer merge, CLI headless, ephemeral hooks (no Markdown writes), and security fixtures.
- CI for Linux/macOS with Bun frozen lockfile, typecheck, markdownlint, tests, build, and Node 18/20/22 CLI smoke.
- Contextual `sessionStart` status (branch, Checkpoint freshness, pending path count) in the hooks message — still no Markdown writes.
- `lint` warnings: `stale-resume` (Checkpoint vs HEAD) and `evidence-pending` (paths in `.hook-sync-state`).
- Git `pre-commit` non-blocking reminder when active-work Checkpoint is behind HEAD.

### Changed

- Hooks are **ephemeral evidence only** — they write `.hook-sync-state` and never edit Markdown under `.agents/memory/`.
- OpenCode plugin runs idle/compact sync only; context comes from the AGENTS.md carrier.
- `log.md` is semantic outcomes only — no path bullets or empty headings from hooks.
- Workflow clarified: **primary write** is in-turn (agent owns meaning); `/agent-memory sync` is **catch-up** (may follow `references/sync.md` without invoking the skill).
- Agent-memory block, READMEs, and skill help aligned with primary write vs catch-up.
- Cross-package docs pin `hooks/README.md` / examples to `0.1.0`.
- Bun is the sole package manager (`bun.lock`); `package-lock.json` is ignored.
- CLI source split into `lib/cli/` modules (filesystem install, semver, detect, hooks spawn, TTY); `install.ts` remains the entrypoint.
- Hook config merge drops legacy per-tool **ours** entries on reinstall while preserving custom hooks on those events.

### Fixed

- Skill install/update replaces the destination directory atomically so obsolete files from prior skill versions are removed.
- Multi-commit ranges since `last_processed_head` are collected instead of only the tip commit.
- `init` / `update` explicitly ensure `.agents/memory/.gitignore` from vendor (dotfiles are often omitted by Glob); `lint` reports when it is missing.
- Hook state fallback prefers canonical `session_binding` over stale `current_session_id` (and does not resurrect an id when binding is `__no_id__`).
- Session rebind clears paths and updates `session_binding` under one lock (fail-open skips both — never wipe paths while leaving the old binding).

### Removed

- Hook Markdown writes: session log headings, path bullets, `Touched files` sections, Task stubs, and `current.md` _In progress_ refresh.
- Per-tool hook events from harness configs (`postToolUse`, `afterFileEdit`, `PostToolUse`, `AfterTool`).

## [0.0.14] - 2026-07-20

### Added

- `/agent-memory consolidate` — guided promotion and pruning of closed-session noise (confirm each diff; no `--auto`; never from hooks/sync/lint).
- Optional on-demand `learnings.md` for evidenced facts with no better canonical source (`pending-doc` when an external doc is still needed).
- `tests/reference-first-contract.sh` and `tests/hooks-checkpoint.sh`; `bun run test` runs both.
- New Bun-built CLI (`install.ts` → `bin/cli.js`):
  - `install skill` — copy packaged skill to `.agents/skills/agent-memory/` (replaces `npx skills add` as the primary path).
  - `install hooks` — headless one harness, or TTY multi-select (Space/Enter).
  - `install` / `install <harness>` — TTY menus for skill and/or hooks.
  - `update` / `update --yes` — refresh skill and/or installed hooks when behind `package.json` version; never edits `.agents/memory/` (points user to `/agent-memory update` or `init` **in the coding-agent chat**).
  - Colored output (`NO_COLOR` / `FORCE_COLOR`); clearer post-install Next steps.
- Hook installer stamps `$harnessHooksDir/.version` with `package.json` version (CLI `update` compares stamps to decide which harnesses to refresh).

### Changed

- Memory is a **recall layer**: prefer links/deltas over copying project docs, ADRs, or AGENTS content (reference-first contract).
- Slim always-load contract and skeleton templates (`instructions`, `index`, `current`, `log`, `decisions`, active-work template).
- Shorter harness agent-memory block and session-start hook message.
- `bootstrap` inventories sources/gaps (no vision/architecture/patterns mirrors); `sync` stays on four files; `lint` soft budgets, exact-dup warnings, and `## Format` allowlist in `log.md`; soft budgets live in the lint reference only.
- `current.md` drops Version/Done/Next — active state only.
- Cross-package pins and examples use `0.0.14` (including manual README `git clone --branch 0.0.14`).
- Removed `bin/agent-memory.js`; project build/test tooling is Bun-only (`bun run build` with `--minify`, `bun run test`).
- Single version SoT is `package.json` `version` (mirrored to `SKILL.md` `metadata.version`); CLI and hook stamps use that value.

### Fixed

- Hook `postToolUse` path: `run_posttool_checkpoint` defined before use.
- Broken section anchors after contract compression (`Workflow`, `Branch work`, harness parity).
- CLI package-root resolution uses `process.argv[1]` (avoids Bun baking a build-time `__dirname`, which broke `npx` consumers).
- CLI `update` refreshes installed hooks even when the skill is not present.
- `lint` no longer false-positives `bad-log-heading` on the skeleton `## Format` docs section in `log.md`.

## [0.0.13] - 2026-07-12

### Changed

- Package renamed to `@dosx/agent-memory` (was `agent-memory` (unscoped)).
- `npx @dosx/agent-memory` is hooks-only; skill install is via `npx skills add diegoos/agent-memory#<version> --skill agent-memory`. `install skill` redirects interactively; `install <harness>` shows a TTY menu (skill + hooks / skill only / hooks only). Removed skill flags and `install hook` alias. `runSkillsAdd` uses that tag-pinned remote source (not the npm package tarball path).
- Git tag / pin refs use `0.0.13` (no `v` prefix), matching published tags.
- Cross-package docs and vendor skeleton links pin `hooks/README.md` to `blob/0.0.13/`.

### Fixed

- Interactive CLI menu: EOF hang, CSI/ESC parsing, Alt+letter handling, and `try/finally` raw-mode cleanup.
- `run()` treats child `signal` / null status as failure so skill+hooks does not continue after a killed child; `shell: false` cannot be overridden via options spread.

## [0.0.12] - 2026-07-12

### Security

- Skill no longer clones or fetches remote content for `init` / `update` — the memory skeleton is **vendored** with the skill package (`vendor/`).
- Skill no longer writes or executes harness hook scripts; users install hooks via a reviewed `install-hooks.sh` or `npx` CLI (pinned release tag).
- OpenCode plugin and `npx` CLI forward an **allowlisted** environment to hook scripts / the installer (includes Windows and `XDG_*` / `GIT_CONFIG_*` keys).
- Installer refuses destination **and parent-directory symlinks** when copying scripts or merging JSON.
- Runtime hooks refuse `.agents/memory` symlink escape and symlink `.hook-sync-state`.
- CLI always uses `spawnSync` with `shell: false` and validates `--agent` names (`[A-Za-z0-9._-]+`) to avoid `cmd.exe` metacharacter injection on Windows.
- Hook `write_state` rejects keys/values with newlines; values may use RS (`\x1e`) as a multi-path delimiter (`session_touched_files`, `logged_files`). `normalize_repo_rel_path` rejects controls and `..` path segments.

### Added

- `hooks/install-hooks.sh` — canonical per-harness hook installer (copy shared scripts + merge host config); lives under repo-root `hooks/` (outside the skill).
- Root `package.json` + `bin/agent-memory.js` — `npx` entry for `install skill`, `install hooks <harness>`, and `install <harness>`.
- Repo-root `agent-memory/` directory moved to `skills/agent-memory/vendor/` (no compat symlink — edit vendor paths only).
- Lifecycle hooks package moved to repo-root `hooks/` (not shipped inside the skill directory).

### Changed

- Canonical skeleton / `UPDATE.md` live under `skills/agent-memory/vendor/`.
- `/agent-memory install hooks`, `init`, and `update` print user-run install instructions only (no agent-side hook copy/merge).
- Hook and skill docs updated for the dual installer and trust boundary.
- `npx` CLI installs the skill from the local checkout (or a tag-pinned GitHub tree URL), not unpinned `diegoos/agent-memory` HEAD.
- OpenCode plugin uses local calendar date (not UTC) for heading binding; env allowlist includes `TZ` and drops unused cross-harness project-dir vars.
- Skill `allowed-tools` allows read-only git used by `sync` / `lint` (`branch` / `status` / `diff` / `log`) instead of broad `Bash(git:*)`.
- Installer creates missing harness dirs (e.g. `.cursor/`); skill still never creates them.
- Cross-package docs link to tag-pinned GitHub `hooks/README.md` (not relative paths that break when the skill is installed alone).
- Installer copies shared scripts **before** merging host config so a failed copy cannot leave config pointing at missing files.
- `isOurs` merge matcher requires a product script basename as a path/token (not a bare substring mention such as `…agent-memory-sync.sh.example`).

### Fixed

- Nested merge (Claude / Codex / Gemini) scrubs only our entries inside `group.hooks[]`, preserving sibling custom hooks in the same group.
- CLI honors `AGENT_MEMORY_PROJECT_DIR` when set (falls back to `cwd`).
- Installer requires `PROJECT_DIR` to exist, then canonicalizes with `realpath` (same behavior with or without GNU/`python3` fallback).
- CLI `install <harness> -a <agent>` preserves valued flags for `skills add`.
- Installer writes merged configs via temp files beside the target (atomic replace).
- Git `pre-commit` uses `git rev-parse --show-toplevel` as project root (not `GIT_PREFIX`, which is the subdirectory where the user ran `git commit`).
- `ensure_active_work` / `add_touched_file` use the cached branch and skip redundant state writes when a path is already in `session_touched_files`.
- Full checkpoints normalize git paths through `normalize_repo_rel_path` before merging into session state.

## [0.0.11] - 2026-07-05

### Fixed

- OpenCode empty `log.md` headings when `ses_*` IDs rotate on idle/compaction — coalesce to one heading per calendar day, prune duplicate empty headings, and ensure headings exist in the file before binding state or appending bullets.

### Added

- **Harness parity — memory contract** in `instructions.md` — canonical split between hook evidence (paths, headings, _Touched files_) and agent meaning (semantic bullets, Task/Progress, `decisions.md`); harness timing table; same memory shape on every harness.
- `ensure_log_heading_for_checkpoint`, read-only session ID normalization, and OpenCode heading prune helpers in shared hook scripts.

### Changed

- OpenCode plugin skips redundant `sessionStart` when the day's bound heading already exists in `log.md`; compaction triggers sync only.
- `hooks/README.md` documents `agent-memory-hooks/` paths and links to the contract; `sync.md` references it instead of duplicating rules.
- `AGENTS.md` points to the contract as single source of truth.

## [0.0.10] - 2026-07-04

### Fixed

- Hook checkpoint regression from 0.0.8: incomplete `active-work` _Touched files_, stray path-only `log.md` bullets after summary lines, and loss of session paths when the working tree was clean at end-of-turn.
- First no-id sync clearing `session_touched_files` right after merge.
- Gemini `AfterTool` misrouted to full checkpoint instead of post-tool accumulate.

### Added

- Session-cumulative `session_touched_files` in `.hook-sync-state`; full checkpoints flush accumulated paths even with an empty git delta.
- Cursor **`afterFileEdit`** hook wiring (agent edits use top-level `file_path`, not `postToolUse`).
- `log_summary_mode` — no individual path bullets after a `changed N files…` summary in the same session.
- `AGENTS.md` **Known issues** section documenting the 0.0.8 regression and consumer upgrade path.

### Changed

- `postToolUse` / `afterFileEdit` update _Touched files_ only — no `log.md` file bullets until a full checkpoint.
- Shared hook stdin parser: `tool_input.file_path`, `tool_input.path`, top-level `file_path`.
- Branch switch clears session path accumulation.

## [0.0.9] - 2026-07-03

### Added

- Per-harness **native instruction files** on `init`: Cursor `.cursor/rules/agent-memory.mdc` (`alwaysApply: true`), Copilot `.github/instructions/agent-memory.instructions.md`, plus existing agent files for claude/codex/opencode/gemini.
- **Auto-detection** when running `/agent-memory init` without a harness — infers harness(es) from project markers; asks the user when inconclusive.
- **Carrier-file resolution** — avoids duplicate blocks when `CLAUDE.md`/`GEMINI.md` delegate to `AGENTS.md` via `@import` (claude + opencode canary).
- **Copilot coexistence** — skips dedicated `.instructions.md` when `AGENTS.md` already serves codex/opencode/claude-via-delegation.
- `lint` checks for potential double-injection and delegation-canary states.
- Copilot `.instructions.md` uses `applyTo: "**"` frontmatter (always-on); Cursor `.mdc` uses `alwaysApply: true`.
- `init` enforces prerequisite harness dirs and auto-detects via `.claude/` / `.gemini/` dirs too; `update` suggests `init` when the native context file is missing but hooks are wired.

### Changed

- `init` and `update` use harness-native targets instead of wiring every root agent file in auto mode.
- `update` refreshes `.mdc` and Copilot `.instructions.md` blocks; offers migration from legacy `AGENTS.md`-only installs.

### Reverted

- 0.0.6 decision to omit `.cursor/rules/agent-memory.mdc` — reintroduced as the Cursor **context layer** (hooks remain the checkpoint layer).

## [0.0.8] - 2026-07-03

### Added

- Gemini CLI is now a supported harness for lifecycle hooks.
  - New `hooks/gemini/settings.json` wiring `SessionStart`, `AfterTool`, `AfterAgent`, and `PreCompress`.
  - Recognition of `GEMINI_PROJECT_DIR` / `GEMINI_SESSION_ID`.
  - Dedicated host case in `agent-memory-session.sh` that emits strict JSON (`{"context": "..."}`).

### Changed

- **Hooks directory reorganized**: canonical scripts moved from `hooks/shared/` to `hooks/agent-memory-hooks/`. All install instructions, snippets, and references updated.
- **Significant performance improvement in hooks**: `postToolUse` no longer runs `git`. It records the file path reported by the harness in stdin (`tool_input.file_path` for `Write`/`Edit`). Full git reconciliation (Touched files + log bullets) happens on `afterAgentResponse` / `preCompact`.
- JSON parsing in hooks now prefers `jq` (spec-correct, handles escaping) with a sed regex fallback for environments without `jq`. Also extracts `tool_name` and file path.
- Branch resolution is cached (`refresh_branch_cache`) so the git-free postToolUse path can still produce correct `active-work/<branch>.md` names.
- Removed the previous postToolUse debounce mechanism (no longer required).

### Removed

- Obsolete `should_skip_posttool` / `files_hash` helpers and related state keys.

## [0.0.7] - 2026-06-30

### Added

- `hooks/shared/agent-memory-common.sh` — shared deterministic helpers sourced by session and sync hooks.
- Per-session `log.md` headings with optional session ID; hooks append file-path bullets once per file per session.
- Session-start refresh of `current.md` _In progress_ from open `active-work/` files.
- OpenCode plugin session-start bridge via `agent-memory-session.sh`.

### Changed

- `instructions.md` — per-file obligations (hooks vs agent); strengthened `decisions.md` recording requirement.
- Skeleton guidance in `log.md`, `current.md`, `decisions.md`, `index.md`, and `active-work/TEMPLATE.md`.
- `agent-block.md`, `bootstrap.md`, `init.md`, `sync.md`, and `hooks/README.md` aligned with hook behavior.
- `init` requires all three shared hook scripts (`common`, `sync`, `session`).

### Removed

- Legacy `.cursor-hook-state` entry from skeleton `.gitignore`.

## [0.0.6] - 2026-06-29

### Added

- `init` harness targets (`init cursor`, `init claude`, `init codex`, `init opencode`, `init copilot`, `init gemini`) and auto-detect mode; wires hooks only into harness dirs that already exist.
- Shared lifecycle hooks: `hooks/shared/agent-memory-sync.sh` and `agent-memory-session.sh` — deterministic git checkpoint (Touched files + conservative `log.md` append; no extra LLM request).
- Unified hook wiring for Cursor, Claude Code, Codex, Copilot, OpenCode, and git `pre-commit`.
- `agent-memory/memory/.gitignore` in the skeleton — ignores hook checkpoint state (`.hook-sync-state`).

### Changed

- Cursor integration is **hooks-only**; hooks are the recommended path (`@import` in `AGENTS.md` remains a no-op).
- `instructions.md` — _Plain-Markdown harnesses_ updated for hooks-only Cursor.
- `update` no longer refreshes `.cursor/rules/agent-memory.mdc`; optional manual removal of legacy rule files noted in the report.
- Documentation aligned across `agent-block.md`, READMEs, `SKILL.md`, and `hooks/README.md`.

### Removed

- `agent-memory-flush.sh` flush-reminder hooks (replaced by deterministic sync).
- Cursor `stop` + `followup_message` pattern (always started another LLM turn).

## [0.0.5] - 2026-06-26

### Added

- Opt-in flush-reminder hooks for Cursor, Claude Code, Codex, OpenCode, Copilot, and a host-agnostic git `pre-commit` hook (`skills/agent-memory/hooks/`).
- `sync --auto` and `lint --fix` documented in skill references.

### Changed

- Canonical agent-memory block now spells out **read AND write** obligation and explicit `Read .agents/memory/instructions.md` for plain-Markdown harnesses.
- Agent-memory block delimiters migrated to HTML comments (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`) — invisible in rendered Markdown, machine-identifiable in source.
- `instructions.md` — _Flush early_ names `sync --auto`; adds plain-Markdown harness note.
- Root and `agent-memory/README.md` rewritten as entry points; stub text points to `agent-block.md` as single source of truth.

## [0.0.4] - 2026-06-24

### Added

- `references/agent-block.md` — single source of truth for the agent-memory block wired into root agent files.

### Changed

- `init` wraps the memory block in `<agent-memory>` … `</agent-memory>` delimiters (later migrated to HTML comments in 0.0.5).
- `update` refreshes **only** the delimited block in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`; migrates legacy `## Agent Memory` sections.

## [0.0.3] - 2026-06-24

### Changed

- Unified agent-file stub for `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` — explicit always-load list plus `@.agents/memory/instructions.md` for `@import` harnesses and plain-Markdown readers.

## [0.0.2] - 2026-06-24

### Added

- `/agent-memory sync` — refresh `current.md`, branch `active-work`, `log.md`, and `index.md` Domains/Features from repo state.

### Changed

- `instructions.md` — _Workflow_ names `/agent-memory sync` as the executable trigger for During / After / Flush early steps.

## [0.0.1] - 2026-06-22

### Added

- Initial Agent Memory method, skill, and `.agents/memory/` skeleton.

[unreleased]: https://github.com/diegoos/agent-memory/compare/0.1.1...HEAD
[0.1.1]: https://github.com/diegoos/agent-memory/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/diegoos/agent-memory/compare/0.0.14...0.1.0
[0.0.14]: https://github.com/diegoos/agent-memory/compare/0.0.13...0.0.14
[0.0.13]: https://github.com/diegoos/agent-memory/compare/0.0.12...0.0.13
[0.0.12]: https://github.com/diegoos/agent-memory/compare/v0.0.11...v0.0.12
[0.0.11]: https://github.com/diegoos/agent-memory/compare/v0.0.10...v0.0.11
[0.0.10]: https://github.com/diegoos/agent-memory/compare/v0.0.9...v0.0.10
[0.0.9]: https://github.com/diegoos/agent-memory/compare/v0.0.8...v0.0.9
[0.0.8]: https://github.com/diegoos/agent-memory/compare/v0.0.7...v0.0.8
[0.0.7]: https://github.com/diegoos/agent-memory/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/diegoos/agent-memory/compare/v0.0.5...v0.0.6
