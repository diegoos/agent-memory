#!/usr/bin/env node
var __create = Object.create;
var __getProtoOf = Object.getPrototypeOf;
var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
function __accessProp(key) {
  return this[key];
}
var __toESMCache_node;
var __toESMCache_esm;
var __toESM = (mod, isNodeMode, target) => {
  var canCache = mod != null && typeof mod === "object";
  if (canCache) {
    var cache = isNodeMode ? __toESMCache_node ??= new WeakMap : __toESMCache_esm ??= new WeakMap;
    var cached = cache.get(mod);
    if (cached)
      return cached;
  }
  target = mod != null ? __create(__getProtoOf(mod)) : {};
  const to = isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target;
  for (let key of __getOwnPropNames(mod))
    if (!__hasOwnProp.call(to, key))
      __defProp(to, key, {
        get: __accessProp.bind(mod, key),
        enumerable: true
      });
  if (canCache)
    cache.set(mod, to);
  return to;
};

// install.ts
var import_node_fs4 = __toESM(require("node:fs"));
var import_node_path4 = __toESM(require("node:path"));

// lib/cli/constants.ts
var CANONICAL_HARNESSES = [
  "cursor",
  "claude",
  "codex",
  "opencode",
  "copilot",
  "gemini"
];
var HARNESS_ALIASES = {
  "claude-code": "claude",
  github: "copilot"
};
var HARNESS_HOOKS_DIR = {
  cursor: ".cursor/hooks",
  claude: ".claude/hooks",
  codex: ".codex/hooks",
  opencode: ".opencode/hooks",
  copilot: ".github/hooks",
  gemini: ".gemini/hooks"
};
var ENV_ALLOWLIST_EXACT = new Set([
  "PATH",
  "HOME",
  "USER",
  "SHELL",
  "TMPDIR",
  "TMP",
  "TEMP",
  "LANG",
  "TZ",
  "LC_ALL",
  "LC_CTYPE",
  "LC_MESSAGES",
  "LC_COLLATE",
  "LC_MONETARY",
  "LC_NUMERIC",
  "LC_TIME",
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
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "GIT_CONFIG_GLOBAL",
  "GIT_CONFIG_SYSTEM",
  "GIT_CONFIG"
]);

// lib/cli/detect.ts
var import_node_fs = __toESM(require("node:fs"));
var import_node_path = __toESM(require("node:path"));
function projectDir() {
  return process.env.AGENT_MEMORY_PROJECT_DIR || process.cwd();
}
function installedSkillDir() {
  return import_node_path.default.join(projectDir(), ".agents", "skills", "agent-memory");
}
function readSkillVersionFromDir(skillDir) {
  const skillMd = import_node_path.default.join(skillDir, "SKILL.md");
  if (!import_node_fs.default.existsSync(skillMd))
    return null;
  const text = import_node_fs.default.readFileSync(skillMd, "utf8");
  const m = text.match(/^metadata:\s*\n(?:[ \t]+.+\n)*?[ \t]+version:\s*["']?([0-9]+\.[0-9]+\.[0-9]+)["']?/m);
  if (m)
    return m[1];
  const loose = text.match(/version:\s*["']([0-9]+\.[0-9]+\.[0-9]+)["']/);
  return loose ? loose[1] : null;
}
function readInstalledSkillVersion() {
  return readSkillVersionFromDir(installedSkillDir());
}
function readInstalledHooksVersion(harness) {
  const stamp = import_node_path.default.join(projectDir(), HARNESS_HOOKS_DIR[harness], ".version");
  if (!import_node_fs.default.existsSync(stamp))
    return null;
  const v = import_node_fs.default.readFileSync(stamp, "utf8").trim();
  return v || null;
}
function fileContains(filePath, needle) {
  try {
    return import_node_fs.default.readFileSync(filePath, "utf8").includes(needle);
  } catch {
    return false;
  }
}
function detectInstalledHarnesses() {
  const root = projectDir();
  const found = [];
  const check = (harness, ok) => {
    if (ok)
      found.push(harness);
  };
  check("cursor", import_node_fs.default.existsSync(import_node_path.default.join(root, ".cursor", "hooks", "agent-memory-sync.sh")) || fileContains(import_node_path.default.join(root, ".cursor", "hooks.json"), "agent-memory"));
  check("claude", import_node_fs.default.existsSync(import_node_path.default.join(root, ".claude", "hooks", "agent-memory-sync.sh")));
  check("codex", import_node_fs.default.existsSync(import_node_path.default.join(root, ".codex", "hooks", "agent-memory-sync.sh")));
  check("opencode", import_node_fs.default.existsSync(import_node_path.default.join(root, ".opencode", "plugin", "agent-memory.ts")) || import_node_fs.default.existsSync(import_node_path.default.join(root, ".opencode", "hooks", "agent-memory-sync.sh")));
  check("copilot", import_node_fs.default.existsSync(import_node_path.default.join(root, ".github", "hooks", "agent-memory.json")) || import_node_fs.default.existsSync(import_node_path.default.join(root, ".github", "hooks", "agent-memory-sync.sh")));
  check("gemini", import_node_fs.default.existsSync(import_node_path.default.join(root, ".gemini", "hooks", "agent-memory-sync.sh")) || fileContains(import_node_path.default.join(root, ".gemini", "settings.json"), "agent-memory"));
  return found;
}
function memoryExists() {
  return import_node_fs.default.existsSync(import_node_path.default.join(projectDir(), ".agents", "memory"));
}
function normalizeHarness(name) {
  if (CANONICAL_HARNESSES.includes(name)) {
    return name;
  }
  return HARNESS_ALIASES[name] ?? null;
}

// lib/cli/fs-install.ts
var import_node_fs2 = __toESM(require("node:fs"));
var import_node_path2 = __toESM(require("node:path"));
function installSkillAtomic(opts) {
  const { skillSource, onError } = opts;
  if (!import_node_fs2.default.existsSync(skillSource)) {
    onError(`missing skill at ${skillSource}`);
  }
  const dest = installedSkillDir();
  refuseSymlinkComponents(dest, onError);
  const existed = import_node_fs2.default.existsSync(dest);
  const parent = import_node_path2.default.dirname(dest);
  import_node_fs2.default.mkdirSync(parent, { recursive: true });
  const staging = import_node_fs2.default.mkdtempSync(import_node_path2.default.join(parent, ".agent-memory-skill-"));
  const backup = `${dest}.bak-${process.pid}-${Date.now()}`;
  let movedAside = false;
  try {
    import_node_fs2.default.cpSync(skillSource, staging, { recursive: true, force: true });
  } catch (err) {
    import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
    onError(`skill install failed: ${err instanceof Error ? err.message : String(err)}`);
  }
  if (existed) {
    try {
      import_node_fs2.default.renameSync(dest, backup);
      movedAside = true;
    } catch (err) {
      import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
      onError(`skill install failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
  try {
    import_node_fs2.default.renameSync(staging, dest);
  } catch {
    try {
      import_node_fs2.default.cpSync(staging, dest, { recursive: true, force: true });
      import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
    } catch (err) {
      if (movedAside) {
        const ok = restoreBackup(backup, dest);
        import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
        if (!ok) {
          onError(`skill install failed and restore failed; previous skill left at ${backup}`);
        }
        onError(`skill install failed: ${err instanceof Error ? err.message : String(err)}`);
      }
      if (!import_node_fs2.default.existsSync(dest) && import_node_fs2.default.existsSync(staging)) {
        try {
          import_node_fs2.default.renameSync(staging, dest);
        } catch {
          try {
            import_node_fs2.default.cpSync(staging, dest, { recursive: true, force: true });
            import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
          } catch {
            import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
            onError(`skill install failed: ${err instanceof Error ? err.message : String(err)}`);
          }
        }
      } else {
        import_node_fs2.default.rmSync(staging, { recursive: true, force: true });
        onError(`skill install failed: ${err instanceof Error ? err.message : String(err)}`);
      }
    }
  }
  if (movedAside && import_node_fs2.default.existsSync(backup)) {
    try {
      import_node_fs2.default.rmSync(backup, { recursive: true, force: true });
    } catch {}
  }
  return {
    destRel: relPath(dest),
    files: countFiles(dest),
    existed
  };
}
function isSymlink(p) {
  try {
    return import_node_fs2.default.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}
function refuseSymlinkComponents(dest, onError) {
  const project = import_node_path2.default.resolve(projectDir());
  let cur = import_node_path2.default.resolve(dest);
  while (true) {
    if (isSymlink(cur)) {
      onError(`refusing symlink in destination path: ${cur}`);
    }
    if (cur === project || cur === import_node_path2.default.parse(cur).root)
      break;
    const parent = import_node_path2.default.dirname(cur);
    if (parent === cur)
      break;
    cur = parent;
  }
}
function relPath(p) {
  const root = import_node_path2.default.resolve(projectDir());
  const abs = import_node_path2.default.resolve(p);
  if (abs === root)
    return ".";
  if (abs.startsWith(root + import_node_path2.default.sep))
    return import_node_path2.default.relative(root, abs);
  return abs;
}
function countFiles(dir) {
  let n = 0;
  const walk = (d) => {
    for (const ent of import_node_fs2.default.readdirSync(d, { withFileTypes: true })) {
      const full = import_node_path2.default.join(d, ent.name);
      if (ent.isDirectory())
        walk(full);
      else if (ent.isFile())
        n += 1;
    }
  };
  walk(dir);
  return n;
}
function restoreBackup(backup, dest) {
  if (!import_node_fs2.default.existsSync(backup)) {
    return import_node_fs2.default.existsSync(dest);
  }
  if (import_node_fs2.default.existsSync(dest)) {
    try {
      import_node_fs2.default.rmSync(dest, { recursive: true, force: true });
    } catch {
      return false;
    }
  }
  try {
    import_node_fs2.default.renameSync(backup, dest);
    return true;
  } catch {
    try {
      import_node_fs2.default.cpSync(backup, dest, { recursive: true, force: true });
      return true;
    } catch {
      return false;
    }
  }
}

// lib/cli/hooks-run.ts
var import_node_child_process = require("node:child_process");
function runCaptured(command, args, options) {
  const result = import_node_child_process.spawnSync(command, args, {
    encoding: "utf8",
    env: options.env,
    shell: false
  });
  if (result.error) {
    options.onSpawnError(result.error.message);
  }
  if (result.signal) {
    process.exit(1);
  }
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  if (result.status === null || result.status !== 0) {
    options.onCommandFail(stderr, result.status);
  }
  return { stdout, stderr };
}
function buildInstallerEnv(version) {
  const env = {
    AGENT_MEMORY_PROJECT_DIR: projectDir(),
    AGENT_MEMORY_VERSION: version
  };
  for (const key of ENV_ALLOWLIST_EXACT) {
    const val = process.env[key];
    if (val !== undefined)
      env[key] = val;
  }
  return env;
}

// lib/cli/package-root.ts
var import_node_fs3 = __toESM(require("node:fs"));
var import_node_path3 = __toESM(require("node:path"));
function resolvePackageRoot() {
  const entry = process.argv[1];
  if (entry) {
    let scriptPath = import_node_path3.default.resolve(entry);
    try {
      scriptPath = import_node_fs3.default.realpathSync(scriptPath);
    } catch {}
    const dir = import_node_path3.default.dirname(scriptPath);
    if (import_node_path3.default.basename(dir) === "bin") {
      return import_node_path3.default.resolve(dir, "..");
    }
    let cur = dir;
    for (;; ) {
      const pkgPath = import_node_path3.default.join(cur, "package.json");
      if (import_node_fs3.default.existsSync(pkgPath)) {
        try {
          const name = JSON.parse(import_node_fs3.default.readFileSync(pkgPath, "utf8")).name;
          if (name === "@dosx/agent-memory")
            return cur;
        } catch {}
      }
      const parent = import_node_path3.default.dirname(cur);
      if (parent === cur)
        break;
      cur = parent;
    }
  }
  console.error("error: unable to resolve @dosx/agent-memory package root from process.argv[1]");
  process.exit(1);
}

// lib/cli/semver.ts
function compareSemver(a, b) {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0;i < 3; i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (x < y)
      return -1;
    if (x > y)
      return 1;
  }
  return 0;
}

// lib/cli/tty.ts
var ESC = "\x1B";
var CSI = `${ESC}[`;
function isTTY() {
  return process.stdin.isTTY === true && process.stdout.isTTY === true;
}
function useColor() {
  if (process.env.NO_COLOR !== undefined && process.env.NO_COLOR !== "") {
    return false;
  }
  if (process.env.FORCE_COLOR !== undefined && process.env.FORCE_COLOR !== "") {
    return process.env.FORCE_COLOR !== "0";
  }
  return process.stdout.isTTY === true;
}
var colorEnabled = useColor();
function wrap(code, text) {
  if (!colorEnabled)
    return text;
  return `${CSI}${code}m${text}${CSI}0m`;
}
var c = {
  bold: (t) => wrap("1", t),
  dim: (t) => wrap("2", t),
  cyan: (t) => wrap("36", t),
  green: (t) => wrap("32", t),
  yellow: (t) => wrap("33", t),
  red: (t) => wrap("31", t),
  magenta: (t) => wrap("35", t),
  boldCyan: (t) => wrap("1;36", t),
  boldGreen: (t) => wrap("1;32", t),
  boldMagenta: (t) => wrap("1;35", t)
};
function renderSelectLines(title, options, selected) {
  const lines = [c.bold(title), ""];
  for (let i = 0;i < options.length; i++) {
    const active = i === selected;
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${label}`);
  }
  lines.push("", c.dim("↑/↓ or j/k · Enter confirm · Ctrl+C/Esc cancel"));
  return lines;
}
function renderMultiSelectLines(title, options, cursor, checked) {
  const lines = [c.bold(title), ""];
  for (let i = 0;i < options.length; i++) {
    const active = i === cursor;
    const box = checked.has(i) ? c.green("[x]") : "[ ]";
    const prefix = active ? `${c.cyan("›")} ` : "  ";
    const label = active ? c.bold(options[i].label) : options[i].label;
    lines.push(`${prefix}${box} ${label}`);
  }
  lines.push("", c.dim("↑/↓ or j/k · Space toggle · Enter confirm · Ctrl+C/Esc cancel"));
  return lines;
}
function clearRenderedLines(lineCount) {
  for (let i = 0;i < lineCount; i++) {
    process.stdout.write(`${CSI}1A${CSI}2K`);
  }
}
function createRawMenuController(opts) {
  let escState = "normal";
  let escTimer = null;
  let rawModeEnabled = false;
  const stdin = process.stdin;
  function disableRawMode() {
    if (rawModeEnabled && typeof stdin.setRawMode === "function") {
      stdin.setRawMode(false);
      rawModeEnabled = false;
    }
  }
  function clearEscTimer() {
    if (escTimer) {
      clearTimeout(escTimer);
      escTimer = null;
    }
  }
  function isCsiFinal(ch) {
    const code = ch.charCodeAt(0);
    return code >= 64 && code <= 126;
  }
  function isAlphanumeric(ch) {
    return /[0-9A-Za-z]/.test(ch);
  }
  function startEscTimer() {
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
  function cleanup() {
    clearEscTimer();
    disableRawMode();
    stdin.pause();
    stdin.removeListener("data", onData);
    stdin.removeListener("end", onEnd);
  }
  function processChar(ch) {
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
      escState = "normal";
      if (!isAlphanumeric(ch)) {
        opts.onAbort();
        return;
      }
    }
    if (escState === "csi" || escState === "ss3") {
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
    if (ch === "\x03") {
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
    if (ch === "\r" || ch === `
`) {
      opts.onConfirm();
    }
  }
  function onData(chunk) {
    for (let i = 0;i < chunk.length; i++) {
      processChar(chunk[i]);
    }
  }
  function onEnd() {
    opts.onAbort();
  }
  function start() {
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
function selectPrompt(title, options) {
  return new Promise((resolve) => {
    let selected = 0;
    let renderedLineCount = 0;
    let controller;
    function abort() {
      controller.cleanup();
      process.stdout.write(`
`);
      process.exit(1);
    }
    function printMenu() {
      const lines = renderSelectLines(title, options, selected);
      lines.forEach((line) => process.stdout.write(`${line}
`));
      renderedLineCount = lines.length;
    }
    function redraw() {
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
        process.stdout.write(`
`);
        resolve(options[selected].value);
      }
    });
    controller.start();
  });
}
function multiSelectPrompt(title, options) {
  return new Promise((resolve) => {
    let cursor = 0;
    const checked = new Set;
    let renderedLineCount = 0;
    let hint = "";
    let controller;
    function abort() {
      controller.cleanup();
      process.stdout.write(`
`);
      process.exit(1);
    }
    function printMenu() {
      const lines = renderMultiSelectLines(title, options, cursor, checked);
      if (hint)
        lines.push(c.yellow(hint));
      lines.forEach((line) => process.stdout.write(`${line}
`));
      renderedLineCount = lines.length;
    }
    function redraw() {
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
        if (checked.has(cursor))
          checked.delete(cursor);
        else
          checked.add(cursor);
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
        process.stdout.write(`
`);
        const values = [...checked].sort((a, b) => a - b).map((i) => options[i].value);
        resolve(values);
      }
    });
    controller.start();
  });
}

// install.ts
var ROOT = resolvePackageRoot();
var VERSION = JSON.parse(import_node_fs4.default.readFileSync(import_node_path4.default.join(ROOT, "package.json"), "utf8")).version;
var INSTALL_HOOKS_SH = import_node_path4.default.join(ROOT, "hooks", "install-hooks.sh");
var SKILL_SOURCE = import_node_path4.default.join(ROOT, "skills", "agent-memory");
function fatal(message) {
  console.error(`${c.red("error:")} ${message}`);
  process.exit(1);
}
function blank() {
  console.log("");
}
function printHeader(action) {
  blank();
  console.log(`${c.boldMagenta("agent-memory")} ${c.dim(`v${VERSION}`)}  ${c.dim("·")}  ${c.cyan(action)}`);
  console.log(c.dim(`project  ${import_node_path4.default.resolve(projectDir())}`));
}
function printSection(title) {
  blank();
  console.log(`${c.cyan("●")} ${c.bold(title)}`);
}
function printDetail(label, value) {
  const pad = label.padEnd(10);
  console.log(`  ${c.dim(pad)} ${value}`);
}
function printStep(line) {
  console.log(`  ${c.dim("·")} ${line}`);
}
function printOk(message) {
  console.log(`  ${c.green("✓")} ${message}`);
}
function printSummary(report) {
  blank();
  console.log(`${c.boldGreen("✓")} ${c.bold("Install complete")} ${c.dim(`v${VERSION}`)}`);
  if (report.skillPath) {
    printDetail("skill", report.skillPath);
  }
  if (report.hooks.length > 0) {
    printDetail("hooks", report.hooks.map((h) => `${h} ${c.dim(`(${HARNESS_HOOKS_DIR[h]})`)}`).join(", "));
  }
  printAgentNextSteps(memoryExists() ? "update" : "init");
}
function printAgentNextSteps(primary) {
  blank();
  console.log(c.bold("Next steps"));
  console.log(`  ${c.dim("In your coding agent chat")} ${c.dim("(Cursor, Claude Code, Codex, … — not this terminal):")}`);
  if (primary === "update") {
    printStep(`${c.cyan("/agent-memory update")}  migrate .agents/memory/ via vendor/UPDATE.md`);
  } else {
    printStep(`${c.cyan("/agent-memory init")}    create .agents/memory/ and wire the agent block`);
  }
  printStep(`${c.dim("/agent-memory help")}    list skill subcommands`);
  blank();
}
function printHelp() {
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
function installSkill() {
  const result = installSkillAtomic({
    skillSource: SKILL_SOURCE,
    onError: fatal
  });
  printSection("Skill");
  printDetail("name", c.bold("agent-memory"));
  printDetail("version", VERSION);
  printDetail("path", result.destRel);
  printDetail("files", `${result.files} files ${c.dim(result.existed ? "(updated)" : "(new)")}`);
  printOk(`skill ready at ${c.cyan(result.destRel)}`);
  return result.destRel;
}
function installHooks(harness) {
  if (!import_node_fs4.default.existsSync(INSTALL_HOOKS_SH)) {
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
        for (const line of errText.trim().split(`
`)) {
          console.error(`  ${c.red("✗")} ${line}`);
        }
      }
      process.exit(status ?? 1);
    }
  });
  for (const line of stdout.split(`
`)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("done:"))
      continue;
    if (trimmed.startsWith("error:")) {
      console.error(`  ${c.red("✗")} ${trimmed}`);
      continue;
    }
    printStep(trimmed);
  }
  for (const line of stderr.split(`
`)) {
    const trimmed = line.trim();
    if (!trimmed)
      continue;
    console.error(`  ${c.red("✗")} ${trimmed}`);
  }
  printOk(`hooks ready for ${c.bold(harness)}`);
}
async function confirmPrompt(message) {
  const choice = await selectPrompt(message, [
    { label: "Yes, update", value: "yes" },
    { label: "Cancel", value: "no" }
  ]);
  return choice === "yes";
}
function printUpdateSummary(opts) {
  blank();
  console.log(`${c.boldGreen("✓")} ${c.bold("Update complete")} ${c.dim(`cli ${VERSION}`)}`);
  if (opts.skillMissing) {
    printDetail("skill", c.dim("not installed (skipped)"));
  } else if (opts.skillUpdated) {
    printDetail("skill", `${opts.skillFrom ?? "?"} → ${opts.skillTo} ${c.dim("(.agents/skills/agent-memory)")}`);
  } else {
    printDetail("skill", `${opts.skillTo} ${c.dim("(already current)")}`);
  }
  if (opts.hooksRefreshed.length > 0) {
    printDetail("hooks", opts.hooksRefreshed.map((h) => `${h} ${c.dim(`→ ${VERSION}`)}`).join(", "));
  }
  if (opts.hooksSkipped.length > 0) {
    printDetail("skipped", opts.hooksSkipped.map((h) => `${h} ${c.dim("(current)")}`).join(", "));
  }
  printAgentNextSteps(memoryExists() ? "update" : "init");
}
async function cmdUpdate(flags) {
  const installedSkill = readInstalledSkillVersion();
  const skillMissing = !installedSkill;
  printHeader("update");
  printSection("Versions");
  printDetail("package", VERSION);
  if (skillMissing) {
    printDetail("skill", c.dim("not installed"));
    printStep(c.yellow(`skill missing — hooks-only update; install with: npx @dosx/agent-memory install skill`));
  } else {
    printDetail("skill", `${installedSkill} ${c.dim("installed")} · ${VERSION} ${c.dim("package")}`);
  }
  printDetail("hooks", `${VERSION} ${c.dim("package")}`);
  let needSkill = false;
  if (installedSkill) {
    const skillCmp = compareSemver(VERSION, installedSkill);
    if (skillCmp > 0) {
      needSkill = true;
      printStep(`skill upgrade available ${c.yellow(`${installedSkill} → ${VERSION}`)}`);
    } else if (skillCmp < 0) {
      console.log(`  ${c.yellow("!")} installed skill (${installedSkill}) is newer than package (${VERSION}); will not downgrade`);
    } else {
      printStep(`skill already at ${VERSION}`);
    }
  }
  const installedHarnesses = detectInstalledHarnesses();
  const hooksToRefresh = [];
  const hooksSkipped = [];
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
  if (skillMissing && hooksToRefresh.length === 0 && installedHarnesses.length === 0) {
    console.error(`${c.red("error:")} nothing to update — install the skill and/or hooks first`);
    console.error(`  ${c.dim("npx @dosx/agent-memory install skill")}`);
    console.error(`  ${c.dim("npx @dosx/agent-memory install hooks <harness>")}`);
    process.exit(1);
  }
  if (!needSkill && hooksToRefresh.length === 0) {
    blank();
    console.log(`${c.boldGreen("✓")} ${c.bold("Already up to date")} ${c.dim(VERSION)}`);
    if (skillMissing) {
      printStep(c.dim(`optional: npx @dosx/agent-memory install skill`));
    }
    printAgentNextSteps(memoryExists() ? "update" : "init");
    return;
  }
  if (!flags.yes) {
    if (!isTTY()) {
      failNonTTY("interactive update requires a TTY (or pass --yes).", [
        "npx @dosx/agent-memory update --yes"
      ]);
    }
    const planParts = [];
    if (needSkill)
      planParts.push(`skill ${installedSkill} → ${VERSION}`);
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
    hooksSkipped
  });
}
function parseUpdateFlags(args) {
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
function harnessOptions() {
  return CANONICAL_HARNESSES.map((h) => ({ label: h, value: h }));
}
var INSTALL_MODE_OPTIONS = [
  { label: "Skill + hooks", value: "both" },
  { label: "Skill only", value: "skill" },
  { label: "Hooks only", value: "hooks" }
];
function pickHarnesses() {
  return multiSelectPrompt("Select harnesses (Space to toggle):", harnessOptions());
}
function failNonTTY(message, hints) {
  console.error(`${c.red("error:")} ${message}`);
  for (const h of hints) {
    console.error(`  ${c.dim(h)}`);
  }
  process.exit(1);
}
function fatalUsage(message) {
  console.error(`${c.red("error:")} ${message}`);
  printHelp();
  process.exit(1);
}
async function promptInstallChoice(harness) {
  if (!isTTY()) {
    failNonTTY("interactive install requires a TTY.", [
      `Hooks: npx @dosx/agent-memory install hooks ${harness}`,
      "Skill: npx @dosx/agent-memory install skill"
    ]);
  }
  const choice = await selectPrompt(`Install agent-memory for ${harness}:`, INSTALL_MODE_OPTIONS);
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
async function promptInstallBare() {
  if (!isTTY()) {
    failNonTTY("interactive install requires a TTY.", [
      "Skill: npx @dosx/agent-memory install skill",
      "Hooks: npx @dosx/agent-memory install hooks <harness>"
    ]);
  }
  const mode = await selectPrompt("What do you want to install?", INSTALL_MODE_OPTIONS);
  if (mode === "skill") {
    printHeader("install · skill");
    printSummary({ skillPath: installSkill(), hooks: [] });
    return;
  }
  const selected = await pickHarnesses();
  printHeader(mode === "both" ? `install · skill + ${selected.join(", ")}` : `install · hooks · ${selected.join(", ")}`);
  const report = { hooks: selected };
  if (mode === "both") {
    report.skillPath = installSkill();
  }
  for (const h of selected) {
    installHooks(h);
  }
  printSummary(report);
}
async function promptHooksMultiSelect() {
  if (!isTTY()) {
    failNonTTY("interactive install hooks requires a TTY.", [
      "Hooks: npx @dosx/agent-memory install hooks <harness>"
    ]);
  }
  const selected = await pickHarnesses();
  printHeader(`install · hooks · ${selected.join(", ")}`);
  for (const h of selected) {
    installHooks(h);
  }
  printSummary({ hooks: selected });
}
async function main(argv) {
  const args = argv.slice(2);
  if (args.length === 0 || args[0] === "help" || args[0] === "--help" || args[0] === "-h") {
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
      console.error(`${c.red("error:")} install skill does not accept arguments`);
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
    const harness2 = normalizeHarness(raw);
    if (!harness2) {
      fatalUsage(`unknown harness: ${raw}`);
    }
    printHeader(`install · hooks · ${harness2}`);
    installHooks(harness2);
    printSummary({ hooks: [harness2] });
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
main(process.argv).catch((err) => {
  console.error(err);
  process.exit(1);
});
