# `/agent-memory update`

Migrate `.agents/memory/` from this skill's `vendor/`. Refresh the harness **block** only between `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->` (migrate legacy plain tags to comments). Hook installer commands only when a harness stamp is **stale**. **Graph reshape** is [`references/update-graph.md`](./update-graph.md) — load it in step 4 even when `.version` already matches.

## Boundary (read before doing anything)

- **Preserve unique recall:** keep decision bodies, log outcomes, learnings H2s, live Task/Next step, and Canonical sources that still pass the index rule — except the mechanical edits in `update-graph.md` (drop bullets `AGENTS.md` already covers or that point at missing docs trees).
- **Scaffolding:** `instructions.md`, `index.md` structure, `.version`, missing core files, harness block, leftover `TEMPLATE.md`, `.gitignore`.
- **Harness files:** edit the delimited agent-memory block; **plus** the `AGENTS.md` docs map outside that block (`references/docs-map.md`). For `.cursor/rules/agent-memory.mdc`, keep YAML frontmatter and replace the delimited body.
- **Learnings / hints:** leave new `learnings.md` rows and new `when editing:` globs to learn / consolidate / write-floor (path evidence required).

## Canonical memory block

The exact block `init` writes and `update` refreshes is defined in [`references/agent-block.md`](./agent-block.md) — read it from there; do not inline the block text here. Each wired file's block is **replaced verbatim** with that canonical block during update (single source of truth).

**Instruction file targets** — same carriers and rules as `references/init.md` (harness table, Cursor/Copilot wrappers, delegation/copilot coexistence). Read that reference for write targets; do not restate the table here.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`.
   **Done when:** memory exists, or init is the only output.

2. **Read versions.** Installed = `.agents/memory/.version`. Latest = the newest version section in this skill's `vendor/UPDATE.md`. If equal, still run step 4 always-on items (gitignore, delete leftover `active-work/TEMPLATE.md`, **graph reshape**), and step 5 (refresh instruction blocks) before reporting "already up to date".

3. **Select migrations.** Read this skill's `vendor/UPDATE.md` (see `SKILL.md` → Vendor source) and collect every entry with a version greater than the installed version, up to the latest. Each change is tagged `safe` or `sensitive`. **Skip** any item marked **superseded** (e.g. a later version says it supersedes an earlier sensitive step) — do not apply superseded migrations.

4. **Apply, conservatively:**
   - **Automatic (no prompt):**
     - Create new core files that are missing. Do **not** create `active-work/TEMPLATE.md`.
     - If `active-work/TEMPLATE.md` exists, **delete it** (safe — copy scaffold lives in this skill's `references/active-work-template.md`). Run this even when installed version equals latest.
     - Ensure `.agents/memory/.gitignore` exists and matches this skill's `vendor/memory/gitignore` (Read vendor template, Write destination — npm packs use the non-dot `gitignore` name because `.gitignore` files are omitted from tarballs). Hosts often hide dotfiles from `Glob` — do **not** rely on directory listings. If the installed file is missing or differs only by missing required hook-state ignores (`.hook-sync-state`, `.hook-sync-state.lock`, `.hook-sync-state.*`, or legacy `.cursor-hook-state`), replace it without prompting. If the user added extra ignore rules, **merge** (keep theirs + ensure those three `.hook-sync-state*` lines are listed) and treat that merge as **sensitive** (show diff, confirm).
   - **Always confirm with a diff before applying:**
     - `instructions.md` when the installed copy differs from the skill's current `vendor/memory/instructions.md` (identical → nothing to do). `instructions.md` is **outside** skill `allowed-tools` — expect a host permission prompt; still show the unified diff and confirm before applying.
     - `current.md` structural cleanup from `UPDATE.md` (e.g. 0.0.14 removal of legacy `Version / milestone` / `Done` / `Next steps`) — preserve `## In progress` and any still-useful bullets the user wants kept.
     - `active-work/*.md` (per-branch files only) — ensure required core resume sections (`Task`, `Next step`, `Validation`, `Checkpoint:`); `Progress` is optional (keep if it has content; offer to drop empty `## Progress` / `_none_` — sensitive). Other optional sections (`Assumptions / open questions`, `Blockers`, `Rejected approaches`, `References`, `Hold`) only when they have content (`Hold` max 3 bullets — offer trim or `/agent-memory learn` if over) — offer to remove empty `_none_` optional sections (sensitive — show diff, confirm); offer removal of legacy `## Touched files` (sensitive — show diff, confirm). Preserve existing semantic content. For existing branch files, strip leftover instructional paragraphs under `##` headings. Copy shape: this skill's `references/active-work-template.md`.
     - `log.md` / `decisions.md` scaffolding from 0.1.0 — refresh format docs only; preserve entries; do not invent headings. Legacy path-only bullets and empty closed-session headings are consolidate candidates (confirm).
     - Any change to a file that can hold user content — including `index.md` (merge structural sections; **preserve** `when editing:` hints; **drop** Canonical bullets that `AGENTS.md` already links or that target missing `docs/` / ADR trees).
     - Any rename, move, or deletion listed in `UPDATE.md` or `update-graph.md`.
   - **Skip superseded items** — e.g. skip agent-merge of `.cursor/hooks.json` `afterFileEdit` when `UPDATE.md` marks that 0.0.10 step as superseded (hooks refresh is user-run installer only).
   - Present each sensitive change as a unified diff and ask the user to approve, skip, or abort. Apply only what is approved.
   - **Graph reshape.** Read [`references/update-graph.md`](./update-graph.md) and follow it exactly.
     **Done when:** `update-graph.md` completion criteria hold, or every remaining item was an explicit skip.

5. **Refresh instruction blocks.** Read the canonical block from [`references/agent-block.md`](./agent-block.md). For **each wired target** that exists at the project root (table above), decide what changed:
   - **A delimited block exists** (`<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`, or legacy plain `<agent-memory>` … `</agent-memory>`): compare its current text (between the delimiters, inclusive) against the canonical block, byte-for-byte. **Identical → skip (already current).** Different → replace block content with the canonical block (comment delimiters). For `.mdc`, replace only the delimited body; preserve existing frontmatter (or apply the canonical frontmatter from `agent-block.md` — `alwaysApply: true` for Cursor, `applyTo: "**"` for Copilot — if missing). **Sensitive** — show the unified diff, confirm first. Do not edit outside the delimiters **in this step**.
   - **No block yet, but a legacy `## Agent Memory` section exists** (installed by an older `init` without delimiters): replace that section with the canonical block (delimiters and content). **Sensitive** — show the diff, confirm first.
   - **No block and no legacy section:** skip (the file was never wired by `init`). Do not create a block here — that is `init`'s job. Mention it in the report so the user can run `init` if they want the file wired.

   **Migration — cursor/copilot from `AGENTS.md` only** (sensitive, with diff): if `.cursor/rules/agent-memory.mdc` or `.github/instructions/agent-memory.instructions.md` is missing but the block lives in `AGENTS.md`, and no codex/opencode/claude-via-delegation needs that carrier, offer to **move** the block from `AGENTS.md` to the harness native file (create native if needed). Keep any `## Docs` / Quick Reference map in `AGENTS.md`.

   **Migration — delegation canary** (sensitive, with diff): if `CLAUDE.md` or `GEMINI.md` contains the block **and** `@AGENTS.md` (or `@./AGENTS.md`) while `AGENTS.md` also contains the block, offer to **remove** the block from the file that delegates (double injection from older installs).

   Apply only what is approved. If every wired file's block is already byte-identical to the canonical block, report "instruction blocks already current" and move on.

   **Docs map.** Follow [`references/docs-map.md`](./docs-map.md): patch `AGENTS.md` **outside** the block when project-docs indices exist and AGENTS omits them. Confirm. Do not add those links to `index.md`. Skip when no such indices exist.

6. **Hook status.** Follow [`references/install-hooks.md`](./install-hooks.md) → **Detecting installed harnesses** and **Stamp vs skill**. Print step 4 installer commands only for **stale** harnesses. **current** harnesses: the one-line skip (CLI already refreshed scripts, or stamps already match). **Do not** copy scripts or merge configs.
   **Done when:** every installed harness is classified current or stale, and installer commands appear only for stale.

7. **Finalize.** Update `.agents/memory/.version` to the latest. Append one `log.md` heading `## [YYYY-MM-DD] [chore] agent-memory update to <version>` (merge into today's existing `[chore]` heading when Graph reshape already coalesced same-day `[chore]`).

8. **Report.** Summarize what was applied automatically, what was confirmed, and what was skipped — including graph-reshape deletions and rewrites (`update-graph.md` Report), **docs-map** patches or skips, which instruction files had their block refreshed, which had a legacy section migrated, delegation-canary removals offered/applied, which files were left untouched, and hook status (current vs stale vs none found). List printed installer commands only under stale. End with: the user may run `/agent-memory lint` to check the memory after this update (optional; not a required next command). Do **not** say that `lint --fix` or `sync` will slim `decisions.md` or invent learnings — that is `/agent-memory consolidate` Pass A.

   For Cursor, note that `.cursor/rules/agent-memory.mdc` is the **context layer** (always-on rules) and hooks are the **checkpoint layer** — both are recommended after `init cursor`. If `.cursor/hooks/agent-memory-sync.sh` exists but `.cursor/rules/agent-memory.mdc` is missing, suggest `/agent-memory init cursor` to add the context layer (likewise for Copilot: if `.github/hooks/` is wired but `.github/instructions/agent-memory.instructions.md` is missing).

## Gotchas

- Treat an ambiguous edit as sensitive and confirm.
- Block refresh: only the delimiters (comment form or legacy plain tags). Missing delimiters → legacy `## Agent Memory` case in step 5, or skip and report. Docs map (`references/docs-map.md`) is **outside** the block.
- File contents: `vendor/memory/`. How to migrate: `vendor/UPDATE.md`. Leftover mirrors: `update-graph.md` (step 4, including when versions already match).
