# Log

Recent session **semantic** deltas. Oldest first — append at the **bottom**. Create a heading only when there is a useful outcome. Closed sessions may be pruned by `/agent-memory consolidate` (never hooks; never the current session). On merge conflicts during work, keep both.

## Format

One heading per session with outcome bullets (not a new heading per checkpoint):

```md
## [YYYY-MM-DD] [session-id] [type] short session outcome

- fixed bug X that breaks marketing pages
```

- **Date** — `YYYY-MM-DD` (session start).
- **Session ID** — from `AGENT_MEMORY_SESSION_ID` when available; omit the bracket if unknown.
- **Type** — `feat` | `fix` | `chore` | `review` | `docs` | `refactor` | `test` | `perf` | `security` | `release` | `ingest` | `improve`.
- **Bullets** — semantic outcomes only. Never path lists, `changed N files…` summaries, conversation transcripts, or empty headings.

Hooks never write this file. Path evidence lives in `.hook-sync-state` (gitignored) and is consumed by `/agent-memory sync` when writing outcomes.

**OpenCode:** when `ses_*` IDs rotate the same day, prefer one semantic heading per calendar day for that work stream.

---

_No entries yet._
