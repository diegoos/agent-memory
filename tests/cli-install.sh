#!/usr/bin/env bash
# Headless CLI smoke: install skill atomically, install hooks, refuse downgrade path.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

# Use committed bin/cli.js; do not rebuild (would hide a stale/tampered artifact).
# `tests/test-runner.sh` / `bun run check` run build:check first.
cli="$repo_root/bin/cli.js"
[[ -f "$cli" ]] || fail "bin/cli.js missing — run bun run build"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- install skill ---
AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" install skill >/dev/null
[[ -f "$TMP/.agents/skills/agent-memory/SKILL.md" ]] || fail "skill not installed"
[[ -d "$TMP/.agents/skills/agent-memory/vendor/memory" ]] || fail "vendor missing"

# Plant an obsolete file then reinstall — atomic replace must remove it
echo obsolete >"$TMP/.agents/skills/agent-memory/OBSOLETE.md"
AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" install skill >/dev/null
[[ ! -e "$TMP/.agents/skills/agent-memory/OBSOLETE.md" ]] ||
  fail "atomic skill install left obsolete file"

# --- install hooks cursor ---
AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" install hooks cursor >/dev/null
[[ -x "$TMP/.cursor/hooks/agent-memory-sync.sh" ]] || fail "cursor sync missing"
[[ -f "$TMP/.cursor/hooks.json" ]] || fail "cursor hooks.json missing"
[[ -f "$TMP/.cursor/hooks/.version" ]] || fail "hooks version stamp missing"
! grep -q postToolUse "$TMP/.cursor/hooks.json" || fail "installed cursor config has postToolUse"

# --- update --yes refreshes from local checkout even when SemVer matches ---
# (source tree has install.ts; published packs skip same-version refresh unless --force)
marker="$TMP/.agents/skills/agent-memory/LOCAL_REFRESH_MARKER.md"
echo stale >"$marker"
out=$(AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" update --yes)
echo "$out" | grep -qi 'Update complete\|skill ready\|refresh' ||
  fail "update --yes unexpected output: $out"
[[ ! -e "$marker" ]] || fail "local checkout update did not refresh skill (marker left)"

# --- --force is accepted (same-version refresh from any package shape) ---
force_out=$(AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" update --force --yes)
echo "$force_out" | grep -qi 'Update complete\|Already up to date\|skill ready\|refresh' ||
  fail "update --force --yes unexpected output: $force_out"

# --- harness detect after cursor install ---
[[ -x "$TMP/.cursor/hooks/agent-memory-sync.sh" ]] || fail "detect marker missing"

# --- refuse skill downgrade ---
skill_md="$TMP/.agents/skills/agent-memory/SKILL.md"
node -e '
const fs = require("fs");
const p = process.argv[1];
let t = fs.readFileSync(p, "utf8");
t = t.replace(/(version:\s*["'\'']?)\d+\.\d+\.\d+/, "$19.9.9");
fs.writeFileSync(p, t);
' "$skill_md"
down_out=$(AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" update --yes 2>&1 || true)
echo "$down_out" | grep -qi 'will not downgrade\|not downgrade\|newer' ||
  fail "expected no-downgrade message: $down_out"
grep -E 'version:.*9\.9\.9' "$skill_md" >/dev/null ||
  fail "skill was downgraded unexpectedly"

# --- install all six harnesses; no per-tool events ---
for h in claude codex opencode copilot gemini; do
  AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" install hooks "$h" >/dev/null ||
    fail "install hooks $h failed"
done
[[ -x "$TMP/.claude/hooks/agent-memory-sync.sh" ]] || fail "claude sync missing"
[[ -x "$TMP/.codex/hooks/agent-memory-sync.sh" ]] || fail "codex sync missing"
[[ -f "$TMP/.opencode/plugin/agent-memory.ts" ]] || fail "opencode plugin missing"
[[ -f "$TMP/.github/hooks/agent-memory.json" ]] ||
  [[ -x "$TMP/.github/hooks/agent-memory-sync.sh" ]] || fail "copilot hooks missing"
[[ -x "$TMP/.gemini/hooks/agent-memory-sync.sh" ]] || fail "gemini sync missing"

for cfg in \
  "$TMP/.cursor/hooks.json" \
  "$TMP/.claude/settings.json" \
  "$TMP/.codex/hooks.json" \
  "$TMP/.gemini/settings.json"; do
  [[ -f "$cfg" ]] || continue
  ! grep -qE 'postToolUse|afterFileEdit|PostToolUse|AfterTool' "$cfg" ||
    fail "per-tool event present in $cfg"
done

# --- non-TTY install bare fails clearly ---
if AGENT_MEMORY_PROJECT_DIR="$TMP" node "$cli" install </dev/null >/dev/null 2>"$TMP/err"; then
  fail "interactive install without TTY should fail"
fi
grep -qi 'TTY\|tty' "$TMP/err" || fail "non-TTY error should mention TTY"

# --- installer fails closed without realpath/python3 ---
mkdir -p "$TMP/empty-bin"
if PATH="$TMP/empty-bin" AGENT_MEMORY_PROJECT_DIR="$TMP" \
  /bin/bash "$repo_root/hooks/install-hooks.sh" cursor >/dev/null 2>"$TMP/no-resolve.err"; then
  fail "installer should fail closed without realpath/python3"
fi
grep -qi 'realpath or python3' "$TMP/no-resolve.err" ||
  fail "expected fail-closed message: $(cat "$TMP/no-resolve.err")"

printf 'ok - cli install smoke\n'
