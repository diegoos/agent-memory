# agent-memory — agent hooks (optional)

Optional hooks that keep agent-memory current during real work. They run a
**deterministic git checkpoint** — no LLM call, no `followup_message` loops:

- Updates `active-work/<branch>.md` **Touched files** from `git`
- Appends a conservative `log.md` checkpoint on end-of-turn / compact / commit
- Injects read/write obligation at **session start** (where the host supports
  it)

**Still manual:** `current.md`, task/progress bullets, decisions — the agent
must update those (or run `/agent-memory sync`). Hooks never invent semantic
text.

## TL;DR

Copy the shared scripts plus host config (paths from repo root):

| Host            | Scripts                                                                       | Config                                  |
| --------------- | ----------------------------------------------------------------------------- | --------------------------------------- |
| **Any agent**   | `hooks/shared/agent-memory-sync.sh` → `.git/hooks/` (with `git/pre-commit`)   | `hooks/git/pre-commit`                  |
| **Cursor**      | → `.cursor/hooks/`                                                            | merge `hooks/cursor/hooks.json`         |
| **Claude Code** | → `.claude/hooks/`                                                            | merge `hooks/claude-code/settings.json` |
| **Codex**       | → `.codex/hooks/`                                                             | merge `hooks/codex/hooks.json`          |
| **Copilot**     | → `.github/hooks/`                                                            | `hooks/copilot/agent-memory.json`       |
| **OpenCode**    | → `.opencode/hooks/` + `hooks/opencode/agent-memory.ts` → `.opencode/plugin/` | plugin spawns sync script               |

Or run `/agent-memory init <harness>` when the harness directory already exists.

**Cursor:** hooks are the recommended integration — `@import` in `AGENTS.md` is
a no-op and `AGENTS.md` may not auto-inject. See root `README.md`.

## Events (all hosts)

| Checkpoint        | Cursor                        | Claude / Codex | Copilot        | OpenCode       |
| ----------------- | ----------------------------- | -------------- | -------------- | -------------- |
| Session start     | `sessionStart`                | `SessionStart` | `sessionStart` | —              |
| After Write/Shell | `postToolUse`                 | `PostToolUse`  | `postToolUse`  | —              |
| End of turn       | `afterAgentResponse`          | `Stop`         | `agentStop`    | `session.idle` |
| Before compact    | `preCompact`                  | `PreCompact`   | `preCompact`   | `compacting`   |
| Git commit        | `precommit` (pre-commit hook) | same           | same           | same           |

**Not used on Cursor:** `stop` + `followup_message` (always starts another LLM
turn).

## Layout

```text
hooks/
├── shared/
│   ├── agent-memory-sync.sh      # deterministic checkpoint (all hosts)
│   └── agent-memory-session.sh   # sessionStart context injection
├── cursor/hooks.json
├── claude-code/settings.json
├── codex/hooks.json
├── codex/config.toml.snippet
├── copilot/agent-memory.json
├── opencode/agent-memory.ts
└── git/pre-commit
```

## Requirements

- `git` on `$PATH`
- POSIX `sh` / `bash` for command hooks
- OpenCode: Bun plugin loader

## Install (per project)

### Cursor (recommended)

```bash
mkdir -p .cursor/hooks
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .cursor/hooks/
cp skills/agent-memory/hooks/shared/agent-memory-session.sh .cursor/hooks/
chmod +x .cursor/hooks/agent-memory-*.sh
# merge hooks/cursor/hooks.json into .cursor/hooks.json
```

### Claude Code

```bash
mkdir -p .claude/hooks
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .claude/hooks/
cp skills/agent-memory/hooks/shared/agent-memory-session.sh .claude/hooks/
chmod +x .claude/hooks/agent-memory-*.sh
# merge hooks/claude-code/settings.json into .claude/settings.json
```

### Codex

```bash
mkdir -p .codex/hooks
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .codex/hooks/
cp skills/agent-memory/hooks/shared/agent-memory-session.sh .codex/hooks/
chmod +x .codex/hooks/agent-memory-*.sh
# merge hooks/codex/hooks.json into .codex/hooks.json
# then run /hooks in the Codex TUI to trust project hooks
```

### Copilot (CLI + cloud agent)

```bash
mkdir -p .github/hooks
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .github/hooks/
cp skills/agent-memory/hooks/shared/agent-memory-session.sh .github/hooks/
chmod +x .github/hooks/agent-memory-*.sh
cp skills/agent-memory/hooks/copilot/agent-memory.json .github/hooks/agent-memory.json
```

### OpenCode

```bash
mkdir -p .opencode/hooks .opencode/plugin
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .opencode/hooks/
chmod +x .opencode/hooks/agent-memory-sync.sh
cp skills/agent-memory/hooks/opencode/agent-memory.ts .opencode/plugin/agent-memory.ts
```

### Git (host-agnostic baseline)

```bash
cp skills/agent-memory/hooks/git/pre-commit .git/hooks/pre-commit
cp skills/agent-memory/hooks/shared/agent-memory-sync.sh .git/hooks/agent-memory-sync.sh
chmod +x .git/hooks/pre-commit .git/hooks/agent-memory-sync.sh
```

## Verifying

- Cursor: **Hooks** settings tab / **Hooks** output channel; restart if needed.
- Claude Code: `/hooks` shows configured hooks.
- Codex: `/hooks` in the TUI to inspect and trust.
- OpenCode: plugin loads at startup; sync script must exist at
  `.opencode/hooks/`.
- Git: `sh .git/hooks/pre-commit` with staged non-memory changes.

## Safe write scope

Hooks may write only evidence-backed fields:

| Field                         | Hook updates?                          |
| ----------------------------- | -------------------------------------- |
| `active-work` → Touched files | Yes (from `git`)                       |
| `log.md` checkpoint line      | Yes (conservative, deduped)            |
| `current.md`, Task, Progress  | **No** — agent or `/agent-memory sync` |

State is tracked in `.agents/memory/.hook-sync-state` (migrates legacy
`.cursor-hook-state` if present). Both are listed in the skeleton `.gitignore`
and should not be committed.
