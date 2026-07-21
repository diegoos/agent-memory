# Decisions

Pointers to the project's ADR / decision system, or a local fallback when none exists. Oldest first — append at the **bottom**. On conflict, keep both. Record when you make, confirm, or change a non-trivial choice; do not copy ADR bodies or index every ADR.

## When to record

Viable approach trade-offs; conventions spanning files; anything a future agent would re-litigate. Skip trivial renames, obvious fixes, formatting-only changes.

## Format — pointer (preferred)

```md
## [YYYY-MM-DD] Short title

- Source: [ADR-012](../../docs/adr/012.md)
- Relevance: constraint the next agent must know.
```

## Format — local fallback

```md
## [YYYY-MM-DD] Short title

- Context: concise problem.
- Decision: chosen option.
- Why: decisive trade-off only.
- Consequence: constraint or follow-up.
```

Replace a local body with a pointer during `/agent-memory consolidate` once an external ADR exists.

---

_No decisions recorded yet._
