#!/bin/bash
# agent-memory sessionStart / NewSession hook — inject context + deterministic
# memory refresh. Captures session_id from harness stdin JSON when provided.
# On new session: refresh current.md In progress from active-work/ + log state.
# No-op when .agents/memory/ is absent.
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
reset_logged_files_if_session_changed "$session_id" sessionStart

# New session: ensure active-work, log heading, current.md in-progress list.
if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  refresh_branch_cache
  aw=$(ensure_active_work)
  update_task_stub "$aw"
  ensure_session_log_heading "$session_id" sessionStart
  refresh_current_in_progress
fi

msg="Agent Memory (.agents/memory/). Before tasks: read instructions.md, index.md, current.md, and your branch active-work file. As you work: refine active-work Task/Progress, append semantic bullets under the current session heading in log.md, and record every architecture/design decision in decisions.md. Hooks keep Touched files, log file-bullets, and current.md In progress synced — you own task meaning, log type/summary, and decisions.md. Run /agent-memory sync at checkpoints (end of task, before commit/compaction)."

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
    # We return the memory guidance as context. The deterministic work
    # (heading, current.md, etc.) happens as side effects before this output.
    printf '{"context":"%s"}\n' "$(json_escape "$msg")"
    ;;
  *)
    [ -n "$session_id" ] && export AGENT_MEMORY_SESSION_ID="$session_id"
    printf '%s\n' "$msg"
    ;;
esac
exit 0
