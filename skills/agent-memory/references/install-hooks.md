# `/agent-memory install hooks`

Print how to install or refresh lifecycle hooks for one harness. **This skill
does not copy scripts, merge configs, or run installers** — the user must run
the shell script or `npx` CLI themselves (trust boundary for security audits).

Does **not** create `.agents/memory/`, touch project memory content, or wire
agent instruction files — use `init` for that.

Also used by `init` (step 6) and `update` (refresh already-installed harnesses)
to print the same instructions.

## Invocation

```text
/agent-memory install hooks <harness>
/agent-memory install hook <harness>    # alias (singular)
```

Accepted `<harness>` values (aliases in parentheses):

| Harness    | Aliases       | Dir (created by installer if missing) | Installer writes into                    |
| ---------- | ------------- | ------------------------------------- | ---------------------------------------- |
| `cursor`   | —             | `.cursor/`                            | `.cursor/hooks/` + merge `hooks.json`    |
| `claude`   | `claude-code` | `.claude/`                            | `.claude/hooks/` + merge `settings.json` |
| `codex`    | —             | `.codex/`                             | `.codex/hooks/` + merge `hooks.json`     |
| `opencode` | —             | `.opencode/`                          | `.opencode/hooks/` + plugin `.ts`        |
| `copilot`  | `github`      | `.github/`                            | `.github/hooks/` + `agent-memory.json`   |
| `gemini`   | —             | `.gemini/`                            | `.gemini/hooks/` + merge `settings.json` |

Canonical hook sources live under `hooks/` in the
[agent-memory](https://github.com/diegoos/agent-memory) repository (tag matching
this skill's `metadata.version`).

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init` first. (Skip this guard when called from `init` step 6.)

2. **Parse harness.** Read `<harness>` from the invocation. Normalize aliases
   (`claude-code` → `claude`, `github` → `copilot`). If missing, stop and list
   accepted values.

3. **Prerequisite dir.** The user-run installer (`install-hooks.sh` / `npx`)
   **creates** the harness prerequisite directory if missing (e.g. `.cursor/`,
   `.opencode/`). The skill itself still must **not** create those dirs — only
   print the install commands.

4. **Print install instructions (do not execute).** Read this skill's
   `metadata.version` (e.g. `0.0.14`). Tell the user to review and run **one** of
   the following from the **project root** (never embed
   `raw.githubusercontent.com` URLs):

   **Preferred — npx:**

   ```bash
   npx @dosx/agent-memory install hooks <harness>
   ```

   **Pinned tag (optional):**

   ```bash
   npx --yes github:diegoos/agent-memory#0.0.14 -- install hooks <harness>
   ```

   (Replace `0.0.14` with this skill's `metadata.version` when it differs.)

   **Alternative — shell script:** open the GitHub release page for the matching
   tag (Releases → `0.0.14`, or the tag tree on GitHub), review
   `hooks/install-hooks.sh`, then from a checkout of that
   tag:

   ```bash
   bash hooks/install-hooks.sh <harness>
   ```

   Replace `<harness>` with the normalized harness name. Remind: the installer
   needs Node.js for JSON merges; it creates the harness directory if missing;
   Codex users should run `/hooks` in the TUI after install; Cursor may need a
   hooks reload.

5. **Report.** List: harness, that hooks were **not** written by the agent, and
   the exact commands printed. Suggest `/agent-memory sync` at the next
   checkpoint after the user installs.

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

For `update`, for **each** installed harness print the refresh commands from
step 4 (no agent copy/merge). Skip harnesses with no marker even if the
prerequisite dir exists.

## Behavior

Hooks run a **deterministic checkpoint** — `active-work/` (Touched files, Task
stub), `log.md` (session heading on session start + file-path bullets), and
`current.md` _In progress_ on session start. Semantic log text, decision
pointers / fallbacks, learnings, and consolidation stay agent-owned (or
`/agent-memory consolidate`). Hooks never copy project docs. See the
[hooks README](https://github.com/diegoos/agent-memory/blob/0.0.14/hooks/README.md).

Optional git `pre-commit` is **not** installed by this command — see the same
[hooks README](https://github.com/diegoos/agent-memory/blob/0.0.14/hooks/README.md).
