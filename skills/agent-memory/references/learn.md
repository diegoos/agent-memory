# `/agent-memory learn`

Capture one gated learning or pitfall into Workspace Memory. Applies the retention gate in `instructions.md`, writes the canonical H2 entry, and links the file from `index.md` when needed. Confirm before writing. Does **not** accept `--auto`. Daily capture is write-floor **Reusable lesson** in-turn (no this command). This command is explicit capture when the user asks now.

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

3. **Apply the retention gate** (`instructions.md` → _Retention gate and lifecycle_). Walk the gate explicitly. **Reusable lesson** is a write-floor row: require an **incident** + Git/docs omit the why + **1–3 concrete paths** (fail closed otherwise). If any step fails (not reusable, already in a canonical source, task-only state, **user constraint / product approach** → `decisions.md` write floor, no incident, no hintable paths, unevidenced, secrets), **stop**: report which step failed and what to do instead (e.g. active-work, write-floor `decisions.md` + supersede, skip). Do not write a learning that failed the gate. Already in README/spec/ADR → skip with an explicit report (pointer-only at most).

4. **Choose the target file.**
   - With `>topic`: the sanitized `learnings-<topic>.md` (create if missing).
   - Without topic, **path-scoped** (Evidence / clue names 1–3 repo-relative paths): if exactly one existing split owns the theme, use it. Else create `learnings-<topic>.md` from a **literal path segment** in those paths (e.g. `auth` from `src/auth/callback.ts`). If two splits could own it, or no literal segment is usable, use `learnings.md` with **file-literal** hints — do not guess; never an overbroad glob.
   - Without topic and **cross-cutting** (no path-scoped Evidence): default `learnings.md`. If the clue explicitly names an existing split's slug, or exactly one existing split unambiguously owns the theme, propose that file in the confirmation diff. If more than one split could own it, **stop** and ask the user for `>topic` — do not guess.
   - Never write under `domains/*` or `features/*`.

5. **Dedupe.** Read the target file first. Skip and report the existing entry — without writing — when the **Duplicate rule** (step 6) matches: same normalized topic + equivalent Insight in an H2 entry, or a legacy one-liner covering the same insight. When a legacy one-liner duplicates the lesson, offer to convert it to H2 in the same confirmed diff instead of appending. **On any skip** (dedupe or gate failure): print a clear report naming the rule/step, the matching existing heading or reason, and what to do instead — do **not** silently no-op. Optionally add one Progress bullet in the branch `active-work` (host may prompt — outside learn Boundary) such as `learn skipped: dup of "[topic]"` so the hot path records the attempt.

6. **Draft the entry** in the canonical H2 form (concise Insight — prefer what to do; generalize beyond this incident):

   ```md
   ## [YYYY-MM-DD] [learning|pitfall] Short topic

   - Insight: reusable pattern in one or two sentences.
   - Evidence: path|link
   - Use when: trigger
   - Verified: YYYY-MM-DD
   - Invalidate when: condition
   - Relates: caused_by [target](path)
   ```

   Use today's date for the heading and `Verified`. Choose `learning` or `pitfall`. When the fact belongs in official docs, add **both** `- pending-doc` and `- Invalidate when: <concrete condition naming the canonical doc/section>` (not `pending-doc` alone). Code/config inferences need evidence + date.

   **`Relates:`** — canonical `- Relates: <verb> [target](path)`. **Write it** when Evidence is already a recall file under `.agents/memory/` (`decisions.md`, `log.md`, `learnings.md` / `learnings-*.md`). Otherwise omit unless a typed link would change the next cold read. Closed verbs only: `supersedes`, `superseded_by`, `caused_by`, `contradicts`, `see` (`instructions.md` → _How to write_). One verb per line. Never `relates_to` or component `depends_on`. Do not add YAML frontmatter. Aliases (`Caused by:`, `- caused_by:`) stay valid on decisions/log; new learnings use `- Relates:` only. Lint flags `learning-missing-relates` when Evidence names a recall file and the H2 entry has no `- Relates:` line.

   **Legacy one-liner** (pre-H2 installs): `- [YYYY-MM-DD] [learning|pitfall] [topic] insight — evidence: …; use when: …; verified: …` — still valid; migrate to H2 only when editing that entry or when consolidate moves it.

   **Duplicate rule** — never record the same lesson twice across formats: skip a new entry when an existing H2 has the same normalized topic and equivalent Insight, or when a legacy one-liner covers the same insight (same evidence/use-when, minor wording aside). Applies to in-turn writes, `/agent-memory learn`, and consolidate promotions.

   **Topic splits** — use `learnings.md` for cross-cutting lessons. Path-scoped write-floor capture may create `learnings-<topic>.md` on the first lesson (literal path segment; step 4). When a theme later has several entries (or lint warns `learnings.md` > 200 lines), consolidate may split; never auto-split a large file without confirmation. Do not create `domains/*` or `features/*`. Link every learnings file from `index.md`; path-scoped links **must** carry a `when editing:` hint (`instructions.md` → _Always load_).

7. **Draft the `index.md` line.** When the file is new or unlisted, add the link. **Path-scoped** (write-floor Reusable lesson, or Evidence lists 1–3 concrete repo-relative paths): the line **must** include `when editing: <globs>; <short description>` in this same event (never a second index entry; never invent globs; never denylist/overbroad forms). Without a usable hint, **stop** — do not write a hidden lesson. When the file is already listed **without** a `when editing:` hint and Evidence lists 1–3 concrete paths (files or narrow globs with a literal segment), **propose** updating that line in place. Path-specific topic splits should get a hint; cross-cutting `learnings.md` may omit one. Hints follow `instructions.md` → _Always load_.

8. **Show the proposal** (entry + `index.md` change if any) as a diff. Confirm: approve / skip / abort. On skip or abort, write nothing — still print the skip report from step 5 if dedupe/gate applied earlier.

9. **Apply.** Append the entry at the **bottom** of the target file (oldest first). Create the file with a short H1 (`# Learnings` or `# <Topic> learnings`) only when creating. Update `index.md` _Recall files_ when needed.

10. **Report.** File written (or **skipped** with reason + matching entry), topic tag, whether `index.md` changed (and whether a hint was added/updated), and one line on when to load it next (`when editing` or on-demand).

## Notes

- H2 / Duplicate / Relates / index hint: steps 6–7. `/agent-memory consolidate` Pass A may promote **incident-shaped decisions** already on disk (max 3 learnings; Duplicate rule). Pass B trims or discards **closed** log headings — it does not scrape the log diary into Insights. Topic splits/merges are consolidate (confirm).
