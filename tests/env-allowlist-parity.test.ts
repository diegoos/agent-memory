import { describe, expect, test } from "bun:test";
import { ENV_ALLOWLIST_EXACT } from "../lib/cli/constants";

/** Keys listed in hooks/opencode/agent-memory.ts ENV_ALLOWLIST_EXACT (keep in sync). */
async function opencodeAllowlistKeys(): Promise<string[]> {
  const src = await Bun.file("hooks/opencode/agent-memory.ts").text();
  const block = src.match(
    /const ENV_ALLOWLIST_EXACT = new Set\(\[([\s\S]*?)\]\)/,
  );
  if (!block) throw new Error("ENV_ALLOWLIST_EXACT not found in OpenCode plugin");
  return [...block[1].matchAll(/'([^']+)'/g)].map((m) => m[1]).sort();
}

describe("ENV_ALLOWLIST_EXACT parity", () => {
  test("CLI constants match OpenCode plugin allowlist", async () => {
    const cli = [...ENV_ALLOWLIST_EXACT].sort();
    const opencode = await opencodeAllowlistKeys();
    expect(opencode).toEqual(cli);
  });
});
