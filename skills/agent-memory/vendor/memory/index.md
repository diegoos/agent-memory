# Memory Index

Map of canonical sources and recall files. Method: `instructions.md`. Keep useful entry points only (what they own + when to read). `/agent-memory sync` may add/remove recall links — it does not re-index the whole docs tree.

## Canonical project sources

- _None yet — run `/agent-memory bootstrap` or add links._ Shape: `[AGENTS.md](../../AGENTS.md) — mandatory agent rules; read before structural changes.`

## Recall files

- [decisions.md](./decisions.md) — decision pointers or local fallback.
- [log.md](./log.md) — recent semantic session deltas.
- `learnings.md` — optional; create when the gate in `instructions.md` passes, then link here. Topic splits: `learnings-<topic>.md` (same gate). Optional `when editing:` hint — syntax in `instructions.md` → _Always load_. Shape: `- [learnings-<topic>.md](./learnings-<topic>.md) — when editing: <path-glob>; what it covers.` (shape only — add globs from evidence, never copy placeholder globs).

Older installs may still have legacy mirror files — convert via `lint` / `consolidate`; do not recreate.
