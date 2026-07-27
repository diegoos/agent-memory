#!/bin/bash
# agent-memory sessionStart / NewSession hook — inject context + ephemeral state.
# Captures session_id from harness stdin JSON when provided.
# Never creates or edits Markdown under .agents/memory/.
#
# Set AGENT_MEMORY_HOST: cursor | claude | codex | copilot | opencode | gemini

set -u

host="${AGENT_MEMORY_HOST:-}"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all three hooks/agent-memory-hooks/*.sh together (see hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

agent_memory_init_context || exit 0

[ -d "$memory" ] || exit 0

session_id=$(resolve_session_id "$hook_stdin_session_id" 0)
[ -n "$session_id" ] || write_state current_session_id ""
persist_session_id "$session_id"
reset_session_state_if_changed "$session_id" sessionStart

if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  refresh_branch_cache
fi

msg="Agent Memory: recall layer in .agents/memory/ — not a docs mirror. Before tasks: read instructions.md, index.md, current.md, and your branch active-work when it exists. Write links/deltas, not copies. Hooks store ephemeral evidence only in .hook-sync-state; you own all Markdown meaning. Run /agent-memory sync at checkpoints."

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

case "$host" in
  cursor)
    if [ -n "$session_id" ]; then
      printf '{"env":{"AGENT_MEMORY_SESSION_ID":"%s"},"additional_context":"%s"}\n' \
        "$(json_escape "$session_id")" "$(json_escape "$msg")"
    else
      printf '{"additional_context":"%s"}\n' "$(json_escape "$msg")"
    fi
    ;;
  claude)
    if [ -n "$session_id" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"},"env":{"AGENT_MEMORY_SESSION_ID":"%s"}}\n' \
        "$(json_escape "$msg")" "$(json_escape "$session_id")"
    else
      printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
        "$(json_escape "$msg")"
    fi
    ;;
  codex)
    [ -n "$session_id" ] && export AGENT_MEMORY_SESSION_ID="$session_id"
    printf '%s\n' "$msg"
    ;;
  copilot)
    if [ -n "$session_id" ]; then
      printf '{"additionalContext":"%s","env":{"AGENT_MEMORY_SESSION_ID":"%s"}}\n' \
        "$(json_escape "$msg")" "$(json_escape "$session_id")"
    else
      printf '{"additionalContext":"%s"}\n' "$(json_escape "$msg")"
    fi
    ;;
  opencode)
    [ -n "$session_id" ] && export AGENT_MEMORY_SESSION_ID="$session_id"
    printf '%s\n' "$msg"
    ;;
  gemini)
    # Gemini CLI requires strict JSON-only stdout for hooks (no stray text).
    if [ -n "$session_id" ]; then
      # Prefer context + env when supported; always persist session in state.
      printf '{"context":"%s"}\n' "$(json_escape "$msg")"
    else
      printf '{"context":"%s"}\n' "$(json_escape "$msg")"
    fi
    ;;
  *)
    [ -n "$session_id" ] && export AGENT_MEMORY_SESSION_ID="$session_id"
    printf '%s\n' "$msg"
    ;;
esac
exit 0
