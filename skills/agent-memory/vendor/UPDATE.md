# agent-memory — Update migrations

Migration log for `/agent-memory update`. One section per released version, newest at the bottom. Each line is a single change tagged `safe` or `sensitive`:

- `safe` — pure addition or a scaffolding change with no user content at risk. `update` may apply it automatically.
- `sensitive` — touches a file that can hold user content, or renames/moves/deletes anything. `update` must show a diff and get confirmation first.

Format:

```md
## <version>

- safe: <change>
- sensitive: <change>
```

---

## 0.0.1

- safe: initial baseline — no migrations.

## 0.0.2

- safe: add `sync` command (`references/sync.md`) — refreshes `current.md`, the branch's `active-work/<branch>.md`, `log.md`, and the Domains/Features lists of `index.md` from repo state. New command in the skill only; no existing memory file is renamed or moved.
- safe: `SKILL.md` routing and help updated to list `sync`.
- sensitive: `instructions.md` — the _Workflow_ section now names `/agent-memory sync` as the executable trigger for the _During_ / _After_ / _Flush early_ steps. `update` must show the diff and confirm.

## 0.0.3

- safe: unify the agent-file stub in `references/init.md` — `AGENTS.md` now gets the same stub as `CLAUDE.md` / `GEMINI.md`, with both the explicit always-load list and `@.agents/memory/instructions.md`. Covers harnesses that read `AGENTS.md` via `@import` (Claude Code, Gemini CLI, Codex) and those that read it as plain Markdown (Cursor).
- safe: `agent-memory/README.md` and root `README.md` — the documented stub is now the single unified one.

## 0.0.4

- safe: wrap the memory block in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` with `<agent-memory>` … `</agent-memory>` delimiters (`references/init.md`), so the block is machine-identifiable.
- sensitive: `references/update.md` — `update` now refreshes **only** the `<agent-memory>` block in the root agent files (replacing it with the canonical block), and migrates legacy `## Agent Memory` sections into the delimited block. Never touches content outside the delimiters. Show the diff and confirm before applying.
- safe: `agent-memory/README.md` and root `README.md` — the documented stub is now the delimited block.
- safe: extract the canonical `<agent-memory>` block into a new reference, `references/agent-block.md`, as the single source of truth.
- safe: `references/init.md` and `references/update.md` now reference `agent-block.md` instead of inlining the block text. `update` compares the installed block against the canonical block byte-for-byte and skips when identical.

## 0.0.5

- sensitive: `references/agent-block.md` — the canonical `<agent-memory>` block now instructs the agent to **Read** `.agents/memory/instructions.md` (not just "open and follow") and spells out the read-AND-write obligation (keep `active-work`, `log.md`, `decisions.md`, `current.md` current; delete `active-work` on merge; run `/agent-memory sync` at checkpoints). Fixes the case where plain-Markdown harnesses (Cursor) never load `instructions.md` via `@import` and so never maintain the memory. `update` compares the block byte-for-byte and will propose the refresh as a sensitive diff.
- safe: `references/agent-block.md` — "Why both the read list and `@import`" rewritten to explain the Cursor/plain-Markdown load path. No file rename or move.
- sensitive: `agent-memory/memory/instructions.md` — the _Flush early_ section now names `Read` as the load verb, calls out `sync --auto` for low-friction checkpoints, and adds a _Cursor and other plain-Markdown harnesses_ note.
- safe: `references/sync.md` — documents the `--auto` flag (apply all proposed diffs without per-file `AskQuestion`), plus an `--auto` steps variant. No existing file renamed or moved.
- safe: `references/lint.md` — documents `--fix` for the safe removal of stale per-branch `active-work` files (branch gone). Confirms each deletion.
- safe: `agent-memory/README.md` and root `README.md` — rewritten as clearer entry points (Quick start, "How agents use it", "Keeping the memory current" with a hooks link). They no longer inline the `<agent-memory>` stub; both point to `references/agent-block.md` as the single source, which removes the doc/canonical drift for good.
- safe: add `skills/agent-memory/hooks/` with opt-in flush-reminder hooks for Cursor, Claude Code, Codex, OpenCode, Copilot (CLI + cloud agent), plus a host-agnostic git `pre-commit` reminder and a shared reminder script. Hooks are non-blocking reminders only — they never write to the memory, never block the agent, and recommend `/agent-memory sync` (per-file confirmed), not `--auto`, so they cannot cause memory inconsistency or loops. Includes a `README.md` with a per-host matrix and install instructions. Optional, opt-in; not wired by `init`.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.5`; `help` text mentions `--auto` and `--fix`.
- sensitive: `references/agent-block.md` — delimiters changed from plain `<agent-memory>` … `</agent-memory>` tags to HTML comments `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` so the block is machine-identifiable but invisible in rendered Markdown. `update` compares the block byte-for-byte and will propose the refresh as a sensitive diff; it also migrates legacy plain-tag blocks to the comment form.
- safe: `references/init.md`, `references/update.md`, `SKILL.md`, root `README.md`, `agent-memory/README.md`, and `instructions.md` — documentation updated for the new delimiters and legacy migration path. No file rename or move.

## 0.0.6

- safe: `references/init.md` — `init` accepts an optional harness target (`init cursor`, `init claude`, `init codex`, `init opencode`, `init copilot`, `init gemini`) or auto-detects from existing agent files and harness dirs. Wires shared lifecycle hooks into existing harness dirs only (never creates `.cursor/`, `.claude/`, etc.).
- safe: add `hooks/shared/agent-memory-sync.sh` and `hooks/shared/agent-memory-session.sh` — deterministic git checkpoint (Touched files + conservative `log.md` append; no LLM). Replaces flush-reminder hooks (`agent-memory-flush.sh` removed).
- safe: unify harness hooks on the shared scripts — Cursor (`sessionStart`, `postToolUse`, `afterAgentResponse`, `preCompact`; no `stop` + `followup_message`), Claude Code (`SessionStart`, `PostToolUse`, `Stop`, `PreCompact`), Codex, Copilot, OpenCode plugin, git `pre-commit`.
- safe: Cursor integration is **hooks-only** — no `.cursor/rules/agent-memory.mdc` ( `@import` in `AGENTS.md` remains a no-op). Root `README.md` and `hooks/README.md` document hooks as the recommended Cursor path.
- sensitive: `agent-memory/memory/instructions.md` — _Plain-Markdown harnesses_ section updated for hooks-only Cursor integration.
- safe: `references/update.md` — drop Cursor rule refresh step; note optional removal of legacy `.cursor/rules/agent-memory.mdc`.
- safe: `references/agent-block.md`, root `README.md`, `agent-memory/README.md`, `SKILL.md` help/routing/allowed-tools — aligned with harness `init` and unified hooks.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.6`.
- safe: add `agent-memory/memory/.gitignore` — ignores hook checkpoint state (`.hook-sync-state`). Shipped with the skeleton; `init` copies it; `update` creates it when missing.

## 0.0.7

- safe: add `hooks/shared/agent-memory-common.sh` — shared helpers sourced by sync and session hooks (session ID, log headings, active-work/current.md refresh). `init` must copy all three shared scripts together.
- safe: refactor `agent-memory-sync.sh` and `agent-memory-session.sh` to source `agent-memory-common.sh`; session hook refreshes `current.md` _In progress_ on session start.
- safe: hooks append file-path bullets under per-session `log.md` headings (session ID when available); no-id sessions and session-ID promotion from type-tag headings.
- safe: OpenCode plugin bridges session start to `agent-memory-session.sh`; install all three shared scripts under `.opencode/hooks/`.
- safe: `references/init.md`, `hooks/README.md`, `SKILL.md` allowed-tools — three-script hook install documented.
- sensitive: `agent-memory/memory/instructions.md` — _Obligations by file_ section (hook vs agent per file); per-session `log.md` contract.
- sensitive: `agent-memory/memory/log.md` — per-session heading format (`## [date] [session-id] [type] summary`).
- sensitive: `agent-memory/memory/decisions.md` — mandatory ADR-style recording when decisions change.
- sensitive: `agent-memory/memory/current.md`, `index.md`, `active-work/TEMPLATE.md` — clearer hook vs agent responsibilities.
- sensitive: `references/agent-block.md` — obligations aligned with `instructions.md`.
- safe: `references/bootstrap.md`, `references/sync.md` — vision gate, per-session log format, `index.md` alignment.
- safe: `agent-memory/memory/.gitignore` — drop legacy `.cursor-hook-state` entry.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.7`.

## 0.0.8

- sensitive: hooks scripts directory renamed from `hooks/shared/` to `hooks/agent-memory-hooks/`. All three canonical scripts now live under the new path. `install hooks`, `update`, and manual copy instructions updated. Projects with manually copied old-path scripts must re-install from the new location.
- safe: `parse_hook_stdin` prefers `jq` when present (with sed fallback) for robust extraction of `session_id`/`conversation_id`/`sessionId`, `cwd`, `tool_name`, and `tool_input.file_path`.
- safe: `postToolUse` is git-free for file edits — it records the path supplied by the harness via stdin (`Write`/`Edit` tool_input). `Shell` invocations are no-ops at this stage (reconciled later).
- safe: branch name is cached at session start and full checkpoints (`refresh_branch_cache`); `sanitize_branch` and postToolUse no longer run `git branch --show-current`.
- safe: new `add_touched_file` helper for incremental Touched files updates from single file paths (used by the git-free postToolUse path).
- safe: full Gemini CLI hooks support:
  - new `hooks/gemini/settings.json` (SessionStart, AfterTool, AfterAgent, PreCompress)
  - `GEMINI_PROJECT_DIR` and `GEMINI_SESSION_ID` recognized
  - dedicated `gemini` host handling in `agent-memory-session.sh` (strict JSON output per Gemini CLI rules)
- safe: removed postToolUse debounce helpers (`should_skip_posttool`, `files_hash`, related state keys) — no longer needed.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.8`.
- safe: documentation refreshed (`hooks/README.md`, `references/install-hooks.md`, `init.md`, `SKILL.md` help text, harness snippets, etc.) for new directory layout and Gemini support.

## 0.0.9

- safe: `init` writes the agent-memory block into each harness's **native instruction file** — Cursor `.cursor/rules/agent-memory.mdc` (`alwaysApply: true`), Copilot `.github/instructions/agent-memory.instructions.md`, claude/codex/opencode/gemini via their agent files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`).
- safe: `init` without `<harness>` **auto-detects** harnesses from project file markers (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, Copilot markers, `AGENTS.md` + `.codex/` or `.opencode/`); asks the user when detection is inconclusive.
- safe: **carrier-file resolution** — when `CLAUDE.md`/`GEMINI.md` delegates via `@AGENTS.md`, write the block once in `AGENTS.md` (claude+opencode canary); skip the delegating file.
- safe: **Copilot coexistence** — when `AGENTS.md` is already a carrier for codex/opencode/claude-via-delegation, skip creating `.github/instructions/agent-memory.instructions.md` (Copilot loads `AGENTS.md` too).
- safe: `update` refreshes blocks in `.cursor/rules/agent-memory.mdc` and `.github/instructions/agent-memory.instructions.md` (body only; preserve frontmatter — `alwaysApply: true` for Cursor, `applyTo: "**"` for Copilot).
- safe: Copilot `.instructions.md` requires `applyTo: "**"` frontmatter to be always-on (path-specific files apply only to files matching `applyTo`); without it the block may never reach the model. Documented in `agent-block.md` and wired by `init`.
- safe: `init` enforces **prerequisite harness dirs** for cursor/copilot natives (`.cursor/`, `.github/`) — does not create harness roots by default; stops and asks the user, creating the root only on explicit request. Subdirectories (`.cursor/rules/`, `.github/instructions/`) may be created inside an existing (or explicitly created) harness dir.
- safe: auto-detection recognizes `.claude/` and `.gemini/` (dirs) as secondary markers alongside `CLAUDE.md` / `GEMINI.md`.
- safe: `update` report suggests `init <harness>` when hooks are wired but the native instruction file is missing (e.g. `.cursor/hooks/` present, `.cursor/rules/agent-memory.mdc` absent).
- safe: `lint` instruction-wiring checks run from the **project root** (not `.agents/memory/`); `test -o` replaced with `|| test` for POSIX portability.
- safe: root `README.md`, `agent-memory/README.md`, and `hooks/README.md` updated for per-harness natives, auto-detection, and the Cursor/Copilot context-vs-checkpoint layers.
- safe: `references/init.md`, `references/update.md`, `references/agent-block.md`, `references/lint.md`, `SKILL.md` (0.0.9, allowed-tools, write boundary), and help text aligned with per-harness natives and auto-detection.
- sensitive: `update` may **move** the block from `AGENTS.md` to cursor/copilot natives for older installs (when `AGENTS.md` is not a shared carrier); show diff and confirm.
- sensitive: `update` may **remove** duplicate blocks from `CLAUDE.md`/`GEMINI.md` that delegate via `@AGENTS.md` when `AGENTS.md` already has the block (delegation canary cleanup); show diff and confirm.
- sensitive: reverts 0.0.6 "Cursor hooks-only, no `.mdc`" — `.mdc` reintroduced as the **context layer** (always-on rules); hooks remain the **checkpoint layer**. `instructions.md` _Plain-Markdown harnesses_ updated.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.9`.

## 0.0.10

- safe: **session-cumulative _Touched files_** — hooks accumulate paths in `.hook-sync-state` (`session_touched_files`) for the active session instead of replacing the section with each git delta; full checkpoints flush even when the working tree is clean.
- safe: **`postToolUse` / `afterFileEdit` no longer write `log.md` bullets** — file-path bullets are appended only on full checkpoints (`afterAgentResponse`, `preCompact`, `precommit`, etc.); semantic bullets remain agent-owned (`/agent-memory sync`).
- safe: after a summary bullet (`changed N files…`), suppress further individual path bullets in the same session (`log_summary_mode`).
- safe: shared stdin parser accepts `tool_input.file_path`, `tool_input.path` (Copilot), and top-level `file_path` (Cursor `afterFileEdit`).
- safe: **Gemini event mapping** — `AfterTool` → post-tool accumulate; `AfterAgent` / `PreCompress` → full git checkpoint (was misrouted to end-of-turn default).
- safe: **branch switch** clears session path accumulation when the cached branch changes mid-session.
- safe: fix first no-id sync clearing `session_touched_files` immediately after merge (regression from 0.0.8 path-state reset).
- safe: `hooks/cursor/hooks.json` adds **`afterFileEdit`** (Cursor agent edits fire this hook with top-level `file_path`; `postToolUse` matches `Write|Shell` only per Cursor docs).
- safe: `hooks/README.md`, `references/install-hooks.md`, `instructions.md`, and `AGENTS.md` (Known issues) updated for hook checkpoint behavior and consumer upgrade path.
- sensitive: **`update` / `install hooks cursor`** must merge `afterFileEdit` into the project's `.cursor/hooks.json` when refreshing Cursor hooks — show diff and confirm if the user has custom hook entries. **Superseded** — hooks refresh is user-run installer only (skill prints instructions; no agent merge).
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.10`.

## 0.0.11

- safe: **OpenCode log heading coalescence** — one `log.md` heading per calendar day when `ses_*` IDs rotate; `opencode_log_heading_id` in `.hook-sync-state` maps later IDs to the bound heading.
- safe: **`ensure_log_heading_for_checkpoint`** — creates the session heading in `log.md` before appending bullets or binding state (state-only binding no longer leaves orphan headings).
- safe: **`normalize_session_id_for_checkpoint`** — read-only ID resolution; does not write `.hook-sync-state` without a corresponding heading.
- safe: **`prune_empty_opencode_session_headings`** — removes duplicate empty same-day `ses_*` headings when binding the canonical day heading.
- safe: OpenCode plugin — skip redundant `sessionStart` when the bound heading **exists in `log.md`**; compaction runs sync only (no synthetic session start).
- safe: `hooks/README.md` — canonical paths under `agent-memory-hooks/`; link to harness parity contract (do not duplicate the contract text).
- safe: `references/sync.md` — links to _Harness parity — memory contract_ in `instructions.md`.
- safe: root `AGENTS.md` — harness parity single source of truth; OpenCode empty heading fix documented for this repo's dogfooding.
- sensitive: `agent-memory/memory/instructions.md` — new _Harness parity — memory contract_ section (hooks vs agent writes, evidence vs meaning split, harness timing table, OpenCode heading rule). `update` must show the diff and confirm.
- sensitive: `agent-memory/memory/log.md` — OpenCode coalescence note under the per-session heading rules. `update` must show the diff and confirm.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.11`.

## 0.0.12

- safe: **Vendor + dual installers** — memory skeleton / `UPDATE.md` under `skills/agent-memory/vendor/`; lifecycle hooks under repo-root `hooks/`; `hooks/install-hooks.sh` + `bin/agent-memory.js` (`npx`) for user-run install. Skill prints hook-install instructions only (no agent-side hook copy/merge). Repo-root `agent-memory/` path removed — edit `skills/agent-memory/vendor/` only (older UPDATE entries that say `agent-memory/memory/…` map to `vendor/memory/…`).
- safe: Installer refuses destination **and parent-directory symlinks**; copies shared scripts before merging host JSON; requires existing `PROJECT_DIR` then `realpath`.
- safe: Runtime hooks refuse `.agents/memory` symlink escape, symlink paths under memory, and symlink `.hook-sync-state`; `write_state` accepts RS (`\x1e`) multi-value delimiters.
- safe: **Supersedes 0.0.10 sensitive** — Cursor `afterFileEdit` / hooks.json refresh is **user-run installer only** (`npx` / `install-hooks.sh`); the skill prints instructions and does not agent-merge hook config.
- safe: Nested / flat JSON merge matches product script path tokens only (not bare filename mentions); preserves sibling custom hooks in nested groups.
- safe: CLI `shell: false`, validates `--agent` charset, expanded env allowlist (Windows / `XDG_*` / `GIT_CONFIG_*`); OpenCode plugin allowlist aligned.
- safe: `write_state` / `normalize_repo_rel_path` reject newlines and `..` path segments; `normalize_repo_rel_path` also rejects `\x1e` in individual paths; `pre-commit` uses `git rev-parse --show-toplevel`.
- safe: `ensure_active_work` prefers branch cache; `add_touched_file` no-ops when the path is already in `session_touched_files`; full checkpoints normalize git paths before merging session state.
- safe: Cross-package docs pin `hooks/README.md` / `npx` examples to `v0.0.12`.
- safe: root `README.md` — `skills add` primary; pinned `npx` for hooks / alt skill.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.12`.
- safe: root `package.json` — version bumped to `0.0.12`.

## 0.0.13

- safe: npm package renamed to `@dosx/agent-memory` (was unscoped `agent-memory`). CLI is hooks-only; skill install is via `npx skills add diegoos/agent-memory#<version> --skill agent-memory`. `install skill` redirects interactively; `install <harness>` shows a TTY menu. Removed CLI skill flags and `install hook` alias.
- safe: `runSkillsAdd` uses tag-pinned remote source (`diegoos/agent-memory#${VERSION}`, no `v` prefix); not the npm tarball path.
- safe: Interactive menu resilience — EOF handler, CSI/ESC parsing, Alt+letter, `try/finally` raw-mode cleanup; `run()` fails on child signal/null status; `shell: false` after options spread.
- safe: Cross-package docs / vendor skeleton pin `hooks/README.md` and examples to `0.0.13` (blob / github / skills add).
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.13`.
- safe: root `package.json` — version bumped to `0.0.13`.

## 0.0.14

- sensitive: `instructions.md` — rewritten as a concise recall-layer contract (authority by fact type, retention gate, minimum formats, slim harness parity). Preserve any project-specific notes the user added outside the method; show the full diff and confirm.
- sensitive: `index.md` — map of canonical sources + recall files (no Domains/Features taxonomy). Merge structural headings; **preserve** the user's _Canonical project sources_ and _Recall files_ lists (including `learnings.md` / topic splits). Do not delete legacy mirror files.
- sensitive: `current.md` — shared active snapshot only (`In progress`, `Blockers / attention`, `Handoff`). If legacy `Version / milestone`, `Done`, or `Next steps` sections exist, propose removing them after confirming any still-useful bullets move to a canonical source, handoff, or are discarded. Preserve the `## In progress` heading (hooks require it).
- sensitive: `log.md` / `decisions.md` / `active-work/TEMPLATE.md` — concise reference-first templates. Preserve existing session entries, decisions, and per-branch active-work files; only refresh scaffolding/instructions text and missing required headings.
- sensitive: harness agent-memory block — shorter recall-layer block from `references/agent-block.md` (Read instructions; links/deltas; sync; consolidate). Refresh delimited blocks with confirmation.
- safe: add `/agent-memory consolidate` (`references/consolidate.md`) — guided promote/prune; no `--auto`; never run from hooks/sync/lint.
- safe: `bootstrap` / `sync` / `lint` references — inventory-first bootstrap, no doc copies; sync four-file boundary; lint soft budgets + legacy/dup checks; promotion deferred to consolidate.
- safe: hooks session message + hooks README — recall-layer context; same checkpoint fields. **User must re-run the hooks installer** to pick up the new session `msg` and any shared-script comment/doc refresh.
- safe: Cross-package docs pin `hooks/README.md` / examples to `0.0.14`.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.0.14`; routing includes `consolidate`.
- safe: root `package.json` — version bumped to `0.0.14`; `bun run test` runs contract + hooks checkpoint fixtures.
- safe: CLI — `install.ts` → `bin/cli.js` (Bun); `install skill` / `install hooks` / `update`; hook `$hooksDir/.version` stamps; `package.json` version is SoT. Re-run `npx @dosx/agent-memory update` (or install) after upgrading the npm package. Memory migration remains `/agent-memory update` in-agent.

## 0.1.0

- sensitive: `instructions.md` — ephemeral-hooks contract (hooks never write Markdown); resumable active-work only; checkpoint freshness (`Checkpoint: date @ sha`); facts vs assumptions; rejected approaches; learning/pitfall formats; on-demand decisions/log/learnings; **primary write** (in-turn) vs **catch-up** (`/agent-memory sync`, or follow `references/sync.md` without invoking the skill). Show full diff and confirm. Preserve any project-specific notes outside the method text.
- sensitive: `active-work/TEMPLATE.md` — replace with resume sections (`Task`, `Progress`, `Next step`, `Validation`, `Assumptions / open questions`, `Blockers`, `Rejected approaches`, `References`); remove `Touched files`. For existing `active-work/*.md`: add missing sections; offer to remove legacy `## Touched files` (sensitive — show diff, confirm). Preserve semantic Task/Progress/Blockers/Notes content.
- sensitive: `log.md` scaffolding — semantic outcomes only; document that hooks never write this file. Preserve existing session entries. Offer to remove legacy path-only bullets and empty closed-session headings via consolidate (confirm). Do not invent new headings.
- sensitive: `decisions.md` scaffolding — add `Status`, `Supersedes` / `Superseded by`, and `Rejected alternatives` fields to format docs. Preserve existing decision bodies.
- sensitive: `index.md` / `current.md` — align wording with resumable active-work and optional learnings/pitfalls. Preserve user source/recall lists and In progress bullets.
- sensitive: harness agent-memory block — refresh from `references/agent-block.md` (primary write + catch-up sync + consolidate). Confirm per file.
- safe: hooks rewritten as **ephemeral evidence only** (`.hook-sync-state`); no Markdown writes; per-tool events removed from harness configs; OpenCode plugin runs idle/compact sync only. Reinstall scrub also drops legacy per-tool **ours** entries via `hooks/lib/merge-hooks.mjs`. **User must re-run the hooks installer** for every installed harness.
- safe: hooks `sessionStart` message — contextual `Status:` (branch, Checkpoint freshness, pending path count); still no Markdown writes. **Re-run the hooks installer** to pick up.
- safe: git `pre-commit` — non-blocking stderr reminder when active-work Checkpoint is behind HEAD (in addition to the no-memory-staged reminder). **Re-run the hooks installer** (or refresh `.git/hooks/pre-commit`) to pick up.
- safe: `resolve_session_id` state fallback — prefer canonical `session_binding` over `current_session_id`; when binding is `__no_id__`, do not resurrect a stale current id. **Re-run the hooks installer** to pick up.
- safe: session rebind — clear paths + write `session_binding` atomically under one lock; fail-open skips both. **Re-run the hooks installer** to pick up.
- safe: `sync` / `lint` / `consolidate` / `bootstrap` references — consume hook state as evidence; resume quality checks; legacy Touched files / path-bullet cleanup; pitfall entries; sync documented as catch-up; lint `stale-resume` / `evidence-pending` warnings.
- safe: Cross-package docs pin `hooks/README.md` / examples to `0.1.0`.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.1.0`.
- safe: root `package.json` — version bumped to `0.1.0`.
- safe: `init` / `update` — explicitly ensure `.agents/memory/.gitignore` from `vendor/memory/.gitignore` (dotfiles are often omitted by Glob); `update` creates/refreshes it when missing or incomplete.

## 0.1.1

- sensitive: `instructions.md` — slimmed always-load (permission boundaries, numbered precedence, task-organized sections, observable turn closure); formats linked to templates; normative `when editing:` contract; H2 learning/pitfall format + legacy one-liner + duplicate rule; topic-split / scope-hint policy; `/agent-memory learn` as gated capture path. Show full diff and confirm. Preserve any project-specific notes outside the method text.
- sensitive: `index.md` — recall files document topic splits (`learnings-<topic>.md`) and optional `when editing:` hints (generic shape). Preserve user source/recall lists.
- safe: `learn` command (`references/learn.md`) — gated capture into `learnings.md` / `learnings-<topic>.md`; conflict/dirty guards; slug sanitize; deterministic routing; duplicate-rule skip. Skill routing + help updated; shared-rules exception for in-turn / bootstrap / learn primary write.
- safe: `bootstrap` / `sync` / `lint` / `consolidate` / `update` references — H2 format; topic splits; `when editing:` preserve/validate; consolidate split/merge converts moved entries to H2.
- safe: OpenCode plugin — refuse symlink hook scripts; confine resolved paths under `.opencode/hooks`; validate session/conversation binding IDs. **User must re-run the hooks installer** for OpenCode.
- safe: Document trust boundary in `SECURITY.md` (package docs; no consumer memory change).
- safe: CLI build publishes `bin/cli.js` without minify for supply-chain auditability. Re-run `npx @dosx/agent-memory update` (or install) after upgrading the npm package. Memory migration remains `/agent-memory update` in-agent.
- safe: Cross-package docs pin `hooks/README.md` / examples to `0.1.1`.
- safe: `skills/agent-memory/SKILL.md` — version bumped to `0.1.1`.
- safe: root `package.json` — version bumped to `0.1.1`.

## 0.2.0

- sensitive: `instructions.md` — primary-write triggers; concise _How to write_; sync meaning sources; **must consume** pending paths when eligible; Checkpoint plain `YYYY-MM-DD @ SHORT-SHA`; Next step product-only; Progress must not replay log; consolidate never empties current-session log; fenced `when editing:`; ownership/precedence bullets; optional active-work sections; denser When starting/stopping/catching-up; harness parity (four flat scripts, `current_session_id`, atomic binds, delayed Stop). Show full diff and confirm. Preserve project-specific notes.
- sensitive: `instructions.md` / `log.md` — pending-doc pairs with Invalidate when; log heading shape / session-id charset; remove `_No entries yet._` on first heading. Show diff and confirm.
- sensitive: `index.md` / `current.md` — map-only index (no _Read first_); minimal `current.md` headings (preserve In progress bullets and user lists).
- sensitive: `active-work/TEMPLATE.md` — required core only (Task / Progress / Next step / Validation / Checkpoint); optional Assumptions / Blockers / Rejected approaches / References only with content; Checkpoint plain line; Next step `/agent-memory` ban off-section; strip section blurbs on copy; References `../../../`. For existing `active-work/*.md`: keep optional sections that have content; strip empty optional headings; strip Checkpoint backticks/trailing prose and leftover TEMPLATE blurbs; fix `../../` → `../../../` when needed (show diff, confirm).
- sensitive: `decisions.md` / `log.md` scaffolding — shorter intro/format prose; preserve existing entries.
- sensitive: harness agent-memory block — shorter untrusted-recall + primary write / catch-up / consume. Confirm per file.
- safe: `agent-memory-consume-evidence.sh` + sessionStart Status (`parse_checkpoint_sha`, tracked `dirty`, Action with repo-relative consume path); stdin also accepts `conversationId` / `composer_id`; Checkpoint parse tolerates legacy backticks; delayed Stop / session binding / lock / path-retarget hardenings; `json_escape` for sessionStart JSON. **User must re-run the hooks installer** (four shared scripts + harness configs).
- safe: OpenCode plugin install path — `.opencode/plugins/` (was singular `.opencode/plugin/`) + `safe-script.ts` beside plugin; migrate/remove legacy singular; `session.compacted`; binding from payload only. **User must re-run** `install hooks opencode` then restart OpenCode.
- safe: pack-safe `vendor/memory/gitignore` (+ lock/temp siblings in ignore rules); `init` / `update` / `lint` require `.hook-sync-state`, `.hook-sync-state.lock`, `.hook-sync-state.*`.
- safe: `sync` / `learn` / `lint` / `consolidate` / `bootstrap` / `update` / `init` references — required consume when eligible; lint severity bands + findings (`empty-optional-section`, `evidence-*`, `checkpoint-prose`, `stale-next-step`, `dup-progress-log`, `pending-doc-met`, `hook-state-absent`, `empty-log*`, `blocker-hooks-contradiction`, …); soft budgets tightened; `when editing:` denylist/normalize-to-fixpoint; write Boundary hot-path only; update delegates carrier table to `init.md`; Validation prefers full closure; bootstrap one synthesis log heading.
- safe: CLI — install from package tree beside `bin/cli.js` (never clones GitHub); source checkouts refresh on SemVer match; `update --force`; `bun audit` / `build:check` / Trusted Publishing publish workflow. Re-run `npx @dosx/agent-memory update` (or install) after upgrading the npm package.
- safe: `SKILL.md` — Boundary / `allowed-tools` hot-path only + exact consume-evidence Bash paths; editorial pass (no method semantics beyond write scope).
- safe: Cross-package docs pin `hooks/README.md` / examples to `0.2.0`.
- safe: delete leftover `active-work/TEMPLATE.md` (copy scaffold is the skill `references/active-work-template.md`). Run even when `.version` already equals latest. Do not recreate TEMPLATE in project memory.
- sensitive: slim `log.md` / `decisions.md` / `index.md` / `current.md` scaffolding — drop format/template prose; preserve session entries, decisions, In progress bullets, and source lists. Show diff and confirm.
- sensitive: `instructions.md` — `index.md` is a short map (not a catalog); `log.md` is a rolling window; same-day same `[type]` headings update in place when superseded; active-work has one live Task. Show diff and confirm. Preserve project-specific notes.
- safe: `lint` / `bootstrap` / `sync` / `consolidate` / harness block — `index-catalog`, `same-day-dup-log`, rolling closed log, same-day supersede merge with confirmation.
- safe: Checkpoint SHA compare uses `git rev-parse --verify` (Git 2.55 `rev-parse --end-of-options <sha>` prints the flag as a revision). Lint sanitizes branch via `printf` so the trailing newline is not turned into `-`. **User must re-run the hooks installer** (shared scripts + `hooks/git/pre-commit` if used).
- safe: git `post-commit` — stamp `last_processed_head` to the new HEAD; drop pending paths that are in that commit and no longer dirty (keep dirty leftovers and session binding). Never Markdown. **Copy** `hooks/git/post-commit` into `.git/hooks/` with the shared scripts (not wired by the harness installer).
- sensitive: `instructions.md` — _Recall hop_ (durable why and no path hit; path hit includes diff / named file / failing test; verbs match edges not the trigger; listing log.md on the index is not a stop; depth 2; hop 2 is causal `{caused_by, supersedes, superseded_by}`; hop 1 inbound `rg -nE 'Relates:|caused_by:' .agents/memory`; ≤4 extra files; index is not a neighbor); Always load / When starting point at the section (algorithm not restated); canonical `- Relates:`; closed typed-edge verbs; causal `log.md` Relates bullet; learning + `index.md` `when editing:` hint in the same event. Show diff and confirm. Preserve project-specific notes.
- sensitive: `instructions.md` — write floor **is** the one-file table (Git does not skip the floor); **User constraint** → `decisions.md` (supersede live; tie-break writes decisions only); **Reusable lesson** → learnings + index hint (**fail closed**: incident + omit-from-Git + 1–3 paths; tie-break writes learnings only vs resume/closed); live user decision beats code for approach; HUMAN_CHECKPOINT carve-out for this-turn supersede and new learning H2; session Status is the turn face; resume/user-constraint/reusable-lesson may add a `when editing:` hint on an existing learnings/`decisions.md` index line. Show diff and confirm. Preserve project-specific notes.
- sensitive: harness agent-memory block — slim trigger-only body (write floor including User constraint and Reusable lesson; live decision vs code for approach; load learnings only via Status `load:` / hint; session Status `load:` / Next / Checkpoint; _Recall hop_ pointer). Catch-up/consume not in the block. Confirm per file.
- safe: sessionStart Status — `Next=` from active-work; `load:` from `index.md` `when editing:` vs pending/dirty paths (overbroad globs ignored); Action cites write floor walk (reusable lesson needs incident+paths) and Read load files. **User must re-run the hooks installer** (`agent-memory-common.sh`).
- safe: `learn` / `lint` / `consolidate` — `Relates:` required when Evidence is a recall file (`learning-missing-relates`); `relates-missing` also checks `#fragment`; `current-stale-branch`; findings `unknown-relates-verb`, `relates-missing`, `learning-missing-evidence`, `contradicts-unlinked`, `supersede-cycle`; consolidate Contradiction / No evidence / Orphan Relates.
- safe: `lint` — six-pass recipe (consistency, dead paths, typos, instruction contradictions, cold-session quality, hook consistency); structural scripts disclosed in `references/lint-structural.md`; findings `typo-heading` / `typo-token` / `method-stale` / `carrier-stale` / `hook-incomplete` / `opencode-legacy-plugin` / `learning-hidden` / `quality-unanswerable` / `live-dup-identity`.

## 0.2.1

- safe: `agent-memory-print-evidence.sh` — allowlisted hook-state stdout for agents (`pending_count` / hex HEAD / validated session id / sanitized branch). Never prints path lists. **User must re-run the hooks installer** (five shared scripts).
- safe: `SKILL.md` `allowed-tools` — exact `Bash(…print-evidence.sh)` paths beside consume-evidence.
- safe: `sync` / `consolidate` / `lint` — do not Read `.hook-sync-state`; sync gathers hook fields from print-evidence; lint `hook-incomplete` expects the fifth script; missing helper is absent evidence, not a Read fallback.
- sensitive: `instructions.md` — catch-up and harness parity: print-evidence / consume-evidence; do not Read `.hook-sync-state`. Show diff and confirm. Preserve project-specific notes.
- sensitive: **graph reshape** (`references/update-graph.md`) — collapse leftover `vision.md` / `architecture.md` / `patterns.md` / `domains/*` / `features/*` / graph-tree dirs into `index.md` Canonical project sources; rewrite Recall files; rewrite dead links; insert missing `**Status:** live` on dated `decisions.md` headings; merge same-day same-`[type]` `log.md` headings; delete non-md `active-work` junk and closed-placeholder resume files (confirm). Runs even when `.version` already equals latest. **Supersedes 0.0.14** “Do not delete legacy mirror files.” Do not invent learnings or `when editing:` globs.
- safe: `SKILL.md` — `update` allowed-tools include `decisions.md` and mirror paths for graph reshape only; sync still must not write decisions/learnings. Help/routing name the collapse.
