#!/usr/bin/env bash
# Ephemeral hook checkpoint fixture: session + full sync never touch Markdown.
# Asserts state-only writes and multi-commit range accumulation.

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

# Snapshot Markdown before hooks
md_checksum() {
  find .agents/memory -name '*.md' | sort | while read -r f; do
    cksum "$f"
  done | cksum
}
md_before=$(md_checksum)

# --- sessionStart ---
printf '{"session_id":"s1","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  ./agent-memory-session.sh >"$TMP/session-out.json"

grep -q '"additional_context"' "$TMP/session-out.json" ||
  grep -qi 'recall layer\|Agent Memory' "$TMP/session-out.json" ||
  fail "session stdout missing agent-memory context"

test -f .agents/memory/.hook-sync-state || fail "session did not create state"
grep -q 'current_session_id=s1' .agents/memory/.hook-sync-state ||
  fail "session id not persisted"

# No active-work created by hooks
active_count=$(find .agents/memory/active-work -name '*.md' ! -name 'TEMPLATE.md' | wc -l | tr -d ' ')
[[ "$active_count" -eq 0 ]] || fail "hooks must not create active-work files"

# No real session log heading created (ignore fenced format examples)
if grep -E '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' .agents/memory/log.md |
  grep -vq 'YYYY-MM-DD'; then
  fail "hooks must not create log headings"
fi

# decisions/learnings untouched
test ! -e .agents/memory/learnings.md || fail "hooks must not create learnings.md"
grep -q 'No decisions recorded yet' .agents/memory/decisions.md ||
  fail "decisions.md unexpectedly rewritten"

# --- full checkpoint with dirty + committed files ---
echo 'hello' > app.txt
git add app.txt && git commit -q -m 'add app'
echo 'dirty' >> app.txt
printf 'x\n' > other.txt

printf '{"session_id":"s1","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s1 \
  ./agent-memory-sync.sh >/dev/null

grep -q 'session_touched_files=.*app.txt' .agents/memory/.hook-sync-state ||
  fail "full checkpoint missing app.txt in state"
grep -q 'other.txt' .agents/memory/.hook-sync-state ||
  fail "full checkpoint missing other.txt in state"
grep -q 'last_processed_head=' .agents/memory/.hook-sync-state ||
  fail "missing last_processed_head"

# Markdown unchanged
md_after=$(md_checksum)
[[ "$md_before" == "$md_after" ]] || fail "hooks must not alter Markdown files"

# --- multi-commit range ---
echo 'a' > a.txt && git add a.txt && git commit -q -m 'a'
echo 'b' > b.txt && git add b.txt && git commit -q -m 'b'

printf '{"session_id":"s1","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s1 \
  ./agent-memory-sync.sh >/dev/null

grep -q 'a.txt' .agents/memory/.hook-sync-state || fail "range missing a.txt"
grep -q 'b.txt' .agents/memory/.hook-sync-state || fail "range missing b.txt"

# --- session change clears paths ---
printf '{"session_id":"s2","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  ./agent-memory-session.sh >/dev/null

touched=$(grep '^session_touched_files=' .agents/memory/.hook-sync-state | cut -d= -f2- || true)
[[ -z "$touched" ]] || fail "new session must clear session_touched_files"

# --- legacy per-tool event is no-op ---
printf '{"session_id":"s2","cwd":"%s","tool_input":{"file_path":"%s/x.txt"}}\n' \
  "$TMP" "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=postToolUse AGENT_MEMORY_SESSION_ID=s2 \
  ./agent-memory-sync.sh >/dev/null

touched2=$(grep '^session_touched_files=' .agents/memory/.hook-sync-state | cut -d= -f2- || true)
[[ -z "$touched2" ]] || fail "postToolUse must be no-op under ephemeral contract"

# --- symlink state refused ---
rm -f .agents/memory/.hook-sync-state
ln -s /tmp/evil-state .agents/memory/.hook-sync-state
printf '{"session_id":"s3","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  ./agent-memory-session.sh >/dev/null 2>"$TMP/symlink.err" || true
grep -qi 'refused symlink\|symlink' "$TMP/symlink.err" ||
  fail "expected symlink refusal on state file"

# --- branch change updates cache and clears then re-accumulates ---
rm -f .agents/memory/.hook-sync-state
printf '%s\n' \
  'current_session_id=s4' \
  'session_binding=s4' \
  'branch=main' \
  'session_touched_files=stale.txt' \
  >.agents/memory/.hook-sync-state
git checkout -q -b other-branch
printf '{"session_id":"s4","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s4 \
  ./agent-memory-sync.sh >/dev/null
grep -q 'branch=other-branch' .agents/memory/.hook-sync-state ||
  fail "branch cache not updated on switch"
! grep -q 'stale.txt' .agents/memory/.hook-sync-state ||
  fail "branch switch must clear stale session_touched_files"

# --- path escape refused ---
! grep -qE '(^|[=])\.\./|/\.\./' .agents/memory/.hook-sync-state ||
  fail "path escape (..) must not appear in state"

# --- end-of-turn / preCompact / pre-commit parity (all full checkpoints) ---
for ev in afterAgentResponse preCompact Stop PreCompact agentStop AfterAgent precommit; do
  printf '{"session_id":"s4","cwd":"%s"}\n' "$TMP" |
    AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
    AGENT_MEMORY_EVENT="$ev" AGENT_MEMORY_SESSION_ID=s4 \
    ./agent-memory-sync.sh >/dev/null ||
    fail "event $ev should succeed"
done
md_final=$(md_checksum)
[[ "$md_before" == "$md_final" ]] || fail "harness events must not alter Markdown"

# --- concurrency: lock fail-open does not remove a foreign live lock ---
mkdir -p .agents/memory/.hook-sync-state.lock
printf '%s\n' "$$" >.agents/memory/.hook-sync-state.lock/pid
printf '{"session_id":"s4","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s4 \
  ./agent-memory-sync.sh >/dev/null 2>"$TMP/lock.err" || true
grep -qi 'fail-open\|lock busy\|stale state lock' "$TMP/lock.err" ||
  fail "expected lock contention message when lock is held"
# Live PID in lock — must not steal/remove foreign lock
[[ -d .agents/memory/.hook-sync-state.lock ]] ||
  fail "must not remove a live foreign lock"
rm -rf .agents/memory/.hook-sync-state.lock

# --- stale lock (dead pid) is stolen ---
mkdir -p .agents/memory/.hook-sync-state.lock
printf '%s\n' "99999999" >.agents/memory/.hook-sync-state.lock/pid
printf '{"session_id":"s4","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s4 \
  ./agent-memory-sync.sh >/dev/null 2>"$TMP/stale.err" || true
grep -qi 'stale state lock\|fail-open\|lock busy' "$TMP/stale.err" || true
# After successful steal+release, lock dir should be gone
[[ ! -d .agents/memory/.hook-sync-state.lock ]] ||
  fail "stale lock should be stolen and released"
awk -F= 'NF < 1 { exit 1 } $1 !~ /^[A-Za-z0-9_]+$/ { exit 1 }' \
  .agents/memory/.hook-sync-state ||
  fail "state file corrupted under lock contention"

# --- OpenCode ses_* rotation keeps accumulated paths (same day) ---
today=$(date +%Y-%m-%d)
printf '%s\n' \
  'current_session_id=ses_aaa' \
  'session_binding=ses_aaa' \
  'session_binding_host=opencode' \
  "session_binding_day=$today" \
  'session_touched_files=kept.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"ses_bbb","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=opencode AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=Stop AGENT_MEMORY_SESSION_ID=ses_bbb \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=ses_bbb' .agents/memory/.hook-sync-state ||
  fail "opencode ses_* rotation should rebind session"
grep -q 'kept.txt' .agents/memory/.hook-sync-state ||
  fail "opencode ses_* rotation must not clear session_touched_files"

# --- OpenCode ses_* across calendar days clears paths ---
printf '%s\n' \
  'session_binding=ses_oldday' \
  'session_binding_host=opencode' \
  'session_binding_day=1999-01-01' \
  'session_touched_files=yesterday.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"ses_newday","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=opencode AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=Stop AGENT_MEMORY_SESSION_ID=ses_newday \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=ses_newday' .agents/memory/.hook-sync-state ||
  fail "opencode cross-day rebind should update session"
! grep -q 'yesterday.txt' .agents/memory/.hook-sync-state ||
  fail "opencode ses_* across days must clear session_touched_files"
grep -q "session_binding_day=$today" .agents/memory/.hook-sync-state ||
  fail "opencode rebind should stamp today's binding day"

# --- promote __no_id__ → real id keeps paths ---
printf '%s\n' \
  'session_binding=__no_id__' \
  'session_touched_files=early.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"s-promoted","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s-promoted \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=s-promoted' .agents/memory/.hook-sync-state ||
  fail "promotion should rebind to real session id"
grep -q 'early.txt' .agents/memory/.hook-sync-state ||
  fail "promoting __no_id__ must not clear session_touched_files"

# --- OpenCode conversation_id → ses_* keeps paths (same host, same day) ---
printf '%s\n' \
  'session_binding=conv-stable' \
  'session_binding_host=opencode' \
  "session_binding_day=$today" \
  'session_touched_files=from-conv.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"ses_ccc","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=opencode AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=Stop AGENT_MEMORY_SESSION_ID=ses_ccc \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=ses_ccc' .agents/memory/.hook-sync-state ||
  fail "opencode conversation→ses should rebind"
grep -q 'from-conv.txt' .agents/memory/.hook-sync-state ||
  fail "opencode conversation→ses must not clear session_touched_files"

# --- Cursor binding then OpenCode ses_* clears foreign paths ---
printf '%s\n' \
  'session_binding=cursor-session' \
  'session_binding_host=cursor' \
  "session_binding_day=$today" \
  'session_touched_files=from-cursor.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"ses_ddd","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=opencode AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=Stop AGENT_MEMORY_SESSION_ID=ses_ddd \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=ses_ddd' .agents/memory/.hook-sync-state ||
  fail "cross-harness rebind should update session"
! grep -q 'from-cursor.txt' .agents/memory/.hook-sync-state ||
  fail "OpenCode must not keep paths from another harness binding"

# --- distinct cursor sessions still clear paths ---
printf '%s\n' \
  'session_binding=s-old' \
  'session_binding_host=cursor' \
  'session_touched_files=stale-session.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"s-new","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=cursor AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=afterAgentResponse AGENT_MEMORY_SESSION_ID=s-new \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=s-new' .agents/memory/.hook-sync-state ||
  fail "cursor session change should rebind"
! grep -q 'stale-session.txt' .agents/memory/.hook-sync-state ||
  fail "distinct cursor sessions must clear session_touched_files"

# --- sync without session id keeps existing binding/paths (e.g. pre-commit) ---
printf '%s\n' \
  'session_binding=s-active' \
  'session_binding_host=cursor' \
  "session_binding_day=$today" \
  'current_session_id=s-active' \
  'session_touched_files=precommit-keep.txt' \
  >.agents/memory/.hook-sync-state
printf '{"cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=git AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=precommit \
  ./agent-memory-sync.sh >/dev/null
grep -q 'session_binding=s-active' .agents/memory/.hook-sync-state ||
  fail "pre-commit without session id must keep binding"
grep -q 'precommit-keep.txt' .agents/memory/.hook-sync-state ||
  fail "pre-commit without session id must keep session_touched_files"

# --- OpenCode same id without binding_day clears legacy paths ---
printf '%s\n' \
  'session_binding=conv-stable' \
  'session_binding_host=opencode' \
  'session_touched_files=legacy-nodate.txt' \
  >.agents/memory/.hook-sync-state
printf '{"session_id":"conv-stable","cwd":"%s"}\n' "$TMP" |
  AGENT_MEMORY_HOST=opencode AGENT_MEMORY_PROJECT_DIR="$TMP" \
  AGENT_MEMORY_EVENT=Stop AGENT_MEMORY_SESSION_ID=conv-stable \
  ./agent-memory-sync.sh >/dev/null
! grep -q 'legacy-nodate.txt' .agents/memory/.hook-sync-state ||
  fail "opencode same-id without binding_day must clear legacy paths"
grep -q "session_binding_day=$today" .agents/memory/.hook-sync-state ||
  fail "opencode same-id should stamp session_binding_day"

printf 'ok - hooks ephemeral checkpoint fixture\n'
