#!/bin/bash
# agent-memory deterministic checkpoint (all harnesses).
#
# Evidence-backed updates to .hook-sync-state only — no Markdown writes.
# Accumulates session_touched_files and last_processed_head from git.
#
# Reads harness stdin JSON when present (session_id, cwd).
# Session ID: harness stdin when valid and disagreeing with inherited
# AGENT_MEMORY_SESSION_ID; otherwise AGENT_MEMORY_SESSION_ID env, then state.
# Set AGENT_MEMORY_HOST to the harness name when possible (cursor | claude |
# codex | copilot | opencode | gemini); when omitted, rebind preserves
# session_binding_host from .hook-sync-state.
#
# Set AGENT_MEMORY_EVENT (any host naming):
#   afterAgentResponse | Stop | agentStop | AfterAgent — end of turn
#   preCompact | PreCompact | precommit | PreCompress — before compaction or
#       git commit
# Per-tool events (postToolUse / afterFileEdit / AfterTool) are no longer wired;
# if invoked, they exit immediately.
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
    # Legacy per-tool events — no-op under ephemeral contract.
    exit 0
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

session_id=$(resolve_session_id "$hook_stdin_session_id")
persist_session_id "$session_id"
reset_session_state_if_changed "$session_id" sync

run_ephemeral_checkpoint() {
  local list_tmp
  agent_memory_include_commit_files=1
  refresh_branch_cache
  list_tmp=$(mktemp)
  list_non_memory_changes >"$list_tmp"
  apply_ephemeral_checkpoint "$list_tmp"
  rm -f "$list_tmp"
}

case "$event" in
  afterAgentResponse|preCompact)
    run_ephemeral_checkpoint
    ;;
  *)
    exit 0
    ;;
esac

exit 0
