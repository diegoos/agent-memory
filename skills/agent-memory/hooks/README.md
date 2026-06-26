# agent-memory — agent hooks (optional)

Optional, opt-in hooks that mechanize the _Flush early_ step of agent-memory:
they remind the agent to flush the memory before context compaction and at
session end, so the memory keeps being updated instead of rotting between
tasks (the exact failure mode where `init`/`bootstrap`/`sync` worked but the
memory was never updated during real work).

The hooks **only remind** — they never write to the memory themselves. The
agent decides whether to run `/agent-memory sync` (the per-file confirmed form)
or update the files by hand. This respects the skill's manual-only design
(`disable-model-invocation: true`, "run inside the agent, no external scripts")
and keeps every memory write reviewed. For why the hooks deliberately do less,
see _About the sync hook_ below.

## TL;DR

Pick the trigger you want and copy its files into your project (paths below are
from the repo root):

- **Any agent (host-agnostic, recommended baseline):** `hooks/git/pre-commit`
  → `.git/hooks/pre-commit`. Fires on commit; works for every agent.
- **Cursor:** `hooks/cursor/hooks.json` + `hooks/shared/agent-memory-flush.sh`.
- **Claude Code:** `hooks/claude-code/settings.json` + the shared script.
- **Codex:** `hooks/codex/hooks.json` (+ `config.toml.snippet`) + the shared
  script.
- **OpenCode:** `hooks/opencode/agent-memory.ts` (no shared script needed).
- **Copilot (CLI + cloud agent):** `hooks/copilot/agent-memory.json` + the
  shared script.

Full per-host steps in _Install_ below. Not wired by `/agent-memory init`.

## Does it make sense to have hooks for these agents?

Yes — all of them ship a lifecycle-hook mechanism (verified against their
current docs):

| Agent | Hook mechanism | Events used | Config location | Notes |
| --- | --- | --- | --- | --- |
| Cursor | `hooks.json` (schema v1) | `preCompact`, `stop` | `.cursor/hooks.json` | `stop` with `followup_message` + `loop_limit:1` continues once, no loop. |
| Claude Code | `settings.json` hooks block | `PreCompact`, `Stop` | `.claude/settings.json` | Uses `systemMessage` (surfaces to user, does **not** force another turn → no loop). |
| Codex | `hooks.json` or inline `[hooks]` in `config.toml` | `PreCompact`, `Stop` | `.codex/hooks.json` or `.codex/config.toml` | `[features] hooks = true` (default on); trust project hooks via `/hooks`; disabled on Windows. |
| OpenCode | TS plugin in `.opencode/plugin/` | `experimental.session.compacting`, `session.idle` | `.opencode/plugin/agent-memory.ts` | No JSON command hooks — a small TS plugin is required. |
| Copilot | `.github/hooks/*.json` | `preCompact`, `agentStop` | `.github/hooks/agent-memory.json` | CLI + cloud agent. Cloud agent honors `bash` only and a subset of events; `agentStop` reminder is stderr-only to avoid looping the agent. |

Caveats that shaped the design:

- **No loops.** None of these hooks block the agent or force a continuation
  that would re-fire the same hook. Cursor's `stop` uses `loop_limit:1`;
  Claude Code uses `systemMessage` (not `decision:"block"`); Codex returns
  `{"continue":true}`; Copilot's `agentStop` emits stderr only.
- **OpenCode has no JSON hooks.** It needs a TS plugin (provided).
- **Copilot cloud agent** runs in an ephemeral Linux sandbox and only honors
  `bash` entries from `.github/hooks/*.json`; user-level hooks do not apply
  there.
- **Codex** requires explicitly trusting project hooks via `/hooks` in the TUI.

If you want a single, host-agnostic trigger that covers every agent (including
Copilot cloud agent) with zero per-host config, use the **git pre-commit hook**
below — it works because all agents commit via git.

## Layout

```text
hooks/
├── shared/agent-memory-flush.sh   # shared reminder script (command-hook hosts)
├── cursor/hooks.json              # Cursor
├── claude-code/settings.json      # Claude Code
├── codex/hooks.json               # Codex (sidecar)
├── codex/config.toml.snippet      # Codex (inline alternative)
├── copilot/agent-memory.json      # Copilot CLI + cloud agent
├── opencode/agent-memory.ts       # OpenCode plugin
└── git/pre-commit                 # host-agnostic git hook
```

`shared/agent-memory-flush.sh` is invoked by Cursor, Claude Code, Codex, and
Copilot with two env vars set inline — `AGENT_MEMORY_HOST` and
`AGENT_MEMORY_EVENT` — and emits host-appropriate JSON plus a stderr reminder.
It no-ops when `.agents/memory/` is absent and fails open. OpenCode and the git
hook do their own reminding (TS / shell).

## Requirements

- `jq` on `$PATH` for the shared script (used to JSON-encode the message).
  Verify with `command -v jq`.
- For OpenCode: its plugin loader (Bun) — no jq needed.
- The git hook: just POSIX `sh` + `git`.

## Install (per project, per host)

These are project hooks — **copy** them into your project; do not run them from
this skill directory. Not wired by `/agent-memory init`.

### Cursor

```bash
mkdir -p .cursor/hooks
cp skills/agent-memory/hooks/shared/agent-memory-flush.sh .cursor/hooks/agent-memory-flush.sh
chmod +x .cursor/hooks/agent-memory-flush.sh
# merge hooks/cursor/hooks.json into .cursor/hooks.json
```

### Claude Code

```bash
mkdir -p .claude/hooks
cp skills/agent-memory/hooks/shared/agent-memory-flush.sh .claude/hooks/agent-memory-flush.sh
chmod +x .claude/hooks/agent-memory-flush.sh
# merge the "hooks" block from claude-code/settings.json into .claude/settings.json
```

### Codex

```bash
mkdir -p .codex/hooks
cp skills/agent-memory/hooks/shared/agent-memory-flush.sh .codex/hooks/agent-memory-flush.sh
chmod +x .codex/hooks/agent-memory-flush.sh
# either copy codex/hooks.json to .codex/hooks.json, or inline codex/config.toml.snippet
# then run /hooks in the Codex TUI to trust the project hooks
```

### OpenCode

```bash
mkdir -p .opencode/plugin
cp skills/agent-memory/hooks/opencode/agent-memory.ts .opencode/plugin/agent-memory.ts
```

### Copilot (CLI + cloud agent)

```bash
mkdir -p .github/hooks
cp skills/agent-memory/hooks/shared/agent-memory-flush.sh .github/hooks/agent-memory-flush.sh
chmod +x .github/hooks/agent-memory-flush.sh
cp skills/agent-memory/hooks/copilot/agent-memory.json .github/hooks/agent-memory.json
```

### Git (host-agnostic — recommended baseline)

```bash
cp skills/agent-memory/hooks/git/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
# or, with a shared hooks dir: git config core.hooksPath .githooks
```

## Verifying

- Cursor: **Hooks** settings tab / **Hooks** output channel; restart Cursor if
  `hooks.json` does not reload.
- Claude Code: `/hooks` shows configured hooks; settings reload without
  restart.
- Codex: `/hooks` in the TUI to inspect and trust.
- OpenCode: check the plugin loaded at startup.
- Git: test the script directly without committing — `sh .git/hooks/pre-commit`
  (with staged non-memory changes, it prints the reminder). Or make a throwaway
  commit and `git reset --soft HEAD~1` afterward.

## About the sync hook

The hooks ship as **non-blocking reminders only** — they never write to the
memory and never block the agent, so they cannot cause memory inconsistency or
loops. They prompt the agent to run `/agent-memory sync` (the per-file
confirmed form) at checkpoints; the agent and the user (via sync's per-file
confirmation) stay in control of every write.

By design the hooks recommend `/agent-memory sync`, **not** `sync --auto`:
`--auto` skips the per-file confirmation and is fine for a manual, low-friction
flush when you are at the wheel, but an automatic trigger (a hook) should push
the safe, reviewed path so an unattended write can't silently apply a wrong or
stale diff.

Intentionally **not provided**, because they risk memory inconsistency:

- A "forcer" hook that blocks `Stop`/`agentStop` until the memory is flushed —
  it can force a flush of incomplete or wrong state, and needs a staleness
  check plus a per-session guard to avoid loops.
- An "auto-write" command hook that writes the memory files directly, bypassing
  the agent — it conflicts with the skill's "run inside the agent, no external
  scripts" principle and cannot do the semantic parts of `sync`.

The **git pre-commit hook** is the best single trigger: host-agnostic, no loop
semantics, fires at a natural checkpoint (the commit), and only reminds. Pair
it with one agent lifecycle hook for compaction to cover both "context is about
to be lost" and "work is being committed" — without any hook touching the
memory.
