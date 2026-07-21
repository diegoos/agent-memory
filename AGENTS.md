# Agent instructions — agent-memory repository

This repo **is** the source for the [Agent Memory](README.md) method and its
manual-only skill. It is not a consumer install — the skeleton the skill copies
into other projects lives under `skills/agent-memory/vendor/`; the orchestrator
lives under `skills/agent-memory/`.

## Layout

```text
skills/agent-memory/          # skill only (no hooks)
├── SKILL.md
├── vendor/                   # SoT: skeleton + UPDATE.md + method README
└── references/

hooks/                        # outside the skill — user-run install
├── install-hooks.sh
├── agent-memory-hooks/       # common / sync / session
├── <harness>/                # cursor, claude-code, …
└── README.md

install.ts                    # CLI source (Bun build)
bin/cli.js                    # npx CLI (skill + hooks)
package.json                  # SoT: package / skill / hooks version

CHANGELOG.md
```

## Conventions for agents working here

- **Single sources of truth** — do not duplicate or drift:
  - Agent-memory block text: `skills/agent-memory/references/agent-block.md`
  - Installed memory shape: `skills/agent-memory/vendor/memory/`
  - **Harness parity (hooks vs agent):**
    `skills/agent-memory/vendor/memory/instructions.md` → _Harness parity —
    memory contract_ (canonical; link, do not copy)
  - Migrations: `skills/agent-memory/vendor/UPDATE.md`
  - Release history: `CHANGELOG.md` ([Keep a Changelog][kac], [SemVer][semver])
  - Package / skill / hooks version: `package.json` `version` (mirror into
    `skills/agent-memory/SKILL.md` → `metadata.version`)
- **Always edit** `skills/agent-memory/vendor/` — never invent a repo-root
  `agent-memory/` path for writes.
- **Version bumps** — only when requested: bump `package.json` `version` (SoT),
  mirror it into `skills/agent-memory/SKILL.md` → `metadata.version`, add a
  `## <version>` section to `skills/agent-memory/vendor/UPDATE.md` when memory
  scaffolding/migrations change, align pinned examples in `references/init.md`,
  `references/install-hooks.md`, `hooks/README.md`, and root `README.md`, keep
  `install-hooks.sh` fallback version in sync if present, and add a matching
  `[<version>]` entry to `CHANGELOG.md` (human-oriented; map `safe`/`sensitive`
  items from `UPDATE.md` into Added / Changed / Removed / Fixed / Security — do
  not dump git logs).
- **Skill boundary** — `/agent-memory` is manual-only
  (`disable-model-invocation: true`). Never auto-trigger it; follow `SKILL.md`
  and the matching `references/<command>.md` when the user invokes a subcommand.
  The skill **never** installs hooks (print instructions only).
- **Hooks** — live under repo-root `hooks/` (**not** inside the skill). Shared
  scripts in `hooks/agent-memory-hooks/` (`common`, `sync`, `session`);
  per-host config in `hooks/<harness>/`. User installs via
  `hooks/install-hooks.sh` or `npx` CLI (`install.ts` → `bin/cli.js`).
  Deterministic checkpoint: session-cumulative `active-work/` _Touched files_,
  `log.md` file bullets on full checkpoints only, `current.md` _In progress_ on
  session start — no LLM loops (`followup_message` on Cursor `stop` is
  intentionally unused). See [Known issues](#known-issues) for hook upgrade
  notes.
- **Markdown** — `markdownlint` with 100-char line length
  (`.markdownlint.json`).
- **Commits** — English, Conventional Commits; do not push unless asked.
- **Content Language** — English.

## Known issues

### Hook checkpoint regression (0.0.8 → fixed in tree)

**Symptom (consumer projects on hooks before this fix):** `log.md` shows a
`changed N files (see active-work Touched files)` summary plus stray
``- `path` `` bullets with no semantic context; `active-work` _Touched files_ is
incomplete (e.g. only files written via `Write`, not edits).
`/agent-memory sync --auto` semantic bullets are unaffected — they come from the
agent, not hooks.

**Root cause:**

1. **0.0.8 perf change** — `postToolUse` stopped running `git` and only read
   `tool_input.file_path` from stdin. Full git reconciliation moved to
   end-of-turn only. If the working tree was clean at end-of-turn, `active-work`
   was not refreshed.
2. **Cursor wiring gap** — Cursor agent **edits** fire `afterFileEdit`
   (top-level `file_path`), not `postToolUse`. The Cursor snippet only matched
   `Write|Shell`, so most edits were never captured between turns.
3. **Replace vs accumulate** — each checkpoint replaced _Touched files_ with the
   current git delta instead of merging session paths; a later small delta could
   shrink a list that `/agent-memory sync` had just filled.
4. **Log noise** — `postToolUse` appended individual path bullets even after a
   summary line for the same session.

**Fix (canonical sources in this repo):**

- Session-cumulative `session_touched_files` in `.hook-sync-state`; full
  checkpoints flush even when git returns no new paths.
- Cursor: add `afterFileEdit` hook; `postToolUse` no longer writes `log.md`.
- Shared stdin parser: `tool_input.file_path`, `tool_input.path`, top-level
  `file_path` (Cursor `afterFileEdit`, Copilot).
- Gemini: map `AfterTool` → post-tool accumulate, `AfterAgent` → full
  checkpoint.
- After a summary bullet, suppress further individual path bullets in the same
  session.

**Consumer upgrade:** re-run the user installer for the release tag (npx or
`install-hooks.sh`) so all three scripts and host config are refreshed
(especially `.cursor/hooks.json` — must include `afterFileEdit`). Or follow
`/agent-memory install hooks <harness>` printed instructions.

### OpenCode empty `log.md` headings (fixed in tree)

**Symptom:** multiple same-day headings like `## [YYYY-MM-DD] [ses_…]` with no
bullets — one per OpenCode `session.idle` / compaction event.

**Root cause:** OpenCode rotates `ses_*` session IDs frequently; the plugin
synthesized `sessionStart` on every idle/compaction and each ID created a new
heading. `session.idle` carries only `sessionID` (no stable conversation id).

**Fix:** bind **one log heading per calendar day** (`opencode_log_heading_id` in
`.hook-sync-state`); map later `ses_*` IDs to that heading; prune empty
duplicate headings; plugin skips redundant `sessionStart` only when the bound
heading **exists in `log.md`**; compaction runs sync only (no new heading).
Checkpoints call `ensure_log_heading_for_checkpoint` before appending bullets
(state binding alone is insufficient). Re-run the OpenCode hook installer for
the release tag (plugin + three `.opencode/hooks/*.sh` scripts).

## Dogfooding

To use Workspace Memory at the repo root, run `/agent-memory init` (installs
`.agents/memory/` from `skills/agent-memory/vendor/memory/`). Until then, treat
`skills/agent-memory/vendor/memory/instructions.md` as the method file for this
project.

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
