import * as fs from 'node:fs';
import * as path from 'node:path';

/** Session / conversation binding ids from harness stdin or env. */
const BINDING_ID_RE = /^[A-Za-z0-9._:@/-]{1,128}$/;

export function isValidBindingId(id: string): boolean {
  return BINDING_ID_RE.test(id);
}

/**
 * Resolve a hook script under hooksDir; refuse symlinks and paths outside hooksDir.
 * Returns absolute script path, or null when unsafe / missing.
 */
export function assertSafeHookScript(
  cwd: string,
  scriptRel: string,
  hooksDir: string
): string | null {
  const scriptPath = path.join(cwd, scriptRel);
  let stat: fs.Stats;
  try {
    stat = fs.lstatSync(scriptPath);
  } catch {
    return null;
  }
  if (!stat.isFile() || stat.isSymbolicLink()) return null;

  let scriptReal: string;
  let hooksReal: string;
  try {
    scriptReal = fs.realpathSync(scriptPath);
    hooksReal = fs.realpathSync(path.join(cwd, hooksDir));
  } catch {
    return null;
  }

  const prefix = hooksReal.endsWith(path.sep)
    ? hooksReal
    : hooksReal + path.sep;
  if (scriptReal !== hooksReal && !scriptReal.startsWith(prefix)) {
    return null;
  }

  return scriptReal;
}
