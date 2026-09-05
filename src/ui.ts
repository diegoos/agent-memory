/** CLI stdout/stderr: headers, help, summaries, fatal exits. */
import path from "node:path";
import {
  CANONICAL_HARNESSES,
  HARNESS_HOOKS_DIR,
  type Harness,
  type InstallReport,
} from "./constants";
import { cliInvocation, isSourceCheckout, ROOT, VERSION } from "./context";
import { projectDir } from "./detect";
import { c } from "./tty";

export function fatal(message: string, hints: string[] = []): never {
  console.error(`${c.red("error:")} ${message}`);
  for (const h of hints) {
    console.error(`  ${c.dim(h)}`);
  }
  process.exit(1);
}

export function blank(): void {
  console.log("");
}

export function printHeader(action: string): void {
  blank();
  console.log(
    `${c.boldMagenta("agent-memory")} ${c.dim(`v${VERSION}`)}  ${c.dim("·")}  ${c.cyan(action)}`,
  );
  console.log(c.dim(`project  ${path.resolve(projectDir())}`));
  console.log(
    c.dim(`source   ${ROOT}${isSourceCheckout() ? " (local checkout)" : ""}`),
  );
}

export function printSection(title: string): void {
  blank();
  console.log(`${c.cyan("●")} ${c.bold(title)}`);
}

export function printDetail(label: string, value: string): void {
  const pad = label.padEnd(10);
  console.log(`  ${c.dim(pad)} ${value}`);
}

export function printStep(line: string): void {
  console.log(`  ${c.dim("·")} ${line}`);
}

export function printOk(message: string): void {
  console.log(`  ${c.green("✓")} ${message}`);
}

export function printSummary(
  report: InstallReport,
  nextStep: "init" | "update",
): void {
  blank();
  console.log(
    `${c.boldGreen("✓")} ${c.bold("Install complete")} ${c.dim(`v${VERSION}`)}`,
  );
  if (report.skillPath) {
    printDetail("skill", report.skillPath);
  }
  if (report.hooks.length > 0) {
    printDetail(
      "hooks",
      report.hooks
        .map((h) => `${h} ${c.dim(`(${HARNESS_HOOKS_DIR[h]})`)}`)
        .join(", "),
    );
  }
  printAgentNextSteps(nextStep);
}

/**
 * Remind the user that slash commands run in the agent chat — not in the shell.
 */
export function printAgentNextSteps(primary: "init" | "update"): void {
  blank();
  console.log(c.bold("Next steps"));
  console.log(
    `  ${c.dim("In your coding agent chat")} ${c.dim("(Cursor, Claude Code, Codex, … — not this terminal):")}`,
  );
  if (primary === "update") {
    printStep(c.cyan("/agent-memory update"));
    console.log(
      `    ${c.dim("Type that command only. The skill migrates .agents/memory/ (reads vendor/UPDATE.md). This CLI already refreshed the skill and does not migrate memory.")}`,
    );
  } else {
    printStep(c.cyan("/agent-memory init"));
    console.log(
      `    ${c.dim("Type that command only. The skill scaffolds .agents/memory/ and wires the agent block.")}`,
    );
  }
  printStep(
    `${c.cyan("/agent-memory help")}  ${c.dim("optional — list skill subcommands")}`,
  );
  blank();
}

export function printHelp(): void {
  const harnessList = CANONICAL_HARNESSES.join(", ");
  const local = cliInvocation();
  console.log(`${c.boldMagenta("agent-memory")} ${c.dim(VERSION)}

${c.cyan("Installer")} for @dosx/agent-memory — copies the skill into the
project and installs harness lifecycle hooks from this package tree
(never clones GitHub).

${c.bold("Usage")}
  ${c.cyan("agent-memory install")}                    ${c.dim("# TTY: pick harnesses + skill/hooks")}
  ${c.cyan("agent-memory install skill")}              ${c.dim("# copy skill → .agents/skills/")}
  ${c.cyan("agent-memory install hooks")}              ${c.dim("# TTY: multi-select harnesses")}
  ${c.cyan("agent-memory install hooks <harness>")}    ${c.dim("# headless: one harness")}
  ${c.cyan("agent-memory install <harness>")}          ${c.dim("# TTY menu for that harness")}
  ${c.cyan("agent-memory update")}                     ${c.dim("# refresh skill + installed hooks")}
  ${c.cyan("agent-memory update --yes")}               ${c.dim("# non-interactive update")}
  ${c.cyan("agent-memory update --force --yes")}       ${c.dim("# reinstall even when SemVer matches")}
  ${c.cyan("agent-memory help")}

${c.bold("Harnesses")}  ${harnessList}
  ${c.dim("aliases: claude-code → claude, github → copilot")}

${c.bold("Examples")}
  ${c.dim("npx @dosx/agent-memory install")}
  ${c.dim("npx @dosx/agent-memory install skill")}
  ${c.dim("npx @dosx/agent-memory install hooks cursor")}
  ${c.dim("npx @dosx/agent-memory update")}
  ${c.dim("npx @dosx/agent-memory update --yes")}

${c.bold("Local checkout")} ${c.dim("(dogfood unreleased — same SemVer, new files)")}
  ${c.dim(`${local} install skill`)}
  ${c.dim(`${local} install hooks cursor`)}
  ${c.dim(`${local} update --yes`)} ${c.dim("# auto-refreshes from this tree")}
  ${c.dim(`${local} update --force --yes`)} ${c.dim("# force refresh from any package")}
`);
}

export function fatalUsage(message: string): never {
  console.error(`${c.red("error:")} ${message}`);
  printHelp();
  process.exit(1);
}

export function printUpdateSummary(opts: {
  skillUpdated: boolean;
  skillFrom: string | null;
  skillTo: string;
  skillMissing: boolean;
  hooksRefreshed: Harness[];
  hooksSkipped: Harness[];
  nextStep: "init" | "update";
}): void {
  blank();
  console.log(
    `${c.boldGreen("✓")} ${c.bold("Update complete")} ${c.dim(`cli ${VERSION}`)}`,
  );
  if (opts.skillMissing) {
    printDetail("skill", c.dim("not installed (skipped)"));
  } else if (opts.skillUpdated) {
    printDetail(
      "skill",
      `${opts.skillFrom ?? "?"} → ${opts.skillTo} ${c.dim("(.agents/skills/agent-memory)")}`,
    );
  } else {
    printDetail("skill", `${opts.skillTo} ${c.dim("(already current)")}`);
  }
  if (opts.hooksRefreshed.length > 0) {
    printDetail(
      "hooks",
      opts.hooksRefreshed
        .map((h) => `${h} ${c.dim(`→ ${VERSION}`)}`)
        .join(", "),
    );
  }
  if (opts.hooksSkipped.length > 0) {
    printDetail(
      "skipped",
      opts.hooksSkipped.map((h) => `${h} ${c.dim("(current)")}`).join(", "),
    );
  }
  printAgentNextSteps(opts.nextStep);
}
