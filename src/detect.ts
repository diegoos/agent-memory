/** Harness detection and path helpers for the installer CLI. */
import fs from "node:fs";
import path from "node:path";
import {
  CANONICAL_HARNESSES,
  HARNESS_ALIASES,
  HARNESS_HOOKS_DIR,
  type Harness,
} from "./constants";

export function projectDir(): string {
  const fromEnv = process.env.AGENT_MEMORY_PROJECT_DIR;
  if (fromEnv) return fromEnv;
  return process.cwd();
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

function fileContains(filePath: string, needle: string): boolean {
  try {
    return fs.readFileSync(filePath, "utf8").includes(needle);
  } catch {
    return false;
  }
}

export function detectInstalledHarnesses(): Harness[] {
  const root = projectDir();
  const found: Harness[] = [];
  if (
    fs.existsSync(path.join(root, ".cursor", "hooks", "agent-memory-sync.sh")) ||
    fileContains(path.join(root, ".cursor", "hooks.json"), "agent-memory")
  ) {
    found.push("cursor");
  }
  if (fs.existsSync(path.join(root, ".claude", "hooks", "agent-memory-sync.sh"))) {
    found.push("claude");
  }
  if (fs.existsSync(path.join(root, ".codex", "hooks", "agent-memory-sync.sh"))) {
    found.push("codex");
  }
  if (
    fs.existsSync(path.join(root, ".opencode", "plugins", "agent-memory.ts")) ||
    // Legacy singular path (pre-fix; OpenCode never auto-loaded it)
    fs.existsSync(path.join(root, ".opencode", "plugin", "agent-memory.ts")) ||
    fs.existsSync(path.join(root, ".opencode", "hooks", "agent-memory-sync.sh"))
  ) {
    found.push("opencode");
  }
  if (
    fs.existsSync(path.join(root, ".github", "hooks", "agent-memory.json")) ||
    fs.existsSync(path.join(root, ".github", "hooks", "agent-memory-sync.sh"))
  ) {
    found.push("copilot");
  }
  if (
    fs.existsSync(path.join(root, ".gemini", "hooks", "agent-memory-sync.sh")) ||
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
