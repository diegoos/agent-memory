# `/agent-memory sync`

**Catch-up** for the four files that rot between commands — `current.md`, your branch's `active-work/<branch>.md`, `log.md`, and `index.md` — from **actual repo state** (`git`), session context, and optional hook evidence via `agent-memory-print-evidence.sh`. This is the executable form of _When catching up_ in `instructions.md`.

**Primary write path** is still the agent in the turn: at most **one** file per event (resume → `active-work`; user constraint → `decisions.md` in-turn, never from sync; reusable lesson → learnings + index hint in-turn, never from sync; closed session → `log.md`; shared blocker → `current.md`; else skip). **Catch-up** only. It fills gaps and aligns Checkpoint / `current.md` / `index.md`; it does not invent meaning from paths alone and does **not** dual-write `active-work` and `log.md` (do not dual-write).

**No-op is success.** If there is no meaning source (step 4) and nothing to resume, report no-op and stop — do not write `log.md`, do not reindex docs, do not copy touched paths.

Use sync when hook Status shows a stale Checkpoint or pending paths **and** there is meaning; or when the user asked. You may follow these steps and edit the four files directly without invoking the skill command.

## Flags

- `--auto` — apply all proposed diffs without the per-file `AskQuestion` prompt. Use at routine checkpoints (where you would approve everything anyway) to keep the flush low-friction; without it, sync is the careful, per-file-confirm form suited to the first run or a manual review. `--auto` still shows the diffs in the report after applying, and still skips fields for which it has no evidence (it never invents progress or log bullets).
- `--force` — reserved for explicit user override.

## Boundary

Sync writes only to: `current.md`, `active-work/<branch>.md`, `log.md`, and `index.md` (recall-file links only). It **never** adds Canonical project sources that `AGENTS.md` already covers or that point at missing `docs/` / ADR trees. It **never** touches `decisions.md`, `learnings.md`, `learnings-*.md`, `instructions.md`, `AGENTS.md`, or any file outside `.agents/memory/`. It never deletes anything except replacing placeholder lines inside the four target files. It never copies documentation, never invents roadmaps, and never re-indexes the whole docs tree. On `index.md`, existing `when editing:` hints are preserved verbatim (details in the steps below).

Hooks never write Markdown. They may populate `.hook-sync-state` (gitignored) with session id, branch, touched paths, and `last_processed_head`. **Do not Read `.hook-sync-state`.** Run the print-evidence helper (stdout is allowlisted `key=value` only: `state`, `pending_count`, hex `last_processed_head`, validated `current_session_id`, sanitized `branch`). Path lists never enter the model context. Prefer `git` for what changed; never treat pending count as meaning for `log.md` or active-work bullets; do not pass a non-hex SHA to git (see `SECURITY.md`). If the helper is missing, treat hook evidence as absent (`pending_count=0`) — do **not** fall back to Reading the state file. The split is the same on every harness — see `instructions.md` → _Harness parity — memory contract_.

## Steps

1. **Guard.** If `.agents/memory/` does not exist, stop and suggest `/agent-memory init`.

2. **Resolve the branch.** Run `git branch --show-current` (fall back to `local` if HEAD is detached or not a git repo). Sanitize every character outside `[A-Za-z0-9._-]` to `-`. This is the active-work filename.

3. **Ensure the active-work file only when resumable.** Treat work as resumable when **any** of: dirty tree; open task context; user intent to continue; an explicit in-repo plan/spec in flight for this branch; **or** print-evidence `pending_count` is greater than 0 **and** at least one meaning source (step 4) covers that work. If `active-work/<branch>.md` is missing and work is resumable, create it from this skill's `references/active-work-template.md`: set the `Branch:` header to the real branch name; set `Checkpoint: YYYY-MM-DD @ SHORT-SHA`; **strip section blurbs** under each `##` heading (keep the heading lines and `-` bullets only — drop instructional paragraphs such as “Do **not** put `/agent-memory …`”); drop the offline Checkpoint / Next-step guidance lines that sit above `## Task`; omit empty optional sections. If no resumable work exists, skip creating the file. If it exists, leave the header as-is (still strip leftover template blurbs when refreshing in step 5).

4. **Gather evidence (read-only, from `git`, memory, and print-evidence).** Run the helper **before** any git range that needs `last_processed_head`. **Do not Read `.hook-sync-state`.**

   ```bash
   # From project root — path depends on harness install site:
   bash .cursor/hooks/agent-memory-print-evidence.sh
   # or: .claude/hooks/ · .codex/hooks/ · .opencode/hooks/ · .github/hooks/ · .gemini/hooks/
   # meta-repo / pre-install: bash hooks/agent-memory-hooks/agent-memory-print-evidence.sh
   ```

   Use stdout only: `pending_count`, `last_processed_head` (empty or hex), `current_session_id` (empty or already validated), `branch`, `state=present|absent`. If the helper is missing, skip hook fields (`pending_count=0`).

   **Meaning sources (prefer these for `log.md` / Next step — never invent without at least one):**

   - `CHANGELOG.md` `[Unreleased]` (or the latest version section when folding into an unreleased SemVer)
   - `git log --oneline <base>..HEAD` subjects (and the tip commit message)
   - Validation / test results stated in-session
   - Explicit user outcomes (“shipped X”, “fixed Y”)

   **Path / tree hints (what changed — not what it meant):**

   ```bash
   git log --since="<last-log-date>" --pretty='%h %ad %s' --date=short --no-merges
   git diff --stat <base>..HEAD          # base: main/master or origin/<branch>@{u}
   git status --porcelain
   git rev-parse --short HEAD
   # Only when <last-log-sha> matches ^[0-9a-fA-F]{4,40}$ :
   git diff --name-only --end-of-options <last-log-sha>..HEAD 2>/dev/null || true
   ```

   Session ID: `AGENT_MEMORY_SESSION_ID`, harness stdin (`session_id` / `conversation_id` / `sessionId` / `conversationId`), or `current_session_id` from print-evidence stdout (already validated). If using env/stdin, **validate before embedding in `log.md` headings** (same rules as hooks): length 1–128, charset `^[A-Za-z0-9._:@/-]+$`, reject reserved `__no_id__`. If the resolved id is invalid, omit the `[session-id]` bracket or use a validated harness id instead — never paste raw stdin/env into headings.

   Do not copy path lists into Markdown. Re-derive paths from `git` when writing meaning. `pending_count` is a count only.

   For `log.md`, find the **current session** heading: `## [YYYY-MM-DD] [session-id] ...` (session-id bracket optional; only when validated). Append bullets under it only when they match that heading's `[type]` / outcome; open a new heading for a new session **or** a different concern — **and** only when there is at least one semantic outcome from a meaning source.

   `<last-log-date>` comes from the newest `## [YYYY-MM-DD]` in `log.md`. If empty, use the repo's first commit or `HEAD~20` as a sane default.

   `<last-log-sha>` is `last_processed_head` from print-evidence stdout (hooks write it after each checkpoint; the helper emits it only when it matches `^[0-9a-fA-F]{4,40}$`). If empty, skip that diff — never pass a raw state-file value to git. When present, prefer `git diff --name-only --end-of-options <last-log-sha>..HEAD`.

5. **Propose updates (one diff per file).** Show each as a unified diff. Unless `--auto` is set, confirm via `AskQuestion` before writing — sync touches project memory, so the "confirm before editing user content" rule applies. Allow approve / skip per file. Under `--auto`, apply routine diffs without prompting and report them after — **except** any `index.md` change that **adds or widens** a `when editing:` hint (new hint, broader globs, or new learnings link that includes a hint): those remain AskQuestion even under `--auto` (hint lines drive Always-load; inventing/widening them is sensitive).
   - **`active-work/<branch>.md`** — fill/refresh required core: _Task_, _Next step_ (**product** action bullet only — never `/agent-memory …`), _Validation_ (prefer the project's full closure command when known — e.g. `bun run check` over a narrower `test` alone when `package.json` defines `check`; include expected result; skill commands may live here). _Progress_ is **optional** — add/refresh only when Next step is not enough (current facts; pointer to `log.md` when outcomes already logged; do not duplicate bootstrap/init bullets). Add or refresh optional _Assumptions / open questions_, _Blockers_, _Rejected approaches_, _References_ (path/link + why), or _Hold_ **only when evidence supports content** — omit empty optional sections; add a section only when evidence supports content; when evidence exists and the section is missing, propose adding it. _Hold_ is branch scratch that failed the durable gate (max **3** bullets; not learnings; gone on merge). Offer to remove optional sections that contain only `_none_`. Cap Hold at 3; extra bullets → trim or propose `/agent-memory learn`. Update Checkpoint to exactly `Checkpoint: YYYY-MM-DD @ SHORT-SHA` from `git rev-parse --short HEAD` — **plain text, no backticks**, no trailing TEMPLATE prose on that line. Strip any leftover TEMPLATE section blurbs under `##` headings (keep headings + `-` bullets). Repo-root links from this file use `../../../…`. Do **not** write path-only _Touched files_ sections. Overwrite only fields the evidence supports. After meaning covers pending paths (or Checkpoint already matches HEAD with a clean tree and coverage), run step 7 consume in the **same** sync — do not end the command with eligible `session_touched_files` still set. If this sync writes `active-work` for resume, **do not** also append `log.md` unless the session is closed (merge/park/handoff).
   - **`log.md`** — skip the file entirely when there is no semantic outcome from a meaning source (no-op). Maintain **one heading per session concern** only for a **closed** session or a fact that must survive after active-work is gone. Heading shape is mandatory: `## [YYYY-MM-DD] [session-id] [type] short outcome` (omit the session-id bracket when missing/invalid; **always** bracket `[type]` — never `## [date] type | title` or other pipe forms). When refining an existing same-day heading that violates this shape, rewrite the heading line to the canonical form. Prefer refining today's existing heading (e.g. bootstrap inventory) over opening a second same-day `[ingest]` / catch-up heading when the outcomes belong to the same dogfood/scaffold stream. If the new outcome **supersedes** an earlier same-day heading of the same `[type]` (the old bullets are now false), rewrite that heading in place; do not leave both. Never write path bullets or `changed N files…`. Never append unrelated concerns under an existing heading (wrong `[type]` / outcome). When adding the **first** session heading, **remove** the scaffold placeholder `_No entries yet._` (and any blank line it leaves redundant). Refine type/summary; dedupe. Oldest first / newest at bottom. Do not reopen or summarize closed sessions. Do not write a heading because paths were touched. `log.md` is a rolling window; do not grow it as an archive (Git already is).
   - **`current.md`** — refresh _In progress_ only for **shared** state (list each open `active-work/*.md` with a one-line branch goal when other agents need it). Do **not** duplicate this branch's Task if `active-work` already exists and there is no shared audience. Aggregate _Blockers / attention_ only for shared impediments; **omit** the heading when empty. **Observably false hooks/state blockers:** if a blocker (or matching current-session log bullet) claims hooks are not installed or `.hook-sync-state` is absent, but the filesystem shows otherwise — state file exists and/or a harness carrier is present (`.cursor/hooks.json`, `.claude/hooks/agent-memory-sync.sh`, `.opencode/plugins/agent-memory.ts`, `.codex/hooks/`, `.gemini/hooks/`, `.github/hooks/`, etc.) — **remove or rewrite** that blocker under `--auto` (or propose the removal without `--auto`). Do not invent replacement product blockers. Update _Handoff_ only from an explicit instruction/plan; omit empty Handoff. Do **not** maintain Done, milestone, or roadmap sections.
   - **`index.md`** — for every existing recall file (`learnings.md`, topic splits, etc.) not yet listed, add a link. Remove links to deleted recall files. When touching `index.md`, never remove or reformat `when editing:` hints on existing lines; when adding a newly listed orphan, write the minimal link without inventing a hint. When this sync writes `active-work` whose _References_ list **1–3 concrete repo-relative paths** and a listed learnings line has no hint, **propose** a narrow `when editing:` on that existing line (`references/learn.md` step 7; AskQuestion even under `--auto`). Do not invent overbroad globs. **Do not** add Canonical project source links (docs stay on `AGENTS.md`; missing trees stay unlisted). Drop Canonical bullets that AGENTS already links if you are already editing `index.md`.

6. **Apply approved diffs** only, with `Edit`/`Write` scoped to this command’s Boundary targets: `current.md`, `active-work/<branch>.md` (and other `active-work/**` only when evidence requires), `log.md`, and `index.md`. Do **not** write `decisions.md`, `learnings.md` / `learnings-*.md`, or `instructions.md` from sync — those belong to learn / consolidate / gated in-turn / `update` graph reshape (`Status: live` only). Skip anything the user declined.

7. **Consume pending path evidence (required when eligible).** Run consume when **any** of: (a) this sync wrote or confirmed semantic `log.md` / active-work Next step (or Progress) that covers the pending work; (b) Checkpoint already matches HEAD, the tree is clean, and meaning for those paths is already in log/active-work. **Dirty worktree does not block (a)** — OpenCode/Cursor idle checkpoints re-list dirty paths until commit; leaving `pending_count` > 0 after a covering sync is a sync defect (`evidence-pending` / later `evidence-stale-uncleared`). Do **not** skip hoping a later turn will clear it. Clear pending paths only via the consume helper — never rewrite session binding or other keys by hand, and never Read `.hook-sync-state` to edit it. Prefer the installed helper (same directory as the other hook scripts):

   ```bash
   # From project root — path depends on harness install site:
   bash .cursor/hooks/agent-memory-consume-evidence.sh
   # or: .claude/hooks/ · .codex/hooks/ · .opencode/hooks/ · .github/hooks/ · .gemini/hooks/
   # meta-repo / pre-install: bash hooks/agent-memory-hooks/agent-memory-consume-evidence.sh
   ```

   The helper locks, clears `session_touched_files`, and leaves other state intact. If hooks are not installed, skip consume and report that print-evidence/consume helpers are missing — do **not** hand-edit `.hook-sync-state`. Skip consume **only** when you skipped all meaning writes **and** `pending_count` still lacks outcomes (real `evidence-pending`). In the Report, state explicitly whether consume ran or why it was skipped.

8. **Report.** List each file: updated, skipped, or unchanged — whether evidence was consumed — and one line on what the next agent should read to continue (the branch's active-work file plus `current.md`). If a **User constraint** fired this session (user rejected an approach), remind the agent to write `decisions.md` in-turn and **supersede** the prior live entry — sync does not write that file. If a **Reusable lesson** fired (incident + 1–3 paths), remind in-turn learnings + `index.md` `when editing:` — sync does not write those files. Suggest `/agent-memory consolidate` **only** when `log.md` has **closed**-session noise (prior days, or the user confirmed this work stream ended). Do **not** recommend prune consolidate on the same calendar day as a founding bootstrap/dogfood heading — that log is current session (report-only consolidate is fine).

## Notes

- Sync is **additive and conservative** for `current.md` product facts — prefer flagging unclear staleness for `lint` over silent deletion. **Exception:** observably false hooks/state absence blockers (step 5 `current.md`) — remove/rewrite those; do not leave them for lint alone.
- If `git` is unavailable, fall back to reading recently modified files under the project and ask the user to confirm what changed.
- Mirrors _When catching up_ / primary-write sections of `instructions.md`; keep them aligned.
