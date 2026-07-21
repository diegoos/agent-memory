# `/agent-memory sync`

Refresh the four files that rot between commands — `current.md`, your branch's
`active-work/<branch>.md`, `log.md`, and `index.md` — from **actual repo state**
(`git`) and session context, not chat history. This is the executable form of
the _Workflow_ section in `instructions.md`.

Use it at any checkpoint: end of a task, before a commit, before context
compaction, or when picking work back up. Safe and idempotent.

## Flags

- `--auto` — apply all proposed diffs without the per-file `AskQuestion` prompt.
  Use at routine checkpoints (where you would approve everything anyway) to keep
  the flush low-friction; without it, sync is the careful, per-file-confirm form
  suited to the first run or a manual review. `--auto` still shows the diffs in
  the report after applying, and still skips fields for which it has no evidence
  (it never invents progress or log bullets).
- `--force` — reserved for explicit user override.

## Boundary

Sync writes only to: `current.md`, `active-work/<branch>.md`, `log.md`, and
`index.md` (recall-file links and newly relevant canonical source links when
evidence exists). It **never** touches `decisions.md`, `learnings.md`,
`instructions.md`, or any file outside `.agents/memory/`. It never deletes
anything except replacing placeholder lines inside the four target files. It
never copies documentation, never invents roadmaps, and never re-indexes the
whole docs tree.

Hooks maintain `log.md` session headings and file-path bullets from `git`; sync
adds semantic outcome bullets, refines summaries/types, and aligns `index.md`
links. The split is the same on every harness — see `instructions.md` →
_Harness parity — memory contract_.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init`.

2. **Resolve the branch.** Run `git branch --show-current` (fall back to `local`
   if HEAD is detached or not a git repo). Sanitize every character outside
   `[A-Za-z0-9._-]` to `-`. This is the active-work filename.

3. **Ensure the active-work file.** If `active-work/<branch>.md` is missing,
   create it from `active-work/TEMPLATE.md` and set its `Branch:` header to the
   real branch name (never reverse the lossy filename). If it exists, leave the
   header as-is.

4. **Gather evidence (read-only, from `git` and memory).**

   ```bash
   git log --since="<last-log-date>" --pretty='%h %ad %s' --date=short --no-merges
   git diff --stat <base>..HEAD          # base: main/master or origin/<branch>@{u}
   git status --porcelain
   git diff --name-only <last-log-sha>..HEAD 2>/dev/null || true
   ```

   Session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin (`session_id` /
   `conversation_id` / `sessionId`), or `current_session_id` from
   `.agents/memory/.hook-sync-state`.

   For `log.md`, find the **current session** heading:
   `## [YYYY-MM-DD] [session-id] ...` (session-id bracket optional). Append
   bullets under it; open a new heading only for a new session.

   `<last-log-date>` comes from the newest `## [YYYY-MM-DD]` in `log.md`. If
   empty, use the repo's first commit or `HEAD~20` as a sane default.

   `<last-log-sha>` is `last_processed_head` from
   `.agents/memory/.hook-sync-state` (written by hooks after each checkpoint).
   If empty, skip the `git diff --name-only <last-log-sha>..HEAD` line — there
   is no prior processed commit to diff from.

5. **Propose updates (one diff per file).** Show each as a unified diff. Unless
   `--auto` is set, confirm via `AskQuestion` before writing — sync touches
   project memory, so the "confirm before editing user content" rule applies.
   Allow approve / skip per file. Under `--auto`, apply all proposed diffs
   without prompting and report them after.
   - **`active-work/<branch>.md`** — fill/refresh _Task_ (infer from branch
     name, user context, `current.md`, recent `log.md` — 1–2 lines),
     _Progress_ (outcomes/state only — never a long commit narrative),
     _Touched files_ (from `git diff --name-only`; hooks may already own this),
     and _Blockers_. Keep _Notes_ as-is unless evidence supports an update.
     Overwrite only fields the evidence supports.
   - **`log.md`** — maintain **one heading per session**:
     `## [YYYY-MM-DD] [session-id] [type] short outcome` with `-` bullets for
     concrete **outcomes** this session. Hooks may have appended ``- `path` ``
     bullets already — add semantic bullets only; **do not repeat paths** already
     in _Touched files_ or written by hooks; refine type/summary; dedupe. Oldest
     first / newest at bottom. Do not reopen or summarize closed sessions.
   - **`current.md`** — refresh _In progress_ (list each open
     `active-work/*.md` with a one-line branch goal). Aggregate
     _Blockers / attention_ only for shared impediments. Update _Handoff_ only
     from an explicit instruction/plan. Do **not** maintain Done, milestone, or
     roadmap sections.
   - **`index.md`** — for every existing recall file (`learnings.md`, topic
     splits, etc.) not yet listed, add a link. Remove links to deleted recall
     files. Add a **canonical source** link only when that source was created or
     became newly relevant this session — do not re-discover the whole docs tree.

6. **Apply approved diffs** only, with `Edit`/`Write` scoped to
   `.agents/memory/**`. Skip anything the user declined.

7. **Report.** List each file: updated, skipped, or unchanged — and one line on
   what the next agent should read to continue (the branch's active-work file
   plus `current.md`). If a decision or learning trigger fired, remind the agent
   to update `decisions.md` / `learnings.md` (or the external ADR/doc) —
   sync does not write those files. Suggest `/agent-memory consolidate` when
   `log.md` has accumulated closed-session noise.

## Notes

- Sync is **additive and conservative** for `current.md` facts — flag staleness
  for `lint` instead of silent deletion.
- If `git` is unavailable, fall back to reading recently modified files under
  the project and ask the user to confirm what changed.
- Mirrors the _Workflow_ section of `instructions.md`; keep them aligned.
