# Log

Recent session deltas. Oldest first — append at the **bottom**. Closed sessions and path-only evidence may be pruned by `/agent-memory consolidate` (never hooks; never the current session). On merge conflicts during work, keep both.

## Format

One heading per session; append outcome bullets under it (not a new heading per checkpoint):

```md
## [YYYY-MM-DD] [session-id] [type] short session outcome

- fixed bug X that breaks marketing pages
```

- **Date** — `YYYY-MM-DD` (session start).
- **Session ID** — from `AGENT_MEMORY_SESSION_ID` when available; omit the bracket if unknown.
- **Type** — `feat` | `fix` | `chore` | `review` | `docs` | `refactor` | `test` | `perf` | `security` | `release` | `ingest` | `improve`. Hooks do not invent type/summary.
- **Bullets** — hooks append ``- `path` `` (temporary). You append semantic outcomes. Do not copy docs, full decisions, or re-list touched files.

**OpenCode:** when `ses_*` IDs rotate the same day, keep appending under the day's bound heading.

---

_No entries yet._
