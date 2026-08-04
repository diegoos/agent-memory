/**
 * Resolve package root at runtime (local checkout or npx cache). Skill/hooks
 * install always from this tree — never clone GitHub. Do not use __dirname —
 * Bun `--format cjs` may bake it to the build-time source directory (breaks npx).
 */
import fs from "node:fs";
import path from "node:path";

export function resolvePackageRoot(): string {
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
