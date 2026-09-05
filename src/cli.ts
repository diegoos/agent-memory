/**
 * npx CLI for @dosx/agent-memory — local skill copy + hooks installer.
 * Source: src/cli.ts → bun build → bin/cli.js
 */
import { cmdInstall } from "./cmd-install";
import { cmdUpdate } from "./cmd-update";
import { fatalUsage, printHelp } from "./ui";

async function main(argv: string[]): Promise<void> {
  const args = argv.slice(2);
  if (
    args.length === 0 ||
    args[0] === "help" ||
    args[0] === "--help" ||
    args[0] === "-h"
  ) {
    printHelp();
    return;
  }

  if (args[0] === "update") {
    await cmdUpdate(args.slice(1));
    return;
  }

  if (args[0] !== "install") {
    fatalUsage(`unknown command: ${args[0]}`);
  }

  await cmdInstall(args.slice(1));
}

main(process.argv).catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
