# `/agent-memory init`

Create the agent-memory structure in the target project and wire it into the harness-specific instruction file(s). Prints user-run instructions for lifecycle hooks (does not install hooks). Idempotent: never duplicate or overwrite existing memory or harness instruction files.

## Invocation

```text
/agent-memory init                  # auto-detect harnesses from the project
/agent-memory init <harness>        # wire one harness only
```

Accepted `<harness>` values (aliases in parentheses):

| Harness    | Aliases       | Native instruction file (context)                   | Harness dir for hooks               |
| ---------- | ------------- | --------------------------------------------------- | ----------------------------------- |
| `cursor`   | —             | `.cursor/rules/agent-memory.mdc`                    | `.cursor/` — lifecycle hooks        |
| `claude`   | `claude-code` | `CLAUDE.md`                                         | `.claude/` — lifecycle hooks        |
| `codex`    | —             | `AGENTS.md`                                         | `.codex/` — lifecycle hooks         |
| `opencode` | —             | `AGENTS.md`                                         | `.opencode/` — plugin + sync script |
| `copilot`  | `github`      | `.github/instructions/agent-memory.instructions.md` | `.github/` — lifecycle hooks        |
| `gemini`   | —             | `GEMINI.md`                                         | `.gemini/` — lifecycle hooks        |

If `<harness>` is missing, **auto-detect** (see step 4). If it is unknown, stop and list the accepted values.

Canonical sources live under `skills/agent-memory/` in the agent-memory repo:

- Agent block: [`references/agent-block.md`](./agent-block.md)
- Harness hooks/plugin: [`references/install-hooks.md`](./install-hooks.md)

## Steps

1. **Guard.** If `.agents/memory/` already exists, stop and tell the user the project is already initialized — suggest `/agent-memory update` or `/agent-memory install hooks <harness>` to refresh hooks. Do not overwrite anything.

2. **Copy the skeleton.** Read this skill's `vendor/memory/` (see `SKILL.md` → Repository source) and copy that directory into the project as `.agents/memory/` (the entire directory, including `active-work/TEMPLATE.md` and the hook-state ignore template). Do not clone or fetch remotely.

   **Dotfiles (required):** hosts often hide dotfiles from `Glob`, and npm omits files named `.gitignore` from published packs. After the copy, **explicitly** Read `vendor/memory/gitignore` (pack-safe name; same rules as a local `.gitignore` sibling when present) and Write it to `.agents/memory/.gitignore` (create/overwrite to match vendor). Contents must ignore `.hook-sync-state`, `.hook-sync-state.lock`, and `.hook-sync-state.*`. Then verify `.agents/memory/.gitignore` exists before continuing.

3. **Write the version anchor.** Create `.agents/memory/.version` containing the latest version — the newest version section in this skill's `vendor/UPDATE.md`, e.g. `0.1.1`.

4. **Parse the harness target.** From the invocation, read optional `<harness>`. Normalize aliases (`claude-code` → `claude`, `github` → `copilot`). If omitted, set mode to `auto` and **detect harnesses** (see **Auto-detection** below).

5. **Resolve carriers and wire instruction files.** Use the **canonical block** from [`references/agent-block.md`](./agent-block.md) — copy it verbatim (the `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` delimiters and everything between them).

   **Carrier resolution (before writing):** a harness is **served** if any file it auto-loads already contains the block. The block is written only into the **distinct set of effective carriers** — never into a second file the same harness also loads.
   - **Nominal native** per harness (table above).
   - **Delegation via `@import`:** if `CLAUDE.md` or `GEMINI.md` contains `@AGENTS.md` or `@./AGENTS.md`, the effective carrier for that harness is `AGENTS.md`, not the nominal file. Do **not** write the block into the file that delegates. Resolve recursively (`@CLAUDE.md`, `@GEMINI.md` in `AGENTS.md` / other agent files); stop on cycles.
   - **Copilot coexistence:** Copilot auto-loads `AGENTS.md` **and** `.github/instructions/agent-memory.instructions.md`. If `AGENTS.md` is an effective carrier (codex, opencode, or claude via delegation), Copilot is already served — **do not** create `.github/instructions/agent-memory.instructions.md`. If Copilot is the only harness that needs a carrier and `AGENTS.md` is not one, create the `.instructions.md` file and do not touch `AGENTS.md`.

   **Targeted mode** (`init <harness>`): resolve the carrier for that harness only. If the nominal native delegates to a file that already has the block, skip and report. If it delegates to a file **without** the block, write the block into the referenced file (effective carrier), not the nominal native.

   **Auto mode** (`init`): detect harnesses (below), resolve carriers for each, write the block once per distinct carrier. Apply copilot coexistence and delegation rules across the full set.

   **Cursor `.mdc` wrapper:** the block body is the canonical block verbatim. Prepend YAML frontmatter:

   ```yaml
   ---
   description: Agent Memory workspace memory workflow
   alwaysApply: true
   ---
   ```

   **Copilot `.instructions.md` wrapper:** the block body is the canonical block verbatim. Prepend YAML frontmatter so the file is **always-on** (Copilot path-specific files apply only to files matching `applyTo`):

   ```yaml
   ---
   applyTo: "**"
   ---
   ```

   **Prerequisite dirs (create harness roots only on explicit request).** Native instruction files inside a harness dir require that dir to exist. The skill does **not** create `.cursor/`, `.claude/`, `.codex/`, `.opencode/`, `.github/`, or `.gemini/` on its own: if the required dir is missing, **stop** for that harness and ask the user — offer to create it (and the needed subdir) on explicit confirmation, or tell them to create/enable it first (e.g. open the harness once so it creates its dir) and re-run. Creating a **subdirectory** inside an existing harness dir (e.g. `.cursor/rules/`, `.github/instructions/`) is allowed. Required dir per harness:

   | Harness  | Required dir (for native + hooks)                                   |
   | -------- | ------------------------------------------------------------------- |
   | cursor   | `.cursor/` (native `.cursor/rules/`, hooks `.cursor/hooks/`)        |
   | copilot  | `.github/` (native `.github/instructions/`, hooks `.github/hooks/`) |
   | claude   | `.claude/` (hooks only; `CLAUDE.md` lives at root)                  |
   | codex    | `.codex/` (hooks only; `AGENTS.md` lives at root)                   |
   | opencode | `.opencode/` (hooks only; `AGENTS.md` lives at root)                |
   | gemini   | `.gemini/` (hooks only; `GEMINI.md` lives at root)                  |

   **Idempotency:** if a carrier already contains a delimited agent-memory block (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain `<agent-memory>` … `</agent-memory>` from 0.0.4–0.0.5), skip it — do not add a second one. For `.mdc`, compare the body between delimiters (ignore frontmatter when comparing).

   **Orphan block cleanup:** for `cursor` / `copilot`, if `AGENTS.md` contains a block but is **not** an effective carrier (no codex/opencode/claude via delegation), warn and offer to remove it (**sensitive** — show diff, confirm first). Do not remove a block from `AGENTS.md` when it serves codex, opencode, or claude via delegation.

6. **Print hook-install instructions.** Follow [`references/install-hooks.md`](./install-hooks.md) for each harness that applies (targeted: that harness only; auto: every detected harness whose prerequisite dir exists). In `init`, run those steps **without** the memory guard (step 1 of that reference). **Do not** copy hook scripts or merge harness hook configs — only print the user-run `npx` / shell commands. Note: the skill never creates harness roots; the user-run installer **does** create them if missing when the user runs the printed command.

7. **Report.** List: mode (auto or targeted harness), detected harness(es), skeleton created, carrier file(s) wired or skipped (and why — delegation, copilot coexistence, idempotency), orphan-block offers, hook-install commands printed (or skipped for missing harness dirs), and suggest `bootstrap` (source inventory / gaps — not doc copies) / `sync` next steps. For Cursor, note that **hooks are the recommended checkpoint integration** (user-installed) and **`.mdc` is the context layer**. For OpenCode, note carrier is usually `AGENTS.md` and hooks are the Bun plugin under `.opencode/plugins/` (plus `.opencode/hooks/*.sh`). **After the user installs hooks**, tell them to **re-run `/agent-memory sync`** (or `--auto`) so `current.md` blockers and evidence catch up — memory written before hooks install will otherwise claim state is absent.

## Auto-detection (`init` without `<harness>`)

Scan the project root for file markers. Do **not** wire every existing agent file — detect harness(es), then install each native (with carrier resolution).

| Marker (project root)                       | Harness inferred | Notes                            |
| ------------------------------------------- | ---------------- | -------------------------------- |
| `CLAUDE.md` or `.claude/` (dir)             | `claude`         | Claude Code                      |
| `GEMINI.md` or `.gemini/` (dir)             | `gemini`         | Gemini CLI / Antigravity         |
| `.cursor/` or `.cursor/rules/` (directory)  | `cursor`         | Cursor rules system              |
| `.github/copilot-instructions.md`           | `copilot`        | Copilot repo-wide                |
| `.github/instructions/` (directory)         | `copilot`        | Copilot path-specific            |
| `~/.copilot/instructions` (home)            | `copilot`        | **detection only** — never write |
| `AGENTS.md` + `.codex/`                     | `codex`          |                                  |
| `AGENTS.md` + `.opencode/`                  | `opencode`       | OpenCode uses `AGENTS.md`        |
| `AGENTS.md` (no `.codex/` nor `.opencode/`) | ambiguous        | ask user: codex or opencode      |

- **Multi-harness:** if several markers match (e.g. `CLAUDE.md` + `.cursor/`), install each harness, applying carrier resolution and copilot coexistence across the set.
- **`~/.copilot/instructions`:** use only to infer Copilot usage. The install target remains project-level `.github/instructions/agent-memory.instructions.md` — never write under `~/`.
- **Inconclusive detection** (no markers, or `AGENTS.md` alone without `.codex/` / `.opencode/`): **ask the user** which harness to install (via `AskQuestion`: cursor, claude, codex, opencode, copilot, gemini). Do not guess. Do not create `AGENTS.md` blindly.

### Carrier example (claude + opencode)

Project: `CLAUDE.md` contains `@AGENTS.md`, `AGENTS.md` exists, `.opencode/` exists.

- opencode → carrier `AGENTS.md`
- claude → `CLAUDE.md` delegates → carrier `AGENTS.md`
- Result: write the block **once** in `AGENTS.md`; skip `CLAUDE.md`. Report: "claude served via `AGENTS.md` (@import in `CLAUDE.md`); `CLAUDE.md` skipped".

When `CLAUDE.md` is standalone (no `@AGENTS.md`), claude and opencode have distinct carriers → write the block in each file that is an effective carrier.

## Notes

- Do not populate the memory here — `init` only scaffolds. To index canonical sources and gaps, the user runs `/agent-memory bootstrap` (pointers, not doc copies). Bootstrap does not invent product vision when docs are missing — it reports the gap.
- Optional git `pre-commit` hook is **not** wired by `init` — see the [hooks README](https://github.com/diegoos/agent-memory/blob/0.1.1/hooks/README.md).
- **Context vs checkpoint:** native instruction files (`.mdc`, agent `*.md`, `.instructions.md`) inject the agent-memory workflow into the model context. Lifecycle hooks (see `install-hooks.md`) run deterministic git checkpoints — they do not replace context injection.
