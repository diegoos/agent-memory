/** `agent-memory update` — SemVer gate, same-version refresh, apply skill/hooks. */
import { installHooks, installSkill } from "./actions";
import { type Harness } from "./constants";
import { cliInvocation, isSourceCheckout, VERSION } from "./context";
import {
  detectInstalledHarnesses,
  nextSkillCommand,
  readInstalledHooksVersion,
  readInstalledSkillVersion,
} from "./detect";
import { compareSemver } from "./semver";
import { c, isTTY, selectPrompt } from "./tty";
import {
  blank,
  fatal,
  fatalUsage,
  printAgentNextSteps,
  printDetail,
  printHeader,
  printSection,
  printStep,
  printUpdateSummary,
} from "./ui";

type SkillPlan =
  | { kind: "missing" }
  | { kind: "upgrade"; from: string }
  | { kind: "downgrade"; from: string }
  | { kind: "refresh" }
  | { kind: "current" };

type HookPlan = {
  harness: Harness;
  kind: "upgrade" | "refresh" | "skip";
  stamp: string | null;
};

function planSkill(
  installed: string | null,
  pkg: string,
  refreshSame: boolean,
): SkillPlan {
  if (!installed) return { kind: "missing" };
  const cmp = compareSemver(pkg, installed);
  if (cmp > 0) return { kind: "upgrade", from: installed };
  if (cmp < 0) return { kind: "downgrade", from: installed };
  if (refreshSame) return { kind: "refresh" };
  return { kind: "current" };
}

function planHooks(
  harnesses: Harness[],
  pkg: string,
  refreshSame: boolean,
): HookPlan[] {
  const plans: HookPlan[] = [];
  for (const h of harnesses) {
    const stamp = readInstalledHooksVersion(h);
    if (!stamp || compareSemver(pkg, stamp) > 0) {
      plans.push({ harness: h, kind: "upgrade", stamp });
      continue;
    }
    if (refreshSame) {
      plans.push({ harness: h, kind: "refresh", stamp });
      continue;
    }
    plans.push({ harness: h, kind: "skip", stamp });
  }
  return plans;
}

function skillNeedsInstall(plan: SkillPlan): boolean {
  return plan.kind === "upgrade" || plan.kind === "refresh";
}

async function confirmPrompt(message: string): Promise<boolean> {
  const choice = await selectPrompt(message, [
    { label: "Yes, update", value: "yes" },
    { label: "Cancel", value: "no" },
  ] as const);
  return choice === "yes";
}

function printSkillPlan(plan: SkillPlan): void {
  if (plan.kind === "upgrade") {
    printStep(
      `skill upgrade available ${c.yellow(`${plan.from} → ${VERSION}`)}`,
    );
    return;
  }
  if (plan.kind === "downgrade") {
    console.log(
      `  ${c.yellow("!")} installed skill (${plan.from}) is newer than package (${VERSION}); will not downgrade`,
    );
    return;
  }
  if (plan.kind === "refresh") {
    printStep(
      `skill refresh ${VERSION} ${c.dim("(same version → package tree)")}`,
    );
    return;
  }
  if (plan.kind === "current") {
    printStep(`skill already at ${VERSION}`);
  }
}

function printHookPlans(plans: HookPlan[], noneInstalled: boolean): void {
  if (noneInstalled) {
    printStep(c.dim("no hooks detected"));
    return;
  }
  for (const p of plans) {
    if (p.kind === "skip") {
      printStep(`hooks ${p.harness}: ${p.stamp} ${c.dim("(current)")}`);
      continue;
    }
    if (p.kind === "refresh") {
      printStep(
        `hooks ${p.harness}: refresh ${p.stamp} ${c.dim("(same version → package tree)")}`,
      );
      continue;
    }
    printStep(
      `hooks ${p.harness}: ${c.yellow(`${p.stamp ?? "none"} → ${VERSION}`)}`,
    );
  }
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
    fatalUsage(`unexpected argument: ${a}`);
  }
  return { yes, force };
}

function printUpdateVersions(opts: {
  installedSkill: string | null;
  skillMissing: boolean;
  refreshSameVersion: boolean;
  force: boolean;
  cli: string;
}): void {
  printHeader("update");
  printSection("Versions");
  printDetail("package", VERSION);
  if (opts.skillMissing) {
    printDetail("skill", c.dim("not installed"));
    printStep(
      c.yellow(
        `skill missing — hooks-only update; install with: ${opts.cli} install skill`,
      ),
    );
  } else {
    printDetail(
      "skill",
      `${opts.installedSkill} ${c.dim("installed")} · ${VERSION} ${c.dim("package")}`,
    );
  }
  printDetail("hooks", `${VERSION} ${c.dim("package")}`);
  if (!opts.refreshSameVersion) return;
  printStep(
    c.dim(
      opts.force
        ? "force refresh enabled"
        : "local checkout — refreshing files even when SemVer matches",
    ),
  );
}

function failIfNothingInstalled(
  skillMissing: boolean,
  hooksToRefresh: Harness[],
  installedHarnesses: Harness[],
  cli: string,
): void {
  if (!skillMissing || hooksToRefresh.length > 0 || installedHarnesses.length > 0) {
    return;
  }
  fatal("nothing to update — install the skill and/or hooks first", [
    `${cli} install skill`,
    `${cli} install hooks <harness>`,
  ]);
}

function printAlreadyCurrent(skillMissing: boolean, cli: string): void {
  blank();
  console.log(
    `${c.boldGreen("✓")} ${c.bold("Already up to date")} ${c.dim(VERSION)}`,
  );
  if (skillMissing) {
    printStep(c.dim(`optional: ${cli} install skill`));
  }
  printAgentNextSteps(nextSkillCommand());
}

async function confirmApply(opts: {
  yes: boolean;
  needSkill: boolean;
  installedSkill: string | null;
  hooksToRefresh: Harness[];
  cli: string;
}): Promise<void> {
  if (opts.yes) return;
  if (!isTTY()) {
    fatal("interactive update requires a TTY (or pass --yes).", [
      `${opts.cli} update --yes`,
    ]);
  }
  const planParts: string[] = [];
  if (opts.needSkill) {
    planParts.push(
      opts.installedSkill === VERSION
        ? `skill refresh ${VERSION}`
        : `skill ${opts.installedSkill} → ${VERSION}`,
    );
  }
  if (opts.hooksToRefresh.length > 0) {
    planParts.push(`hooks ${opts.hooksToRefresh.join(", ")} → ${VERSION}`);
  }
  blank();
  const ok = await confirmPrompt(`Apply update? (${planParts.join("; ")})`);
  if (ok) return;
  console.log(c.dim("Cancelled."));
  process.exit(0);
}

export async function cmdUpdate(args: string[]): Promise<void> {
  const flags = parseUpdateFlags(args);
  const installedSkill = readInstalledSkillVersion();
  const skillMissing = !installedSkill;
  // Source checkouts fold unreleased work into the current SemVer — refresh
  // content even when the version stamp matches. Published packs skip that.
  const refreshSameVersion = flags.force || isSourceCheckout();
  const cli = cliInvocation();
  const skillPlan = planSkill(installedSkill, VERSION, refreshSameVersion);
  const installedHarnesses = detectInstalledHarnesses();
  const hookPlans = planHooks(installedHarnesses, VERSION, refreshSameVersion);
  const hooksToRefresh: Harness[] = [];
  const hooksSkipped: Harness[] = [];
  for (const p of hookPlans) {
    if (p.kind === "skip") hooksSkipped.push(p.harness);
    else hooksToRefresh.push(p.harness);
  }
  const needSkill = skillNeedsInstall(skillPlan);

  printUpdateVersions({
    installedSkill,
    skillMissing,
    refreshSameVersion,
    force: flags.force,
    cli,
  });
  printSkillPlan(skillPlan);
  printHookPlans(hookPlans, installedHarnesses.length === 0);
  failIfNothingInstalled(
    skillMissing,
    hooksToRefresh,
    installedHarnesses,
    cli,
  );

  if (!needSkill && hooksToRefresh.length === 0) {
    printAlreadyCurrent(skillMissing, cli);
    return;
  }

  await confirmApply({
    yes: flags.yes,
    needSkill,
    installedSkill,
    hooksToRefresh,
    cli,
  });

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
    nextStep: nextSkillCommand(),
  });
}
