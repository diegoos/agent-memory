#!/bin/bash
# Print allowlisted hook-state fields for agents. Never dumps path lists.
# Usage (project root): bash <harness-hooks>/agent-memory-print-evidence.sh
# Or: AGENT_MEMORY_PROJECT_DIR=/path bash …/agent-memory-print-evidence.sh

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
_common_sh="$script_dir/agent-memory-common.sh"
if [ ! -f "$_common_sh" ]; then
  printf 'agent-memory: missing agent-memory-common.sh beside %s; install all shared hooks/agent-memory-hooks/*.sh together (see hooks/README.md)\n' \
    "$(basename -- "$0")" >&2
  printf '%s\n' \
    'state=absent' \
    'pending_count=0' \
    'last_processed_head=' \
    'current_session_id=' \
    'branch='
  exit 0
fi
# shellcheck source=agent-memory-common.sh
. "$_common_sh"

if ! agent_memory_init_context; then
  _print_sanitized_hook_evidence_absent
  exit 0
fi

print_sanitized_hook_evidence
exit 0
