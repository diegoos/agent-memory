#!/bin/bash
# Deterministic checkpoint — writes .hook-sync-state only (no Markdown writes).
#
# Session id: resolved under lock inside run_sync_ephemeral_checkpoint (common.sh).
# Set AGENT_MEMORY_HOST when possible; when omitted, rebind keeps session_binding_host.
#
# AGENT_MEMORY_EVENT aliases (any host naming):
#   afterAgentResponse | Stop | agentStop | AfterAgent — end of turn
#   preCompact | PreCompact | precommit | PreCompress — before compact / commit
# Unknown events still run a full checkpoint (legacy configs).
# Legacy per-tool events exit 0.
#
# Install per host — see hooks/README.md.

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all shared hooks/agent-memory-hooks/*.sh together (see hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

raw_event="${AGENT_MEMORY_EVENT:-afterAgentResponse}"
case "$raw_event" in
  postToolUse|PostToolUse|posttool|AfterTool|aftertool|afterFileEdit|afterfileedit)
    # Legacy aliases kept for installed configs — no-op.
    exit 0
    ;;
esac

agent_memory_init_context || exit 0

[ -d "$memory" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# One lock: resolve session id, persist, rebind, refresh branch, merge paths.
run_sync_ephemeral_checkpoint "$hook_stdin_session_id"
amc_maybe_stop_floor_reminder "$raw_event"

exit 0
