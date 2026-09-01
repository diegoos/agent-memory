# `/agent-memory consolidate`

Guided, conservative promotion and pruning of memory. Turns closed-session noise into pointers, decisions, learnings/pitfalls, or discard — **with confirmation**. Never run automatically (not from hooks, sync, lint, pre-commit, or init). Does **not** accept `--auto`.

Two passes, always both:

- **Pass A — corpus** (decisions / index / AGENTS docs map / learnings). Run even when Pass B is empty (open branch, today's log only). Candidates: `decision-docs-map`, `decision-canonical-dup`, `decision-stale-live`, `live-dup-identity`, `incident-unpromoted`, `decision-hidden`, `decision-body-bloat`, `memory-ghost-docs`, `agents-docs-gap`.
- **Pass B — closed log prune.** Current session = session id **or** today's calendar date (below). **An open branch is not the current session.** Prior-day `log.md` headings are Trim/Discard candidates even when `active-work` exists.

report **no-op** and stop only when **both** passes have zero candidates — do not invent promotions. If lint (or step 3) marked a Pass A finding ID, an empty plan is a **failed consolidate**, not no-op. Defer only with one reason line per ID.

Learning promotions: at most **3** per run (confirm each). Do not scrape `log.md` diary bullets into Insights. Promote Learning only from an **incident-shaped decision** (rollback / workaround / revert + 1–3 `src/` or config paths) or skip that row.

## Boundary

- **May edit** (with per-diff confirmation): paths in `SKILL.md` `allowed-tools`, plus `decisions.md` / `learnings.md` / `learnings-*.md` when a promotion needs them — those three are **not** pre-approved (expect a host permission prompt). **`AGENTS.md` docs map only** (bullets outside the agent-memory block — `references/docs-map.md`). **Not** `instructions.md` (that is `/agent-memory update` only).
- **Must not** edit README, docs, specs, or ADR **bodies**, or harness agent files **except** that `AGENTS.md` map. Patch `AGENTS.md` **outside** `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`.
- When an external promotion is needed, report the suggested path and keep the fact as `pending-doc` until the user updates the external source.
- Never prune the **current session** heading(s) in `log.md` (definition below).
- Never prune the **current branch's** active-work file.
- Never propose a Discard set that would leave `log.md` with **zero** session headings (`## [YYYY-MM-DD]…`) — including replacing the body with `_No entries yet._`. Prefer **Retain** / **Trim** / **Defer**.
- Require `git` available before classifying evidence as reconstructible.

### Current session (prune exclusion)

Treat a `log.md` heading as **current session** (not a prune/Discard candidate) when **any** of:

1. Its `[session-id]` matches the resolved current session ID (env / stdin / print-evidence `current_session_id`), when that id is valid.
2. **Same calendar day** as today (`YYYY-MM-DD` in the heading = today) **and** no distinct closed-session marker exists (e.g. user has not said the prior work stream is done) — especially headings typed `[docs] bootstrap`, `[ingest]`, or summarizing init/bootstrap/sync on a fresh memory.
3. It is the **only** remaining session heading in `log.md` (last entry — never Discard the sole heading).

When unsure whether a same-day heading is closed, **Retain** (default AskQuestion recommendation: keep). Founding bootstrap / first dogfood day is almost always current session. A live `active-work/<branch>.md` does **not** make older-day log headings current.

**Exception (same-day supersede):** if two headings share today's date and the same `[type]`, and the later bullets make the earlier heading **false**, offer to merge into one heading (Trim/remove the stale heading) with confirmation. Do not keep contradictory inventory on the always-read log path.

**Not Discard:** “Already promoted to `index.md` / `learnings.md`” does **not** mean the session log heading is disposable. Log holds **temporal session deltas**; learnings/index hold **durable recall**. After promotion, at most **Trim** bullets under a closed heading, or **Defer** until the session is closed (next calendar day, or user confirms the work stream ended). Do not offer Discard of bootstrap/ingest headings on day 0 because gaps already live in learnings.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`.

2. **Resolve context.**
   - Branch: `git branch --show-current` (sanitize as in `sync.md`); fall back to `local`.
   - Current session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin, or `current_session_id` from `agent-memory-print-evidence.sh` (do **not** Read `.hook-sync-state`).
   - Today's date and the set of `log.md` headings matching **Current session** above.
   - If any target memory file has unresolved merge conflict markers, **stop**.
   - If memory has uncommitted changes, warn and require confirmation before proposing diffs — never silently overwrite pre-existing edits.

3. **Collect candidates (read-only).** Two lists. Never skip Pass A because Pass B is empty.

   **Pass A — corpus** (exclude nothing for these IDs; they are not log prune):
   - Local decision bodies that already have (or should have) an ADR pointer (`decision-canonical-dup:`).
   - Decisions that should be marked `superseded` with `Superseded by:` (`decision-stale-live:` when Status is still live and the block says superseded).
   - Two `Status: live` entries on the same identity (append without supersede) — keep one live successor (`live-dup-identity:`).
   - Path-scoped learnings / topic splits listed in `index.md` **without** a `when editing:` hint when Evidence names concrete paths (lint stale/missing hint). Live `decisions.md` that names 1–3 repo-relative paths while the index `decisions.md` line has no hint (`decision-hidden:`).
   - **Contradiction** — two recall Insights or decision pointers that conflict (`contradicts-unlinked` from lint). Propose a `contradicts` / `Contradicts:` edge, Trim the stale side, or Defer — do not re-crawl architecture folders.
   - **No evidence** — a learning/pitfall with no Evidence (or `learning-missing-evidence`); `Invalidate when` already true. Propose pointer, Discard, or Defer. Not a graph rebuild.
   - **Orphan Relates** (`relates-missing`) — typed edge whose target file is gone, or whose `#fragment` is missing from the target. Propose drop the Relates line, retarget, or Defer. After an approved log Discard/Trim, Grep Relates / aliases for that heading or path and offer the same.
   - Learnings/pitfalls that now have a canonical source.
   - Entries marked `pending-doc` — including those whose `Invalidate when` is already satisfied or whose Insight now appears in the named canonical doc (`pending-doc-met` from lint): propose **remove** the `pending-doc` bullet and either keep the learning as-is, convert to a pointer, or discard if fully superseded by the doc.
   - Legacy mirror files (`vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*`) **only if they survived `/agent-memory update`** (user skipped graph reshape). Prefer pointer then delete. Do **not** fold their docs links into `index.md` — AGENTS map (`references/docs-map.md`).
   - **Docs now canonical** — a local decision body or Canonical bullet that duplicates an ADR/spec/`AGENTS.md` link: **Reference** (pointer or drop); patch `AGENTS.md` if the index exists and AGENTS omits it; then strip the memory copy (`decision-docs-map:` when live + Source-only and AGENTS already links the path).
   - **Superseded bodies** — `Status: superseded` still has Context / Decision / Why: collapse to heading + Status + `Superseded by:` (+ Relates).
   - **Incident-shaped decisions** (`incident-unpromoted:`) — rollback/workaround/revert + 1–3 `src/` or config paths: promote **Learning** (H2 + `when editing:`), cap **3** per run; leave at most `- Relates: see` on the decision if the live approach still matters. Do not invent Insights from `log.md`.
   - **`live-dup-identity`** — keep one live successor; mark the rest superseded **and** collapse those bodies.
   - **Ghost docs** — memory links `docs/` or an ADR path that does not exist: drop the link (do not invent the tree).
   - **AGENTS docs gap** — a project-docs index exists and `AGENTS.md` does not link it: patch AGENTS (`references/docs-map.md`), then drop the duplicate from memory.

   **Pass B — closed log / stale resume** (exclude current-session headings and current branch active-work from prune/Discard):
   - Stale `active-work/*.md` whose branch no longer exists.
   - **Closed** session headings in `log.md` only (not current session; not the sole remaining heading). `log.md` is a **rolling window** of recent deltas, not an archive: closed headings whose outcomes are reconstructible from Git or already live in `index.md` / learnings are Discard or Trim candidates.
   - Same-day headings of the same `[type]` where a later heading supersedes an earlier one (false inventory left behind): merge into one heading (Trim the stale one) even on the current calendar day when the user confirms the older bullets are obsolete.
   - Empty **closed**-session headings (no bullets).
   - Legacy path-only bullets (``- `path` `` or `changed N files…`) under **closed** sessions — leftover from pre-0.1.0 hooks.
   - Duplicate semantic bullets across **closed** sessions (trim under closed headings; do not wipe current session).
   - Legacy `## Touched files` sections in active-work (pre-0.1.0).
   - **Hold** bullets on stale `active-work` (branch gone) or on a file about to be deleted on merge: promote through the retention gate (`/agent-memory learn`) or Discard with the file. Do not copy Hold into `learnings.md` without the gate. Cap remains 3 on the live branch file (`hold-overflow`).
   - **Mixed-type log bullets** — under a closed or current heading, bullets that belong to a different `[type]` / concern than the heading summary: propose **moving** them to a correctly typed heading (or trimming noise). Do **not** Discard the whole current-session heading to “fix” mixed types.

4. **Classify each candidate.** Propose one action per item:
   - **Reference** — replace body with a pointer to a canonical source **or drop it when `AGENTS.md` already maps that source**; update `index.md` only for recall files, not a second docs catalog.
   - **Decision** — add/replace only a live fallback with no ADR; **supersede** older live entries on the same identity instead of appending a second `Status: live`, then **collapse** superseded bodies. Do not add an ADR-index pointer when no ADR tree exists. User-constraint Hold / Rejected approaches on **closed** work: promote to a live decision only if they pass the write-floor User constraint gate.
   - **Learning / pitfall** — promote to `learnings.md` or an existing `learnings-<topic>.md` using the H2 format in `references/learn.md` (evidence + use when + verified + invalidate when). Prefer an existing topic split when the theme matches; otherwise `learnings.md`. Apply the **Duplicate rule** from `references/learn.md` — skip when the insight already exists in the target file (H2 or legacy one-liner). Path-scoped entries must get an `index.md` `when editing:` hint in the same promotion. At most **3** Learning rows per run; origin is an incident-shaped **decision**, not a log diary.
   - **Split** — when `learnings.md` is large or thematically clustered, propose moving entries into `learnings-<topic>.md` and updating `index.md` (path-scoped lines need `when editing:` hints). Convert moved entries to the H2 form as part of the move (do not move raw one-liners unless the user declines conversion). Confirm; never auto-split.
   - **Merge** — when a topic split is tiny or redundant with another, propose merging back into `learnings.md` or a sibling split; same H2 conversion and duplicate rule (confirm).
   - **Current** — keep in `current.md` / active-work because still active.
   - **Trim** — shorten bullets under a **closed** log heading after promotion (keep the heading + ≥1 outcome bullet when the session still matters for continuity).
   - **Discard** — remove because transient, reconstructible from Git, or duplicated (including legacy path bullets and empty **closed** headings). **Never** Discard current-session headings, the sole remaining heading, or a set of removals that empties `log.md`.
   - **Contradiction** — keep one live fact; add `contradicts` only when both must remain; otherwise Trim/pointer the stale side.
   - **Orphan Relates** — drop or retarget; do not leave a hop pointing at a discarded log heading.
   - **Defer** — preserve when unsure, waiting on external doc promotion (`pending-doc`), or when durable facts already live in learnings/index but the session heading is still current — **unless** lint/`pending-doc-met` shows the invalidate condition is already true — then prefer remove `pending-doc` / pointer / discard over indefinite defer.

5. **Show the classification plan** to the user (table or grouped list). Group Pass A vs Pass B. Do not write yet. For any log Discard AskQuestion on a borderline same-day heading, recommend **Manter** by default. In the plan table, mark current-session log rows as **Retained** (reason: current session / founding day) — do not list them as Discard candidates. If Pass A findings exist, the table must include a row per ID (Reference / Learning / Defer+reason) — empty Pass A while those IDs exist is a failed consolidate.

6. **Apply in safe order** — confirm each diff (approve / skip / abort):
   1. Additions/promotions first: `decisions.md`, `learnings.md` / `learnings-*.md`, `current.md` (shared blockers only if still active), `index.md` (recall links and `when editing:` hints — not a docs catalog), `AGENTS.md` docs-map bullets when a project-docs index exists and AGENTS omits it.
   2. Only after a promotion is **approved**, and only for **closed** session origins, propose Trim or removal of promoted bullets / empty closed headings from `log.md` or a legacy file body. If promotion is declined, **keep** the origin. Apply approved split/merge moves only after the destination write is confirmed. **Never** remove a heading that would leave zero session entries. After an approved log Discard/Trim, propose Relates retarget/drop for lines that pointed at the removed heading.
   3. Propose removal of legacy path-only bullets, empty closed-session headings, and legacy _Touched files_ sections (Git available; evidence reconstructible).
   4. Propose deleting stale `active-work/<branch>.md` one-by-one, or with an explicit "delete all stale" approval. If `active-work/TEMPLATE.md` is still present, delete it (scaffold SoT is this skill's `references/active-work-template.md`).
   5. For leftover mirrors (user skipped `update` graph reshape): fold unique **non-docs** facts then delete; deleting a legacy file is sensitive and must be confirmed. Skip if the file is already gone. Do not dump docs links into `index.md`.
   6. **Progress follow-up** — only if a **closed**-session log Discard/Trim was approved: offer to refresh active-work Progress so it does not point at removed log headings. Do not open this AskQuestion when no closed-session log removal was approved.

7. **Report.** Summarize separately:
   - **promoted** — decision or learning/pitfall bodies added;
   - **split / merged** — learnings moved between `learnings.md` and topic splits;
   - **referenced** — pointers to canonical sources (no body copy);
   - **superseded** — prior decisions marked with `Superseded by:`;
   - **trimmed** — closed-session log bullets shortened;
   - **discarded** — transient / reconstructible / duplicated removed;
   - **retained** — kept as-is. **Always name current-session log headings** that the prune-exclusion guard kept (e.g. `retained: current-session founding log — ## [YYYY-MM-DD] [docs] …`) so the user can see the contract working — even when nothing else changed. If Pass A applied and Pass B retained, say both;
   - **deferred** — `pending-doc` or user skip;
   - **external promotions suggested** — paths the user should update outside the skill.

## Notes

- Consolidation should be a dedicated change (its own commit when practical).
- Prefer linking over copying. Prefer discard of reconstructible path evidence over keeping duplicate lists — without emptying the session log.
- If `git` is unavailable, do not discard path bullets as "reconstructible" — defer them.
- Align with the lifecycle and gate in `instructions.md`.
- **Day-0 / founding session:** after bootstrap or first dogfood on the same calendar day, treat consolidate as **report-only for Pass B prune** (pending-doc deferrals, external promotions, uncommitted-scaffold advice). Do not set user expectations for Discard/Trim of founding headings — that waits for a closed session (next day or explicit stream-ended confirmation). Pass A still runs (docs-map / stale-live / incident-shaped).
