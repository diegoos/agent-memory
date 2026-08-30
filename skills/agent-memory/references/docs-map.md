# Docs map — `AGENTS.md` is SoT

Loaded from `init` / `update` (with the agent-memory block) and from `consolidate` when a project doc appears. **Not** a wiki. **Sensitive:** unified diff, confirm. Never edit inside `<!-- <agent-memory> -->` … `<!-- </agent-memory> -->`.

**Project-docs indices (on disk only; empty dir = absent):**

- `docs/README.md` (or the repo’s docs index if that name differs)
- `docs/architecture/` (dir with at least one file)
- `docs/specs/` (dir with at least one file)
- ADR index: first existing of `docs/architecture/decisions/`, `docs/decisions/`, `adr/`, `docs/adr/` (dir with at least one file)

At most: docs index + architecture dir + specs dir + one ADR dir. Skip paths that do not exist. Specs stay behind those indices — one bullet per index, not per spec.

**Absent tree:** leave those paths out of `.agents/memory/` (no Canonical bullets, no “see ADR index” in `decisions.md`, no `pending-doc` to a missing path).

## Patch `AGENTS.md`

1. Inventory the indices above that exist.
2. Collect markdown hrefs already in `AGENTS.md` (resolve relative to repo root). Skip any inventory path already linked.
3. Remaining paths → insert one bullet each (`- [label](path) — what it covers`) under an existing Docs / Quick Reference heading. If none, create `## Docs` **outside** the agent-memory block (never inside).
4. The memory **block** may live in `.mdc` / `CLAUDE.md`. The **map** still goes in `AGENTS.md`. If `AGENTS.md` is missing and at least one index exists: create a minimal file with only that section (duplicate the memory block only when `AGENTS.md` is the effective carrier). Confirm.
5. Leave `index.md` Canonical project sources unchanged for these paths.

**Done when:** every existing index is linked from `AGENTS.md`, or each omission was an explicit skip; memory Canonical sources were not filled with those paths.

## Later docs

When an index/ADR/spec **starts existing**:

1. Patch `AGENTS.md` as above if the path is not linked.
2. Memory: drop Canonical bullets AGENTS now covers; collapse or delete a local `decisions.md` body that the ADR now owns; remove `pending-doc` whose Invalidate is true.
3. Same-turn if this agent **created** the doc: AGENTS pointer + strip memory body — the doc stays in Git. Sync leaves `AGENTS.md` and `decisions.md` alone.
