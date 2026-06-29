# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Migration details for `/agent-memory update` live in
[`agent-memory/UPDATE.md`](agent-memory/UPDATE.md) (machine-oriented `safe` /
`sensitive` tags). This changelog is the human-oriented release history — keep
both in sync on version bumps.

## [Unreleased]

## [0.0.6] - 2026-06-29

### Added

- `init` harness targets (`init cursor`, `init claude`, `init codex`, `init
  opencode`, `init copilot`, `init gemini`) and auto-detect mode; wires hooks
  only into harness dirs that already exist.
- Shared lifecycle hooks: `hooks/shared/agent-memory-sync.sh` and
  `agent-memory-session.sh` — deterministic git checkpoint (Touched files +
  conservative `log.md` append; no extra LLM request).
- Unified hook wiring for Cursor, Claude Code, Codex, Copilot, OpenCode, and git
  `pre-commit`.
- `agent-memory/memory/.gitignore` in the skeleton — ignores hook checkpoint
  state (`.hook-sync-state`, legacy `.cursor-hook-state`).

### Changed

- Cursor integration is **hooks-only**; hooks are the recommended path
  (`@import` in `AGENTS.md` remains a no-op).
- `instructions.md` — _Plain-Markdown harnesses_ updated for hooks-only Cursor.
- `update` no longer refreshes `.cursor/rules/agent-memory.mdc`; optional manual
  removal of legacy rule files noted in the report.
- Documentation aligned across `agent-block.md`, READMEs, `SKILL.md`, and
  `hooks/README.md`.

### Removed

- `agent-memory-flush.sh` flush-reminder hooks (replaced by deterministic sync).
- Cursor `stop` + `followup_message` pattern (always started another LLM turn).

## [0.0.5] - 2026-06-26

### Added

- Opt-in flush-reminder hooks for Cursor, Claude Code, Codex, OpenCode, Copilot,
  and a host-agnostic git `pre-commit` hook (`skills/agent-memory/hooks/`).
- `sync --auto` and `lint --fix` documented in skill references.

### Changed

- Canonical agent-memory block now spells out **read AND write** obligation and
  explicit `Read .agents/memory/instructions.md` for plain-Markdown harnesses.
- Agent-memory block delimiters migrated to HTML comments
  (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`) — invisible in
  rendered Markdown, machine-identifiable in source.
- `instructions.md` — _Flush early_ names `sync --auto`; adds plain-Markdown
  harness note.
- Root and `agent-memory/README.md` rewritten as entry points; stub text points
  to `agent-block.md` as single source of truth.

## [0.0.4] - 2026-06-24

### Added

- `references/agent-block.md` — single source of truth for the agent-memory
  block wired into root agent files.

### Changed

- `init` wraps the memory block in `<agent-memory>` … `</agent-memory>`
  delimiters (later migrated to HTML comments in 0.0.5).
- `update` refreshes **only** the delimited block in `AGENTS.md` / `CLAUDE.md` /
  `GEMINI.md`; migrates legacy `## Agent Memory` sections.

## [0.0.3] - 2026-06-24

### Changed

- Unified agent-file stub for `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` — explicit
  always-load list plus `@.agents/memory/instructions.md` for `@import` harnesses
  and plain-Markdown readers.

## [0.0.2] - 2026-06-24

### Added

- `/agent-memory sync` — refresh `current.md`, branch `active-work`, `log.md`,
  and `index.md` Domains/Features from repo state.

### Changed

- `instructions.md` — _Workflow_ names `/agent-memory sync` as the executable
  trigger for During / After / Flush early steps.

## [0.0.1] - 2026-06-22

### Added

- Initial Agent Memory method, skill, and `.agents/memory/` skeleton.

[unreleased]: https://github.com/diegoos/agent-memory/compare/v0.0.6...HEAD
[0.0.6]: https://github.com/diegoos/agent-memory/compare/v0.0.5...v0.0.6
