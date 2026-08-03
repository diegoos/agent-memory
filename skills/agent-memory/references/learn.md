# `/agent-memory learn`

Capture one gated learning or pitfall into Workspace Memory. Applies the retention gate in `instructions.md`, writes the canonical H2 entry, and links the file from `index.md` when needed. Confirm before writing. Does **not** accept `--auto`.

## Syntax

```text
/agent-memory learn [>topic] <lesson clue>
```

- `>topic` — optional. Target a topic split (`learnings-<topic>.md`). The slug is sanitized like branch names (lowercase; every character outside `[a-z0-9-]` → `-`; collapse repeats); the resulting slug is shown in the confirmation diff. Stop only when the sanitized slug is empty or collides with an existing split of a different theme.
- `<lesson clue>` — required. Free text from the user and/or the current session; the agent turns it into a generalized, actionable Insight.

Examples:

- `/agent-memory learn OpenCode spawn must go through safe-script before execFileSync`
- `/agent-memory learn >hooks hooks never write Markdown under .agents/memory`

## Boundary

- **May create/edit** `learnings.md`, `learnings-<topic>.md`, and the matching link line in `index.md` (with confirmation). `learnings*` paths are **outside** skill `allowed-tools` pre-approval — expect a host permission prompt.
- **Must not** edit `current.md`, `active-work/*`, `decisions.md`, `log.md`, `instructions.md`, or anything outside `.agents/memory/`.
- **Must not** copy docs into memory or invent evidence.
- Skill stays manual-only — never auto-trigger learn.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`. If any target file (`learnings.md`, the resolved `learnings-<topic>.md`, or `index.md`) has unresolved merge conflict markers, **stop**. If those files have uncommitted changes, warn and require confirmation before proposing diffs — never silently overwrite pre-existing edits.

2. **Parse input.** Extract optional `>topic` and the lesson clue. If the clue is empty, stop and show usage. Sanitize `>topic` to the slug form above and use it for the filename.

3. **Apply the retention gate** (`instructions.md` → _Retention gate and lifecycle_). Walk the gate explicitly. If any step fails (not reusable, already in a canonical source, task-only state, decision not learning, unevidenced, secrets), **stop**: report which step failed and what to do instead (e.g. active-work, `decisions.md`, pointer-only, or skip). Do not write a learning that failed the gate.

4. **Choose the target file.**
   - With `>topic`: the sanitized `learnings-<topic>.md` (create if missing).
   - Without topic: default `learnings.md`. If the clue explicitly names an existing split's slug, or exactly one existing split unambiguously owns the theme, propose that file in the confirmation diff. If more than one split could own it, **stop** and ask the user for `>topic` — do not guess.
   - Never write under `domains/*` or `features/*`.

5. **Dedupe.** Read the target file first. Skip and report the existing entry — without writing — when the duplicate rule in `instructions.md` matches: same normalized topic + equivalent Insight in an H2 entry, or a legacy one-liner covering the same insight. When a legacy one-liner duplicates the lesson, offer to convert it to H2 in the same confirmed diff instead of appending. **On any skip** (dedupe or gate failure): print a clear report naming the rule/step, the matching existing heading or reason, and what to do instead — do **not** silently no-op. Optionally add one Progress bullet in the branch `active-work` (host may prompt — outside learn Boundary) such as `learn skipped: dup of "[topic]"` so the hot path records the attempt.

6. **Draft the entry** in the canonical H2 form from `instructions.md` (concise Insight — see _How to write_):

   ```md
   ## [YYYY-MM-DD] [learning|pitfall] Short topic

   - Insight: reusable pattern (prefer what to do; generalize beyond this incident).
   - Evidence: path|link
   - Use when: trigger
   - Verified: YYYY-MM-DD
   - Invalidate when: condition
   ```

   Use today's date for the heading and `Verified`. Choose `learning` or `pitfall`. When the fact belongs in official docs, add **both** `- pending-doc` and `- Invalidate when: <concrete condition naming the canonical doc/section>` (not `pending-doc` alone).

7. **Draft the `index.md` line.** When the file is new or unlisted, add the link. When the file is already listed **without** a `when editing:` hint and Evidence lists **1–3 concrete repo-relative paths** (files or narrow globs with a literal segment — never denylist/overbroad forms), **propose** updating that line in place with `when editing: <globs>; <short description>` (never a second entry; never invent globs). Path-specific topic splits should usually get a hint; cross-cutting `learnings.md` may still get one when Evidence is path-obvious. Hints follow `instructions.md` → _Always load_.

8. **Show the proposal** (entry + `index.md` change if any) as a diff. Confirm: approve / skip / abort. On skip or abort, write nothing — still print the skip report from step 5 if dedupe/gate applied earlier.

9. **Apply.** Append the entry at the **bottom** of the target file (oldest first). Create the file with a short H1 (`# Learnings` or `# <Topic> learnings`) only when creating. Update `index.md` _Recall files_ when needed.

10. **Report.** File written (or **skipped** with reason + matching entry), topic tag, whether `index.md` changed (and whether a hint was added/updated), and one line on when to load it next (`when editing` or on-demand).

## Notes

- Align with writing guidance in `instructions.md`: generalize; prefer correct patterns over “don’t” lists.
- Primary write in-turn may still append learnings without this command; `learn` is the explicit capture path when the user wants a gated write now.
- `/agent-memory consolidate` remains the path for promoting closed-session log noise into learnings and for proposing topic splits/merges.
