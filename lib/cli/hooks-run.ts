/** Spawn helpers and env allowlist for hooks installer. */
import { spawnSync } from "node:child_process";
import { ENV_ALLOWLIST_EXACT } from "./constants";
import { projectDir } from "./detect";

/** Always shell:false — argv must not be re-parsed by cmd.exe. */
export function runCaptured(
  command: string,
  args: string[],
  options: {
    env?: NodeJS.ProcessEnv;
    onSpawnError: (message: string) => never;
    onCommandFail: (stderr: string, status: number | null) => never;
  },
): { stdout: string; stderr: string } {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env: options.env,
    shell: false,
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

export function buildInstallerEnv(version: string): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {
    AGENT_MEMORY_PROJECT_DIR: projectDir(),
    AGENT_MEMORY_VERSION: version,
  };
  for (const key of Object.keys(process.env)) {
    if (ENV_ALLOWLIST_EXACT.has(key) || key.startsWith("LC_")) {
      const val = process.env[key];
      if (val !== undefined) env[key] = val;
    }
  }
  return env;
}
