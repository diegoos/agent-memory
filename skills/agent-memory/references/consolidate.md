# `/agent-memory consolidate`

Guided, conservative promotion and pruning of memory. Turns closed-session noise into pointers, decisions, learnings/pitfalls, or discard — **with confirmation**. Never run automatically (not from hooks, sync, lint, pre-commit, or init). Does **not** accept `--auto`.

## Boundary

- **May edit** (with per-diff confirmation): paths in `SKILL.md` `allowed-tools`, plus `decisions.md` / `learnings.md` / `learnings-*.md` when a promotion needs them — those three are **not** pre-approved (expect a host permission prompt). **Not** `instructions.md` (that is `/agent-memory update` only).
- **Must not** edit README, docs, specs, ADRs, issues, or harness agent files.
- When an external promotion is needed, report the suggested path and keep the fact as `pending-doc` until the user updates the external source.
- Never prune the **current session** heading(s) in `log.md` (definition below).
- Never prune the **current branch's** active-work file.
- Never propose a Discard set that would leave `log.md` with **zero** session headings (`## [YYYY-MM-DD]…`) — including replacing the body with `_No entries yet._`. Prefer **Retain** / **Trim** / **Defer**.
- Require `git` available before classifying evidence as reconstructible.

### Current session (prune exclusion)

Treat a `log.md` heading as **current session** (not a prune/Discard candidate) when **any** of:

1. Its `[session-id]` matches the resolved current session ID (env / stdin / `.hook-sync-state`), when that id is valid.
2. **Same calendar day** as today (`YYYY-MM-DD` in the heading = today) **and** no distinct closed-session marker exists (e.g. user has not said the prior work stream is done) — especially headings typed `[docs] bootstrap`, `[ingest]`, or summarizing init/bootstrap/sync on a fresh memory.
3. It is the **only** remaining session heading in `log.md` (last entry — never Discard the sole heading).

When unsure whether a same-day heading is closed, **Retain** (default AskQuestion recommendation: keep). Founding bootstrap / first dogfood day is almost always current session.

**Not Discard:** “Already promoted to `index.md` / `learnings.md`” does **not** mean the session log heading is disposable. Log holds **temporal session deltas**; learnings/index hold **durable recall**. After promotion, at most **Trim** bullets under a closed heading, or **Defer** until the session is closed (next calendar day, or user confirms the work stream ended). Do not offer Discard of bootstrap/ingest headings on day 0 because gaps already live in learnings.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`.

2. **Resolve context.**
   - Branch: `git branch --show-current` (sanitize as in `sync.md`); fall back to `local`.
   - Current session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin, or `current_session_id` from `.hook-sync-state`.
   - Today's date and the set of `log.md` headings matching **Current session** above.
   - If any target memory file has unresolved merge conflict markers, **stop**.
   - If memory has uncommitted changes, warn and require confirmation before proposing diffs — never silently overwrite pre-existing edits.

3. **Collect candidates (read-only).** Exclude current-session headings and current branch active-work from prune/Discard candidates.
   - Stale `active-work/*.md` whose branch no longer exists.
   - **Closed** session headings in `log.md` only (not current session; not the sole remaining heading).
   - Empty **closed**-session headings (no bullets).
   - Legacy path-only bullets (``- `path` `` or `changed N files…`) under **closed** sessions — leftover from pre-0.1.0 hooks.
   - Duplicate semantic bullets across **closed** sessions (trim under closed headings; do not wipe current session).
   - Local decision bodies that already have (or should have) an ADR pointer.
   - Decisions that should be marked `superseded` with `Superseded by:`.
   - Learnings/pitfalls that now have a canonical source.
   - Entries marked `pending-doc` — including those whose `Invalidate when` is already satisfied or whose Insight now appears in the named canonical doc (`pending-doc-met` from lint): propose **remove** the `pending-doc` bullet and either keep the learning as-is, convert to a pointer, or discard if fully superseded by the doc.
   - Legacy mirror files (`vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*`) whose useful content can become a source pointer or learning.
   - Legacy `## Touched files` sections in active-work (pre-0.1.0).
   - **Mixed-type log bullets** — under a closed or current heading, bullets that belong to a different `[type]` / concern than the heading summary: propose **moving** them to a correctly typed heading (or trimming noise). Do **not** Discard the whole current-session heading to “fix” mixed types.

4. **Classify each candidate.** Propose one action per item:
   - **Reference** — replace body with a pointer to a canonical source; update `index.md` if needed.
   - **Decision** — add/replace pointer in `decisions.md` (or local fallback if no ADR system); mark superseded entries instead of deleting them.
   - **Learning / pitfall** — promote to `learnings.md` or an existing `learnings-<topic>.md` using the H2 format in `instructions.md` (evidence + use when + verified + invalidate when). Prefer an existing topic split when the theme matches; otherwise `learnings.md`. Apply the duplicate rule from `instructions.md` — skip when the insight already exists in the target file (H2 or legacy one-liner).
   - **Split** — when `learnings.md` is large or thematically clustered, propose moving entries into `learnings-<topic>.md` and updating `index.md` (optional `when editing:` hints). Convert moved entries to the H2 form as part of the move (do not move raw one-liners unless the user declines conversion). Confirm; never auto-split.
   - **Merge** — when a topic split is tiny or redundant with another, propose merging back into `learnings.md` or a sibling split; same H2 conversion and duplicate rule (confirm).
   - **Current** — keep in `current.md` / active-work because still active.
   - **Trim** — shorten bullets under a **closed** log heading after promotion (keep the heading + ≥1 outcome bullet when the session still matters for continuity).
   - **Discard** — remove because transient, reconstructible from Git, or duplicated (including legacy path bullets and empty **closed** headings). **Never** Discard current-session headings, the sole remaining heading, or a set of removals that empties `log.md`.
   - **Defer** — preserve when unsure, waiting on external doc promotion (`pending-doc`), or when durable facts already live in learnings/index but the session heading is still current — **unless** lint/`pending-doc-met` shows the invalidate condition is already true — then prefer remove `pending-doc` / pointer / discard over indefinite defer.

5. **Show the classification plan** to the user (table or grouped list). Do not write yet. For any log Discard AskQuestion on a borderline same-day heading, recommend **Manter** by default.

6. **Apply in safe order** — confirm each diff (approve / skip / abort):
   1. Additions/promotions first: `decisions.md`, `learnings.md` / `learnings-*.md`, `current.md` (shared blockers only if still active), `index.md` (including new/updated learnings links and `when editing:` hints).
   2. Only after a promotion is **approved**, and only for **closed** session origins, propose Trim or removal of promoted bullets / empty closed headings from `log.md` or a legacy file body. If promotion is declined, **keep** the origin. Apply approved split/merge moves only after the destination write is confirmed. **Never** remove a heading that would leave zero session entries.
   3. Propose removal of legacy path-only bullets, empty closed-session headings, and legacy _Touched files_ sections (Git available; evidence reconstructible).
   4. Propose deleting stale `active-work/<branch>.md` one-by-one, or with an explicit "delete all stale" approval. Never delete `TEMPLATE.md`.
   5. For legacy mirrors: prefer converting to pointers / learnings over delete; deleting a legacy file is sensitive and must be confirmed.
   6. **Progress follow-up** — only if a **closed**-session log Discard/Trim was approved: offer to refresh active-work Progress so it does not point at removed log headings. Do not open this AskQuestion when no closed-session log removal was approved.

7. **Report.** Summarize separately:
   - **promoted** — decision or learning/pitfall bodies added;
   - **split / merged** — learnings moved between `learnings.md` and topic splits;
   - **referenced** — pointers to canonical sources (no body copy);
   - **superseded** — prior decisions marked with `Superseded by:`;
   - **trimmed** — closed-session log bullets shortened;
   - **discarded** — transient / reconstructible / duplicated removed;
   - **retained** — kept as-is (including current-session log);
   - **deferred** — `pending-doc` or user skip;
   - **external promotions suggested** — paths the user should update outside the skill.

## Notes

- Consolidation should be a dedicated change (its own commit when practical).
- Prefer linking over copying. Prefer discard of reconstructible path evidence over keeping duplicate lists — without emptying the session log.
- If `git` is unavailable, do not discard path bullets as "reconstructible" — defer them.
- Align with the lifecycle and gate in `instructions.md`.
