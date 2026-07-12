# `/agent-memory update`

Migrate an existing `.agents/memory/` to the latest structure from this skill's
`vendor/` — **without ever altering the project's memory content.** It also
refreshes the memory **block** inside harness instruction files, **only**
between the `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` delimiters
(or legacy plain `<agent-memory>` … `</agent-memory>` tags, which `update`
migrates to the comment form). Hook refresh is **instructions only** (user-run
installer).

## Boundary (read before doing anything)

- **Project memory (NEVER touch):** `current.md`, `active-work/*`,
  `decisions.md`, `log.md`, `domains/*`, `features/*`, and any user-authored
  content.
- **Scaffolding (may change, see rules):** `instructions.md`, the structural
  sections of `index.md`, the `.version` file, brand-new core files, and the
  agent-memory block in harness instruction files.
- **Outside the block (NEVER touch):** any content in instruction files outside
  the agent-memory delimiters (`<!-- <agent-memory> -->` …
  `<!-- </agent-memory> -->`, or legacy plain tags). For
  `.cursor/rules/agent-memory.mdc`, preserve YAML frontmatter — refresh only the
  delimited body.

## Canonical memory block

The exact block `init` writes and `update` refreshes is defined in
[`references/agent-block.md`](./agent-block.md) — read it from there; do not
inline the block text here. Each wired file's block is **replaced verbatim**
with that canonical block during update (single source of truth).

**Instruction file targets** (same as `init`; see `references/init.md` for
carrier rules):

| File                                                | Notes                                                   |
| --------------------------------------------------- | ------------------------------------------------------- |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`               | Root agent files                                        |
| `.cursor/rules/agent-memory.mdc`                    | Compare body only; keep `alwaysApply: true` frontmatter |
| `.github/instructions/agent-memory.instructions.md` | Copilot path-specific; keep `applyTo: "**"` frontmatter |

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init`.

2. **Read versions.** Installed = `.agents/memory/.version`. Latest = the newest
   version section in this skill's `vendor/UPDATE.md`. If equal, still run step 5
   (refresh instruction blocks) before reporting "already up to date".

3. **Select migrations.** Read this skill's `vendor/UPDATE.md` (see `SKILL.md` →
   Repository source) and collect every entry with a version greater than the
   installed version, up to the latest. Each change is tagged `safe` or
   `sensitive`. **Skip** any item marked **superseded** (e.g. a later version
   says it supersedes an earlier sensitive step) — do not apply superseded
   migrations.

4. **Apply, conservatively:**
   - **Automatic (no prompt):**
     - Create new core files that are missing.
   - **Always confirm with a diff before applying:**
     - `instructions.md` when the installed copy differs from the skill's
       current `vendor/memory/instructions.md` (identical → nothing to do).
     - Any change to a file that can hold user content — including `index.md`
       (merge structural sections, **preserve the user's Domains/Features
       lists**).
     - Any rename, move, or deletion.
   - **Skip superseded items** — e.g. do **not** agent-merge `.cursor/hooks.json`
     for `afterFileEdit` when `UPDATE.md` marks that 0.0.10 sensitive step as
     superseded (hooks refresh is user-run installer only).
   - Present each sensitive change as a unified diff and ask the user to
     approve, skip, or abort. Apply only what is approved.

5. **Refresh instruction blocks.** Read the canonical block from
   [`references/agent-block.md`](./agent-block.md). For **each wired target**
   that exists at the project root (table above), decide what changed:
   - **A delimited block exists** (`<!-- <agent-memory> -->` …
     `<!-- </agent-memory> -->`, or legacy plain `<agent-memory>` …
     `</agent-memory>`): compare its current text (between the delimiters,
     inclusive) against the canonical block, byte-for-byte. **Identical → skip
     (already current).** Different → replace block content with the canonical
     block (comment delimiters). For `.mdc`, replace only the delimited body;
     preserve existing frontmatter (or apply the canonical frontmatter from
     `agent-block.md` — `alwaysApply: true` for Cursor, `applyTo: "**"` for
     Copilot — if missing). **Sensitive** — show the unified diff, confirm
     first. Never touch anything outside the delimiters.
   - **No block yet, but a legacy `## Agent Memory` section exists** (installed
     by an older `init` without delimiters): replace that section with the
     canonical block (delimiters and content). **Sensitive** — show the diff,
     confirm first.
   - **No block and no legacy section:** skip (the file was never wired by
     `init`). Do not create a block here — that is `init`'s job. Mention it in
     the report so the user can run `init` if they want the file wired.

   **Migration — cursor/copilot from `AGENTS.md` only** (sensitive, with diff):
   if `.cursor/rules/agent-memory.mdc` or
   `.github/instructions/agent-memory.instructions.md` is missing but the block
   lives in `AGENTS.md`, and no codex/opencode/claude-via-delegation needs that
   carrier, offer to **move** the block from `AGENTS.md` to the harness native
   file (create native if needed).

   **Migration — delegation canary** (sensitive, with diff): if `CLAUDE.md` or
   `GEMINI.md` contains the block **and** `@AGENTS.md` (or `@./AGENTS.md`) while
   `AGENTS.md` also contains the block, offer to **remove** the block from the
   file that delegates (double injection from older installs).

   Apply only what is approved. If every wired file's block is already
   byte-identical to the canonical block, report "instruction blocks already
   current" and move on.

6. **Instruct hook refresh.** Follow
   [`references/install-hooks.md`](./install-hooks.md) → **Detecting installed
   harnesses** and for each installed harness print the user-run refresh
   commands (step 4 of that reference). **Do not** copy scripts or merge
   configs. Run even when the installed version already equals the latest (hook
   scripts may have changed without a memory migration). Report which harnesses
   need a user refresh and which were skipped.

7. **Finalize.** Update `.agents/memory/.version` to the latest. Append one
   entry to `log.md`:
   `## [YYYY-MM-DD] chore | agent-memory update to <version>`.

8. **Report.** Summarize what was applied automatically, what was confirmed, and
   what was skipped — including which instruction files had their block
   refreshed, which had a legacy section migrated, delegation-canary removals
   offered/applied, which files were left untouched, and which harness hook
   refresh commands were printed.

   For Cursor, note that `.cursor/rules/agent-memory.mdc` is the **context
   layer** (always-on rules) and hooks are the **checkpoint layer** — both are
   recommended after `init cursor`. If `.cursor/hooks/agent-memory-sync.sh`
   exists but `.cursor/rules/agent-memory.mdc` is missing, suggest
   `/agent-memory init cursor` to add the context layer (likewise for Copilot:
   if `.github/hooks/` is wired but
   `.github/instructions/agent-memory.instructions.md` is missing).

## Gotchas

- Never resolve a sensitive change silently. When in doubt, treat it as
  sensitive and confirm.
- The block refresh edits only between the agent-memory delimiters (comment form
  or legacy plain tags). If no delimiters are found, do **not** guess where the
  block starts — treat it as the legacy-section case above, or skip and report.
- The skeleton source of truth is this skill's `vendor/memory/`;
  `vendor/UPDATE.md` only describes _how_ to migrate between versions, not the
  file contents.
