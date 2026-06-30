#!/bin/bash
# agent-memory sessionStart / NewSession hook — inject context + deterministic
# memory refresh. Captures session_id from harness stdin JSON when provided.
# On new session: refresh current.md In progress from active-work/ + log state.
# No-op when .agents/memory/ is absent.
#
# Set AGENT_MEMORY_HOST: cursor | claude | codex | copilot | opencode

set -u

host="${AGENT_MEMORY_HOST:-}"

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

session_id=$(resolve_session_id "$hook_stdin_session_id" 0)
[ -n "$session_id" ] || write_state current_session_id ""
persist_session_id "$session_id"
reset_logged_files_if_session_changed "$session_id" sessionStart

# New session: ensure active-work, log heading, current.md in-progress list.
if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  aw=$(ensure_active_work)
  update_task_stub "$aw"
  ensure_session_log_heading "$session_id" sessionStart
  refresh_current_in_progress
fi

msg="This project uses Agent Memory in .agents/memory/. Before tasks, Read .agents/memory/instructions.md, index.md, current.md, and your branch active-work file. While you work: refine active-work Task/Progress, append semantic bullets under the current session heading in log.md, and record every architecture/design decision in decisions.md when you make or change one. Hooks keep Touched files, log file-change bullets, and current.md In progress in sync — you own task meaning, log summaries/types, and decisions.md. Session ID: AGENT_MEMORY_SESSION_ID when set. Run /agent-memory sync at checkpoints."

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
  *)
    [ -n "$session_id" ] && export AGENT_MEMORY_SESSION_ID="$session_id"
    printf '%s\n' "$msg"
    ;;
esac
exit 0
