#!/bin/bash
# sessionStart / NewSession — inject context + bind ephemeral state.
# Never creates or edits Markdown under .agents/memory/.
# Set AGENT_MEMORY_HOST: cursor | claude | codex | copilot | opencode | gemini

set -u

host="${AGENT_MEMORY_HOST:-}"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all shared hooks/agent-memory-hooks/*.sh together (see hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

agent_memory_init_context || exit 0

[ -d "$memory" ] || exit 0

# Resolve + bind under one lock (run_session_start_ephemeral_bind in common.sh).
run_session_start_ephemeral_bind "$hook_stdin_session_id"
bound_session_id=""
if [ "${agent_memory_session_bind_ok:-0}" = "1" ] && [ -n "${agent_memory_bound_session_id:-}" ]; then
  bound_session_id="$agent_memory_bound_session_id"
fi

msg=$(build_session_context_msg)

case "$host" in
  cursor)
    if [ -n "$bound_session_id" ]; then
      printf '{"env":{"AGENT_MEMORY_SESSION_ID":"%s"},"additional_context":"%s"}\n' \
        "$(json_escape "$bound_session_id")" "$(json_escape "$msg")"
    else
      printf '{"additional_context":"%s"}\n' "$(json_escape "$msg")"
    fi
    ;;
  claude)
    if [ -n "$bound_session_id" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"env":{"AGENT_MEMORY_SESSION_ID":"%s"}}\n' \
        "$(json_escape "$msg")" "$(json_escape "$bound_session_id")"
    else
      printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
        "$(json_escape "$msg")"
    fi
    ;;
  codex)
    [ -n "$bound_session_id" ] && export AGENT_MEMORY_SESSION_ID="$bound_session_id"
    printf '%s\n' "$msg"
    ;;
  copilot)
    if [ -n "$bound_session_id" ]; then
      printf '{"additionalContext":"%s","env":{"AGENT_MEMORY_SESSION_ID":"%s"}}\n' \
        "$(json_escape "$msg")" "$(json_escape "$bound_session_id")"
    else
      printf '{"additionalContext":"%s"}\n' "$(json_escape "$msg")"
    fi
    ;;
  opencode)
    [ -n "$bound_session_id" ] && export AGENT_MEMORY_SESSION_ID="$bound_session_id"
    printf '%s\n' "$msg"
    ;;
  gemini)
    # Gemini CLI requires strict JSON-only stdout for hooks (no stray text).
    printf '{"context":"%s"}\n' "$(json_escape "$msg")"
    ;;
  *)
    [ -n "$bound_session_id" ] && export AGENT_MEMORY_SESSION_ID="$bound_session_id"
    printf '%s\n' "$msg"
    ;;
esac
exit 0
