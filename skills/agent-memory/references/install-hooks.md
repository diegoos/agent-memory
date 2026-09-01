# `/agent-memory install hooks`

Print how to install or refresh lifecycle hooks for one harness. **This skill does not copy scripts, merge configs, or run installers** — the user must run the shell script or `npx` CLI themselves (trust boundary for security audits).

Does **not** create `.agents/memory/`, touch project memory content, or wire agent instruction files — use `init` for that.

Also used by `init` (step 7) and `update` (refresh already-installed harnesses) to print the same instructions.

## Invocation

```text
/agent-memory install hooks <harness>
/agent-memory install hook <harness>    # alias (singular)
```

Accepted `<harness>` values (aliases in parentheses):

| Harness    | Aliases       | Dir (created by installer if missing) | Installer writes into                         |
| ---------- | ------------- | ------------------------------------- | --------------------------------------------- |
| `cursor`   | —             | `.cursor/`                            | `.cursor/hooks/` + merge `hooks.json`         |
| `claude`   | `claude-code` | `.claude/`                            | `.claude/hooks/` + merge `settings.json`      |
| `codex`    | —             | `.codex/`                             | `.codex/hooks/` + merge `hooks.json`          |
| `opencode` | —             | `.opencode/`                          | `.opencode/hooks/` + `.opencode/plugins/*.ts` |
| `copilot`  | `github`      | `.github/`                            | `.github/hooks/` + `agent-memory.json`        |
| `gemini`   | —             | `.gemini/`                            | `.gemini/hooks/` + merge `settings.json`      |

Canonical hook sources live under `hooks/` in the [agent-memory](https://github.com/diegoos/agent-memory) repository (tag matching this skill's `metadata.version`).

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init` first. (Skip this guard when called from `init` step 7.)

2. **Parse harness.** Read `<harness>` from the invocation. Normalize aliases (`claude-code` → `claude`, `github` → `copilot`). If missing, stop and list accepted values.

3. **Prerequisite dir.** The user-run installer (`install-hooks.sh` / `npx`) **creates** the harness prerequisite directory if missing (e.g. `.cursor/`, `.opencode/`). The skill itself still must **not** create those dirs — only print the install commands.

4. **Print install instructions (do not execute).** Read this skill's `metadata.version` (e.g. `0.2.0`). Tell the user to review and run **one** of the following from the **project root** (never embed `raw.githubusercontent.com` URLs):

   **Preferred — npx:**

   ```bash
   npx @dosx/agent-memory install hooks <harness>
   ```

   **Pinned tag (optional):**

   ```bash
   npx --yes github:diegoos/agent-memory#0.2.0 -- install hooks <harness>
   ```

   (Replace `0.2.0` with this skill's `metadata.version` when it differs.)

   **Alternative — shell script:** open the GitHub release page for the matching tag (Releases → `0.2.0`, or the tag tree on GitHub), review `hooks/install-hooks.sh`, then from a checkout of that tag:

   ```bash
   bash hooks/install-hooks.sh <harness>
   ```

   Replace `<harness>` with the normalized harness name. Remind: the installer needs Node.js for JSON merges; it creates the harness directory if missing; Codex users should run `/hooks` in the TUI after install; Cursor may need a hooks reload.

5. **Report.** List: harness, that hooks were **not** written by the agent, and the exact commands printed. Suggest `/agent-memory sync` at the next checkpoint after the user installs. For OpenCode: restart the harness after install; expect `.hook-sync-state` on `session.idle` / native `/compact` (plugin also listens for `session.compacted`) — DCP commands such as `/dcp-compact` do **not** trigger agent-memory PreCompact.

## Detecting installed harnesses (`update`)

A harness counts as **already installed** when its prerequisite dir exists **and** any of these markers is present:

| Harness    | Marker (any one)                                                                                   |
| ---------- | -------------------------------------------------------------------------------------------------- |
| `cursor`   | `.cursor/hooks/agent-memory-sync.sh` or agent-memory in `.cursor/hooks.json`                       |
| `claude`   | `.claude/hooks/agent-memory-sync.sh`                                                               |
| `codex`    | `.codex/hooks/agent-memory-sync.sh`                                                                |
| `opencode` | `.opencode/plugins/agent-memory.ts` (+ `safe-script.ts`) or `.opencode/hooks/agent-memory-sync.sh` |
| `copilot`  | `.github/hooks/agent-memory.json` or `.github/hooks/agent-memory-sync.sh`                          |
| `gemini`   | `.gemini/settings.json` containing agent-memory or `.gemini/hooks/agent-memory-sync.sh`            |

Skip harnesses with no marker even if the prerequisite dir exists.

### Stamp vs skill (`update` only)

Target = this skill's `metadata.version` (Read `SKILL.md` frontmatter). For each installed harness:

1. Read `$hooksDir/.version` (first line, trim). Stamp path is the installer dir: `.cursor/hooks/.version`, `.opencode/hooks/.version`, and so on.
2. **Complete** when all five scripts exist in that dir (`agent-memory-common.sh`, `agent-memory-sync.sh`, `agent-memory-session.sh`, `agent-memory-consume-evidence.sh`, `agent-memory-print-evidence.sh`). OpenCode also needs `.opencode/plugins/agent-memory.ts` and `safe-script.ts`.
3. **current:** stamp equals target **and** Complete. Report one line: `hooks <harness> current (<stamp>) — installer skip`. Do **not** print step 4 commands.
4. **stale:** missing stamp, stamp ≠ target, or not Complete. Print step 4 commands for that harness (no agent copy/merge).
5. No installed harness: report none found. Do **not** print step 4.

`/agent-memory install hooks <harness>` and `init` step 7 always print step 4 (user asked to install). This stamp check is **`update` only**.

## Behavior

Hooks run a **deterministic ephemeral checkpoint** — session binding and session-cumulative touched paths in `.hook-sync-state` only. Semantic log text, active-work resume fields, decision pointers / fallbacks, learnings, and consolidation stay agent-owned (or `/agent-memory sync` / `/agent-memory consolidate`). Hooks never write Markdown and never copy project docs. See the [hooks README](https://github.com/diegoos/agent-memory/blob/HEAD/hooks/README.md).

Optional git `pre-commit` and `post-commit` are **not** installed by this command — see the same [hooks README](https://github.com/diegoos/agent-memory/blob/HEAD/hooks/README.md).
