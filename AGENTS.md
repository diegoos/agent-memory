# Agent instructions — agent-memory repository

This repo **is** the source for the [Agent Memory](README.md) method and its
manual-only skill. It is not a consumer install — the skeleton agents copy into
other projects lives under `agent-memory/memory/`; the orchestrator lives under
`skills/agent-memory/`.

## Layout

```text
agent-memory/
├── memory/           # canonical skeleton → copied to .agents/memory/ on init
├── UPDATE.md         # migration log; drives /agent-memory update
└── README.md         # method documentation

skills/agent-memory/
├── SKILL.md          # skill entry (version in frontmatter)
├── references/       # init, install-hooks, update, bootstrap, sync, lint, agent-block.md
└── hooks/            # optional lifecycle hooks per harness

CHANGELOG.md          # release history (Keep a Changelog + SemVer)
```

## Conventions for agents working here

- **Single sources of truth** — do not duplicate or drift:
  - Agent-memory block text: `skills/agent-memory/references/agent-block.md`
  - Installed memory shape: `agent-memory/memory/`
  - Migrations: `agent-memory/UPDATE.md`
  - Release history: `CHANGELOG.md` ([Keep a Changelog][kac], [SemVer][semver])
- **Version bumps** — only when requested: add a `## <version>` section to
  `agent-memory/UPDATE.md`, bump `metadata.version` in
  `skills/agent-memory/SKILL.md`, align the example in `references/init.md`, and
  add a matching `[<version>]` entry to `CHANGELOG.md` (human-oriented; map
  `safe`/`sensitive` items from `UPDATE.md` into Added / Changed / Removed /
  Fixed / Security — do not dump git logs).
- **Skill boundary** — `/agent-memory` is manual-only
  (`disable-model-invocation: true`). Never auto-trigger it; follow `SKILL.md`
  and the matching `references/<command>.md` when the user invokes a subcommand.
- **Hooks** — shared scripts in `skills/agent-memory/hooks/agent-memory-hooks/`
  (`common`, `sync`, `session`); per-host config in `hooks/<harness>/`.
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

**Consumer upgrade:** re-copy the three scripts from
`skills/agent-memory/hooks/agent-memory-hooks/` and merge host config
(especially `.cursor/hooks.json` — must include `afterFileEdit`). Or run
`/agent-memory install hooks <harness>` / `/agent-memory update`.

## Dogfooding

To use Workspace Memory at the repo root, run `/agent-memory init` (installs
`.agents/memory/` from `agent-memory/memory/`). Until then, treat
`agent-memory/memory/instructions.md` as the method file for this project.

<!-- <agent-memory> -->

## Agent Memory

This project uses Agent Memory (a local Workspace Memory). **Before starting any
task**, Read `.agents/memory/instructions.md` (it defines the workflow), then
read `.agents/memory/index.md`, `.agents/memory/current.md`, and your branch's
file in `.agents/memory/active-work/`.

This memory is **read AND written** by agents — it is not chat history. While
you work and when you finish a task, keep it current per `instructions.md`:
update your branch's `active-work/<branch>.md` (Task, progress, touched files,
blockers), append bullets to the **current session** heading in `log.md`,
**record architecture and design decisions in `decisions.md`**, keep `index.md`
aligned with lazy and domain/feature files, and refresh `current.md` when
project state changes (list open active-work files in _In progress_; move
completed work to _Done_). Ask the user before changing `vision.md` when
uncertain. Delete your `active-work/` file when the branch merges. At
checkpoints (end of task, before commit, before compaction, end of session), run
`/agent-memory sync` to flush `current.md`, active-work, `log.md`, and
`index.md` from repo state.

@.agents/memory/instructions.md

<!-- </agent-memory> -->

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
