#!/usr/bin/env bash
# Installer merge fixtures: idempotent, preserves custom hooks, drops per-tool.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
merge="$repo_root/hooks/lib/merge-hooks.mjs"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Flat merge (Cursor)
cat >"$TMP/src.json" <<'EOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "AGENT_MEMORY_HOST=cursor .cursor/hooks/agent-memory-session.sh" }
    ],
    "afterAgentResponse": [
      { "command": "AGENT_MEMORY_EVENT=afterAgentResponse .cursor/hooks/agent-memory-sync.sh" }
    ]
  }
}
EOF

cat >"$TMP/tgt.json" <<'EOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "AGENT_MEMORY_HOST=cursor .cursor/hooks/agent-memory-session.sh" }
    ],
    "postToolUse": [
      { "command": "AGENT_MEMORY_EVENT=postToolUse .cursor/hooks/agent-memory-sync.sh" }
    ],
    "afterAgentResponse": [
      { "command": "my-custom-hook.sh" }
    ]
  }
}
EOF

node "$merge" "$TMP/src.json" "$TMP/tgt.json" "$TMP/out1.json" flat
node "$merge" "$TMP/src.json" "$TMP/out1.json" "$TMP/out2.json" flat

# Idempotent
diff -u "$TMP/out1.json" "$TMP/out2.json" >/dev/null || fail "flat merge not idempotent"

# Custom preserved
grep -q 'my-custom-hook.sh' "$TMP/out1.json" || fail "custom hook not preserved"

# Legacy per-tool ours removed on reinstall
! grep -q 'postToolUse' "$TMP/out1.json" || fail "flat merge must scrub postToolUse ours"

# Ours replaced once for sessionStart / afterAgentResponse
count=$(grep -c 'agent-memory-session.sh' "$TMP/out1.json")
[[ "$count" -eq 1 ]] || fail "sessionStart should have exactly one agent-memory entry"

# Nested merge (Claude)
cat >"$TMP/src-n.json" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "AGENT_MEMORY_HOST=claude .claude/hooks/agent-memory-session.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "AGENT_MEMORY_EVENT=Stop .claude/hooks/agent-memory-sync.sh" }
        ]
      }
    ]
  }
}
EOF

cat >"$TMP/tgt-n.json" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "custom-start.sh" },
          { "type": "command", "command": "AGENT_MEMORY_HOST=claude .claude/hooks/agent-memory-session.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "AGENT_MEMORY_EVENT=PostToolUse .claude/hooks/agent-memory-sync.sh" }
        ]
      }
    ]
  }
}
EOF

node "$merge" "$TMP/src-n.json" "$TMP/tgt-n.json" "$TMP/out-n.json" nested
grep -q 'custom-start.sh' "$TMP/out-n.json" || fail "nested custom sibling not preserved"
grep -q 'agent-memory-session.sh' "$TMP/out-n.json" || fail "nested ours missing"
! grep -q 'PostToolUse' "$TMP/out-n.json" || fail "nested merge must scrub PostToolUse ours"

# Nested: custom-only per-tool event preserved (not ours)
cat >"$TMP/tgt-n2.json" <<'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "custom-audit.sh" }
        ]
      }
    ]
  }
}
EOF
node "$merge" "$TMP/src-n.json" "$TMP/tgt-n2.json" "$TMP/out-n2.json" nested
grep -q 'custom-audit.sh' "$TMP/out-n2.json" || fail "custom PostToolUse must be preserved"
grep -q 'PostToolUse' "$TMP/out-n2.json" || fail "custom PostToolUse event key must remain"

# isOurs should not match doc mentions
node --input-type=module <<NODE
import { pathToFileURL } from 'node:url';
const mod = await import(pathToFileURL("$merge").href);
if (mod.isOurs('see docs/agent-memory-sync.sh.example')) {
  console.error('false positive on doc mention');
  process.exit(1);
}
if (!mod.isOurs('AGENT_MEMORY_EVENT=Stop .claude/hooks/agent-memory-sync.sh')) {
  console.error('failed to detect ours');
  process.exit(1);
}
NODE

printf 'ok - hooks merge fixtures\n'
