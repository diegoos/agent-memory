/** Filesystem helpers and atomic skill install for the CLI. */
import fs from "node:fs";
import path from "node:path";
import { installedSkillDir, projectDir } from "./detect";

export type AtomicSkillInstallResult = {
  destRel: string;
  files: number;
  existed: boolean;
};

/**
 * Atomic replace: stage into a sibling temp dir, then swap. Removes obsolete
 * files from prior skill versions that a force-copy would leave behind.
 */
export function installSkillAtomic(opts: {
  skillSource: string;
  onError: (message: string) => never;
}): AtomicSkillInstallResult {
  const { skillSource, onError } = opts;
  if (!fs.existsSync(skillSource)) {
    onError(`missing skill at ${skillSource}`);
  }

  const dest = installedSkillDir();
  refuseSymlinkComponents(dest, onError);

  const existed = fs.existsSync(dest);
  const parent = path.dirname(dest);
  fs.mkdirSync(parent, { recursive: true });

  const staging = fs.mkdtempSync(path.join(parent, ".agent-memory-skill-"));
  const backup = `${dest}.bak-${process.pid}-${Date.now()}`;
  let movedAside = false;

  try {
    fs.cpSync(skillSource, staging, { recursive: true, force: true });
  } catch (err) {
    fs.rmSync(staging, { recursive: true, force: true });
    onError(
      `skill install failed: ${err instanceof Error ? err.message : String(err)}`,
    );
  }

  if (existed) {
    try {
      fs.renameSync(dest, backup);
      movedAside = true;
    } catch (err) {
      fs.rmSync(staging, { recursive: true, force: true });
      onError(
        `skill install failed: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  try {
    fs.renameSync(staging, dest);
  } catch {
    // Cross-device / platform: fall back to copy then remove staging.
    try {
      fs.cpSync(staging, dest, { recursive: true, force: true });
      fs.rmSync(staging, { recursive: true, force: true });
    } catch (err) {
      if (movedAside) {
        const ok = restoreBackup(backup, dest);
        fs.rmSync(staging, { recursive: true, force: true });
        if (!ok) {
          onError(
            `skill install failed and restore failed; previous skill left at ${backup}`,
          );
        }
        onError(
          `skill install failed: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
      // First install: leave staging contents in place as dest if possible.
      if (!fs.existsSync(dest) && fs.existsSync(staging)) {
        try {
          fs.renameSync(staging, dest);
        } catch {
          try {
            fs.cpSync(staging, dest, { recursive: true, force: true });
            fs.rmSync(staging, { recursive: true, force: true });
          } catch {
            fs.rmSync(staging, { recursive: true, force: true });
            onError(
              `skill install failed: ${err instanceof Error ? err.message : String(err)}`,
            );
          }
        }
        // Dest recovered via fallback — treat as success.
      } else {
        fs.rmSync(staging, { recursive: true, force: true });
        onError(
          `skill install failed: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
  }

  // New skill is in place — backup cleanup must not fail the install.
  if (movedAside && fs.existsSync(backup)) {
    try {
      fs.rmSync(backup, { recursive: true, force: true });
    } catch {
      /* non-fatal */
    }
  }

  return {
    destRel: relPath(dest),
    files: countFiles(dest),
    existed,
  };
}

function isSymlink(p: string): boolean {
  try {
    return fs.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

/** Refuse if dest or any existing parent under project is a symlink. */
function refuseSymlinkComponents(
  dest: string,
  onError: (message: string) => never,
): void {
  const project = path.resolve(projectDir());
  let cur = path.resolve(dest);
  while (true) {
    if (isSymlink(cur)) {
      onError(`refusing symlink in destination path: ${cur}`);
    }
    if (cur === project || cur === path.parse(cur).root) break;
    const parent = path.dirname(cur);
    if (parent === cur) break;
    cur = parent;
  }
}

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

function restoreBackup(backup: string, dest: string): boolean {
  if (!fs.existsSync(backup)) {
    return fs.existsSync(dest);
  }
  // Prefer the backup over any partial dest left by a failed promote.
  if (fs.existsSync(dest)) {
    try {
      fs.rmSync(dest, { recursive: true, force: true });
    } catch {
      return false;
    }
  }
  try {
    fs.renameSync(backup, dest);
    return true;
  } catch {
    try {
      fs.cpSync(backup, dest, { recursive: true, force: true });
      return true;
    } catch {
      return false;
    }
  }
}
