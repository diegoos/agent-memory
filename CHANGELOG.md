# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Migration details for `/agent-memory update` live in [`skills/agent-memory/vendor/UPDATE.md`](skills/agent-memory/vendor/UPDATE.md) (machine-oriented `safe` / `sensitive` tags). This changelog is the human-oriented release history — keep both in sync on version bumps.

## [Unreleased]

### Fixed

- Hooks: `_rebind_session_state_unlocked` preserves `session_binding_host` from `.hook-sync-state` when `AGENT_MEMORY_HOST` is unset; sync harness configs now set `AGENT_MEMORY_HOST` on checkpoint commands (re-run hooks installer to pick up).
- Hooks: `refresh_branch_cache` updates `branch` and clears `session_touched_files` under one lock; fail-open skips both (no path wipe without branch update).

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
