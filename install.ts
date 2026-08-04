/**
 * npx CLI for @dosx/agent-memory — local skill copy + hooks installer.
 * Source: install.ts → bun build → bin/cli.js
 */

import fs from "node:fs";
import path from "node:path";
import {
  CANONICAL_HARNESSES,
  HARNESS_HOOKS_DIR,
  type Harness,
  type InstallReport,
  type SelectOption,
} from "./lib/cli/constants";
import {
  detectInstalledHarnesses,
  memoryExists,
  normalizeHarness,
  projectDir,
  readInstalledHooksVersion,
  readInstalledSkillVersion,
} from "./lib/cli/detect";
import { installSkillAtomic } from "./lib/cli/fs-install";
import { buildInstallerEnv, runCaptured } from "./lib/cli/hooks-run";
import { resolvePackageRoot } from "./lib/cli/package-root";
import { compareSemver } from "./lib/cli/semver";
import { c, isTTY, multiSelectPrompt, selectPrompt } from "./lib/cli/tty";

const ROOT = resolvePackageRoot();

const VERSION: string = JSON.parse(
  fs.readFileSync(path.join(ROOT, "package.json"), "utf8"),
).version;

const INSTALL_HOOKS_SH = path.join(ROOT, "hooks", "install-hooks.sh");
const SKILL_SOURCE = path.join(ROOT, "skills", "agent-memory");

/**
 * Install source is always `ROOT/skills/agent-memory` + `ROOT/hooks/` (never GitHub clone).
 *
 * - Local checkout (`node ./bin/cli.js` / `bun ./install.ts`): ROOT is this repo — rule 1.
 * - `npx @dosx/agent-memory` (published pack): ROOT is the npm package tree (`files` allowlist,
 *   no `install.ts`) — rule 2; same copy path, SemVer-gated update unless `--force`.
 *
 * `install.ts` presence distinguishes dogfood refresh (same SemVer) from registry packs.
 */
function isSourceCheckout(): boolean {
  return fs.existsSync(path.join(ROOT, "install.ts"));
}

/** How to re-invoke this CLI in printed hints (local bin vs npx). */
function cliInvocation(): string {
  if (isSourceCheckout()) {
    return `node ${path.join(ROOT, "bin", "cli.js")}`;
  }
  return "npx @dosx/agent-memory";
}

function fatal(message: string): never {
  console.error(`${c.red("error:")} ${message}`);
  process.exit(1);
}

function blank(): void {
  console.log("");
}

function printHeader(action: string): void {
  blank();
  console.log(
    `${c.boldMagenta("agent-memory")} ${c.dim(`v${VERSION}`)}  ${c.dim("·")}  ${c.cyan(action)}`,
  );
  console.log(c.dim(`project  ${path.resolve(projectDir())}`));
  console.log(
    c.dim(
      `source   ${ROOT}${isSourceCheckout() ? " (local checkout)" : ""}`,
    ),
  );
}

function printSection(title: string): void {
  blank();
  console.log(`${c.cyan("●")} ${c.bold(title)}`);
}

function printDetail(label: string, value: string): void {
  const pad = label.padEnd(10);
  console.log(`  ${c.dim(pad)} ${value}`);
}

function printStep(line: string): void {
  console.log(`  ${c.dim("·")} ${line}`);
}

function printOk(message: string): void {
  console.log(`  ${c.green("✓")} ${message}`);
}

function printSummary(report: InstallReport): void {
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
  printAgentNextSteps(memoryExists() ? "update" : "init");
}

/**
 * Remind the user that slash commands run in the agent chat — not in the shell.
 */
function printAgentNextSteps(primary: "init" | "update"): void {
  blank();
  console.log(c.bold("Next steps"));
  console.log(
    `  ${c.dim("In your coding agent chat")} ${c.dim("(Cursor, Claude Code, Codex, … — not this terminal):")}`,
  );
  if (primary === "update") {
    printStep(
      `${c.cyan("/agent-memory update")}  migrate .agents/memory/ via vendor/UPDATE.md`,
    );
  } else {
    printStep(
      `${c.cyan("/agent-memory init")}    create .agents/memory/ and wire the agent block`,
    );
  }
  printStep(`${c.dim("/agent-memory help")}    list skill subcommands`);
  blank();
}

function printHelp(): void {
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

function installSkill(): string {
  const result = installSkillAtomic({
    skillSource: SKILL_SOURCE,
    onError: fatal,
  });

  printSection("Skill");
  printDetail("name", c.bold("agent-memory"));
  printDetail("version", VERSION);
  printDetail("path", result.destRel);
  printDetail(
    "files",
    `${result.files} files ${c.dim(result.existed ? "(updated)" : "(new)")}`,
  );
  printOk(`skill ready at ${c.cyan(result.destRel)}`);
  return result.destRel;
}

function installHooks(harness: Harness): void {
  if (!fs.existsSync(INSTALL_HOOKS_SH)) {
    fatal(`missing installer at ${INSTALL_HOOKS_SH}`);
  }
  const bash = process.platform === "win32" ? "bash.exe" : "bash";
  printSection(`Hooks · ${harness}`);
  printDetail("target", HARNESS_HOOKS_DIR[harness]);

  const { stdout, stderr } = runCaptured(bash, [INSTALL_HOOKS_SH, harness], {
    env: buildInstallerEnv(VERSION),
    onSpawnError: fatal,
    onCommandFail: (errText, status) => {
      if (errText.trim()) {
        for (const line of errText.trim().split("\n")) {
          console.error(`  ${c.red("✗")} ${line}`);
        }
      }
      process.exit(status ?? 1);
    },
  });

  for (const line of stdout.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("done:")) continue;
    if (trimmed.startsWith("error:")) {
      console.error(`  ${c.red("✗")} ${trimmed}`);
      continue;
    }
    printStep(trimmed);
  }
  for (const line of stderr.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    console.error(`  ${c.red("✗")} ${trimmed}`);
  }

  printOk(`hooks ready for ${c.bold(harness)}`);
}

async function confirmPrompt(message: string): Promise<boolean> {
  const choice = await selectPrompt(message, [
    { label: "Yes, update", value: "yes" },
    { label: "Cancel", value: "no" },
  ] as const);
  return choice === "yes";
}

function printUpdateSummary(opts: {
  skillUpdated: boolean;
  skillFrom: string | null;
  skillTo: string;
  skillMissing: boolean;
  hooksRefreshed: Harness[];
  hooksSkipped: Harness[];
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
  printAgentNextSteps(memoryExists() ? "update" : "init");
}

async function cmdUpdate(flags: { yes: boolean; force: boolean }): Promise<void> {
  const installedSkill = readInstalledSkillVersion();
  const skillMissing = !installedSkill;
  // Source checkouts fold unreleased work into the current SemVer — refresh
  // content even when the version stamp matches. Published packs skip that.
  const refreshSameVersion = flags.force || isSourceCheckout();
  const cli = cliInvocation();

  printHeader("update");
  printSection("Versions");
  printDetail("package", VERSION);
  if (skillMissing) {
    printDetail("skill", c.dim("not installed"));
    printStep(
      c.yellow(`skill missing — hooks-only update; install with: ${cli} install skill`),
    );
  } else {
    printDetail(
      "skill",
      `${installedSkill} ${c.dim("installed")} · ${VERSION} ${c.dim("package")}`,
    );
  }
  printDetail("hooks", `${VERSION} ${c.dim("package")}`);
  if (refreshSameVersion) {
    printStep(
      c.dim(
        flags.force
          ? "force refresh enabled"
          : "local checkout — refreshing files even when SemVer matches",
      ),
    );
  }

  let needSkill = false;
  if (installedSkill) {
    const skillCmp = compareSemver(VERSION, installedSkill);
    if (skillCmp > 0) {
      needSkill = true;
      printStep(
        `skill upgrade available ${c.yellow(`${installedSkill} → ${VERSION}`)}`,
      );
    } else if (skillCmp < 0) {
      console.log(
        `  ${c.yellow("!")} installed skill (${installedSkill}) is newer than package (${VERSION}); will not downgrade`,
      );
    } else if (refreshSameVersion) {
      needSkill = true;
      printStep(`skill refresh ${VERSION} ${c.dim("(same version → package tree)")}`);
    } else {
      printStep(`skill already at ${VERSION}`);
    }
  }

  const installedHarnesses = detectInstalledHarnesses();
  const hooksToRefresh: Harness[] = [];
  const hooksSkipped: Harness[] = [];

  if (installedHarnesses.length === 0) {
    printStep(c.dim("no hooks detected"));
  } else {
    for (const h of installedHarnesses) {
      const stamp = readInstalledHooksVersion(h);
      if (!stamp || compareSemver(VERSION, stamp) > 0) {
        hooksToRefresh.push(h);
        printStep(`hooks ${h}: ${c.yellow(`${stamp ?? "none"} → ${VERSION}`)}`);
      } else if (refreshSameVersion) {
        hooksToRefresh.push(h);
        printStep(`hooks ${h}: refresh ${stamp} ${c.dim("(same version → package tree)")}`);
      } else {
        hooksSkipped.push(h);
        printStep(`hooks ${h}: ${stamp} ${c.dim("(current)")}`);
      }
    }
  }

  if (
    skillMissing &&
    hooksToRefresh.length === 0 &&
    installedHarnesses.length === 0
  ) {
    console.error(
      `${c.red("error:")} nothing to update — install the skill and/or hooks first`,
    );
    console.error(`  ${c.dim(`${cli} install skill`)}`);
    console.error(`  ${c.dim(`${cli} install hooks <harness>`)}`);
    process.exit(1);
  }

  if (!needSkill && hooksToRefresh.length === 0) {
    blank();
    console.log(
      `${c.boldGreen("✓")} ${c.bold("Already up to date")} ${c.dim(VERSION)}`,
    );
    if (skillMissing) {
      printStep(c.dim(`optional: ${cli} install skill`));
    }
    printAgentNextSteps(memoryExists() ? "update" : "init");
    return;
  }

  if (!flags.yes) {
    if (!isTTY()) {
      failNonTTY("interactive update requires a TTY (or pass --yes).", [
        `${cli} update --yes`,
      ]);
    }
    const planParts: string[] = [];
    if (needSkill) {
      planParts.push(
        installedSkill === VERSION
          ? `skill refresh ${VERSION}`
          : `skill ${installedSkill} → ${VERSION}`,
      );
    }
    if (hooksToRefresh.length > 0) {
      planParts.push(`hooks ${hooksToRefresh.join(", ")} → ${VERSION}`);
    }
    blank();
    const ok = await confirmPrompt(`Apply update? (${planParts.join("; ")})`);
    if (!ok) {
      console.log(c.dim("Cancelled."));
      process.exit(0);
    }
  }

  let skillUpdated = false;
  if (needSkill) {
    installSkill();
    skillUpdated = true;
  }

  for (const h of hooksToRefresh) {
    installHooks(h);
  }

  printUpdateSummary({
    skillUpdated,
    skillFrom: installedSkill,
    skillTo: VERSION,
    skillMissing,
    hooksRefreshed: hooksToRefresh,
    hooksSkipped,
  });
}

function parseUpdateFlags(args: string[]): { yes: boolean; force: boolean } {
  let yes = false;
  let force = false;
  for (const a of args) {
    if (a === "--yes" || a === "-y") {
      yes = true;
      continue;
    }
    if (a === "--force" || a === "-f") {
      force = true;
      continue;
    }
    console.error(`${c.red("error:")} unexpected argument: ${a}`);
    printHelp();
    process.exit(1);
  }
  return { yes, force };
}

function harnessOptions(): SelectOption<Harness>[] {
  return CANONICAL_HARNESSES.map((h) => ({ label: h, value: h }));
}

type InstallMode = "both" | "skill" | "hooks";

const INSTALL_MODE_OPTIONS: SelectOption<InstallMode>[] = [
  { label: "Skill + hooks", value: "both" },
  { label: "Skill only", value: "skill" },
  { label: "Hooks only", value: "hooks" },
];

function pickHarnesses(): Promise<Harness[]> {
  return multiSelectPrompt(
    "Select harnesses (Space to toggle):",
    harnessOptions(),
  );
}

function failNonTTY(message: string, hints: string[]): never {
  console.error(`${c.red("error:")} ${message}`);
  for (const h of hints) {
    console.error(`  ${c.dim(h)}`);
  }
  process.exit(1);
}

function fatalUsage(message: string): never {
  console.error(`${c.red("error:")} ${message}`);
  printHelp();
  process.exit(1);
}

async function promptInstallChoice(harness: Harness): Promise<void> {
  if (!isTTY()) {
    const cli = cliInvocation();
    failNonTTY("interactive install requires a TTY.", [
      `Hooks: ${cli} install hooks ${harness}`,
      `Skill: ${cli} install skill`,
    ]);
  }

  const choice = await selectPrompt(
    `Install agent-memory for ${harness}:`,
    INSTALL_MODE_OPTIONS,
  );

  printHeader(`install · ${harness}`);
  if (choice === "both") {
    const skillPath = installSkill();
    installHooks(harness);
    printSummary({ skillPath, hooks: [harness] });
    return;
  }
  if (choice === "skill") {
    printSummary({ skillPath: installSkill(), hooks: [] });
    return;
  }
  installHooks(harness);
  printSummary({ hooks: [harness] });
}

async function promptInstallBare(): Promise<void> {
  if (!isTTY()) {
    const cli = cliInvocation();
    failNonTTY("interactive install requires a TTY.", [
      `Skill: ${cli} install skill`,
      `Hooks: ${cli} install hooks <harness>`,
    ]);
  }

  const mode = await selectPrompt(
    "What do you want to install?",
    INSTALL_MODE_OPTIONS,
  );

  if (mode === "skill") {
    printHeader("install · skill");
    printSummary({ skillPath: installSkill(), hooks: [] });
    return;
  }

  const selected = await pickHarnesses();

  printHeader(
    mode === "both"
      ? `install · skill + ${selected.join(", ")}`
      : `install · hooks · ${selected.join(", ")}`,
  );
  const report: InstallReport = { hooks: selected };
  if (mode === "both") {
    report.skillPath = installSkill();
  }
  for (const h of selected) {
    installHooks(h);
  }
  printSummary(report);
}

async function promptHooksMultiSelect(): Promise<void> {
  if (!isTTY()) {
    failNonTTY("interactive install hooks requires a TTY.", [
      `Hooks: ${cliInvocation()} install hooks <harness>`,
    ]);
  }
  const selected = await pickHarnesses();
  printHeader(`install · hooks · ${selected.join(", ")}`);
  for (const h of selected) {
    installHooks(h);
  }
  printSummary({ hooks: selected });
}

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
    await cmdUpdate(parseUpdateFlags(args.slice(1)));
    return;
  }

  if (args[0] !== "install") {
    fatalUsage(`unknown command: ${args[0]}`);
  }

  const rest = args.slice(1);
  if (rest.length === 0) {
    await promptInstallBare();
    return;
  }

  if (rest[0] === "skill") {
    if (rest.length > 1) {
      console.error(
        `${c.red("error:")} install skill does not accept arguments`,
      );
      process.exit(1);
    }
    printHeader("install · skill");
    printSummary({ skillPath: installSkill(), hooks: [] });
    return;
  }

  if (rest[0] === "hooks") {
    if (rest.length === 1) {
      await promptHooksMultiSelect();
      return;
    }
    const raw = rest[1];
    if (rest.length > 2) {
      console.error(`${c.red("error:")} unexpected argument: ${rest[2]}`);
      process.exit(1);
    }
    const harness = normalizeHarness(raw);
    if (!harness) {
      fatalUsage(`unknown harness: ${raw}`);
    }
    printHeader(`install · hooks · ${harness}`);
    installHooks(harness);
    printSummary({ hooks: [harness] });
    return;
  }

  const harness = normalizeHarness(rest[0]);
  if (harness) {
    if (rest.length > 1) {
      console.error(`${c.red("error:")} unexpected argument: ${rest[1]}`);
      process.exit(1);
    }
    await promptInstallChoice(harness);
    return;
  }

  fatalUsage(`unknown install target: ${rest[0]}`);
}

main(process.argv).catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
