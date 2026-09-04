/**
 * Package tree, version stamp, and how this CLI was invoked.
 * Source checkouts (`src/cli.ts` on disk) refresh same-SemVer; npm packs do not.
 */
import fs from "node:fs";
import path from "node:path";
import { resolvePackageRoot } from "./package-root";

export const ROOT = resolvePackageRoot();

export const VERSION = readPackageVersion(ROOT);

export const INSTALL_HOOKS_SH = path.join(ROOT, "hooks", "install-hooks.sh");
export const SKILL_SOURCE = path.join(ROOT, "skills", "agent-memory");

const SOURCE_CHECKOUT = fs.existsSync(path.join(ROOT, "src", "cli.ts"));

function readPackageVersion(root: string): string {
  let data: unknown;
  try {
    data = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  } catch {
    console.error("error: cannot read package.json version");
    process.exit(1);
  }
  const version =
    data && typeof data === "object" && "version" in data
      ? (data as { version: unknown }).version
      : undefined;
  if (
    typeof version !== "string" ||
    version.length === 0 ||
    /[\0\r\n]/.test(version)
  ) {
    console.error("error: invalid package.json version");
    process.exit(1);
  }
  return version;
}

/**
 * Install source is always `ROOT/skills/agent-memory` + `ROOT/hooks/` (never GitHub clone).
 *
 * - Local checkout (`node ./bin/cli.js` / `bun ./src/cli.ts`): ROOT is this repo — rule 1.
 * - `npx @dosx/agent-memory` (published pack): ROOT is the npm package tree (`files` allowlist,
 *   no `src/`): rule 2; same copy path, SemVer-gated update unless `--force`.
 *
 * `src/cli.ts` presence distinguishes dogfood refresh (same SemVer) from registry packs.
 */
export function isSourceCheckout(): boolean {
  return SOURCE_CHECKOUT;
}

/** How to re-invoke this CLI in printed hints (local bin vs npx). */
export function cliInvocation(): string {
  if (isSourceCheckout()) {
    return `node ${path.join(ROOT, "bin", "cli.js")}`;
  }
  return "npx @dosx/agent-memory";
}
