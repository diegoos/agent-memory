#!/bin/bash
# agent-memory deterministic checkpoint (all harnesses).
#
# Evidence-backed updates from git + session ID — no LLM, no invented semantics.
# Maintains: active-work (Touched files, Task stub), log.md (session heading +
# file-change bullets). current.md is refreshed on sessionStart only.
#
# Reads harness stdin JSON when present (session_id, cwd, tool_name,
# tool_input.file_path — Claude, Cursor, Copilot, Codex, Gemini). Session ID also from
# AGENT_MEMORY_SESSION_ID env or state.
#
# Set AGENT_MEMORY_EVENT (any host naming):
#   postToolUse | PostToolUse        — after Write/Edit; logs the stdin file_path
#                                       (no git; Shell is a no-op here)
#   afterAgentResponse | Stop | agentStop — end of assistant turn; full git
#                                       reconciliation (Touched files, log bullets)
#   preCompact | PreCompact | precommit — before compaction or git commit; same
#                                       as afterAgentResponse
#
# Git runs only at afterAgentResponse/preCompact (+ sessionStart in session.sh);
# postToolUse is git-free, using the branch cache and the stdin file path.
#
# Install per host — see hooks/README.md.

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all three hooks/agent-memory-hooks/*.sh together (see skills/agent-memory/hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

raw_event="${AGENT_MEMORY_EVENT:-afterAgentResponse}"
case "$raw_event" in
  postToolUse|PostToolUse|posttool) event=postToolUse ;;
  afterAgentResponse|Stop|stop|agentStop|afterresponse) event=afterAgentResponse ;;
  preCompact|PreCompact|precompact|precommit) event=preCompact ;;
  *) event=afterAgentResponse ;;
esac

agent_memory_init_context

[ -d "$memory" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

session_id=$(resolve_session_id "$hook_stdin_session_id")
persist_session_id "$session_id"

mark_head_processed() {
  local current_head
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  [ -n "$current_head" ] || return 0
  write_state last_processed_head "$current_head"
}


run_checkpoint() {
  local list_file=$1 aw
  [ -s "$list_file" ] || return 0
  aw=$(ensure_active_work)
  update_touched_files "$aw" "$list_file"
  update_task_stub "$aw"
  append_log_file_bullets "$session_id" "$list_file"
}

case "$event" in
  postToolUse)
    # Git-free: log the file from the harness stdin (Write/Edit tool_input.
    # file_path) for a live preview; Shell (no file_path) is a no-op. The full
    # git reconciliation runs at afterAgentResponse/preCompact (catches shell-
    # created files, deletions, and refreshes Touched files). Branch comes from
    # the state cache populated at sessionStart/afterAgentResponse.
    agent_memory_include_commit_files=0
    [ -n "$hook_stdin_tool_file" ] || exit 0
    rel="$hook_stdin_tool_file"
    case "$rel" in
      "$cwd"/*) rel=${rel#"$cwd"/} ;;   # absolute under cwd → repo-relative
      /*) exit 0 ;;                       # absolute outside cwd → not tracked
    esac
    case "$rel" in
      .agents/memory/*) exit 0 ;;         # memory files aren't logged
    esac
    [ -n "$rel" ] || exit 0
    aw=$(ensure_active_work)
    add_touched_file "$aw" "$rel"
    update_task_stub "$aw"
    single=$(mktemp)
    printf '%s\n' "$rel" >"$single"
    append_log_file_bullets "$session_id" "$single"
    rm -f "$single"
    ;;
  afterAgentResponse|preCompact)
    agent_memory_include_commit_files=1
    refresh_branch_cache
    list_tmp=$(mktemp)
    list_non_memory_changes >"$list_tmp"
    [ -s "$list_tmp" ] || { rm -f "$list_tmp"; mark_head_processed; exit 0; }
    run_checkpoint "$list_tmp"
    rm -f "$list_tmp"
    mark_head_processed
    ;;
  *)
    exit 0
    ;;
esac

exit 0
