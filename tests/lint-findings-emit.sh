#!/usr/bin/env bash
# Run the packed memory-cwd emitter against a fixture (no duplicated awk).

set -euo pipefail

fail() { echo "not ok - $*" >&2; exit 1; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
memory_script="$repo_root/skills/agent-memory/scripts/lint-structural-from-memory.sh"
root_script="$repo_root/skills/agent-memory/scripts/lint-structural-from-root.sh"

fx2=""
fx=$(mktemp -d)
trap 'rm -rf "$fx" "$fx2"' EXIT
mkdir -p "$fx/active-work"
printf '%s\n' '# Index' >"$fx/index.md"
printf '%s\n' '# Current' '## In progress' '- _none_' >"$fx/current.md"
printf '%s\n' '# Log' >"$fx/log.md"

cat >"$fx/decisions.md" <<'EOF'
# Decisions

## [2026-07-07] Astro 7 named-slot workaround: wrap multiple children in `Fragment`

**Status:** live

**Context:** slots missing.

**Decision:** Wrap in Fragment in `src/pages/[category]/[postSlug]/index.astro`.

**Why:** Astro 7 workaround.

- Relates: see [Astro 7 named-slot pitfall](./learnings.md#2026-07-07-astro-7-named-slot-workaround-wrap-multiple-children-in-fragment)

## [2026-07-09] Rollback para TypeScript 6.0.3 único

**Status:** live

**Context:** Dual-package TS6+TS7 failed.

**Decision:** Pin typescript in `src/package.json`.

**Why:** rollback.

## [2026-07-11] Revert broken parser

**Status:** live

**Context:** parser crash.

**Decision:** Revert `src/parse.ts`.

**Why:** revert.

- Relates: see [pin](./decisions.md#2026-07-09-rollback-para-typescript-6-0-3-unico)
- Relates: see [gone](./decisions.md#no-such-decision-heading)

## [2026-07-12] Rollback

**Status:** live

**Context:** short.

**Decision:** Revert `src/short.ts`.

**Why:** rollback.

## [2026-07-12] Rollback and more

**Status:** live

**Context:** long.

**Decision:** Revert `src/long.ts`.

**Why:** rollback.

## [2026-07-06] Docs reorganization structure

**Status:** live

**Decision:** Use `docs/domains/*`.

## [2026-07-09] docs/ follows spec-docs layout (English)

**Status:** live

**Decision:** Adopt spec-docs.

## [2026-07-10] Docs suite follows make-docs (not spec-docs)

**Status:** live

**Decision:** Keep make-docs.
EOF

cat >"$fx/learnings.md" <<'EOF'
# Learnings

## [2026-09-01] [pitfall] Astro 7 multiple named-slot children

- Insight: Wrap slot children in Fragment.
- Evidence: `src/pages/[category]/[postSlug]/index.astro`
- Relates: caused_by [workaround](./decisions.md#2026-07-07-astro-7-named-slot-workaround-wrap-multiple-children-in-fragment)

## [2026-09-01] [pitfall] TS pin

- Insight: One TypeScript version.
- Relates: caused_by [rollback](./decisions.md#2026-07-09-rollback-para-typescript-6-0-3-único)

## [2026-09-01] [pitfall] Rollback and more

- Insight: Longer rollback title.
- Relates: caused_by [rollback](./decisions.md#2026-07-12-rollback-and-more)

## [2026-09-01] [note] Prose only

- Insight: Mentioned ## [2026-07-12] Rollback in prose without a Relates edge.

## [2026-09-02] [note] Prose slug cite

- Insight: see decisions.md#2026-07-12-rollback for context without a Relates line.

## [2026-09-03] [note] Fenced Relates example

```
- Relates: see [x](./decisions.md#fake-fenced-slug)
```
EOF

cat >>"$fx/log.md" <<'EOF'

## Format
Document session headings.
## Notes

## [2026-09-02] [chore]
```
[broken](./fake-fenced-example.md)
```

## [2026-09-03] [chore]
```
- changed 3 files
```
EOF

cat >"$fx/active-work/x'y.md" <<'EOF'
## Task
- pin TS
## Next step
- ship
## Validation
- bun test
Checkpoint: 2026-09-01 @ abcd1234
## Hold
- one
- two
- three
- four
EOF

cat >"$fx/active-work/foo\\nbar.md" <<'EOF'
## Task
- pin
## Next step
- ship
## Validation
- bun test
Checkpoint: 2026-09-01 @ abcd1234
## Hold
- one
- two
- three
- four
EOF

out=$(cd "$fx" && bash "$memory_script")

printf '%s' "$out" | grep -q 'decision-lesson-dup: ## \[2026-07-07\] Astro 7 named-slot workaround' \
  || fail "Relates on the decision must emit decision-lesson-dup"
printf '%s' "$out" | grep -q 'decision-lesson-dup: ## \[2026-07-09\] Rollback para TypeScript 6.0.3' \
  || fail "learnings-only accented Relates must emit decision-lesson-dup"
printf '%s' "$out" | grep -q 'decision-lesson-dup: ## \[2026-07-12\] Rollback and more' \
  || fail "exact longer slug must emit decision-lesson-dup"
if printf '%s' "$out" | grep 'decision-lesson-dup' | grep -F '## [2026-07-12] Rollback —' | grep -qv 'and more'; then
  fail "shorter Rollback heading must not match rollback-and-more slug"
fi
printf '%s' "$out" | grep -qF 'incident-unpromoted: ## [2026-07-12] Rollback —' \
  || fail "short Rollback heading must stay incident-unpromoted"
if printf '%s' "$out" | grep 'incident-unpromoted' | grep -q 'Rollback and more'; then
  fail "Rollback and more must not emit incident-unpromoted"
fi
printf '%s' "$out" | grep -q 'incident-unpromoted: ## \[2026-07-11\] Revert broken parser' \
  || fail "unpromoted revert with src/ must emit incident-unpromoted"
if printf '%s' "$out" | grep 'incident-unpromoted' | grep -q 'named-slot workaround'; then
  fail "promoted named-slot must not emit incident-unpromoted"
fi
if printf '%s' "$out" | grep 'incident-unpromoted' | grep -q 'Rollback para TypeScript'; then
  fail "accented slug match must not emit incident-unpromoted"
fi
if printf '%s' "$out" | grep 'decision-lesson-dup' | grep -qF '## [2026-07-12] Rollback —'; then
  fail "prose decisions.md#slug must not emit decision-lesson-dup"
fi
if printf '%s' "$out" | grep -q 'missing: fake-fenced-example.md'; then
  fail "fenced example links must not emit missing:"
fi
if printf '%s' "$out" | grep -q 'relates-missing:.*fake-fenced-slug'; then
  fail "fenced Relates lines must not emit relates-missing"
fi
if printf '%s' "$out" | grep -q 'bad-log-heading: ## Notes'; then
  fail "## Format body must not emit bad-log-heading"
fi
if printf '%s' "$out" | grep -q 'legacy-path-bullet:.*changed 3 files'; then
  fail "fenced legacy-path bullets must not emit legacy-path-bullet"
fi
printf '%s' "$out" | grep -q 'relates-missing:.*no-such-decision-heading' \
  || fail "dead heading slug must emit relates-missing"
if printf '%s' "$out" | grep 'relates-missing' | grep -q '2026-07-09-rollback-para-typescript'; then
  fail "date-prefixed H2 slug must not emit relates-missing"
fi
printf '%s' "$out" | grep -q 'live-dup-identity: 3' \
  || fail "three live docs-layout headings must emit live-dup-identity"
printf '%s' "$out" | grep -q "hold-overflow: active-work/x'y.md" \
  || fail "hold-overflow must emit with quote in active-work basename"
printf '%s\n' "$out" | grep -q 'hold-overflow: active-work/foo\\nbar.md' \
  || fail "backslash-n basename must stay one finding line"
if printf '%s\n' "$out" | grep -q '^bar.md'; then
  fail "awk must not split hold-overflow on backslash-n in the filename"
fi

fx2=$(mktemp -d)
mkdir -p "$fx2/active-work"
printf '%s\n' '# Index' '- [decisions.md](./decisions.md)' >"$fx2/index.md"
printf '%s\n' '# Current' '## In progress' '- _none_' >"$fx2/current.md"
printf '%s\n' '# Log' >"$fx2/log.md"
cat >"$fx2/decisions.md" <<'EOF'
# Decisions

## [2026-01-01] Old incident

**Status:** superseded

**Decision:** Touched `src/old.ts`.

## [2026-01-02] Docs layout only

**Status:** live

**Decision:** Keep docs at docs/specs.
EOF
printf '%s\n' '# Learnings' >"$fx2/learnings.md"
out2=$(cd "$fx2" && bash "$memory_script")
if printf '%s' "$out2" | grep -q 'decision-hidden:'; then
  fail "superseded src/ plus live docs-only must not emit decision-hidden"
fi

wrong=$(cd "$repo_root" && bash "$memory_script")
printf '%s' "$wrong" | grep -q 'wrong-cwd:' \
  || fail "memory emitter must emit wrong-cwd when not run from .agents/memory/"

wrong_root=$(cd "$repo_root/skills/agent-memory" && bash "$root_script")
printf '%s' "$wrong_root" | grep -q 'wrong-cwd:' \
  || fail "root emitter must emit wrong-cwd when not run from project root"

root_fx=$(mktemp -d)
mkdir -p "$root_fx/.agents/memory/active-work"
printf '%s\n' '# AGENTS' >"$root_fx/AGENTS.md"
printf '%s\n' '# Index' >"$root_fx/.agents/memory/index.md"
printf '%s\n' '# Current' '## In progress' '- _none_' >"$root_fx/.agents/memory/current.md"
printf '%s\n' '# Log' >"$root_fx/.agents/memory/log.md"
printf '%s\n' '# Decisions' >"$root_fx/.agents/memory/decisions.md"
(
  cd "$root_fx"
  git init -q
  git add -A
  git commit -q -m init
  branch=$(git branch --show-current)
  cat >".agents/memory/active-work/${branch}.md" <<AWEOF
## Task
- work
## Next step
- next
## Validation
- bun test
Checkpoint: 2026-09-01 @ deadbeef
AWEOF
)
root_out=$(cd "$root_fx" && bash "$root_script")
printf '%s' "$root_out" | grep -q 'stale-resume:' \
  || fail "root emitter must emit stale-resume when Checkpoint != HEAD"
printf '%s' "$root_out" | grep -q 'hook-state-absent:' \
  || fail "root emitter must emit hook-state-absent when .hook-sync-state missing"

cat >"$root_fx/.agents/memory/learnings.md" <<'EOF'
# Learnings
```
[ghost](./docs/missing.md)
```
EOF
root_out2=$(cd "$root_fx" && bash "$root_script")
if printf '%s' "$root_out2" | grep -q 'memory-ghost-docs:'; then
  fail "fenced docs links must not emit memory-ghost-docs"
fi

fx3=$(mktemp -d)
printf '%s\n' '# Index' >"$fx3/index.md"
printf '%s\n' '# Current' '## In progress' '- _none_' >"$fx3/current.md"
err=$(cd "$fx3" && bash "$memory_script" 2>&1 >/dev/null)
if printf '%s' "$err" | grep -q "can't open file log.md"; then
  fail "missing log.md must not run awk on absent file"
fi
rm -rf "$fx3"

rm -rf "$root_fx"

echo "ok - lint findings emit (per-heading incident, lesson-dup, live-dup-identity)"
