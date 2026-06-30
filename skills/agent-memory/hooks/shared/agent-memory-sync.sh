#!/bin/bash
# agent-memory deterministic checkpoint (all harnesses).
#
# Evidence-backed updates from git + session ID — no LLM, no invented semantics.
# Maintains: active-work (Touched files, Task stub), log.md (session heading +
# file-change bullets). current.md is refreshed on sessionStart only.
#
# Reads harness stdin JSON when present (session_id, cwd — Claude, Cursor,
# Copilot, Codex). Session ID also from AGENT_MEMORY_SESSION_ID env or state.
#
# Set AGENT_MEMORY_EVENT (any host naming):
#   postToolUse | PostToolUse        — after Write/Edit/Bash; debounced
#   afterAgentResponse | Stop | agentStop — end of assistant turn
#   preCompact | PreCompact | precommit — before compaction or git commit
#
# Install per host — see hooks/README.md.

set -u

raw_event="${AGENT_MEMORY_EVENT:-afterAgentResponse}"
case "$raw_event" in
  postToolUse|PostToolUse|posttool) event=postToolUse ;;
  afterAgentResponse|Stop|stop|agentStop|afterresponse) event=afterAgentResponse ;;
  preCompact|PreCompact|precompact|precommit) event=preCompact ;;
  *) event=afterAgentResponse ;;
esac

hook_input=""
if [ ! -t 0 ]; then
  hook_input=$(cat 2>/dev/null || true)
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all three hooks/shared/*.sh together (see skills/agent-memory/hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

parse_hook_stdin "$hook_input"
cwd=$(resolve_project_dir "$hook_stdin_cwd")
memory="$cwd/.agents/memory"
state_file="$memory/.hook-sync-state"

[ -d "$memory" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

session_id=$(resolve_session_id "$hook_stdin_session_id")
persist_session_id "$session_id"

files_hash() {
  list_non_memory_changes | shasum -a 256 2>/dev/null | awk '{print $1}' || echo "none"
}

mark_head_processed() {
  local current_head
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  [ -n "$current_head" ] || return 0
  write_state last_processed_head "$current_head"
}

should_skip_posttool() {
  local hash now last_ts min_interval=45
  hash=$(files_hash)
  [ "$hash" != "none" ] || return 0
  last_ts=$(read_state last_posttool_ts "0")
  now=$(date +%s)
  if [ "$hash" = "$(read_state last_posttool_hash "")" ] && [ $((now - last_ts)) -lt $min_interval ]; then
    return 0
  fi
  write_state last_posttool_hash "$hash"
  write_state last_posttool_ts "$now"
  return 1
}

run_checkpoint() {
  local aw
  aw=$(ensure_active_work)
  update_touched_files "$aw"
  update_task_stub "$aw"
  append_log_file_bullets "$session_id"
}

case "$event" in
  postToolUse)
    agent_memory_include_commit_files=0
    changes=$(list_non_memory_changes)
    [ -n "$changes" ] || exit 0
    should_skip_posttool && exit 0
    run_checkpoint
    ;;
  afterAgentResponse|preCompact)
    agent_memory_include_commit_files=1
    changes=$(list_non_memory_changes)
    [ -n "$changes" ] || { mark_head_processed; exit 0; }
    run_checkpoint
    mark_head_processed
    ;;
  *)
    exit 0
    ;;
esac

exit 0
