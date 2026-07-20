# Agent Memory — Instructions

Workspace Memory in `.agents/memory/` is a Git-versioned **recall layer**, not a copy of project docs. Keep enough for another human or agent to continue without chat history.

## Always load

Harness context must load this file. Before every task, read `index.md`, `current.md`, and the branch `active-work` file (create from `active-work/TEMPLATE.md` if missing). Follow canonical sources listed in `index.md`; load `decisions.md`, `log.md`, and optional recall only when needed. Keep always-loaded files short: one fact per bullet, update before create, link instead of copy.

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
5. Stable, non-obvious, evidenced, undocumented, secret-free learning? → `learnings.md`.
6. Transient, Git-reconstructible, or unevidenced? → do not make durable.

Lifecycle: `active-work → log → canonical pointer | decision | learning | discard`. Record decisions/learnings when discovered; never remove durable knowledge without reason. Delete branch active-work on merge. Only manual `/agent-memory consolidate` may promote or prune closed sessions / path-only evidence — never hooks, never mid-session automation, never the current session.

Legacy mirrors may exist; do not create, auto-delete, or prefer them over canonical sources. Lint/consolidate may propose pointer conversion.

Minimum pointer line: `- [topic] useful delta — source: [doc](../../path); relevant when: trigger; verified: YYYY-MM-DD`

## Branch work

One file per branch. Sanitize the real branch name (or `local`) to `active-work/<branch>.md` by replacing every character outside `[A-Za-z0-9._-]` with `-`. Copy `TEMPLATE.md`, keep the unsanitized name in the `Branch:` header, replace placeholders with a meaningful task. Keep _Progress_, _Blockers_, and resume-only _Notes_ current; _Touched files_ is evidence, not a command diary.

## Minimum durable formats

- **Log** — one `## [YYYY-MM-DD] [session-id] [type] short outcome` per session (oldest first); append outcome bullets; do not re-list touched paths. Types and OpenCode day-coalesce rules live in `log.md`.
- **Decision** — `## [YYYY-MM-DD] Short title` with `Source` + `Relevance` (pointer), or local `Context` / `Decision` / `Why` / `Consequence` when no ADR system; replace fallback with a pointer once an external ADR exists. Details in `decisions.md`.
- **Learning** — create `learnings.md` only when the gate passes, link from `index.md`, one line: `- [YYYY-MM-DD] [topic] insight — evidence: path|link; use when: trigger.` Append `pending-doc` when it belongs in official docs; keep until that source exists, then pointer or remove via consolidate. Code/config inferences need evidence + date.

## Workflow

- During work: maintain semantic branch progress, append semantic log outcomes, record decisions, apply the gate, align `index.md` when entry points change.
- At end of turn / before compact / before commit / end of session: flush continuation state. Update `current.md` only when shared active state changed; _Handoff_ must be explicit/evidenced — never an invented roadmap.
- `/agent-memory sync` refreshes only `current.md`, branch active-work, `log.md`, and `index.md`. It never replaces decision/learning duties, invents roadmaps, or copies docs.

### Harness parity — memory contract

Every supported harness targets the same memory shape. **Context layer** injects the obligation to read/maintain memory; **checkpoint layer** (hooks/plugin) syncs Git/session evidence. Harness config controls timing, not meaning — see the [hooks README](https://github.com/diegoos/agent-memory/blob/0.0.14/hooks/README.md). Differing outcomes are bugs.

**Hooks own evidence/scaffolding:** session log heading; `current.md` _In progress_ from open active-work; ensure branch file exists; session-cumulative _Touched files_; full-checkpoint path bullets (or `changed N files…` above eight); generic _Task_ stub only; `.hook-sync-state` (uncommitted).

Hooks never write: semantic log outcomes, heading type/summary, decisions/learnings, meaningful task/progress/blockers/notes, shared blockers/handoff, `index.md` prose, copied docs, or consolidation.

**Agent owns meaning:** refine task and shared state; semantic log outcomes and heading metadata; progress/blockers/notes; source/recall links; decisions; gated learnings. Without hooks, run `/agent-memory sync` at the same checkpoints and supply both evidence and meaning.

## Multi-developer safety

- `active-work/` — per branch; edit only yours; delete on merge.
- `current.md` — shared; change with the PR that changes shared active state.
- `decisions.md` / `learnings.md` / working `log.md` — oldest-first, append-oriented; on conflict keep both valid contributions.
- Prune closed log only via consolidate in a dedicated change — never hooks, never the current session.

## Memory lint boundaries

Run `/agent-memory lint` on request or review. It checks structure, wiring, staleness, links, duplication, legacy mirrors, unsupported learnings, and closed-session path noise; it warns rather than adjudicating product truth or deleting user content. Soft line/heading budgets and auto-fix limits live in the skill's `lint` reference — consolidation handles promotion/pruning, not `lint --fix`.
