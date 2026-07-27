# Agent instructions — agent-memory repository

This repo **is** the source for the [Agent Memory](README.md) method and its manual-only skill. It is not a consumer install — the skeleton the skill copies into other projects lives under `skills/agent-memory/vendor/`; the orchestrator lives under `skills/agent-memory/`.

## Layout

```text
skills/agent-memory/          # skill only (no hooks)
├── SKILL.md
├── vendor/                   # SoT: skeleton + UPDATE.md + method README
└── references/

hooks/                        # outside the skill — user-run install
├── install-hooks.sh
├── agent-memory-hooks/       # common / sync / session
├── <harness>/                # cursor, claude-code, …
└── README.md

install.ts                    # CLI source (Bun build)
bin/cli.js                    # npx CLI (skill + hooks)
package.json                  # SoT: package / skill / hooks version

CHANGELOG.md
```

## Conventions for agents working here

- **Single sources of truth** — do not duplicate or drift:
  - Agent-memory block text: `skills/agent-memory/references/agent-block.md`
  - Installed memory shape: `skills/agent-memory/vendor/memory/`
  - **Harness parity (hooks vs agent):** `skills/agent-memory/vendor/memory/instructions.md` → _Harness parity — memory contract_ (canonical; link, do not copy)
  - Migrations: `skills/agent-memory/vendor/UPDATE.md`
  - Release history: `CHANGELOG.md` ([Keep a Changelog][kac], [SemVer][semver])
  - Package / skill / hooks version: `package.json` `version` (mirror into `skills/agent-memory/SKILL.md` → `metadata.version`)
- **Always edit** `skills/agent-memory/vendor/` — never invent a repo-root `agent-memory/` path for writes.
- **Version bumps** — only when requested: bump `package.json` `version` (SoT), mirror it into `skills/agent-memory/SKILL.md` → `metadata.version`, add a `## <version>` section to `skills/agent-memory/vendor/UPDATE.md` when memory scaffolding/migrations change, align pinned examples in `references/init.md`, `references/install-hooks.md`, `hooks/README.md`, and root `README.md`, keep `install-hooks.sh` fallback version in sync if present, and add a matching `[<version>]` entry to `CHANGELOG.md` (human-oriented; map `safe`/`sensitive` items from `UPDATE.md` into Added / Changed / Removed / Fixed / Security — do not dump git logs).
- **Skill boundary** — `/agent-memory` is manual-only (`disable-model-invocation: true`). Never auto-trigger it; follow `SKILL.md` and the matching `references/<command>.md` when the user invokes a subcommand. The skill **never** installs hooks (print instructions only).
- **Hooks** — live under repo-root `hooks/` (**not** inside the skill). Shared scripts in `hooks/agent-memory-hooks/` (`common`, `sync`, `session`); per-host config in `hooks/<harness>/`. User installs via `hooks/install-hooks.sh` or `npx` CLI (`install.ts` → `bin/cli.js`). Deterministic checkpoint: ephemeral evidence in `.hook-sync-state` only (session id, branch, touched paths, `last_processed_head`) — **no Markdown writes**, no LLM loops (`followup_message` on Cursor `stop` is intentionally unused). See [Known issues](#known-issues) for hook upgrade notes.
- **Markdown** — write prose as normal paragraphs (no hard-wrap for line length); `markdownlint` config lives in `.markdownlint.json` (MD013 currently off for long URLs / tables).
- **Commits** — English, Conventional Commits; do not push unless asked.
- **Content Language** — English.

## Known issues

### Hook Markdown writes removed (0.0.15)

**Symptom (consumers on hooks before 0.0.15):** hooks may still create empty `log.md` headings, path bullets, `Touched files` sections, or refresh `current.md` _In progress_. That is superseded — semantic Markdown is agent-owned only.

**Fix:** re-run the user installer for the release tag so scripts and harness config are refreshed (per-tool events removed). Then run `/agent-memory update` and `/agent-memory consolidate` to migrate templates and prune legacy path noise.

### Hook checkpoint regression (0.0.8 → fixed in 0.0.10; superseded by 0.0.15)

**Symptom (consumer projects on hooks before the 0.0.10 fix):** `log.md` shows a `changed N files (see active-work Touched files)` summary plus stray ``- `path` `` bullets with no semantic context; `active-work` _Touched files_ is incomplete. Superseded by the 0.0.15 ephemeral-hooks contract (no Markdown writes at all).

**Consumer upgrade:** re-run the user installer for the release tag (npx or `install-hooks.sh`) so all three scripts and host config are refreshed. Or follow `/agent-memory install hooks <harness>` printed instructions.

### OpenCode empty `log.md` headings (fixed in 0.0.11; superseded by 0.0.15)

**Symptom:** multiple same-day empty headings from OpenCode `ses_*` rotation. 0.0.15 OpenCode plugin no longer synthesizes sessionStart / day headings — hooks never write `log.md`. Re-install the OpenCode plugin + scripts.

## Dogfooding

To use Workspace Memory at the repo root, run `/agent-memory init` (installs `.agents/memory/` from `skills/agent-memory/vendor/memory/`). Until then, treat `skills/agent-memory/vendor/memory/instructions.md` as the method file for this project.

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
