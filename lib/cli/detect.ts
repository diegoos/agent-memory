/** Harness detection and path helpers for the installer CLI. */
import fs from "node:fs";
import path from "node:path";
import {
  CANONICAL_HARNESSES,
  HARNESS_ALIASES,
  HARNESS_HOOKS_DIR,
  HARNESS_SET,
  type Harness,
} from "./constants";

export function projectDir(): string {
  return process.env.AGENT_MEMORY_PROJECT_DIR || process.cwd();
}

export function installedSkillDir(): string {
  return path.join(projectDir(), ".agents", "skills", "agent-memory");
}

export function readSkillVersionFromDir(skillDir: string): string | null {
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

export function readInstalledSkillVersion(): string | null {
  return readSkillVersionFromDir(installedSkillDir());
}

export function readInstalledHooksVersion(harness: Harness): string | null {
  const stamp = path.join(projectDir(), HARNESS_HOOKS_DIR[harness], ".version");
  if (!fs.existsSync(stamp)) return null;
  const v = fs.readFileSync(stamp, "utf8").trim();
  return v || null;
}

export function fileContains(filePath: string, needle: string): boolean {
  try {
    return fs.readFileSync(filePath, "utf8").includes(needle);
  } catch {
    return false;
  }
}

export function detectInstalledHarnesses(): Harness[] {
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

export function memoryExists(): boolean {
  return fs.existsSync(path.join(projectDir(), ".agents", "memory"));
}

export function normalizeHarness(name: string): Harness | null {
  if (HARNESS_SET.has(name)) return name as Harness;
  return HARNESS_ALIASES[name] ?? null;
}

export { CANONICAL_HARNESSES, HARNESS_HOOKS_DIR };
