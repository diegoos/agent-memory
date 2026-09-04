# Agent instructions — agent-memory repository

This repo is the source for the [Agent Memory](README.md) method and its manual-only skill — not a consumer install. Skeleton: `skills/agent-memory/vendor/`; skill orchestrator: `skills/agent-memory/`; hooks: repo-root `hooks/`; CLI: `src/cli.ts` → `bin/cli.js`.

Package manager: **Bun** (`bun.lock`). Verify with `bun run check` (typecheck + markdownlint + `build:check` + tests + build). Shorter: `bun run test`, `bun run typecheck`, `bun run lint:md`, `bun run build`.

## Permission boundaries

| Mode             | Scope |
| ---------------- | ----- |
| READ             | Whole repo; method details in `skills/agent-memory/vendor/memory/instructions.md` |
| WRITE            | `skills/agent-memory/`, `hooks/`, `src/`, `tests/`, `bin/cli.js` (via `bun run build`), root docs (`README.md`, `CHANGELOG.md`, `SECURITY.md`, this file), `package.json` / `bun.lock` when asked |
| NEVER            | Invent a repo-root `agent-memory/` path for writes; push; create git tags or npm publish unless the user explicitly asks; install hooks into a consumer project from this agent (print commands only); add `shell: true` on child processes; forward full `process.env` to hook children; write Markdown from hooks |
| HUMAN_CHECKPOINT | Version bump; release tag; npm publish; any change that rewrites consumer memory Markdown outside this meta-repo |

## Precedence

1. User explicit request (including “do not bump” / “fold into current version”).
2. This file’s NEVER / HUMAN_CHECKPOINT.
3. Single sources of truth below — link, do not copy.
4. Conventional Commits in English; do not push unless asked.

## Escalation

If blocked (missing permission, ambiguous SemVer, conflict between docs and code): stop and ask the user. Do not invent a version bump, tag, or publish path to “unblock.” Do not skip `bun run test` / `version-parity` after a requested bump.

## Single sources of truth

- Agent-memory block: `skills/agent-memory/references/agent-block.md`
- Installed memory shape: `skills/agent-memory/vendor/memory/`
- Recall hop: `skills/agent-memory/vendor/memory/instructions.md` → _Recall hop_
- Harness parity (hooks vs agent): `skills/agent-memory/vendor/memory/instructions.md` → _Harness parity — memory contract_
- Trust boundary / intentional capabilities (CLI + hooks): `SECURITY.md`
- Migrations: `skills/agent-memory/vendor/UPDATE.md`
- Release history: `CHANGELOG.md` ([Keep a Changelog][kac], [SemVer][semver])
- Package / skill / hooks version: `package.json` `version` → mirror `skills/agent-memory/SKILL.md` → `metadata.version`
- Version pin check: `tests/version-parity.sh` (run via `bun run test`)

## Conventions

- **Skill boundary** — `/agent-memory` is manual-only (`disable-model-invocation: true`). Never auto-trigger it. Follow `SKILL.md` + `references/<command>.md`. The skill **never** installs hooks (print instructions only).
- **Hooks** — under `hooks/` (not inside the skill). Shared scripts in `hooks/agent-memory-hooks/`; per-host config in `hooks/<harness>/`. User installs via `hooks/install-hooks.sh` or `npx` CLI. Deterministic checkpoint: ephemeral evidence in `.hook-sync-state` only — **no Markdown writes**, no LLM loops (`followup_message` on Cursor `stop` unused). Trust model and audit path: `SECURITY.md`. Upgrade notes: [Known issues](#known-issues).
- **Security (CLI / OpenCode spawn)** — details in `SECURITY.md`. Keep `ENV_ALLOWLIST_EXACT` aligned (`src/constants.ts` ↔ `hooks/opencode/agent-memory.ts`). OpenCode spawn must go through `hooks/opencode/safe-script.ts` before `execFileSync`. Do not add `--minify` to `bun run build` (auditability; `bun run build:check`). Closure for spawn/security edits: `bun run test` (includes `tests/opencode-safe-script.test.ts`).
- **Markdown** — normal paragraphs (no hard-wrap for line length); `.markdownlint.json` (MD013 off).
- **Content language** — English in repo docs and commits.

## When bumping versions

Only when the user asks. Do **not** invent a bump.

**Released vs unreleased:** a version is **released** only if its git tag exists (no `v` prefix — e.g. `0.1.0`). Check with:

```bash
git tag -l '<version>'
# or remote: git ls-remote --tags origin '<version>' 'refs/tags/<version>'
```

If the tag is **missing**, that version was **not** launched: fold further work into the **current** `package.json` version (same `CHANGELOG.md` / `UPDATE.md` section). Do **not** bump to the next SemVer until the user asks for a new release.

When a bump **is** requested:

1. Set `package.json` `version` (SoT).
2. Mirror into `skills/agent-memory/SKILL.md` → `metadata.version`.
3. Add or rename `## <version>` in `skills/agent-memory/vendor/UPDATE.md` when memory scaffolding/migrations change (`safe` / `sensitive` lines).
4. Add or rename `## [<version>]` in `CHANGELOG.md` (human-oriented; map UPDATE items into Added / Changed / Removed / Fixed / Security / Breaking — do not dump git logs). Keep `[Unreleased]` and footer compare links aligned.
5. Align pinned examples: `references/init.md`, `references/install-hooks.md`, root `README.md`, and any `blob/<ver>` / `#<ver>` / `--branch <ver>` pins; keep `hooks/install-hooks.sh` `VERSION=…` fallback in sync.
6. Closure — `bun run test` must exit 0 (includes `tests/version-parity.sh`). Do not create the git tag or publish unless the user asks.

## Known issues

### Hook Markdown writes removed (0.1.0)

**Symptom (consumers on hooks before 0.1.0):** hooks may still create empty `log.md` headings, path bullets, `Touched files` sections, or refresh `current.md` _In progress_. That is superseded — semantic Markdown is agent-owned only.

**Fix:** re-run the user installer for the release tag so scripts and harness config are refreshed (per-tool events removed). Then run `/agent-memory update` and `/agent-memory consolidate` to migrate templates and prune legacy path noise.

### Hook checkpoint regression (0.0.8 → fixed in 0.0.10; superseded by 0.1.0)

**Symptom (consumer projects on hooks before the 0.0.10 fix):** `log.md` shows a `changed N files (see active-work Touched files)` summary plus stray ``- `path` `` bullets with no semantic context; `active-work` _Touched files_ is incomplete. Superseded by the 0.1.0 ephemeral-hooks contract (no Markdown writes at all).

**Consumer upgrade:** re-run the user installer for the release tag (npx or `install-hooks.sh`) so all three scripts and host config are refreshed. Or follow `/agent-memory install hooks <harness>` printed instructions.

### OpenCode empty `log.md` headings (fixed in 0.0.11; superseded by 0.1.0)

**Symptom:** multiple same-day empty headings from OpenCode `ses_*` rotation. 0.1.0 OpenCode plugin no longer synthesizes sessionStart / day headings — hooks never write `log.md`. Re-install the OpenCode plugin + scripts.

## Dogfooding

Local dogfood memory is `.agents/memory/` (gitignored with other harness dirs). Method file once initialized: `.agents/memory/instructions.md`. Skeleton SoT remains `skills/agent-memory/vendor/memory/`. To (re)scaffold, run `/agent-memory init`.

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
