# Memory Index

Map of canonical sources and recall files. Before any task: read this, `current.md`, and your branch `active-work` file when it exists. Method: `instructions.md`.

Keep aligned with useful entry points only (what they own + when to read). `/agent-memory sync` may add/remove recall links — it does not re-index the whole docs tree.

## Read first

- [current.md](./current.md) — shared active state.
- `active-work/<branch>.md` — branch scratchpad when work is resumable (see `instructions.md` → _When starting or resuming work_).

## Canonical project sources

- _None yet — run `/agent-memory bootstrap` or add links._ Shape: `[AGENTS.md](../../AGENTS.md) — mandatory agent rules; read before structural changes.`

## Recall files

- [decisions.md](./decisions.md) — decision pointers or local fallback.
- [log.md](./log.md) — recent semantic session deltas.
- `learnings.md` — optional; create when the gate in `instructions.md` passes, then link here. Supports `learning` and `pitfall` entries.

Older installs may still have legacy mirror files — convert via `lint` / `consolidate`; do not recreate.
