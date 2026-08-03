# Active Work — Branch: `<branch>`

Ephemeral per-branch scratchpad. Copy to `active-work/<branch>.md` (sanitize: non `[A-Za-z0-9._-]` → `-`), set the real `Branch:` header, delete on merge. Create only when work is resumable. Method: `instructions.md`.

Checkpoint: YYYY-MM-DD @ SHORT-SHA

Replace `SHORT-SHA` with `git rev-parse --short HEAD` and the date with today. Keep the Checkpoint line machine-parseable: date and sha only after `@` — no backticks and no extra instructions on that line.

## Task

**Required.** 1–2 lines: what this branch is delivering.

- _No active task._

## Progress

Current facts only — not a command diary and not a replay of `log.md`. Prefer a short pointer to the session log over duplicating bootstrap/init bullets.

- _none_

## Next step

One concrete **product** next action (commit, PR, feature work). Do **not** put `/agent-memory …` commands here — those belong in Validation or the session plan.

- _none_

## Validation

Exact command and expected result. Prefer copy-pasteable lines. Prefer the project's full closure command when known (e.g. `bun run check` over a narrower suite alone).

- _none_

## Assumptions / open questions

Unconfirmed hypotheses and open questions — never present as facts.

- _none_

## Blockers

- _none_

## Rejected approaches

Tried paths that failed, with why. Prevents rediscovery.

- _none_

## References

Pointers only: `path` or link + why it matters for this task. From this folder, repo-root docs are `../../../…` (example shape: `[CHANGELOG.md](../../../CHANGELOG.md)` — Unreleased scope).

- _none_
