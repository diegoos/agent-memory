/** Copy the skill tree and run the hooks installer for one harness. */
import fs from "node:fs";
import { HARNESS_HOOKS_DIR, type Harness } from "./constants";
import { INSTALL_HOOKS_SH, ROOT, SKILL_SOURCE, VERSION } from "./context";
import { installSkillAtomic, resolvedUnder } from "./fs-install";
import { buildInstallerEnv, runCaptured } from "./hooks-run";
import { c } from "./tty";
import { fatal, printDetail, printOk, printSection, printStep } from "./ui";

let cachedSkillSource: string | undefined;
let cachedInstaller: string | undefined;

function packageSkillSource(): string {
  if (!cachedSkillSource) {
    cachedSkillSource = resolvedUnder(
      SKILL_SOURCE,
      ROOT,
      fatal,
      (real) => `skill source escapes package: ${real}`,
    );
  }
  return cachedSkillSource;
}

function packageInstaller(): string {
  if (!cachedInstaller) {
    cachedInstaller = resolvedUnder(
      INSTALL_HOOKS_SH,
      ROOT,
      fatal,
      (real) => `installer escapes package: ${real}`,
    );
  }
  return cachedInstaller;
}

function printInstallerOutput(stdout: string, stderr: string): void {
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
}

export function installSkill(): string {
  const result = installSkillAtomic({
    skillSource: packageSkillSource(),
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

export function installHooks(harness: Harness): void {
  if (!fs.existsSync(INSTALL_HOOKS_SH)) {
    fatal(`missing installer at ${INSTALL_HOOKS_SH}`);
  }
  const bash = process.platform === "win32" ? "bash.exe" : "bash";
  printSection(`Hooks · ${harness}`);
  printDetail("target", HARNESS_HOOKS_DIR[harness]);

  const { stdout, stderr } = runCaptured(bash, [packageInstaller(), harness], {
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

  printInstallerOutput(stdout, stderr);
  printOk(`hooks ready for ${c.bold(harness)}`);
}
