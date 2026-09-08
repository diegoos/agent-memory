/** Harness detection and path helpers for the installer CLI. */
import fs from "node:fs";
import path from "node:path";
import {
  CANONICAL_HARNESSES,
  HARNESS_ALIASES,
  HARNESS_HOOKS_DIR,
  SHARED_HOOK_SCRIPTS,
  type Harness,
} from "./constants";

export function projectDir(): string {
  const fromEnv = process.env.AGENT_MEMORY_PROJECT_DIR;
  const raw = fromEnv && fromEnv.length > 0 ? fromEnv : process.cwd();
  try {
    return fs.realpathSync(raw);
  } catch {
    return path.resolve(raw);
  }
}

export function installedSkillDir(): string {
  return path.join(projectDir(), ".agents", "skills", "agent-memory");
}

function readSkillVersionFromDir(skillDir: string): string | null {
  const skillMd = path.join(skillDir, "SKILL.md");
  if (!fs.existsSync(skillMd)) return null;
  const text = fs.readFileSync(skillMd, "utf8");
  const m = text.match(
    /^metadata:\s*\n(?:[ \t]+.+\n)*?[ \t]+version:\s*["']?([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)["']?/m,
  );
  if (m) return m[1];
  // Fallback when the metadata block layout differs from the strict form.
  const loose = text.match(
    /version:\s*["']([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)["']/,
  );
  return loose ? loose[1] : null;
}

export function readInstalledSkillVersion(): string | null {
  return readSkillVersionFromDir(installedSkillDir());
}

export function readInstalledHooksVersion(harness: Harness): string | null {
  const stamp = path.join(projectDir(), HARNESS_HOOKS_DIR[harness], ".version");
  if (!fs.existsSync(stamp)) return null;
  const v = fs.readFileSync(stamp, "utf8").trim();
  return v || null;
}

export function hooksInstallComplete(harness: Harness): boolean {
  const root = projectDir();
  const dir = path.join(root, HARNESS_HOOKS_DIR[harness]);
  for (const f of SHARED_HOOK_SCRIPTS) {
    if (!fs.existsSync(path.join(dir, f))) return false;
  }
  if (harness === "opencode") {
    const plugins = path.join(root, ".opencode", "plugins");
    if (!fs.existsSync(path.join(plugins, "agent-memory.ts"))) return false;
    if (!fs.existsSync(path.join(plugins, "safe-script.ts"))) return false;
  }
  return true;
}

function fileContains(filePath: string, needle: string): boolean {
  try {
    return fs.readFileSync(filePath, "utf8").includes(needle);
  } catch {
    return false;
  }
}

function hookSyncPath(root: string, harness: Harness): string {
  return path.join(root, HARNESS_HOOKS_DIR[harness], "agent-memory-sync.sh");
}

export function detectInstalledHarnesses(): Harness[] {
  const root = projectDir();
  const found: Harness[] = [];
  if (
    fs.existsSync(hookSyncPath(root, "cursor")) ||
    fileContains(path.join(root, ".cursor", "hooks.json"), "agent-memory")
  ) {
    found.push("cursor");
  }
  if (fs.existsSync(hookSyncPath(root, "claude"))) {
    found.push("claude");
  }
  if (fs.existsSync(hookSyncPath(root, "codex"))) {
    found.push("codex");
  }
  if (
    fs.existsSync(path.join(root, ".opencode", "plugins", "agent-memory.ts")) ||
    // Legacy singular path (pre-fix; OpenCode never auto-loaded it)
    fs.existsSync(path.join(root, ".opencode", "plugin", "agent-memory.ts")) ||
    fs.existsSync(hookSyncPath(root, "opencode"))
  ) {
    found.push("opencode");
  }
  if (
    fs.existsSync(path.join(root, ".github", "hooks", "agent-memory.json")) ||
    fs.existsSync(hookSyncPath(root, "copilot"))
  ) {
    found.push("copilot");
  }
  if (
    fs.existsSync(hookSyncPath(root, "gemini")) ||
    fileContains(path.join(root, ".gemini", "settings.json"), "agent-memory")
  ) {
    found.push("gemini");
  }
  return found;
}

function memoryExists(): boolean {
  return fs.existsSync(path.join(projectDir(), ".agents", "memory"));
}

export function nextSkillCommand(): "init" | "update" {
  return memoryExists() ? "update" : "init";
}

export function normalizeHarness(name: string): Harness | null {
  if ((CANONICAL_HARNESSES as readonly string[]).includes(name)) {
    return name as Harness;
  }
  return HARNESS_ALIASES[name] ?? null;
}
