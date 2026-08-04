# Decisions

Pointers to the project's ADR / decision system, or a local fallback when none exists. Oldest first — append at the **bottom**. On conflict, keep both and mark supersession — never silently delete a replaced decision. Record when you make, confirm, or change a non-trivial choice; do not copy ADR bodies or index every ADR. Skip trivial renames, obvious fixes, formatting-only changes.

## Format — pointer (preferred)

```md
## [YYYY-MM-DD] Short title

- Status: active | superseded
- Source: [ADR-012](../../docs/adr/012.md)
- Relevance: constraint the next agent must know.
- Supersedes: optional prior title/id
- Superseded by: optional newer title/id (when Status is superseded)
```

## Format — local fallback

```md
## [YYYY-MM-DD] Short title

- Status: active | superseded
- Context: concise problem.
- Decision: chosen option.
- Why: decisive trade-off only.
- Rejected alternatives: alternatives tried or considered, with why not.
- Consequence: constraint or follow-up.
- Supersedes: optional prior title/id
- Superseded by: optional newer title/id (when Status is superseded)
```

Replace a local body with a pointer during `/agent-memory consolidate` once an external ADR exists. Keep the superseded entry with `Status: superseded` and `Superseded by:` — do not delete it silently.

---

_No decisions recorded yet._
