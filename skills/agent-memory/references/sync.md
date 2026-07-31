# `/agent-memory sync`

**Catch-up** for the four files that rot between commands — `current.md`, your branch's `active-work/<branch>.md`, `log.md`, and `index.md` — from **actual repo state** (`git`), session context, and optional `.hook-sync-state` evidence. This is the executable form of the _Workflow_ catch-up step in `instructions.md`.

**Primary write path** is still the agent in the turn: durable progress → update `active-work` resume fields and a semantic `log.md` outcome before stopping. Sync fills gaps and aligns Checkpoint / `current.md` / `index.md`; it does not invent meaning from paths alone.

Use sync at any checkpoint: end of a task, before a commit, before context compaction, or when picking work back up. Safe and idempotent. You may follow these steps and edit the four files directly without invoking the skill command.

## Flags

- `--auto` — apply all proposed diffs without the per-file `AskQuestion` prompt. Use at routine checkpoints (where you would approve everything anyway) to keep the flush low-friction; without it, sync is the careful, per-file-confirm form suited to the first run or a manual review. `--auto` still shows the diffs in the report after applying, and still skips fields for which it has no evidence (it never invents progress or log bullets).
- `--force` — reserved for explicit user override.

## Boundary

Sync writes only to: `current.md`, `active-work/<branch>.md`, `log.md`, and `index.md` (recall-file links and newly relevant canonical source links when evidence exists). It **never** touches `decisions.md`, `learnings.md`, `learnings-*.md`, `instructions.md`, or any file outside `.agents/memory/`. It never deletes anything except replacing placeholder lines inside the four target files. It never copies documentation, never invents roadmaps, and never re-indexes the whole docs tree. On `index.md`, existing `when editing:` hints are preserved verbatim (details in the steps below).

Hooks never write Markdown. They may populate `.hook-sync-state` (gitignored) with session id, branch, touched paths, and `last_processed_head`. Sync may **read** that state as evidence, then write semantic resume fields and log outcomes. The split is the same on every harness — see `instructions.md` → _Harness parity — memory contract_.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`.

2. **Resolve the branch.** Run `git branch --show-current` (fall back to `local` if HEAD is detached or not a git repo). Sanitize every character outside `[A-Za-z0-9._-]` to `-`. This is the active-work filename.

3. **Ensure the active-work file only when resumable.** If `active-work/<branch>.md` is missing and there is resumable work (dirty tree, open task context, or user intent to continue), create it from `active-work/TEMPLATE.md` and set its `Branch:` header to the real branch name. If no resumable work exists, skip creating the file. If it exists, leave the header as-is.

4. **Gather evidence (read-only, from `git`, memory, and hook state).**

   ```bash
   git log --since="<last-log-date>" --pretty='%h %ad %s' --date=short --no-merges
   git diff --stat <base>..HEAD          # base: main/master or origin/<branch>@{u}
   git status --porcelain
   git rev-parse --short HEAD
   git diff --name-only <last-log-sha>..HEAD 2>/dev/null || true
   ```

   Session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin (`session_id` / `conversation_id` / `sessionId`), or `current_session_id` from `.agents/memory/.hook-sync-state`.

   Optional hook state keys (evidence only — never copy into Markdown verbatim as path diaries): `session_touched_files`, `last_processed_head`, `branch`.

   For `log.md`, find the **current session** heading: `## [YYYY-MM-DD] [session-id] ...` (session-id bracket optional). Append bullets under it; open a new heading only for a new session **and** only when there is at least one semantic outcome.

   `<last-log-date>` comes from the newest `## [YYYY-MM-DD]` in `log.md`. If empty, use the repo's first commit or `HEAD~20` as a sane default.

   `<last-log-sha>` is `last_processed_head` from `.agents/memory/.hook-sync-state` (written by hooks after each checkpoint). If empty, skip the `git diff --name-only <last-log-sha>..HEAD` line — there is no prior processed commit to diff from.

5. **Propose updates (one diff per file).** Show each as a unified diff. Unless `--auto` is set, confirm via `AskQuestion` before writing — sync touches project memory, so the "confirm before editing user content" rule applies. Allow approve / skip per file. Under `--auto`, apply all proposed diffs without prompting and report them after.
   - **`active-work/<branch>.md`** — fill/refresh _Task_, _Progress_ (facts only), _Next step_, _Validation_ (command + expected result), _Assumptions / open questions_, _Blockers_, _Rejected approaches_, and _References_ (path/link + why). Update `Checkpoint: YYYY-MM-DD @ <short-sha>` from `git rev-parse --short HEAD`. Do **not** write path-only _Touched files_ sections. Overwrite only fields the evidence supports.
   - **`log.md`** — maintain **one heading per session** only when there is a useful outcome: `## [YYYY-MM-DD] [session-id] [type] short outcome` with `-` semantic bullets. Never write path bullets or `changed N files…`. Refine type/summary; dedupe. Oldest first / newest at bottom. Do not reopen or summarize closed sessions. Skip the file entirely when there is no semantic outcome.
   - **`current.md`** — refresh _In progress_ (list each open `active-work/*.md` with a one-line branch goal). Aggregate _Blockers / attention_ only for shared impediments. Update _Handoff_ only from an explicit instruction/plan. Do **not** maintain Done, milestone, or roadmap sections.
   - **`index.md`** — for every existing recall file (`learnings.md`, topic splits, etc.) not yet listed, add a link. Remove links to deleted recall files. When touching `index.md`, never remove or reformat `when editing:` hints on existing lines; when adding a newly listed orphan, write the minimal link without inventing a hint (hint creation belongs to `/agent-memory learn` / `consolidate` with path evidence). Add a **canonical source** link only when that source was created or became newly relevant this session — do not re-discover the whole docs tree.

6. **Apply approved diffs** only, with `Edit`/`Write` scoped to `.agents/memory/**`. Skip anything the user declined.

7. **Report.** List each file: updated, skipped, or unchanged — and one line on what the next agent should read to continue (the branch's active-work file plus `current.md`). If a decision or learning/pitfall trigger fired, remind the agent to update `decisions.md` / `learnings.md` (or run `/agent-memory learn`) — sync does not write those files. Suggest `/agent-memory consolidate` when `log.md` has accumulated closed-session noise.

## Notes

- Sync is **additive and conservative** for `current.md` facts — flag staleness for `lint` instead of silent deletion.
- If `git` is unavailable, fall back to reading recently modified files under the project and ask the user to confirm what changed.
- Mirrors the _Workflow_ section of `instructions.md`; keep them aligned.
