# `/agent-memory update` — graph reshape

Loaded from `update.md` **Graph reshape**. Fold leftover mirrors into the index map; type decisions and log; drop dead paths. Unique facts stay.

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
2. Merge each unique target into `index.md` **Canonical project sources** if missing. Line shape: `- [label](path) — one-line delta.` Deduplicate by resolved path. If the section would exceed **8** bullets, keep the existing user list; add only targets not already listed until 8; report overflow paths as “live in Git, not on the map.”
3. If the file has product prose: add at most **one** Canonical project sources bullet (≤20 words, unique fact → README/AGENTS/docs). Report leftover unique facts as **consolidate** candidates. Then delete the file.
4. Delete the mirror file.
5. After all files in a graph dir are gone, remove the empty directory.

**Done when:** no inventory mirror path remains on disk; Canonical sources ≤8 or overflow is reported.

## Rewrite `index.md` Recall files

Keep **only** lines whose target file still exists, from this set:

- `./decisions.md`
- `./log.md`
- `./learnings.md`
- `./learnings-*.md` (keep `when editing:` text on those lines)

Drop mirror names from Recall files (vision, architecture, patterns, domains, features, “Older installs…”). Add `learnings.md` only when that file exists. Keep Canonical project sources except Collapse merges.

**Done when:** every Recall files link resolves; no recall line names a deleted path.

## Dead references

Grep `.agents/memory/**/*.md` (skip `instructions.md`) for:

- `](./vision.md`, `](./architecture.md`, `](./patterns.md`, `](./project.md`
- `domains/`, `features/`, `active-work/TEMPLATE`
- `mistakes.md`, `known-issues.md` as memory-relative links

Rewrite each hit to the folded canonical path from Collapse, or delete the sentence if it only pointed at the mirror. In `decisions.md` / `log.md`, replace “memory `domains/*.md`” with “canonical specs under `docs/`” (or the folded path).

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

List: deleted mirrors, index bullets added/dropped, dead links rewritten, decisions `Status: live` count, log headings merged, active-work deletes, skipped items, consolidate leftovers (unique facts not folded).
