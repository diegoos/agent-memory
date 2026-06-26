#!/bin/bash
# agent-memory flush reminder hook (shared across agent hosts).
#
# Non-blocking: it only reminds the agent/user to flush agent-memory at
# checkpoints (pre-compaction, stop/session-end). It never writes to the
# memory itself and never blocks the agent, so it cannot loop. The actual
# flush is done by the agent running `/agent-memory sync` (the skill is
# manual-only by design — see skills/agent-memory/SKILL.md). The hooks
# intentionally recommend the per-file confirmed `sync`, not `--auto`, so an
# automatic trigger never causes an unattended memory write.
#
# Wire each host to invoke this script with two env vars set inline:
#   AGENT_MEMORY_HOST=<cursor|claude|codex|copilot>
#   AGENT_MEMORY_EVENT=<precompact|stop>
#
# Input: the host's hook JSON on stdin (ignored except for project-dir hints).
# Output: host-appropriate JSON on stdout + a human reminder on stderr.
# No-op when .agents/memory/ is absent. Fails open.

set -u

host="${AGENT_MEMORY_HOST:-}"
event="${AGENT_MEMORY_EVENT:-precompact}"

# Resolve the project root: prefer host-provided env, then stdin cwd, then $PWD.
cwd="${AGENT_MEMORY_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-}}}"
if [ -z "$cwd" ]; then
  cwd=$(jq -r '.cwd // empty' 2>/dev/null || true)
fi
[ -n "$cwd" ] || cwd="$PWD"

# No memory installed → nothing to do.
[ -d "$cwd/.agents/memory" ] || exit 0

pre_msg="Context is about to be compacted. Before compaction, flush agent-memory so the next agent continues from the files, not chat history: run \`/agent-memory sync\` (or manually update \`.agents/memory/active-work/<branch>.md\` and append to \`.agents/memory/log.md\`)."
stop_msg="Before ending, flush agent-memory: run \`/agent-memory sync\` (or update \`.agents/memory/active-work/<branch>.md\`, \`.agents/memory/log.md\`, and \`.agents/memory/current.md\` per \`.agents/memory/instructions.md\`). If the branch just merged, delete its \`.agents/memory/active-work/<branch>.md\`."

if [ "$event" = "stop" ]; then msg="$stop_msg"; else msg="$pre_msg"; fi

# Human-readable reminder (stderr) — shown to the user on every host.
printf '%s\n' "$msg" >&2

case "$host" in
  cursor)
    if [ "$event" = "stop" ]; then
      printf '{"followup_message":%s}\n' "$(printf '%s' "$msg" | jq -Rs .)"
    else
      printf '{"additional_context":%s}\n' "$(printf '%s' "$msg" | jq -Rs .)"
    fi
    ;;
  claude)
    # systemMessage surfaces to the user without forcing another turn (no loop).
    printf '{"systemMessage":%s}\n' "$(printf '%s' "$msg" | jq -Rs .)"
    ;;
  codex)
    # continue:true = do not block; the stderr line above carries the reminder.
    printf '{"continue":true}\n'
    ;;
  copilot)
    # agentStop with additionalContext can force another turn (loop), so on
    # stop we only remind via stderr. preCompact is notification-only.
    if [ "$event" != "stop" ]; then
      printf '{"additionalContext":%s}\n' "$(printf '%s' "$msg" | jq -Rs .)"
    fi
    ;;
  *)
    # Unknown host: remind via stderr only, succeed silently.
    ;;
esac
exit 0
