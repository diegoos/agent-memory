import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  assertSafeHookScript,
  firstBindingId,
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

  test('rejects reserved __no_id__ sentinel (bash parity)', () => {
    expect(isValidBindingId('__no_id__')).toBe(false);
    expect(firstBindingId(['__no_id__', 'ses_ok'])).toBe('ses_ok');
  });
});

describe('firstBindingId', () => {
  test('skips invalid and returns next valid', () => {
    expect(firstBindingId(['bad;meta', 'live-ok', 'other'])).toBe('live-ok');
  });

  test('returns undefined when all invalid or empty', () => {
    expect(firstBindingId(['bad;meta', '', 'x\ny'])).toBeUndefined();
    expect(firstBindingId([])).toBeUndefined();
  });

  test('returns first valid without short-circuit on prior empty', () => {
    expect(firstBindingId([undefined, '', 'ses_ok'])).toBe('ses_ok');
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

  test('refuses hooks dir that resolves outside cwd', () => {
    const victim = fs.mkdtempSync(path.join(os.tmpdir(), 'am-victim-'));
    try {
      fs.mkdirSync(path.join(victim, HOOKS_DIR), { recursive: true });
      fs.writeFileSync(
        path.join(victim, SYNC_SCRIPT),
        '#!/usr/bin/env bash\nexit 0\n',
        { mode: 0o755 }
      );
      fs.rmSync(path.join(tmp, HOOKS_DIR), { recursive: true, force: true });
      fs.symlinkSync(path.join(victim, HOOKS_DIR), path.join(tmp, HOOKS_DIR));
      expect(assertSafeHookScript(tmp, SYNC_SCRIPT, HOOKS_DIR)).toBeNull();
    } finally {
      fs.rmSync(victim, { recursive: true, force: true });
    }
  });

  test('returns null for missing script', () => {
    fs.unlinkSync(path.join(tmp, SYNC_SCRIPT));
    expect(assertSafeHookScript(tmp, SYNC_SCRIPT, HOOKS_DIR)).toBeNull();
  });
});
