import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  assertSafeHookScript,
  isValidBindingId,
} from '../hooks/opencode/safe-script';

const HOOKS_DIR = '.opencode/hooks';
const SYNC_SCRIPT = `${HOOKS_DIR}/agent-memory-sync.sh`;

describe('isValidBindingId', () => {
  test('accepts harness-style ids', () => {
    expect(isValidBindingId('ses_abc')).toBe(true);
    expect(isValidBindingId('conv-stable')).toBe(true);
    expect(isValidBindingId('a:b/c@d.e-1')).toBe(true);
  });

  test('rejects metacharacters and empty', () => {
    expect(isValidBindingId('')).toBe(false);
    expect(isValidBindingId('id;rm')).toBe(false);
    expect(isValidBindingId('id\nx')).toBe(false);
    expect(isValidBindingId('a'.repeat(129))).toBe(false);
  });
});

describe('assertSafeHookScript', () => {
  let tmp: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'am-safe-'));
    fs.mkdirSync(path.join(tmp, HOOKS_DIR), { recursive: true });
    fs.writeFileSync(
      path.join(tmp, SYNC_SCRIPT),
      '#!/usr/bin/env bash\nexit 0\n',
      { mode: 0o755 }
    );
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  test('allows regular file under hooks dir', () => {
    const resolved = assertSafeHookScript(tmp, SYNC_SCRIPT, HOOKS_DIR);
    expect(resolved).toBe(fs.realpathSync(path.join(tmp, SYNC_SCRIPT)));
  });

  test('refuses symlink escape', () => {
    const outside = path.join(tmp, 'outside.sh');
    fs.writeFileSync(outside, '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 });
    fs.unlinkSync(path.join(tmp, SYNC_SCRIPT));
    fs.symlinkSync(outside, path.join(tmp, SYNC_SCRIPT));
    expect(assertSafeHookScript(tmp, SYNC_SCRIPT, HOOKS_DIR)).toBeNull();
  });

  test('returns null for missing script', () => {
    fs.unlinkSync(path.join(tmp, SYNC_SCRIPT));
    expect(assertSafeHookScript(tmp, SYNC_SCRIPT, HOOKS_DIR)).toBeNull();
  });
});
