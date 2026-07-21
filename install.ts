/**
 * npx CLI for @dosx/agent-memory — local skill copy + hooks installer.
 * Source: install.ts → bun build → bin/cli.js
 */

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

/**
 * Resolve package root at runtime. Do not use __dirname — Bun `--format cjs`
 * may bake it to the build-time source directory (breaks npx installs).
 */
function resolvePackageRoot(): string {
  const entry = process.argv[1];
  if (entry) {
    let scriptPath = path.resolve(entry);
    try {
      scriptPath = fs.realpathSync(scriptPath);
    } catch {
      /* keep resolve() path */
    }
    const dir = path.dirname(scriptPath);
    if (path.basename(dir) === "bin") {
      return path.resolve(dir, "..");
    }
    let cur = dir;
    for (;;) {
      const pkgPath = path.join(cur, "package.json");
      if (fs.existsSync(pkgPath)) {
        try {
          const name = JSON.parse(fs.readFileSync(pkgPath, "utf8")).name as
            | string
            | undefined;
          if (name === "@dosx/agent-memory") return cur;
        } catch {
          /* continue walking */
        }
      }
      const parent = path.dirname(cur);
      if (parent === cur) break;
      cur = parent;
    }
  }
  console.error(
    "error: unable to resolve @dosx/agent-memory package root from process.argv[1]",
  );
  process.exit(1);
}

const ROOT = resolvePackageRoot();

const VERSION: string = JSON.parse(
  fs.readFileSync(path.join(ROOT, "package.json"), "utf8"),
).version;

const INSTALL_HOOKS_SH = path.join(ROOT, "hooks", "install-hooks.sh");
const SKILL_SOURCE = path.join(ROOT, "skills", "agent-memory");

const CANONICAL_HARNESSES = [
  "cursor",
  "claude",
  "codex",
  "opencode",
  "copilot",
  "gemini",
] as const;

type Harness = (typeof CANONICAL_HARNESSES)[number];

const HARNESS_ALIASES: Record<string, Harness> = {
  "claude-code": "claude",
  github: "copilot",
};

const HARNESS_SET = new Set<string>(CANONICAL_HARNESSES);

/**
 * Env keys forwarded to install-hooks.sh (keep in sync with OpenCode
 * ENV_ALLOWLIST_EXACT + prefixes in hooks/opencode/agent-memory.ts).
 */
const ENV_ALLOWLIST_EXACT = new Set([
  "PATH",
  "HOME",
  "USER",
  "SHELL",
  "TMPDIR",
  "TMP",
  "TEMP",
  "LANG",
  "TZ",
  // Windows
  "SystemRoot",
  "SYSTEMROOT",
  "windir",
  "WINDIR",
  "USERPROFILE",
  "HOMEDRIVE",
  "HOMEPATH",
  "ComSpec",
  "COMSPEC",
  "PATHEXT",
  // Git / XDG
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "GIT_CONFIG_GLOBAL",
  "GIT_CONFIG_SYSTEM",
  "GIT_CONFIG",
]);

const ESC = "\u001b";
const CSI = `${ESC}[`;

type SelectOption<T extends string> = { label: string; value: T };

type InstallReport = {
  skillPath?: string;
  hooks: Harness[];
};

const HARNESS_HOOKS_DIR: Record<Harness, string> = {
  cursor: ".cursor/hooks",
  claude: ".claude/hooks",
  codex: ".codex/hooks",
  opencode: ".opencode/hooks",
  copilot: ".github/hooks",
  gemini: ".gemini/hooks",
};

function projectDir(): string {
  return process.env.AGENT_MEMORY_PROJECT_DIR || process.cwd();
}

function installedSkillDir(): string {
  return path.join(projectDir(), ".agents", "skills", "agent-memory");
}

function readSkillVersionFromDir(skillDir: string): string | null {
  const skillMd = path.join(skillDir, "SKILL.md");
  if (!fs.existsSync(skillMd)) return null;
  const text = fs.readFileSync(skillMd, "utf8");
  const m = text.match(
    /^metadata:\s*\n(?:[ \t]+.+\n)*?[ \t]+version:\s*["']?([0-9]+\.[0-9]+\.[0-9]+)["']?/m,
  );
  if (m) return m[1];
  const loose = text.match(/version:\s*["']([0-9]+\.[0-9]+\.[0-9]+)["']/);
  return loose ? loose[1] : null;
}

function readInstalledSkillVersion(): string | null {
  return readSkillVersionFromDir(installedSkillDir());
}

function readInstalledHooksVersion(harness: Harness): string | null {
  const stamp = path.join(projectDir(), HARNESS_HOOKS_DIR[harness], ".version");
  if (!fs.existsSync(stamp)) return null;
  const v = fs.readFileSync(stamp, "utf8").trim();
  return v || null;
}

/** Compare semver x.y.z. Returns -1 if a<b, 0 if equal, 1 if a>b. */
function compareSemver(a: string, b: string): -1 | 0 | 1 {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (x < y) return -1;
    if (x > y) return 1;
  }
  return 0;
}

function fileContains(filePath: string, needle: string): boolean {
  try {
    return fs.readFileSync(filePath, "utf8").includes(needle);
  } catch {
    return false;
  }
}

function detectInstalledHarnesses(): Harness[] {
  const root = projectDir();
  const found: Harness[] = [];

  const check = (harness: Harness, ok: boolean): void => {
    if (ok) found.push(harness);
  };

  check(
    "cursor",
    fs.existsSync(
      path.join(root, ".cursor", "hooks", "agent-memory-sync.sh"),
    ) || fileContains(path.join(root, ".cursor", "hooks.json"), "agent-memory"),
  );
  check(
    "claude",
    fs.existsSync(path.join(root, ".claude", "hooks", "agent-memory-sync.sh")),
  );
  check(
    "codex",
    fs.existsSync(path.join(root, ".codex", "hooks", "agent-memory-sync.sh")),
  );
  check(
    "opencode",
    fs.existsSync(path.join(root, ".opencode", "plugin", "agent-memory.ts")) ||
      fs.existsSync(
        path.join(root, ".opencode", "hooks", "agent-memory-sync.sh"),
      ),
  );
  check(
    "copilot",
    fs.existsSync(path.join(root, ".github", "hooks", "agent-memory.json")) ||
      fs.existsSync(
        path.join(root, ".github", "hooks", "agent-memory-sync.sh"),
      ),
  );
  check(
    "gemini",
    fs.existsSync(
      path.join(root, ".gemini", "hooks", "agent-memory-sync.sh"),
    ) ||
      fileContains(path.join(root, ".gemini", "settings.json"), "agent-memory"),
  );

  return found;
}

function memoryExists(): boolean {
  return fs.existsSync(path.join(projectDir(), ".agents", "memory"));
}

function normalizeHarness(name: string): Harness | null {
  if (HARNESS_SET.has(name)) return name as Harness;
  return HARNESS_ALIASES[name] ?? null;
}

function isTTY(): boolean {
  return process.stdin.isTTY === true && process.stdout.isTTY === true;
}

function useColor(): boolean {
  if (process.env.NO_COLOR !== undefined && process.env.NO_COLOR !== "") {
    return false;
  }
  if (process.env.FORCE_COLOR !== undefined && process.env.FORCE_COLOR !== "") {
    return process.env.FORCE_COLOR !== "0";
  }
  return process.stdout.isTTY === true;
}

const colorEnabled = useColor();

function wrap(code: string, text: string): string {
  if (!colorEnabled) return text;
  return `${CSI}${code}m${text}${CSI}0m`;
}

const c = {
  bold: (t: string) => wrap("1", t),
  dim: (t: string) => wrap("2", t),
  cyan: (t: string) => wrap("36", t),
  green: (t: string) => wrap("32", t),
  yellow: (t: string) => wrap("33", t),
  red: (t: string) => wrap("31", t),
  magenta: (t: string) => wrap("35", t),
  boldCyan: (t: string) => wrap("1;36", t),
  boldGreen: (t: string) => wrap("1;32", t),
  boldMagenta: (t: string) => wrap("1;35", t),
};

function relPath(p: string): string {
  const root = path.resolve(projectDir());
  const abs = path.resolve(p);
  if (abs === root) return ".";
  if (abs.startsWith(root + path.sep)) return path.relative(root, abs);
  return abs;
}

function countFiles(dir: string): number {
  let n = 0;
  const walk = (d: string): void => {
    for (const ent of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, ent.name);
      if (ent.isDirectory()) walk(full);
      else if (ent.isFile()) n += 1;
    }
  };
  walk(dir);
  return n;
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
  console.log(`${c.boldMagenta("agent-memory")} ${c.dim(VERSION)}

${c.cyan("Installer")} for @dosx/agent-memory — copies the skill into the
project and installs harness lifecycle hooks.

${c.bold("Usage")}
  ${c.cyan("agent-memory install")}                    ${c.dim("# TTY: pick harnesses + skill/hooks")}
  ${c.cyan("agent-memory install skill")}              ${c.dim("# copy skill → .agents/skills/")}
  ${c.cyan("agent-memory install hooks")}              ${c.dim("# TTY: multi-select harnesses")}
  ${c.cyan("agent-memory install hooks <harness>")}    ${c.dim("# headless: one harness")}
  ${c.cyan("agent-memory install <harness>")}          ${c.dim("# TTY menu for that harness")}
  ${c.cyan("agent-memory update")}                     ${c.dim("# refresh skill + installed hooks")}
  ${c.cyan("agent-memory update --yes")}               ${c.dim("# non-interactive update")}
  ${c.cyan("agent-memory help")}

${c.bold("Harnesses")}  ${harnessList}
  ${c.dim("aliases: claude-code → claude, github → copilot")}

${c.bold("Examples")}
  ${c.dim("npx @dosx/agent-memory install")}
  ${c.dim("npx @dosx/agent-memory install skill")}
  ${c.dim("npx @dosx/agent-memory install hooks cursor")}
  ${c.dim("npx @dosx/agent-memory update")}
  ${c.dim("npx @dosx/agent-memory update --yes")}
`);
}

/** Always shell:false — argv must not be re-parsed by cmd.exe. */
function runCaptured(
  command: string,
  args: string[],
  options: { env?: NodeJS.ProcessEnv } = {},
): { stdout: string; stderr: string } {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env: options.env,
    shell: false,
  });
  if (result.error) {
    console.error(`${c.red("error:")} ${result.error.message}`);
    process.exit(1);
  }
  if (result.signal) {
    process.exit(1);
  }
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  if (result.status === null || result.status !== 0) {
    if (stderr.trim()) {
      for (const line of stderr.trim().split("\n")) {
        console.error(`  ${c.red("✗")} ${line}`);
      }
    }
    process.exit(result.status ?? 1);
  }
  return { stdout, stderr };
}

function buildInstallerEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {
    AGENT_MEMORY_PROJECT_DIR: projectDir(),
    AGENT_MEMORY_VERSION: VERSION,
  };
  for (const key of Object.keys(process.env)) {
    if (ENV_ALLOWLIST_EXACT.has(key) || key.startsWith("LC_")) {
      const val = process.env[key];
      if (val !== undefined) env[key] = val;
    }
  }
  return env;
}

function isSymlink(p: string): boolean {
  try {
    return fs.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

/** Refuse if dest or any existing parent under project is a symlink. */
function refuseSymlinkComponents(dest: string): void {
  const project = path.resolve(projectDir());
  let cur = path.resolve(dest);
  while (true) {
    if (isSymlink(cur)) {
      console.error(
        `${c.red("error:")} refusing symlink in destination path: ${cur}`,
      );
      process.exit(1);
    }
    if (cur === project || cur === path.parse(cur).root) break;
    const parent = path.dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
}

function installSkill(): string {
  if (!fs.existsSync(SKILL_SOURCE)) {
    console.error(`${c.red("error:")} missing skill at ${SKILL_SOURCE}`);
    process.exit(1);
  }

  const dest = path.join(projectDir(), ".agents", "skills", "agent-memory");
  refuseSymlinkComponents(dest);
  if (fs.existsSync(dest) && isSymlink(dest)) {
    console.error(`${c.red("error:")} refusing to overwrite symlink: ${dest}`);
    process.exit(1);
  }

  const existed = fs.existsSync(dest);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(SKILL_SOURCE, dest, { recursive: true, force: true });
  const files = countFiles(dest);
  const destRel = relPath(dest);

  printSection("Skill");
  printDetail("name", c.bold("agent-memory"));
  printDetail("version", VERSION);
  printDetail("path", destRel);
  printDetail(
    "files",
    `${files} files ${c.dim(existed ? "(updated)" : "(new)")}`,
  );
  printOk(`skill ready at ${c.cyan(destRel)}`);
  return destRel;
}

function installHooks(harness: Harness): void {
  if (!fs.existsSync(INSTALL_HOOKS_SH)) {
    console.error(
      `${c.red("error:")} missing installer at ${INSTALL_HOOKS_SH}`,
    );
    process.exit(1);
  }
  const bash = process.platform === "win32" ? "bash.exe" : "bash";
  printSection(`Hooks · ${harness}`);
  printDetail("target", HARNESS_HOOKS_DIR[harness]);

  const { stdout, stderr } = runCaptured(bash, [INSTALL_HOOKS_SH, harness], {
    env: buildInstallerEnv(),
  });

  for (const line of stdout.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (trimmed.startsWith("done:")) continue;
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

function installHooksMany(harnesses: Harness[]): void {
  for (const h of harnesses) {
    installHooks(h);
  }
}

function finishInstall(report: InstallReport): void {
  printSummary(report);
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

async function cmdUpdate(flags: { yes: boolean }): Promise<void> {
  const installedSkill = readInstalledSkillVersion();
  const skillDir = installedSkillDir();
  const skillMissing = !fs.existsSync(skillDir) || !installedSkill;

  printHeader("update");
  printSection("Versions");
  printDetail("package", VERSION);
  if (skillMissing) {
    printDetail("skill", c.dim("not installed"));
    printStep(
      c.yellow(
        `skill missing — hooks-only update; install with: npx @dosx/agent-memory install skill`,
      ),
    );
  } else {
    printDetail(
      "skill",
      `${installedSkill} ${c.dim("installed")} · ${VERSION} ${c.dim("package")}`,
    );
  }
  printDetail("hooks", `${VERSION} ${c.dim("package")}`);

  let needSkill = false;
  if (!skillMissing && installedSkill) {
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
    console.error(`  ${c.dim("npx @dosx/agent-memory install skill")}`);
    console.error(
      `  ${c.dim("npx @dosx/agent-memory install hooks <harness>")}`,
    );
    process.exit(1);
  }

  if (!needSkill && hooksToRefresh.length === 0) {
    blank();
    console.log(
      `${c.boldGreen("✓")} ${c.bold("Already up to date")} ${c.dim(VERSION)}`,
    );
    if (skillMissing) {
      printStep(c.dim(`optional: npx @dosx/agent-memory install skill`));
    }
    printAgentNextSteps(memoryExists() ? "update" : "init");
    return;
  }

  const planParts: string[] = [];
  if (needSkill) planParts.push(`skill ${installedSkill} → ${VERSION}`);
  if (hooksToRefresh.length > 0) {
    planParts.push(`hooks ${hooksToRefresh.join(", ")} → ${VERSION}`);
  }

  if (!flags.yes) {
    if (!isTTY()) {
      failNonTTY("interactive update requires a TTY (or pass --yes).", [
        "npx @dosx/agent-memory update --yes",
      ]);
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

function parseUpdateFlags(args: string[]): { yes: boolean } {
  let yes = false;
  for (const a of args) {
    if (a === "--yes" || a === "-y") {
      yes = true;
      continue;
    }
    console.error(`${c.red("error:")} unexpected argument: ${a}`);
    printHelp();
    process.exit(1);
  }
  return { yes };
}

function renderSelectLines(
  title: string,
  options: SelectOption<string>[],
  selected: number,
): string[] {
  const lines = [c.bold(title), ""];
  for (let i = 0; i < options.length; i++) {
    const active = i === selected;
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${label}`);
  }
  lines.push("", c.dim("↑/↓ or j/k · Enter confirm · Ctrl+C/Esc cancel"));
  return lines;
}

function renderMultiSelectLines(
  title: string,
  options: SelectOption<string>[],
  cursor: number,
  checked: Set<number>,
): string[] {
  const lines = [c.bold(title), ""];
  for (let i = 0; i < options.length; i++) {
    const active = i === cursor;
    const box = checked.has(i) ? c.green("[x]") : "[ ]";
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${box} ${label}`);
  }
  lines.push(
    "",
    c.dim("↑/↓ or j/k · Space toggle · Enter confirm · Ctrl+C/Esc cancel"),
  );
  return lines;
}

function clearRenderedLines(lineCount: number): void {
  for (let i = 0; i < lineCount; i++) {
    process.stdout.write(`${CSI}1A${CSI}2K`);
  }
}

type EscState = "normal" | "esc" | "csi" | "ss3";

function createRawMenuController(opts: {
  onAbort: () => void;
  onRedraw: () => void;
  onConfirm: () => void;
  onUp: () => void;
  onDown: () => void;
  onSpace?: () => void;
}): { start: () => void; cleanup: () => void } {
  let escState: EscState = "normal";
  let escTimer: ReturnType<typeof setTimeout> | null = null;
  let rawModeEnabled = false;
  const stdin = process.stdin;

  function disableRawMode(): void {
    if (rawModeEnabled && typeof stdin.setRawMode === "function") {
      stdin.setRawMode(false);
      rawModeEnabled = false;
    }
  }

  function clearEscTimer(): void {
    if (escTimer) {
      clearTimeout(escTimer);
      escTimer = null;
    }
  }

  function isCsiFinal(ch: string): boolean {
    const code = ch.charCodeAt(0);
    return code >= 0x40 && code <= 0x7e;
  }

  function isAlphanumeric(ch: string): boolean {
    return /[0-9A-Za-z]/.test(ch);
  }

  function startEscTimer(): void {
    clearEscTimer();
    escTimer = setTimeout(() => {
      escTimer = null;
      if (escState === "esc") {
        escState = "normal";
        opts.onAbort();
        return;
      }
      if (escState === "csi" || escState === "ss3") {
        escState = "normal";
      }
    }, 50);
  }

  function cleanup(): void {
    clearEscTimer();
    disableRawMode();
    stdin.pause();
    stdin.removeListener("data", onData);
    stdin.removeListener("end", onEnd);
  }

  function processChar(ch: string): void {
    if (escState === "esc") {
      clearEscTimer();
      if (ch === "[") {
        escState = "csi";
        startEscTimer();
        return;
      }
      if (ch === "O") {
        escState = "ss3";
        startEscTimer();
        return;
      }
      if (isAlphanumeric(ch)) {
        escState = "normal";
      } else {
        escState = "normal";
        opts.onAbort();
        return;
      }
    }

    if (escState === "csi") {
      if (!isCsiFinal(ch)) {
        startEscTimer();
        return;
      }
      clearEscTimer();
      escState = "normal";
      if (ch === "A") {
        opts.onUp();
        return;
      }
      if (ch === "B") {
        opts.onDown();
        return;
      }
      return;
    }

    if (escState === "ss3") {
      if (!isCsiFinal(ch)) {
        startEscTimer();
        return;
      }
      clearEscTimer();
      escState = "normal";
      if (ch === "A") {
        opts.onUp();
        return;
      }
      if (ch === "B") {
        opts.onDown();
        return;
      }
      return;
    }

    if (ch === "\u0003") {
      opts.onAbort();
      return;
    }
    if (ch === ESC) {
      escState = "esc";
      startEscTimer();
      return;
    }
    if (ch === "k") {
      opts.onUp();
      return;
    }
    if (ch === "j") {
      opts.onDown();
      return;
    }
    if (ch === " " && opts.onSpace) {
      opts.onSpace();
      return;
    }
    if (ch === "\r" || ch === "\n") {
      opts.onConfirm();
    }
  }

  function onData(chunk: string): void {
    for (let i = 0; i < chunk.length; i++) {
      processChar(chunk[i]);
    }
  }

  function onEnd(): void {
    opts.onAbort();
  }

  function start(): void {
    let setupComplete = false;
    try {
      if (typeof stdin.setRawMode === "function") {
        stdin.setRawMode(true);
        rawModeEnabled = true;
      }
      stdin.resume();
      stdin.setEncoding("utf8");
      stdin.on("data", onData);
      stdin.on("end", onEnd);
      opts.onRedraw();
      setupComplete = true;
    } finally {
      if (!setupComplete) {
        disableRawMode();
      }
    }
  }

  return { start, cleanup };
}

/**
 * Interactive single-select menu (TTY only). Returns the chosen option value.
 * Aborts with exit 1 on Ctrl+C or Esc.
 */
function selectPrompt<T extends string>(
  title: string,
  options: SelectOption<T>[],
): Promise<T> {
  return new Promise((resolve) => {
    let selected = 0;
    let renderedLineCount = 0;
    let controller: ReturnType<typeof createRawMenuController>;

    function abort(): void {
      controller.cleanup();
      process.stdout.write("\n");
      process.exit(1);
    }

    function printMenu(): void {
      const lines = renderSelectLines(title, options, selected);
      lines.forEach((line) => process.stdout.write(`${line}\n`));
      renderedLineCount = lines.length;
    }

    function redraw(): void {
      clearRenderedLines(renderedLineCount);
      printMenu();
    }

    controller = createRawMenuController({
      onAbort: abort,
      onRedraw: printMenu,
      onUp: () => {
        selected = (selected - 1 + options.length) % options.length;
        redraw();
      },
      onDown: () => {
        selected = (selected + 1) % options.length;
        redraw();
      },
      onConfirm: () => {
        controller.cleanup();
        process.stdout.write("\n");
        resolve(options[selected].value);
      },
    });
    controller.start();
  });
}

/**
 * Multi-select checkbox menu. Space toggles; Enter confirms (≥1 required).
 */
function multiSelectPrompt<T extends string>(
  title: string,
  options: SelectOption<T>[],
): Promise<T[]> {
  return new Promise((resolve) => {
    let cursor = 0;
    const checked = new Set<number>();
    let renderedLineCount = 0;
    let hint = "";
    let controller: ReturnType<typeof createRawMenuController>;

    function abort(): void {
      controller.cleanup();
      process.stdout.write("\n");
      process.exit(1);
    }

    function printMenu(): void {
      const lines = renderMultiSelectLines(title, options, cursor, checked);
      if (hint) lines.push(c.yellow(hint));
      lines.forEach((line) => process.stdout.write(`${line}\n`));
      renderedLineCount = lines.length;
    }

    function redraw(): void {
      clearRenderedLines(renderedLineCount);
      printMenu();
    }

    controller = createRawMenuController({
      onAbort: abort,
      onRedraw: printMenu,
      onUp: () => {
        cursor = (cursor - 1 + options.length) % options.length;
        hint = "";
        redraw();
      },
      onDown: () => {
        cursor = (cursor + 1) % options.length;
        hint = "";
        redraw();
      },
      onSpace: () => {
        if (checked.has(cursor)) checked.delete(cursor);
        else checked.add(cursor);
        hint = "";
        redraw();
      },
      onConfirm: () => {
        if (checked.size === 0) {
          hint = "Select at least one harness (Space), then Enter.";
          redraw();
          return;
        }
        controller.cleanup();
        process.stdout.write("\n");
        const values = [...checked]
          .sort((a, b) => a - b)
          .map((i) => options[i].value);
        resolve(values);
      },
    });
    controller.start();
  });
}

function harnessOptions(): SelectOption<Harness>[] {
  return CANONICAL_HARNESSES.map((h) => ({ label: h, value: h }));
}

function failNonTTY(message: string, hints: string[]): never {
  console.error(`${c.red("error:")} ${message}`);
  for (const h of hints) {
    console.error(`  ${c.dim(h)}`);
  }
  process.exit(1);
}

async function promptInstallChoice(harness: Harness): Promise<void> {
  if (!isTTY()) {
    failNonTTY("interactive install requires a TTY.", [
      `Hooks: npx @dosx/agent-memory install hooks ${harness}`,
      "Skill: npx @dosx/agent-memory install skill",
    ]);
  }

  const choice = await selectPrompt(`Install agent-memory for ${harness}:`, [
    { label: "Skill + hooks", value: "both" },
    { label: "Skill only", value: "skill" },
    { label: "Hooks only", value: "hooks" },
  ] as const);

  printHeader(`install · ${harness}`);
  if (choice === "both") {
    const skillPath = installSkill();
    installHooks(harness);
    finishInstall({ skillPath, hooks: [harness] });
    return;
  }
  if (choice === "skill") {
    finishInstall({ skillPath: installSkill(), hooks: [] });
    return;
  }
  installHooks(harness);
  finishInstall({ hooks: [harness] });
}

async function promptInstallBare(): Promise<void> {
  if (!isTTY()) {
    failNonTTY("interactive install requires a TTY.", [
      "Skill: npx @dosx/agent-memory install skill",
      "Hooks: npx @dosx/agent-memory install hooks <harness>",
    ]);
  }

  const mode = await selectPrompt("What do you want to install?", [
    { label: "Skill + hooks", value: "both" },
    { label: "Skill only", value: "skill" },
    { label: "Hooks only", value: "hooks" },
  ] as const);

  if (mode === "skill") {
    printHeader("install · skill");
    finishInstall({ skillPath: installSkill(), hooks: [] });
    return;
  }

  const selected = await multiSelectPrompt(
    "Select harnesses (Space to toggle):",
    harnessOptions(),
  );

  printHeader(
    mode === "both"
      ? `install · skill + ${selected.join(", ")}`
      : `install · hooks · ${selected.join(", ")}`,
  );
  const report: InstallReport = { hooks: selected };
  if (mode === "both") {
    report.skillPath = installSkill();
  }
  installHooksMany(selected);
  finishInstall(report);
}

async function promptHooksMultiSelect(): Promise<void> {
  if (!isTTY()) {
    failNonTTY("interactive install hooks requires a TTY.", [
      "Hooks: npx @dosx/agent-memory install hooks <harness>",
    ]);
  }
  const selected = await multiSelectPrompt(
    "Select harnesses (Space to toggle):",
    harnessOptions(),
  );
  printHeader(`install · hooks · ${selected.join(", ")}`);
  installHooksMany(selected);
  finishInstall({ hooks: selected });
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
    console.error(`${c.red("error:")} unknown command: ${args[0]}`);
    printHelp();
    process.exit(1);
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
    finishInstall({ skillPath: installSkill(), hooks: [] });
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
      console.error(`${c.red("error:")} unknown harness: ${raw}`);
      printHelp();
      process.exit(1);
    }
    printHeader(`install · hooks · ${harness}`);
    installHooks(harness);
    finishInstall({ hooks: [harness] });
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

  console.error(`${c.red("error:")} unknown install target: ${rest[0]}`);
  printHelp();
  process.exit(1);
}

main(process.argv).catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
