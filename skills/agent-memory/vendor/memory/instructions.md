# Agent Memory — Instructions

Workspace Memory in `.agents/memory/` is a Git-versioned **recall layer**, not a copy of project docs. Keep enough for another human or agent to continue without chat history.

## Always load

Harness context must load this file. Before every task, read `index.md` and `current.md`. Read the branch `active-work` file when it exists (create from `active-work/TEMPLATE.md` only when work is resumable across sessions). Follow canonical sources listed in `index.md`; load `decisions.md`, `log.md`, and optional recall only when needed. Keep always-loaded files short: one fact per bullet, update before create, link instead of copy.

Hot path: `index.md` + `current.md` + branch `active-work` (when present). `decisions.md`, `log.md`, and `learnings.md` are on-demand.

## Authority by information type

No global source of truth — authority follows the fact:

- Working rules → repo/harness instructions and linters
- Product goals / expected behavior → README, specs, product docs
- Architecture decisions → project ADR / decision system
- Implemented behavior → code, tests, manifests, config
- Temporary execution state → `current.md`, `active-work/<branch>.md`
- Recent activity → `log.md`
- Reusable knowledge with no better source → on-demand `learnings.md`

If memory diverges from an authoritative source: do not pick silently; record under `current.md` _Blockers / attention_ or branch _Blockers_; consult the source or user; then fix or remove the stale entry.

## Retention gate and lifecycle

Before recording:

1. Reusable in another session? If no → skip (keep in the current log only if useful to resume this session, until consolidate).
2. Already in a canonical source? → store only `link + delta/relevance` (optional `relevant when:` / `verified: YYYY-MM-DD` for code/config inferences).
3. Current-task state only? → branch `active-work`; shared active state → `current.md`.
4. Non-trivial decision? → pointer to the project decision system; local fallback in `decisions.md` only when none exists.
5. Stable, non-obvious, evidenced, undocumented, secret-free learning or pitfall? → `learnings.md`.
6. Transient, Git-reconstructible, or unevidenced? → do not make durable.

Lifecycle: `active-work → log → canonical pointer | decision | learning | discard`. Record decisions/learnings when discovered; never remove durable knowledge without reason. Delete branch active-work on merge. Only manual `/agent-memory consolidate` may promote or prune closed sessions — never hooks, never mid-session automation, never the current session.

Legacy mirrors may exist; do not create, auto-delete, or prefer them over canonical sources. Lint/consolidate may propose pointer conversion.

Minimum pointer line: `- [topic] useful delta — source: [doc](../../path); relevant when: trigger; verified: YYYY-MM-DD`

## Branch work

One file per branch, only when work is resumable. Sanitize the real branch name (or `local`) to `active-work/<branch>.md` by replacing every character outside `[A-Za-z0-9._-]` with `-`. Copy `TEMPLATE.md`, keep the unsanitized name in the `Branch:` header, replace placeholders with a meaningful task.

Keep these sections current and distinct:

- _Progress_ — confirmed facts / outcomes
- _Next step_ — one concrete next action
- _Validation_ — exact command + expected result
- _Assumptions / open questions_ — hypotheses, never presented as facts
- _Blockers_ — shared or branch impediments
- _Rejected approaches_ — tried paths that failed, with why
- _References_ — path/link + why it matters (not copied docs)

Update the `Checkpoint: YYYY-MM-DD @ <short-sha>` line on every semantic sync (HEAD short SHA from `git`). Do not invent roadmaps in _Handoff_ or _Next step_.

## Minimum durable formats

- **Log** — one `## [YYYY-MM-DD] [session-id] [type] short outcome` per session with useful outcomes (oldest first); append semantic bullets only. Never path lists, empty headings, or conversation transcripts. Types live in `log.md`.
- **Decision** — `## [YYYY-MM-DD] Short title` with `Status`, `Source` + `Relevance` (pointer), or local `Context` / `Decision` / `Why` / `Rejected` / `Consequence` when no ADR system. Use `Supersedes` / `Superseded by` when replacing a prior decision; keep the old entry marked superseded. Details in `decisions.md`.
- **Learning / pitfall** — create `learnings.md` only when the gate passes, link from `index.md`, one line: `- [YYYY-MM-DD] [learning|pitfall] [topic] insight — evidence: path|link; use when: trigger; verified: YYYY-MM-DD; invalidate when: condition.` Append `pending-doc` when it belongs in official docs; keep until that source exists, then pointer or remove via consolidate. Code/config inferences need evidence + date.

## Workflow

**Primary write path (agent, in the turn):** when a turn produces durable progress, update branch `active-work` resume fields (facts vs hypotheses, next step, validation) and append a semantic `log.md` outcome before stopping. Record decisions and gated learnings when discovered; align `index.md` when entry points change. Do not defer meaning to a later sync — hooks only accumulate evidence.

**Catch-up (`/agent-memory sync`):** at end of turn / before compact / before commit / end of session, or when picking work back up — consistency pass over `current.md`, branch active-work, `log.md`, and `index.md`. It may read `.hook-sync-state` and `git` as evidence but never invents progress or log bullets without meaning. Update `current.md` only when shared active state changed; _Handoff_ must be explicit/evidenced — never an invented roadmap. Sync never replaces decision/learning duties, invents roadmaps, or copies docs.

You may follow the skill's `references/sync.md` steps and edit those four files directly without invoking the skill command.

### Harness parity — memory contract

Every supported harness targets the same memory shape. **Context layer** injects the obligation to read/maintain memory; **checkpoint layer** (hooks/plugin) collects **ephemeral evidence only** in `.hook-sync-state` (gitignored). Harness config controls timing, not meaning — see the [hooks README](https://github.com/diegoos/agent-memory/blob/0.0.15/hooks/README.md). Differing outcomes are bugs.

**Hooks own ephemeral evidence only:** session id binding; branch cache; session-cumulative touched paths; `last_processed_head` / commit range markers. Hooks never create or edit Markdown under `.agents/memory/` (no `active-work`, `log.md`, `current.md`, decisions, learnings, or consolidation).

**Agent owns all versioned Markdown:** create/refine active-work and shared state; semantic log outcomes and headings; progress / next step / validation / assumptions / blockers / rejected approaches / references; source/recall links; decisions; gated learnings/pitfalls. Meaning is written in-turn (primary); sync is catch-up. Without hooks, use the same checkpoints and supply both evidence (from `git`) and meaning — via `/agent-memory sync` or by following `references/sync.md` directly.

## Multi-developer safety

- `active-work/` — per branch; edit only yours; delete on merge.
- `current.md` — shared; change with the PR that changes shared active state.
- `decisions.md` / `learnings.md` / working `log.md` — oldest-first, append-oriented; on conflict keep both valid contributions and mark supersession when one replaces another.
- Prune closed log only via consolidate in a dedicated change — never hooks, never the current session.

## Memory lint boundaries

Run `/agent-memory lint` on request or review. It checks structure, wiring, staleness, links, duplication, legacy mirrors, unsupported learnings, empty log headings, missing resume sections, Checkpoint freshness vs HEAD (`stale-resume`), and pending hook path evidence (`evidence-pending`); it warns rather than adjudicating product truth or deleting user content. Soft line/heading budgets and auto-fix limits live in the skill's `lint` reference — consolidation handles promotion/pruning, not `lint --fix`.
