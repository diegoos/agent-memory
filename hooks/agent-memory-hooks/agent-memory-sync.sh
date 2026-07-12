#!/bin/bash
# agent-memory deterministic checkpoint (all harnesses).
#
# Evidence-backed updates from git + session ID — no LLM, no invented semantics.
# Maintains: active-work (Touched files, Task stub), log.md (session heading +
# file-change bullets on full checkpoints). current.md is refreshed on sessionStart only.
#
# Reads harness stdin JSON when present (session_id, cwd, tool_name,
# tool_input.file_path / tool_input.path / file_path — Claude, Cursor, Copilot,
# Codex, Gemini). Session ID also from AGENT_MEMORY_SESSION_ID env or state.
#
# Set AGENT_MEMORY_EVENT (any host naming):
#   postToolUse | PostToolUse | AfterTool | afterFileEdit
#       — accumulate touched paths from stdin (git-free; no log.md bullets)
#   afterAgentResponse | Stop | agentStop | AfterAgent — end of turn; full git
#       reconciliation (session-cumulative Touched files, log bullets)
#   preCompact | PreCompact | precommit | PreCompress — before compaction or
#       git commit; same as afterAgentResponse
#
# Git runs only at afterAgentResponse/preCompact (+ sessionStart in session.sh);
# postToolUse/afterFileEdit use the branch cache and stdin file path only.
#
# Install per host — see hooks/README.md.

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all three hooks/agent-memory-hooks/*.sh together (see hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

raw_event="${AGENT_MEMORY_EVENT:-afterAgentResponse}"
case "$raw_event" in
  postToolUse|PostToolUse|posttool|AfterTool|aftertool|afterFileEdit|afterfileedit)
    event=postToolUse
    ;;
  afterAgentResponse|Stop|stop|agentStop|afterresponse|AfterAgent|afteragent)
    event=afterAgentResponse
    ;;
  preCompact|PreCompact|precompact|precommit|PreCompress|precompress)
    event=preCompact
    ;;
  *) event=afterAgentResponse ;;
esac

agent_memory_init_context || exit 0

[ -d "$memory" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Normalize harness file path to a repo-relative path, or return non-zero to skip.
normalize_repo_rel_path() {
  local rel=$1
  case "$rel" in
    *$'\n'* | *$'\r'* | *$'\x1e'*) return 1 ;;
  esac
  case "$rel" in
    "$cwd"/*) rel=${rel#"$cwd"/} ;;
    /*) return 1 ;;
  esac
  case "$rel" in
    .agents/memory/*) return 1 ;;
  esac
  case "/$rel/" in
    */../*) return 1 ;;
  esac
  [ -n "$rel" ] || return 1
  printf '%s' "$rel"
}

case "$event" in
  postToolUse)
    agent_memory_include_commit_files=0
    [ -n "$hook_stdin_tool_file" ] || exit 0
    run_posttool_checkpoint "$hook_stdin_tool_file"
    exit 0
    ;;
esac

session_id=$(resolve_session_id "$hook_stdin_session_id")
log_session_id=$(normalize_session_id_for_checkpoint "$session_id")
persist_session_id "$session_id"

mark_head_processed() {
  local current_head
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  [ -n "$current_head" ] || return 0
  write_state last_processed_head "$current_head"
}

# Git-free: merge stdin path into session touched set; no log.md bullets.
run_posttool_checkpoint() {
  local rel=$1 aw accumulated
  rel=$(normalize_repo_rel_path "$rel") || return 0
  accumulated=$(read_state session_touched_files "")
  file_already_logged "$rel" "$accumulated" && return 0
  aw=$(ensure_active_work)
  add_touched_file "$aw" "$rel"
  update_task_stub "$aw"
}

run_full_checkpoint() {
  local list_file=$1 aw resolved_sid filtered_tmp
  aw=$(ensure_active_work)
  update_task_stub "$aw"
  resolved_sid=$(ensure_log_heading_for_checkpoint "$log_session_id")
  if [ -s "$list_file" ]; then
    filtered_tmp=$(mktemp)
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      f=$(normalize_repo_rel_path "$f") || continue
      printf '%s\n' "$f" >>"$filtered_tmp"
    done <"$list_file"
    if [ -s "$filtered_tmp" ]; then
      update_touched_files "$aw" "$filtered_tmp"
      append_log_file_bullets "$resolved_sid" "$filtered_tmp"
    else
      write_active_work_touched_from_session "$aw"
    fi
    rm -f "$filtered_tmp"
  else
    write_active_work_touched_from_session "$aw"
  fi
}

case "$event" in
  afterAgentResponse|preCompact)
    agent_memory_include_commit_files=1
    refresh_branch_cache
    list_tmp=$(mktemp)
    list_non_memory_changes >"$list_tmp"
    run_full_checkpoint "$list_tmp"
    rm -f "$list_tmp"
    mark_head_processed
    ;;
  *)
    exit 0
    ;;
esac

exit 0
