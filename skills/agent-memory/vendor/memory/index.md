# Memory Index

Map of canonical sources and recall files. Before any task: read this, `current.md`, and your branch `active-work` file. Method: `instructions.md`.

Keep aligned with useful entry points only (what they own + when to read). `/agent-memory sync` may add/remove recall links — it does not re-index the whole docs tree.

## Read first

- [current.md](./current.md) — shared active state.
- `active-work/<branch>.md` — branch scratchpad (see `instructions.md` → _Branch work_).

## Canonical project sources

- _None yet — run `/agent-memory bootstrap` or add links._ Shape: `[AGENTS.md](../../AGENTS.md) — mandatory agent rules; read before structural changes.`

## Recall files

- [decisions.md](./decisions.md) — decision pointers or local fallback.
- [log.md](./log.md) — recent session deltas.
- `learnings.md` — optional; create when the gate in `instructions.md` passes, then link here.

Legacy mirrors (`vision.md`, `architecture.md`, `patterns.md`, `domains/*`, `features/*`, …) may exist — convert via `lint` / `consolidate`; do not recreate.
