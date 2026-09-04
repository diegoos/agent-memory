/** `agent-memory install` — TTY menus and headless skill/hooks targets. */
import { installHooks, installSkill } from "./actions";
import {
  CANONICAL_HARNESSES,
  type Harness,
  type InstallReport,
} from "./constants";
import { cliInvocation } from "./context";
import { nextSkillCommand, normalizeHarness } from "./detect";
import { isTTY, multiSelectPrompt, selectPrompt, type SelectOption } from "./tty";
import { fatal, fatalUsage, printHeader, printSummary } from "./ui";

type InstallMode = "both" | "skill" | "hooks";

const INSTALL_MODE_OPTIONS: SelectOption<InstallMode>[] = [
  { label: "Skill + hooks", value: "both" },
  { label: "Skill only", value: "skill" },
  { label: "Hooks only", value: "hooks" },
];

function harnessOptions(): SelectOption<Harness>[] {
  return CANONICAL_HARNESSES.map((h) => ({ label: h, value: h }));
}

function pickHarnesses(): Promise<Harness[]> {
  return multiSelectPrompt(
    "Select harnesses (Space to toggle):",
    harnessOptions(),
  );
}

function requireTty(message: string, hints: string[]): void {
  if (!isTTY()) fatal(message, hints);
}

function applyInstall(header: string, skill: boolean, hooks: Harness[]): void {
  printHeader(header);
  const report: InstallReport = { hooks };
  if (skill) report.skillPath = installSkill();
  for (const h of hooks) {
    installHooks(h);
  }
  printSummary(report, nextSkillCommand());
}

async function promptInstallChoice(harness: Harness): Promise<void> {
  const cli = cliInvocation();
  requireTty("interactive install requires a TTY.", [
    `Hooks: ${cli} install hooks ${harness}`,
    `Skill: ${cli} install skill`,
  ]);

  const choice = await selectPrompt(
    `Install agent-memory for ${harness}:`,
    INSTALL_MODE_OPTIONS,
  );

  const header = `install · ${harness}`;
  if (choice === "both") {
    applyInstall(header, true, [harness]);
    return;
  }
  if (choice === "skill") {
    applyInstall(header, true, []);
    return;
  }
  applyInstall(header, false, [harness]);
}

async function promptInstallBare(): Promise<void> {
  const cli = cliInvocation();
  requireTty("interactive install requires a TTY.", [
    `Skill: ${cli} install skill`,
    `Hooks: ${cli} install hooks <harness>`,
  ]);

  const mode = await selectPrompt(
    "What do you want to install?",
    INSTALL_MODE_OPTIONS,
  );

  if (mode === "skill") {
    applyInstall("install · skill", true, []);
    return;
  }

  const selected = await pickHarnesses();
  const header =
    mode === "both"
      ? `install · skill + ${selected.join(", ")}`
      : `install · hooks · ${selected.join(", ")}`;
  applyInstall(header, mode === "both", selected);
}

async function promptHooksMultiSelect(): Promise<void> {
  requireTty("interactive install hooks requires a TTY.", [
    `Hooks: ${cliInvocation()} install hooks <harness>`,
  ]);
  const selected = await pickHarnesses();
  applyInstall(`install · hooks · ${selected.join(", ")}`, false, selected);
}

export async function cmdInstall(rest: string[]): Promise<void> {
  if (rest.length === 0) {
    await promptInstallBare();
    return;
  }

  if (rest[0] === "skill") {
    if (rest.length > 1) {
      fatal("install skill does not accept arguments");
    }
    applyInstall("install · skill", true, []);
    return;
  }

  if (rest[0] === "hooks") {
    if (rest.length === 1) {
      await promptHooksMultiSelect();
      return;
    }
    const raw = rest[1];
    if (rest.length > 2) {
      fatal(`unexpected argument: ${rest[2]}`);
    }
    const harness = normalizeHarness(raw);
    if (!harness) {
      fatalUsage(`unknown harness: ${raw}`);
    }
    applyInstall(`install · hooks · ${harness}`, false, [harness]);
    return;
  }

  const harness = normalizeHarness(rest[0]);
  if (harness) {
    if (rest.length > 1) {
      fatal(`unexpected argument: ${rest[1]}`);
    }
    await promptInstallChoice(harness);
    return;
  }

  fatalUsage(`unknown install target: ${rest[0]}`);
}
