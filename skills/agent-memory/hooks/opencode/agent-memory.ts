// OpenCode plugin: remind the agent to flush agent-memory at compaction and
// when the session goes idle (≈ stop). Non-blocking — it only logs a reminder
// to stderr; it never writes to the memory and never mutates the compaction
// output, so it cannot cause memory inconsistency or loops. The agent decides
// whether to run `/agent-memory sync`.
//
// Install (see ../README.md): copy to <project>/.opencode/plugin/agent-memory.ts
// (or ~/.config/opencode/plugin/). Requires OpenCode's plugin loader.
//
// References:
//   - experimental.session.compacting: fires before the compaction summary.
//   - session.idle: fires when the session completes (≈ agent stop).

import * as fs from "node:fs";
import * as path from "node:path";

const PRE_MSG =
  "Context is about to be compacted. Before compaction, flush agent-memory so the next agent continues from the files, not chat history: run `/agent-memory sync` (or manually update `.agents/memory/active-work/<branch>.md` and append to `.agents/memory/log.md`).";
const STOP_MSG =
  "Before ending, flush agent-memory: run `/agent-memory sync` (or update `.agents/memory/active-work/<branch>.md`, `.agents/memory/log.md`, and `.agents/memory/current.md` per `.agents/memory/instructions.md`). If the branch just merged, delete its `.agents/memory/active-work/<branch>.md`.";

function hasMemory(): boolean {
  return fs.existsSync(path.join(process.cwd(), ".agents", "memory"));
}

export const agentMemoryPlugin = async () => {
  if (!hasMemory()) return {};

  return {
    "experimental.session.compacting": async () => {
      console.error(PRE_MSG);
    },
    event: async (input: { event: { type: string } }) => {
      if (input?.event?.type === "session.idle") {
        console.error(STOP_MSG);
      }
    },
  };
};

export default agentMemoryPlugin;
