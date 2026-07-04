# `/agent-memory install hooks`

Install or refresh lifecycle hooks for one harness. Idempotent: overwrites the
canonical shared scripts and merges harness config from the agent-memory
repository. Does **not** create `.agents/memory/`, touch project memory content,
or wire agent instruction files — use `init` for that.

Also used by `init` (step 6) and `update` (refresh already-installed harnesses).

## Invocation

```text
/agent-memory install hooks <harness>
/agent-memory install hook <harness>    # alias (singular)
```

Accepted `<harness>` values (aliases in parentheses):

| Harness    | Aliases       | Prerequisite dir | Installs into                            |
| ---------- | ------------- | ---------------- | ---------------------------------------- |
| `cursor`   | —             | `.cursor/`       | `.cursor/hooks/` + merge `hooks.json`    |
| `claude`   | `claude-code` | `.claude/`       | `.claude/hooks/` + merge `settings.json` |
| `codex`    | —             | `.codex/`        | `.codex/hooks/` + merge `hooks.json`     |
| `opencode` | —             | `.opencode/`     | `.opencode/hooks/` + plugin `.ts`        |
| `copilot`  | `github`      | `.github/`       | `.github/hooks/` + `agent-memory.json`   |
| `gemini`   | —             | `.gemini/`       | `.gemini/hooks/` + merge `settings.json` |

Canonical sources live under `skills/agent-memory/hooks/` in the agent-memory
repository (see `SKILL.md` → Repository source).

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init` first.

2. **Parse harness.** Read `<harness>` from the invocation. Normalize aliases
   (`claude-code` → `claude`, `github` → `copilot`). If missing, stop and list
   accepted values.

3. **Prerequisite dir.** If the harness prerequisite directory does not exist,
   stop — tell the user to create it first (e.g. `mkdir .opencode` after
   enabling OpenCode in the project). **Never create** `.cursor/`, `.claude/`,
   `.codex/`, `.opencode/`, or `.github/` unless the user explicitly requests
   it; on explicit confirmation, create the dir (and any needed subdir) and
   continue.

4. **Obtain repository.** Load hook sources from the agent-memory repository
   (local clone, shallow `git clone`, or `WebFetch` — see `SKILL.md`).

5. **Install shared scripts (always).** Copy **all three** files from
   `hooks/agent-memory-hooks/` into the harness hooks directory:
   - `agent-memory-common.sh`
   - `agent-memory-sync.sh`
   - `agent-memory-session.sh`

   `chmod +x` each script. Never install sync/session without `common`.

   | Harness    | Hooks directory    |
   | ---------- | ------------------ |
   | `cursor`   | `.cursor/hooks/`   |
   | `claude`   | `.claude/hooks/`   |
   | `codex`    | `.codex/hooks/`    |
   | `opencode` | `.opencode/hooks/` |
   | `copilot`  | `.github/hooks/`   |
   | `gemini`   | `.gemini/hooks/`   |

6. **Merge harness config (idempotent).** Add or update agent-memory entries
   only — do not remove unrelated hooks the user may have configured.

   | Harness    | Action                                                                                                                                                                                              |
   | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | `cursor`   | Merge [`hooks/cursor/hooks.json`](../hooks/cursor/hooks.json) into `.cursor/hooks.json` (create file if missing). Must include **`afterFileEdit`** (agent edits) alongside `postToolUse` (`Write`). |
   | `claude`   | Merge [`hooks/claude-code/settings.json`](../hooks/claude-code/settings.json) into `.claude/settings.json`.                                                                                         |
   | `codex`    | Merge [`hooks/codex/hooks.json`](../hooks/codex/hooks.json) into `.codex/hooks.json`. Remind user to run `/hooks` in Codex TUI to trust hooks.                                                      |
   | `opencode` | Copy [`hooks/opencode/agent-memory.ts`](../hooks/opencode/agent-memory.ts) → `.opencode/plugin/agent-memory.ts` (overwrite canonical plugin).                                                       |
   | `copilot`  | Copy [`hooks/copilot/agent-memory.json`](../hooks/copilot/agent-memory.json) → `.github/hooks/agent-memory.json` if missing; merge if file exists.                                                  |
   | `gemini`   | Merge [`hooks/gemini/settings.json`](../hooks/gemini/settings.json) into `.gemini/settings.json`.                                                                                                   |

7. **Report.** List: harness, scripts copied, config merged or skipped (and
   why), and any harness-specific reminders (Codex `/hooks`, Cursor hooks
   reload). Suggest `/agent-memory sync` at the next checkpoint.

## Detecting installed harnesses (`update`)

A harness counts as **already installed** when its prerequisite dir exists
**and** any of these markers is present:

| Harness    | Marker (any one)                                                                        |
| ---------- | --------------------------------------------------------------------------------------- |
| `cursor`   | `.cursor/hooks/agent-memory-sync.sh` or agent-memory in `.cursor/hooks.json`            |
| `claude`   | `.claude/hooks/agent-memory-sync.sh`                                                    |
| `codex`    | `.codex/hooks/agent-memory-sync.sh`                                                     |
| `opencode` | `.opencode/plugin/agent-memory.ts` or `.opencode/hooks/agent-memory-sync.sh`            |
| `copilot`  | `.github/hooks/agent-memory.json` or `.github/hooks/agent-memory-sync.sh`               |
| `gemini`   | `.gemini/settings.json` containing agent-memory or `.gemini/hooks/agent-memory-sync.sh` |

For `update`, run steps 4–6 above for **each** installed harness (no `<harness>`
argument). Skip harnesses with no marker even if the prerequisite dir exists.

## Behavior

Hooks run a **deterministic checkpoint** — `active-work/` (Touched files, Task
stub), `log.md` (session heading on session start + file-path bullets), and
`current.md` _In progress_ on session start. Semantic log text and
`decisions.md` stay agent-owned. See [`hooks/README.md`](../hooks/README.md).

Optional git `pre-commit` is **not** installed by this command — see
[`hooks/README.md`](../hooks/README.md).
