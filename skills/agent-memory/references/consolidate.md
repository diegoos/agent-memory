# `/agent-memory consolidate`

Guided, conservative promotion and pruning of memory. Turns closed-session noise
into pointers, decisions, learnings, or discard — **with confirmation**. Never
run automatically (not from hooks, sync, lint, pre-commit, or init). Does
**not** accept `--auto`.

## Boundary

- **May edit** under `.agents/memory/**` only (with per-diff confirmation).
- **Must not** edit README, docs, specs, ADRs, issues, or harness agent files.
- When an external promotion is needed, report the suggested path and keep the
  fact as `pending-doc` until the user updates the external source.
- Never prune the **current session** heading in `log.md`.
- Never prune the **current branch's** active-work file.
- Require `git` available before classifying evidence as reconstructible.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest
   `/agent-memory init`.

2. **Resolve context.**
   - Branch: `git branch --show-current` (sanitize as in `sync.md`); fall back
     to `local`.
   - Current session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin, or
     `current_session_id` from `.hook-sync-state`.
   - If any target memory file has unresolved merge conflict markers, **stop**.
   - If memory has uncommitted changes, warn and require confirmation before
     proposing diffs — never silently overwrite pre-existing edits.

3. **Collect candidates (read-only).** Exclude current session and current
   branch active-work from prune candidates.
   - Stale `active-work/*.md` whose branch no longer exists.
   - Closed session headings in `log.md` (all except current session / today's
     OpenCode-bound heading when applicable).
   - Path-only bullets (``- `path` `` or `changed N files…`) under closed
     sessions.
   - Duplicate semantic bullets across sessions.
   - Local decision bodies that already have (or should have) an ADR pointer.
   - Learnings that now have a canonical source.
   - Entries marked `pending-doc`.
   - Legacy mirror files (`vision.md`, `architecture.md`, `patterns.md`,
     `domains/*`, `features/*`) whose useful content can become a source pointer
     or learning.

4. **Classify each candidate.** Propose one action per item:
   - **Reference** — replace body with a pointer to a canonical source; update
     `index.md` if needed.
   - **Decision** — add/replace pointer in `decisions.md` (or local fallback if
     no ADR system).
   - **Learning** — promote to `learnings.md` with evidence + use trigger.
   - **Current** — keep in `current.md` / active-work because still active.
   - **Discard** — remove because transient, reconstructible from Git, or
     duplicated.
   - **Defer** — preserve when unsure or waiting on external doc promotion
     (`pending-doc`).

5. **Show the classification plan** to the user (table or grouped list). Do not
   write yet.

6. **Apply in safe order** — confirm each diff (approve / skip / abort):
   1. Additions/promotions first: `decisions.md`, `learnings.md`, `current.md`
      (shared blockers only if still active), `index.md`.
   2. Only after a promotion is **approved**, propose removing its origin from
      `log.md` or a legacy file body. If promotion is declined, **keep** the
      origin.
   3. Propose removal of path-only bullets and empty closed-session headings
      (Git available; evidence reconstructible).
   4. Propose deleting stale `active-work/<branch>.md` one-by-one, or with an
      explicit "delete all stale" approval. Never delete `TEMPLATE.md`.
   5. For legacy mirrors: prefer converting to pointers / learnings over delete;
      deleting a legacy file is sensitive and must be confirmed.

7. **Report.** Summarize separately:
   - **promoted** — decision or learning bodies added;
   - **referenced** — pointers to canonical sources (no body copy);
   - **discarded** — transient / reconstructible / duplicated removed;
   - **retained** — kept as-is;
   - **deferred** — `pending-doc` or user skip;
   - **external promotions suggested** — paths the user should update outside
     the skill.

## Notes

- Consolidation should be a dedicated change (its own commit when practical).
- Prefer linking over copying. Prefer discard of reconstructible path evidence
  over keeping duplicate lists.
- If `git` is unavailable, do not discard path bullets as "reconstructible" —
  defer them.
- Align with the lifecycle and gate in `instructions.md`.
