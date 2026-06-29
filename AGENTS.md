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
├── references/       # init, update, bootstrap, sync, lint, agent-block.md
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
- **Hooks** — shared scripts in `skills/agent-memory/hooks/shared/`; per-host
  config in `hooks/<harness>/`. Deterministic git checkpoint only — no LLM loops
  (`followup_message` on Cursor `stop` is intentionally unused).
- **Markdown** — `markdownlint` with 100-char line length
  (`.markdownlint.json`).
- **Commits** — English, Conventional Commits; do not push unless asked.

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
update your branch's `active-work/<branch>.md` (task, progress, touched files,
blockers), append events to `log.md`, record decisions in `decisions.md`, and
refresh `current.md` when project state changes. Delete your `active-work/` file
when the branch merges. At checkpoints (end of task, before commit, before
compaction, end of session), run `/agent-memory sync` to flush `current.md`,
`active-work`, `log.md`, and `index.md` from repo state.

@.agents/memory/instructions.md

<!-- </agent-memory> -->

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
