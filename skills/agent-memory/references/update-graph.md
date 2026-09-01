# `/agent-memory update` — graph reshape

Loaded from `update.md` **Graph reshape**. Delete leftover mirrors; type decisions and log; drop dead paths. Unique facts stay. **Do not** merge project-docs links into `index.md` Canonical sources (`AGENTS.md` is that map — `references/docs-map.md`).

**Sensitive:** one unified diff per file (or one delete batch). Confirm; skip/abort that item and continue. **Do not** invent learnings, ADRs, or `when editing:` globs (this step has no path-evidence gate).

**Done when:** every step below ran or was an explicit skip; no remaining link under `.agents/memory/` points at a deleted path; `index.md` Recall files lists only files that exist.

## Inventory

Glob under `.agents/memory/` (not `instructions.md`):

| Class             | Paths                                                                                                                                |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Mirrors**       | `vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`, `known-issues.md`, `project.md`; `domains/**/*.md`; `features/**/*.md` |
| **Graph dirs**    | `architecture/`, `domains/`, `features/`, `components/`, `episodes/`, `changes/`, `timeline/` (directories under memory)             |
| **Junk**          | `active-work/*` that is not `*.md` (e.g. `.json` loop state)                                                                         |
| **Closed resume** | `active-work/*.md` except `TEMPLATE.md`                                                                                              |

**Pointer-only file:** after dropping blank lines, `---`, and headings, every remaining line is a markdown link bullet and/or the words “pointer only” / “do not duplicate” / “Canonical sources”. No extra product prose.

**Done when:** the inventory list is complete (including empty dirs and junk).

## Collapse mirrors

For each mirror file (inventory order: files, then empty dirs):

1. Collect outbound markdown links whose target is outside `.agents/memory/` (`../../` / `../../../`).
2. **Do not** merge those targets into `index.md` Canonical project sources. If `AGENTS.md` already links the path, discard. If the path is a project-docs index (`references/docs-map.md`) and AGENTS omits it, report as an **AGENTS docs-map** candidate — leave it off memory. Other unique facts (not docs/ADR) that pass the index rule (AGENTS does not link it **and** a cold session needs it before choosing a recall file): at most **one** Canonical bullet (≤20 words) **or** report as a consolidate candidate.
3. If the file has product prose: report leftover unique facts as **consolidate** candidates (this step invents no learnings).
4. Delete the mirror file.
5. After all files in a graph dir are gone, remove the empty directory.

**Done when:** no inventory mirror path remains on disk; Canonical sources were not filled from mirror docs links.

## Rewrite `index.md` Recall files

Keep **only** lines whose target file still exists, from this set:

- `./decisions.md`
- `./log.md`
- `./learnings.md`
- `./learnings-*.md` (keep `when editing:` text on those lines)

Drop mirror names from Recall files (vision, architecture, patterns, domains, features, “Older installs…”). Add `learnings.md` only when that file exists. **Do not** keep Canonical bullets that `AGENTS.md` already links or that point at missing `docs/` / ADR trees — drop them (confirm).

**Done when:** every Recall files link resolves; no recall line names a deleted path.

## Dead references

Grep `.agents/memory/**/*.md` (skip `instructions.md`) for:

- `](./vision.md`, `](./architecture.md`, `](./patterns.md`, `](./project.md`
- `domains/`, `features/`, `active-work/TEMPLATE`
- `mistakes.md`, `known-issues.md` as memory-relative links
- unlinked prose `vision.md` / `memory domain files` / `domains/*.md` in `decisions.md` / `log.md`

Rewrite each hit to the folded canonical path, or delete the sentence if it only pointed at the mirror. In `decisions.md` / `log.md`, replace “memory `domains/*.md`” / “memory domain files” with “canonical specs under `docs/`” **only when that tree exists**; otherwise drop the phrase. Same for bare `vision.md` mentions.

**Done when:** Grep for those tokens under `.agents/memory/` (except `instructions.md` method text) is empty, or each leftover is a false positive in a quoted path that still exists in the repo **outside** memory.

## Decisions graph fields

For each `## [YYYY-MM-DD]` entry in `decisions.md`: if the body until the next `##` has no `Status:` line, insert `**Status:** live` immediately after the heading (before Context / Decision). Leave `Superseded by:`, `Relates:`, and new learnings files to consolidate / learn / lint (`live-dup-identity`).

Host may prompt (`decisions.md` is durable recall).

**Done when:** every dated decision heading has a `Status:` line, or the user skipped the file.

## Log shape (mechanical)

Closed types: `feat` `fix` `chore` `review` `docs` `refactor` `test` `perf` `security` `release` `ingest` `improve`.

- Heading whose `[type]` is outside that list: rewrite the token to `chore` (show diff).
- Same calendar day **and** same `[type]` more than once: keep the **last** heading title; move earlier bullets under it (drop exact-duplicate lines); delete the earlier headings. Keep at least one session heading.

Rolling-window prune of old dates is consolidate.

**Done when:** `same-day-dup-log` would not fire for remaining headings, or the user skipped the merge.

## Closed / junk active-work

- Delete non-`.md` files under `active-work/` (confirm).
- Offer delete (confirm) for `active-work/<name>.md` when **any** of: Task line starts with `Closed`; Next step is only “delete this file” / “confirm branch merged”; Task is a placeholder (`refine in session`, `_none_` only) **and** `<name>` is `main`. Keep the current git branch’s file (`lint --fix` deletes stale-branch-gone).

**Done when:** junk is gone or skipped; closed-file offers were shown.

## Report

List: deleted mirrors, Canonical bullets **dropped** (not added from docs), dead links rewritten, decisions `Status: live` count, log types rewritten / headings merged, active-work deletes, skipped items, AGENTS docs-map candidates, consolidate leftovers (unique facts not folded).
