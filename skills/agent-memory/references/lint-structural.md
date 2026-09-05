# Lint structural checks

Disclosed from `references/lint.md` step 2. Run both scripts. Emit every matching finding ID. Skip `./file` and `<…>` placeholders (see `references/lint.md` step 4). Do not fix here.

Packed with this skill (`scripts/` next to `SKILL.md`).

**Done when:** both scripts ran; stdout is the finding list for the Report.

`<skill-dir>` is the directory that contains `SKILL.md`. Resolve it to an **absolute** path first. Installed: `<repo>/.agents/skills/agent-memory/`. Dogfood checkout: `<repo>/skills/agent-memory/`. Then `cd` to the cwd below and run `bash <absolute-skill-dir>/scripts/…`. Do not use the repo-relative forms as the bash operand while cwd is `.agents/memory/` (`SKILL.md` `allowed-tools` strings are matched from the project root).

## From `.agents/memory/`

Cwd: `.agents/memory/` (or a fixture with the same file names).

```bash
bash <absolute-skill-dir>/scripts/lint-structural-from-memory.sh
```

## From project root

Cwd: the target project root (`AGENTS.md`, `.agents/memory/`, harness dirs).

```bash
bash <absolute-skill-dir>/scripts/lint-structural-from-root.sh
```
