// OpenCode plugin: deterministic agent-memory checkpoints at compaction and
// session idle (≈ end of turn). Spawns the shared sync script — no LLM call.
//
// Install: copy to <project>/.opencode/plugin/agent-memory.ts and copy
// hooks/shared/agent-memory-sync.sh → .opencode/hooks/agent-memory-sync.sh

import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";

const SYNC_SCRIPT = ".opencode/hooks/agent-memory-sync.sh";

function hasMemory(): boolean {
  return fs.existsSync(path.join(process.cwd(), ".agents", "memory"));
}

function runSync(event: string): void {
  if (!hasMemory()) return;
  const script = path.join(process.cwd(), SYNC_SCRIPT);
  if (!fs.existsSync(script)) return;
  try {
    execFileSync(
      "bash",
      [script],
      {
        env: { ...process.env, AGENT_MEMORY_EVENT: event, AGENT_MEMORY_PROJECT_DIR: process.cwd() },
        stdio: "ignore",
        timeout: 15_000,
      },
    );
  } catch {
    // Fail open — never block the session.
  }
}

export const agentMemoryPlugin = async () => {
  if (!hasMemory()) return {};

  return {
    "experimental.session.compacting": async () => {
      runSync("PreCompact");
    },
    event: async (input: { event: { type: string } }) => {
      if (input?.event?.type === "session.idle") {
        runSync("Stop");
      }
    },
  };
};

export default agentMemoryPlugin;
