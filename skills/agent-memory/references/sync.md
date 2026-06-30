# `/agent-memory sync`

Refresh the four files that rot between commands — `current.md`, your branch's
`active-work/<branch>.md`, `log.md`, and `index.md` — from **actual repo state**
(`git`) and session context, not chat history. This is the executable form of
the _During_ / _After_ / _Flush early_ workflow in `instructions.md`.

Use it at any checkpoint: end of a task, before a commit, before context
compaction, or when picking work back up. Safe and idempotent.

## Flags

- `--auto` — apply all proposed diffs without the per-file `AskQuestion` prompt.
  Use at routine checkpoints (where you would approve everything anyway) to keep
  the flush low-friction; without it, sync is the careful, per-file-confirm form
  suited to the first run or a manual review. `--auto` still shows the diffs in
  the report after applying, and still skips fields for which it has no evidence
  (it never invents progress or log bullets).
- `--force` — reserved for explicit user override; does not skip the vision
  uncertainty gate below.

## Boundary

Sync writes only to: `current.md`, `active-work/<branch>.md`, `log.md`, and
`index.md` (domains/features links and lazy-file links when evidence exists). It
**never** touches `decisions.md`, `instructions.md`, `domains/*` / `features/*`
body content, or any file outside `.agents/memory/`. It never deletes anything
except replacing placeholder lines inside the four target files.

Hooks maintain `log.md` session headings and file-path bullets from `git`; sync
adds semantic bullets, refines summaries/types, and aligns `decisions.md`
indirectly (sync still does not write `decisions.md` — the agent must).

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

   `<last-log-sha>` is `last_processed_head` from `.agents/memory/.hook-sync-state`
   (written by hooks after each checkpoint). If empty, skip the
   `git diff --name-only <last-log-sha>..HEAD` line — there is no prior
   processed commit to diff from.

5. **Vision gate (unless `--auto`).** If `vision.md` does not exist or looks
   stale/ambiguous and docs do not clarify product purpose, **ask the user**
   before creating or rewriting `vision.md`. If you inferred a vision change
   during sync, note it in the report for the user to confirm at session end.

6. **Propose updates (one diff per file).** Show each as a unified diff. Unless
   `--auto` is set, confirm via `AskQuestion` before writing — sync touches
   project memory, so the "confirm before editing user content" rule applies.
   Allow approve / skip per file. Under `--auto`, apply all proposed diffs
   without prompting and report them after.
   - **`active-work/<branch>.md`** — fill/refresh _Task_ (infer from branch
     name, user context, `current.md`, recent `log.md`), _Progress_, _Touched
     files_ (from `git diff --name-only`), and _Blockers_. Keep _Notes_ as-is
     unless evidence supports an update. Overwrite only fields the evidence
     supports.
   - **`log.md`** — maintain **one heading per session**:
     `## [YYYY-MM-DD] [session-id] [type] short summary` with `-` bullets for
     concrete changes this session. Hooks may have appended ``- `path` ``
     bullets already — add semantic bullets; refine type/summary; dedupe. Oldest
     first / newest at bottom.
   - **`current.md`** — refresh _Version / milestone_, _Done_, _In progress_
     (list each open `active-work/*.md` with a one-line branch goal), from
     evidence plus active-work files. Move completed branch work to _Done_ when
     the active-work file is gone. _Next steps_ **only** if an explicit
     roadmap/plan exists — remove or leave placeholder otherwise; never infer.
   - **`index.md`** — for every existing lazy file (`vision.md`,
     `architecture.md`, `patterns.md`, etc.) and every `domains/*.md` /
     `features/*.md` not yet listed, add a link (replace `_None yet._` the first
     time). Remove links to deleted files. Do not remove valid entries.

7. **Apply approved diffs** only, with `Edit`/`Write` scoped to
   `.agents/memory/**`. Skip anything the user declined.

8. **Report.** List each file: updated, skipped, or unchanged — and one line on
   what the next agent should read to continue (the branch's active-work file
   plus `current.md`). If `vision.md` may need user input, say so explicitly.

## Notes

- Sync is **additive and conservative** for `current.md` facts — flag staleness
  for `lint` instead of silent deletion.
- If `git` is unavailable, fall back to reading recently modified files under
  the project and ask the user to confirm what changed.
- Remind the agent to update `decisions.md`, `architecture.md`, and
  `patterns.md` when their triggers fired — sync does not write those files.
- Mirrors the _Flush early_ section of `instructions.md`; keep them aligned.
