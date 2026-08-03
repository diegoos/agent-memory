# `/agent-memory bootstrap`

Analyze the project and populate the memory as a **source inventory + gaps** — not a parallel wiki. Uses three analyses that run as subagents when the host supports them.

## Steps

1. **Permission gate (always).** Tell the user that bootstrap will spawn up to three subagents to analyze the project, and ask for explicit permission before continuing — **even when running under bypass/auto-approve**. If declined, stop.

2. **Ensure structure.** If `.agents/memory/` does not exist, run the `init` procedure first (`references/init.md`), then continue.

3. **Run the three analyses.** Launch them as **parallel subagents** if the host supports subagents (e.g. Claude Code's Task/Agent tool). If it does not, run the same three analyses **sequentially** in the current agent.
   - **A — Source inventory.** Locate agent files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`), README, docs indices, specs, ADRs/decision systems, roadmaps, and issue references. For each entry point: what type of information it owns and when to read it. Return entry points + gaps only — never paste document bodies.
   - **B — Structure evidence.** Map modules and entry points from paths / manifests. Check whether that structure is already documented. Return only useful gaps or divergences (documented vs actual layout).
   - **C — Tooling and behavior evidence.** Identify stack and commands from manifests/configs. Check coverage in AGENTS/README. Return only undocumented or contradictory facts with evidence paths.

4. **Synthesize and write (inventory-first, skip empties).** Wait for all three, then fill memory **without copying docs**:

   | Source       | Writes to                                                     |
   | ------------ | ------------------------------------------------------------- |
   | A (sources)  | `index.md` → _Canonical project sources_ (few entry points)   |
   | A (ADRs)     | `decisions.md` — optional single pointer to ADR index/dir     |
   |              | when a decision system exists and is useful for continuity    |
   | B + C (gaps) | `learnings.md` (or a clear `learnings-<topic>.md`) — **only** |
   |              | stable, evidenced, undocumented facts that pass the gate      |
   | synthesis    | `log.md` — one bootstrap session entry                        |

   Rules:
   - Do **not** create `vision.md`, `architecture.md`, `patterns.md`, `mistakes.md`, `known-issues.md`, `domains/*`, or `features/*`.
   - Do **not** invent product vision/scope. If purpose/scope is undocumented, report the gap — do not write a vision file.
   - Leave `current.md` with empty placeholders if there is no active work — do not invent milestones, Done lists, or roadmaps.
   - Leave `active-work/` with only its `TEMPLATE.md` **unless** the branch already has resumable product work (dirty tree / open task / in-flight plan). If you create or refresh `active-work/<branch>.md` after bootstrap, set _Next step_ to a **product** action (commit, PR, feature gap) — never “run `/agent-memory lint|sync|consolidate`”. Put memory-command suggestions in the Report, not in Next step. Progress may point at `log.md` / `learnings.md`; do not copy bootstrap bullets into Progress.
   - Do **not** invent decisions — only point at an existing ADR index/dir when helpful, or leave `decisions.md` empty.
   - Create `learnings.md` (or a topic split) only when at least one fact passes the gate (reusable, undocumented, non-obvious, evidenced, no secrets). Use the H2 learning/pitfall format in `instructions.md`. Documented-vs-actual layout or AGENTS/README closure gaps that pass the gate **must** become learnings (not log-only inventory): include `pending-doc` **and** `Invalidate when: <concrete doc condition>`. Skip facts already clear from a linked canonical one-liner; prefer quality over volume (merge related tooling nits when one Invalidate condition covers them). Link every new learnings file from `index.md`. When Evidence paths are clear and globs stay within the `when editing:` contract, add a narrow hint on the learnings index line (AskQuestion if unsure). Prefer one `learnings.md` on first bootstrap unless a single theme dominates.
   - Append **one** synthesis heading to `log.md` for the whole bootstrap (init scaffold + inventory + gaps) — e.g. `## [YYYY-MM-DD] [docs] bootstrap source inventory` — with short bullets for sources indexed / learnings created / “gaps → learnings” / contradictions needing a user decision. Do **not** paste durable gap bodies into the log (those live in learnings). Do **not** open a second `[ingest]` / init-only heading for the same calendar day; fold init into this heading. When writing the first session heading, **remove** the scaffold placeholder `_No entries yet._`.
   - Keep every `index.md` source line to: link + what it owns + when to read.

5. **Report.** Group clearly:
   - **Sources indexed** — paths linked in `index.md`.
   - **Gaps kept as learnings** — with evidence and `pending-doc` / `Invalidate when` when applicable.
   - **Contradictions** — need a user decision.
   - **Missing documentation recommended** — suggested external paths (skill does **not** create those docs).
   - **Ignored** — transient or already covered by a source. Tell the user to run `/agent-memory sync` at checkpoints. After hooks are installed for this harness, **re-run sync** (or `--auto`) so blockers/evidence catch up — name the harness (Cursor `.mdc` vs OpenCode `AGENTS.md` + `.opencode/plugins/`). Prefer `/agent-memory consolidate` later for **closed**-session **prune**; same-day consolidate after bootstrap is **report-only** at best (pending-doc / commit hygiene) — founding log headings are current session (do not expect Discard/Trim).

## Subagent prompts

Pass each analysis to a subagent with `Task` (read-only). Replies must be short and high-signal — they feed the memory, where tokens matter. **If subagents are unavailable, run the three prompts yourself, in order.**

- **A — Source inventory:**

  > Read-only task. Inventory project documentation entry points: agent files
  > (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`), `README.md`, docs indices, specs,
  > ADRs/decision folders, roadmaps, notable issue/tracker links in docs. Do not
  > paste document bodies. Return ≤150 words: a bullet list of paths, each with
  > (1) what information type it owns and (2) when an agent should read it.
  > Flag gaps (e.g. no ADR system, no product docs). Never invent sources.

- **B — Structure evidence:**

  > Read-only task. Map the repository layout from paths and manifests. Identify
  > major modules/areas and key entry-point paths. Check whether README/docs/
  > AGENTS already describe that structure. Return ≤150 words: only gaps or
  > divergences (documented vs actual), each with evidence paths. If structure
  > is already well documented, say so and return no memory candidates.

- **C — Tooling and behavior evidence:**

  > Read-only task. From manifests (`package.json`, `pyproject.toml`, `go.mod`,
  > `Cargo.toml`, etc.) and config, identify stack and build/test commands.
  > Check whether AGENTS/README already cover them. Return ≤150 words: only
  > undocumented or contradictory facts, each with evidence file. Skip anything
  > already clearly documented. Never invent.
