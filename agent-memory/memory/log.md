# Log

Chronological record of relevant activity. Oldest first — append new entries at
the **bottom** (the most recent come out with `tail`). On merge conflicts, keep
both.

## Format (one heading per date + session)

Each session gets **one** heading. Append concise bullets under it as work
happens — do not create a new heading for every checkpoint.

```md
## [YYYY-MM-DD] [session-id] [type] short session summary

- fixed bug X that breaks marketing pages
- implemented rate limit logic in `lib/rate-limit.ts`
```

- **Date** — `YYYY-MM-DD` (session start date).
- **Session ID** — harness session/conversation ID when available (from
  `AGENT_MEMORY_SESSION_ID` / `CURSOR_SESSION_ID`, or omit the bracket if
  unknown).
- **Type** — one of: `feat`, `fix`, `chore`, `review`, `docs`, `refactor`,
  `test`, `perf`, `security`, `release`, `ingest`, `improve`. Hooks default to
  `[chore]`; you refine when the session goal is clear.
- **Summary** — one line describing the session's purpose (not a file count).
  Hooks seed `session work`; you replace with a meaningful summary.
- **Bullets** — hooks append ``- `path/to/file` `` from `git` (once per file per
  session). You append semantic bullets (fixes, features, outcomes) during work
  and at checkpoints.

To continue an existing session, **append bullets** under its heading; only open
a new heading for a new session (new conversation / new session ID).

---

_No entries yet._
