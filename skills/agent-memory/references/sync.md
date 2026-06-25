# `/agent-memory sync`

Refresh the four files that rot between commands — `current.md`, your branch's
`active-work/<branch>.md`, `log.md`, and `index.md` — from **actual repo state**
(`git`), not chat history. This is the executable form of the _During_ / _After_
/ _Flush early_ workflow in `instructions.md`.

Use it at any checkpoint: end of a task, before a commit, before context
compaction, or when picking work back up. Safe and idempotent.

## Boundary

Sync writes only to: `current.md`, `active-work/<branch>.md`, `log.md`, and the
Domains/Features lists of `index.md`. It **never** touches `decisions.md`,
`instructions.md`, `domains/*` / `features/*` content, or any file outside
`.agents/memory/`. It never deletes anything.

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

4. **Gather evidence (read-only, from `git`).**

   ```bash
   git log --since="<last-log-date>" --pretty='%h %ad %s' --date=short --no-merges
   git diff --stat <base>..HEAD          # base: main/master or origin/<branch>@{u}
   git status --porcelain
   git diff --name-only <last-log-sha>..HEAD 2>/dev/null || true
   ```

   `<last-log-date>` and `<last-log-sha>` come from the newest `## [YYYY-MM-DD]`
   header in `log.md`. If `log.md` is empty, use the repo's first commit
   (`git log --reverse --pretty='%h' | head -1`) or `HEAD~20` as a sane default.

5. **Propose updates (one diff per file).** Show each as a unified diff and
   confirm via `AskQuestion` before writing — sync touches project memory, so
   the "confirm before editing user content" rule applies. Allow approve / skip
   per file.
   - **`active-work/<branch>.md`** — fill/refresh _Task_, _Progress_, _Touched
     files_ (from `git diff --name-only`), and _Blockers_. Keep _Notes_ as-is.
     Overwrite only fields the evidence supports; do not invent progress.
   - **`log.md`** — append one entry per meaningful change since the last entry:
     `## [YYYY-MM-DD] type | description`. Type from the commit message or the
     change shape (`feature`, `fix`, `refactor`, `docs`, `chore`, `test`,
     `perf`, `security`). Merge trivial churn into a single `chore` entry.
     Oldest first / newest at the bottom; keep both on conflict.
   - **`current.md`** — refresh _Version / milestone_, _Done_, _In progress_,
     _Next steps_ from the evidence plus a read of `active-work/<branch>.md`.
     Keep it a short snapshot — detail stays in `log.md` / lazy files.
   - **`index.md`** — for every `domains/*.md` / `features/*.md` that exists but
     is not yet listed under its section, add a link line (replacing the
     `_None yet._` placeholder the first time). Do not remove existing entries.

6. **Apply approved diffs** only, with `Edit`/`Write` scoped to
   `.agents/memory/**`. Skip anything the user declined.

7. **Report.** List each file: updated, skipped, or unchanged — and one line on
   what the next agent should read to continue (the branch's active-work file
   plus `current.md`).

## Notes

- Sync is **additive and conservative**. It will not remove a stale `current.md`
  fact on its own — flag staleness for `lint` instead.
- If `git` is unavailable, fall back to reading recently modified files under
  the project and ask the user to confirm what changed.
- Mirrors the _Flush early_ section of `instructions.md`; keep them aligned.
