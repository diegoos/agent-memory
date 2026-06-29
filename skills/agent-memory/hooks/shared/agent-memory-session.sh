#!/bin/bash
# agent-memory sessionStart hook — inject read/write obligation (all harnesses).
# No-op when .agents/memory/ is absent. Outputs host-appropriate JSON or plain text.
#
# Set AGENT_MEMORY_HOST: cursor | claude | codex | copilot

set -u

host="${AGENT_MEMORY_HOST:-}"
cwd="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-${AGENT_MEMORY_PROJECT_DIR:-$PWD}}}}"
[ -d "$cwd/.agents/memory" ] || exit 0

msg="This project uses Agent Memory in .agents/memory/. Before tasks, Read .agents/memory/instructions.md, index.md, current.md, and your branch active-work file. While you work, keep active-work, log.md, and current.md current; run /agent-memory sync at checkpoints. Hooks update Touched files from git between turns — you still own task/progress text."

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
    printf '{"additional_context":"%s"}\n' "$(json_escape "$msg")"
    ;;
  claude)
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$msg")"
    ;;
  codex)
    # SessionStart: plain stdout is injected as developer context.
    printf '%s\n' "$msg"
    ;;
  copilot)
    printf '{"additionalContext":"%s"}\n' "$(json_escape "$msg")"
    ;;
  *)
  # Unknown host: plain text (safe default).
    printf '%s\n' "$msg"
    ;;
esac
exit 0
