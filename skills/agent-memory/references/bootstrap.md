# `/agent-memory bootstrap`

Analyze the project and populate the memory with real content. Uses three
analyses that run as subagents when the host supports them.

## Steps

1. **Permission gate (always).** Tell the user that bootstrap will spawn up to
   three subagents to analyze the project, and ask for explicit permission before
   continuing — **even when running under bypass/auto-approve**. If declined, stop.

2. **Ensure structure.** If `.agents/memory/` does not exist, run the `init`
   procedure first (`references/init.md`), then continue.

3. **Run the three analyses.** Launch them as **parallel subagents** if the host
   supports subagents (e.g. Claude Code's Task/Agent tool). If it does not, run
   the same three analyses **sequentially** in the current agent.

   - **A — Documentation.** Read `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, then
     `README.md` and other `.md` docs. Extract: product purpose, scope, goals.
   - **B — Structure.** Map the repo layout: backend, frontend, database,
     services, and the major areas/modules.
   - **C — Technologies.** Identify the main languages, frameworks, and tooling,
     and determine what kind of project it is.

4. **Synthesize and write (skip empties).** Wait for all three, then fill memory
   files only where there is real content — respect the lazy principle, do not
   create shallow placeholders:

   | Source        | Writes to                                         |
   | ------------- | ------------------------------------------------- |
   | A (docs)      | `vision.md`                                       |
   | B (structure) | `architecture.md`, `domains/*.md` (per major area)|
   | C (tech)      | `architecture.md` (stack), `patterns.md`          |
   | synthesis     | `current.md` (state/version), `log.md` entry      |

   - **Register every created `domains/*.md` and `features/*.md` in `index.md`**
     (under its Domains/Features section, replacing `_None yet._`). Otherwise
     `lint` will flag them as orphans.
   - Append to `log.md`: `## [YYYY-MM-DD] docs | bootstrap initial memory`.
   - Leave `active-work/` with only its `TEMPLATE.md` (no branch files), and **do
     not invent** decisions — `decisions.md` stays empty unless a genuine,
     already-made trade-off is documented in the project.

5. **Report.** List which files were created/filled and which were skipped (and
   why), so the user can fill the gaps later. Tell the user to run
   `/agent-memory sync` at checkpoints to keep `current.md`, active-work,
   `log.md`, and `index.md` current.

## Subagent prompts

Pass each analysis to a subagent with `Task` (read-only). Replies must be short
and high-signal — they feed the memory, where tokens matter. **If subagents are
unavailable, run the three prompts yourself, in order.**

- **A — Documentation:**
  > Read-only task. Read the project's agent/instruction files (`AGENTS.md`,
  > `CLAUDE.md`, `GEMINI.md`), then `README.md` and other top-level `*.md` docs.
  > Do not read source code. Return, in ≤150 words: the product purpose (1–2
  > sentences), scope/goals (bullets), and any stated conventions or constraints.
  > Cite the file for each fact. If something is not documented, say so — never
  > invent.

- **B — Structure:**
  > Read-only task. Map the repository layout. Identify backend, frontend,
  > database, services, and the major modules/areas. Return a concise list of
  > top-level areas, each with its role and key entry-point path(s). Flag anything
  > ambiguous. Classify from paths and manifests; avoid reading file bodies unless
  > necessary.

- **C — Technologies:**
  > Read-only task. From manifests (`package.json`, `pyproject.toml`, `go.mod`,
  > `Cargo.toml`, etc.) and config files, identify the main languages, frameworks,
  > and build/test tooling, and decide the project type (web app, library, CLI,
  > service, monorepo…). Return: the stack (bullets), notable tooling, and a
  > one-line project-type verdict with the evidence (which file).
