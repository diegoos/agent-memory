#!/usr/bin/env bash
# Minimal hook checkpoint fixture: session start, post-tool accumulate, full sync.
# Asserts structural writes only — no decisions/learnings/consolidation.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
hook_dir="$repo_root/hooks/agent-memory-hooks"
skeleton="$repo_root/skills/agent-memory/vendor/memory"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

git init -q
git config user.email test@example.com
git config user.name test

mkdir -p .agents
cp -R "$skeleton" .agents/memory
cp "$hook_dir"/agent-memory-*.sh .
chmod +x agent-memory-*.sh

# --- sessionStart ---
printf '{"session_id":"s1","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  ./agent-memory-session.sh >"$TMP/session-out.json"

grep -q '"additional_context"' "$TMP/session-out.json" ||
  grep -qi 'recall layer\|Agent Memory' "$TMP/session-out.json" ||
  fail "session stdout missing agent-memory context"
grep -q '^## In progress' .agents/memory/current.md || fail "missing In progress"
grep -q '^## \[' .agents/memory/log.md || fail "session log heading missing"
test -n "$(find .agents/memory/active-work -name '*.md' ! -name 'TEMPLATE.md')" ||
  fail "active-work file not created"
grep -q '_No active task_\|refine in session\|main\|master\|local' \
  .agents/memory/active-work/*.md || fail "active-work task stub missing"

# Ensure decisions/learnings untouched by hooks
! grep -q 'Source:\|insight —' .agents/memory/decisions.md 2>/dev/null || true
test ! -e .agents/memory/learnings.md || fail "hooks must not create learnings.md"

# --- postToolUse: accumulate path, no log bullet ---
printf 'x\n' > other.txt
log_before=$(wc -l < .agents/memory/log.md)

printf '{"session_id":"s1","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s/other.txt"}}\n' \
  "$TMP" "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=postToolUse AGENT_MEMORY_SESSION_ID=s1 \
  ./agent-memory-sync.sh >/dev/null

grep -q 'other.txt' .agents/memory/active-work/*.md || fail "postToolUse did not touch files"
log_after=$(wc -l < .agents/memory/log.md)
[[ "$log_after" -eq "$log_before" ]] || fail "postToolUse must not append log bullets"
! grep -q '`other.txt`' .agents/memory/log.md || fail "postToolUse wrote path bullet to log"

# --- full checkpoint: path bullet after dirty git file ---
echo 'hello' > app.txt
git add app.txt && git commit -q -m 'add app'
echo 'dirty' >> app.txt

printf '{"session_id":"s1","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s1 \
  ./agent-memory-sync.sh >/dev/null

grep -q 'app.txt\|changed .* files' .agents/memory/log.md ||
  fail "full checkpoint missing path evidence in log"
grep -q 'app.txt\|other.txt' .agents/memory/active-work/*.md ||
  fail "full checkpoint missing touched files"

# hooks never invent decisions
tail -n +1 .agents/memory/decisions.md | grep -q '_No decisions recorded yet_\|^# Decisions' ||
  fail "decisions.md unexpectedly rewritten"

printf 'ok - hooks checkpoint fixture\n'
