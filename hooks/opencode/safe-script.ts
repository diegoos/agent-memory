import * as fs from 'node:fs';
import * as path from 'node:path';

/** Mirrors hooks bash is_valid_external_binding_id (charset/length + no __no_id__). */
const BINDING_ID_RE = /^[A-Za-z0-9._:@/-]{1,128}$/;
const NO_ID_SESSION_SENTINEL = '__no_id__';

export function isValidBindingId(id: string): boolean {
  return BINDING_ID_RE.test(id) && id !== NO_ID_SESSION_SENTINEL;
}

/**
 * First non-empty candidate that passes isValidBindingId.
 * Invalid ids are skipped (do not short-circuit the list).
 */
export function firstBindingId(candidates: unknown[]): string | undefined {
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && candidate.length > 0) {
      if (isValidBindingId(candidate)) return candidate;
    }
  }
  return undefined;
}

/**
 * Resolve a hook script under hooksDir; refuse symlinks and paths outside
 * hooksDir. Also require hooksDir itself to resolve under cwd (no cross-project
 * dir symlink). Returns absolute script path, or null when unsafe / missing.
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
  let cwdReal: string;
  try {
    scriptReal = fs.realpathSync(scriptPath);
    hooksReal = fs.realpathSync(path.join(cwd, hooksDir));
    cwdReal = fs.realpathSync(cwd);
  } catch {
    return null;
  }

  const cwdPrefix = cwdReal.endsWith(path.sep) ? cwdReal : cwdReal + path.sep;
  if (hooksReal !== cwdReal && !hooksReal.startsWith(cwdPrefix)) {
    return null;
  }

  const hooksPrefix = hooksReal.endsWith(path.sep)
    ? hooksReal
    : hooksReal + path.sep;
  if (scriptReal !== hooksReal && !scriptReal.startsWith(hooksPrefix)) {
    return null;
  }

  return scriptReal;
}
