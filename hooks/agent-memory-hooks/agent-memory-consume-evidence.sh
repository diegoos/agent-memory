#!/bin/bash
# Clear session_touched_files after the agent wrote semantic memory outcomes.
# Never edits Markdown. Safe no-op when memory/state missing.
# Usage (project root): bash <harness-hooks>/agent-memory-consume-evidence.sh
# Or: AGENT_MEMORY_PROJECT_DIR=/path bash …/agent-memory-consume-evidence.sh

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

agent_memory_init_context || exit 0
[ -d "${memory:-}" ] || exit 0

consume_pending_path_evidence
exit 0
