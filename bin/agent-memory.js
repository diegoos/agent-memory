#!/usr/bin/env node
'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const VERSION = require('../package.json').version;
const INSTALL_HOOKS_SH = path.join(ROOT, 'hooks', 'install-hooks.sh');
const REMOTE_SKILL_SOURCE = `diegoos/agent-memory#${VERSION}`;

const CANONICAL_HARNESSES = new Set([
  'cursor',
  'claude',
  'codex',
  'opencode',
  'copilot',
  'gemini',
]);

const HARNESS_ALIASES = {
  'claude-code': 'claude',
  github: 'copilot',
};

/**
 * Env keys forwarded to install-hooks.sh (keep in sync with OpenCode
 * ENV_ALLOWLIST_EXACT + prefixes in hooks/opencode/agent-memory.ts).
 */
const ENV_ALLOWLIST_EXACT = new Set([
  'PATH',
  'HOME',
  'USER',
  'SHELL',
  'TMPDIR',
  'TMP',
  'TEMP',
  'LANG',
  'TZ',
  // Windows
  'SystemRoot',
  'SYSTEMROOT',
  'windir',
  'WINDIR',
  'USERPROFILE',
  'HOMEDRIVE',
  'HOMEPATH',
  'ComSpec',
  'COMSPEC',
  'PATHEXT',
  // Git / XDG (safe.directory and config discovery)
  'XDG_CONFIG_HOME',
  'XDG_DATA_HOME',
  'GIT_CONFIG_GLOBAL',
  'GIT_CONFIG_SYSTEM',
  'GIT_CONFIG',
]);

const ESC = '\u001b';
const CSI = `${ESC}[`;

function normalizeHarness(name) {
  if (CANONICAL_HARNESSES.has(name)) return name;
  return HARNESS_ALIASES[name] || null;
}

function isTTY() {
  return process.stdin.isTTY === true && process.stdout.isTTY === true;
}

function skillsAddCommandText() {
  return `npx --yes skills add ${REMOTE_SKILL_SOURCE} --skill agent-memory`;
}

function printHelp() {
  console.log(`agent-memory ${VERSION}

Hooks installer for @dos/agent-memory. The skill is installed separately
via npx skills add (not this CLI).

Usage:
  agent-memory install hooks <harness>
  agent-memory install <harness>          # interactive menu (TTY)
  agent-memory install skill              # redirect to npx skills add
  agent-memory help

Harnesses: cursor, claude (claude-code), codex, opencode, copilot (github), gemini

Examples:
  npx @dos/agent-memory install hooks cursor
  npx @dos/agent-memory install cursor
  npx skills add diegoos/agent-memory#${VERSION} --skill agent-memory
`);
}

/** Always shell:false — argv must not be re-parsed by cmd.exe. */
function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: 'inherit',
    ...options,
    shell: false,
  });
  if (result.error) {
    console.error(`error: ${result.error.message}`);
    process.exit(1);
  }
  if (result.signal) {
    process.exit(1);
  }
  if (result.status === null || result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function buildInstallerEnv() {
  const env = {
    AGENT_MEMORY_PROJECT_DIR:
      process.env.AGENT_MEMORY_PROJECT_DIR || process.cwd(),
    AGENT_MEMORY_VERSION: VERSION,
  };
  for (const key of Object.keys(process.env)) {
    if (ENV_ALLOWLIST_EXACT.has(key) || key.startsWith('LC_')) {
      const val = process.env[key];
      if (val !== undefined) env[key] = val;
    }
  }
  return env;
}

function runSkillsAdd() {
  const args = [
    '--yes',
    'skills',
    'add',
    REMOTE_SKILL_SOURCE,
    '--skill',
    'agent-memory',
  ];
  const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
  run(npx, args);
}

function installHooks(harness) {
  if (!fs.existsSync(INSTALL_HOOKS_SH)) {
    console.error(`error: missing installer at ${INSTALL_HOOKS_SH}`);
    process.exit(1);
  }
  const bash = process.platform === 'win32' ? 'bash.exe' : 'bash';
  run(bash, [INSTALL_HOOKS_SH, harness], { env: buildInstallerEnv() });
}

function renderSelectLines(title, options, selected) {
  const lines = [title, ''];
  for (let i = 0; i < options.length; i++) {
    const active = i === selected;
    const prefix = active ? `${ESC}[1m› ` : '  ';
    const suffix = active ? `${ESC}[22m` : '';
    lines.push(`${prefix}${options[i].label}${suffix}`);
  }
  lines.push('', '↑/↓ or j/k · Enter confirm · Ctrl+C/Esc cancel');
  return lines;
}

function clearRenderedLines(lineCount) {
  for (let i = 0; i < lineCount; i++) {
    process.stdout.write(`${CSI}1A${CSI}2K`);
  }
}

/**
 * Interactive single-select menu (TTY only). Returns the chosen option value.
 * Aborts with exit 1 on Ctrl+C or Esc.
 */
function selectPrompt(title, options) {
  return new Promise((resolve) => {
    let selected = 0;
    let renderedLineCount = 0;
    let escState = 'normal';
    let escTimer = null;
    let rawModeEnabled = false;
    const stdin = process.stdin;

    function disableRawMode() {
      if (rawModeEnabled && typeof stdin.setRawMode === 'function') {
        stdin.setRawMode(false);
        rawModeEnabled = false;
      }
    }

    function clearEscTimer() {
      if (escTimer) {
        clearTimeout(escTimer);
        escTimer = null;
      }
    }

    function isCsiFinal(ch) {
      const code = ch.charCodeAt(0);
      return code >= 0x40 && code <= 0x7e;
    }

    function isAlphanumeric(ch) {
      return /[0-9A-Za-z]/.test(ch);
    }

    function startEscTimer() {
      clearEscTimer();
      escTimer = setTimeout(() => {
        escTimer = null;
        if (escState === 'esc') {
          escState = 'normal';
          abort();
          return;
        }
        if (escState === 'csi' || escState === 'ss3') {
          escState = 'normal';
        }
      }, 50);
    }

    function moveUp() {
      selected = (selected - 1 + options.length) % options.length;
      redraw();
    }

    function moveDown() {
      selected = (selected + 1) % options.length;
      redraw();
    }

    function abort() {
      cleanup();
      process.stdout.write('\n');
      process.exit(1);
    }

    function cleanup() {
      clearEscTimer();
      disableRawMode();
      stdin.pause();
      stdin.removeListener('data', onData);
      stdin.removeListener('end', onEnd);
    }

    function printMenu() {
      const lines = renderSelectLines(title, options, selected);
      lines.forEach((line) => process.stdout.write(`${line}\n`));
      renderedLineCount = lines.length;
    }

    function redraw() {
      clearRenderedLines(renderedLineCount);
      printMenu();
    }

    function processChar(ch) {
      if (escState === 'esc') {
        clearEscTimer();
        if (ch === '[') {
          escState = 'csi';
          startEscTimer();
          return;
        }
        if (ch === 'O') {
          escState = 'ss3';
          startEscTimer();
          return;
        }
        if (isAlphanumeric(ch)) {
          escState = 'normal';
        } else {
          escState = 'normal';
          abort();
          return;
        }
      }

      if (escState === 'csi') {
        if (!isCsiFinal(ch)) {
          startEscTimer();
          return;
        }
        clearEscTimer();
        escState = 'normal';
        if (ch === 'A') {
          moveUp();
          return;
        }
        if (ch === 'B') {
          moveDown();
          return;
        }
        return;
      }

      if (escState === 'ss3') {
        if (!isCsiFinal(ch)) {
          startEscTimer();
          return;
        }
        clearEscTimer();
        escState = 'normal';
        if (ch === 'A') {
          moveUp();
          return;
        }
        if (ch === 'B') {
          moveDown();
          return;
        }
        return;
      }

      if (ch === '\u0003') {
        abort();
        return;
      }
      if (ch === ESC) {
        escState = 'esc';
        startEscTimer();
        return;
      }
      if (ch === 'k') {
        moveUp();
        return;
      }
      if (ch === 'j') {
        moveDown();
        return;
      }
      if (ch === '\r' || ch === '\n') {
        cleanup();
        process.stdout.write('\n');
        resolve(options[selected].value);
      }
    }

    function onData(chunk) {
      for (let i = 0; i < chunk.length; i++) {
        processChar(chunk[i]);
      }
    }

    function onEnd() {
      abort();
    }

    let setupComplete = false;
    try {
      if (typeof stdin.setRawMode === 'function') {
        stdin.setRawMode(true);
        rawModeEnabled = true;
      }
      stdin.resume();
      stdin.setEncoding('utf8');
      stdin.on('data', onData);
      stdin.on('end', onEnd);
      printMenu();
      setupComplete = true;
    } finally {
      if (!setupComplete) {
        disableRawMode();
      }
    }
  });
}

function failNonTTYInstallChoice(harness) {
  console.error('error: interactive install requires a TTY.');
  console.error(`  Hooks: npx @dos/agent-memory install hooks ${harness}`);
  console.error(`  Skill: ${skillsAddCommandText()}`);
  process.exit(1);
}

function failNonTTYSkillsAdd() {
  console.error('error: interactive install requires a TTY.');
  console.error(`  Skill: ${skillsAddCommandText()}`);
  process.exit(1);
}

async function promptInstallChoice(harness) {
  if (!isTTY()) {
    failNonTTYInstallChoice(harness);
  }

  const choice = await selectPrompt(`Install agent-memory for ${harness}:`, [
    { label: 'Skill + hooks', value: 'both' },
    { label: 'Skill only', value: 'skill' },
    { label: 'Hooks only', value: 'hooks' },
  ]);

  if (choice === 'both') {
    runSkillsAdd();
    installHooks(harness);
    return;
  }
  if (choice === 'skill') {
    runSkillsAdd();
    return;
  }
  installHooks(harness);
}

async function promptSkillsAddOrCancel() {
  const choice = await selectPrompt('Continue?', [
    { label: 'Run npx skills add', value: 'run' },
    { label: 'Cancel', value: 'cancel' },
  ]);

  if (choice === 'run') {
    runSkillsAdd();
    return;
  }
  process.exit(0);
}

async function main(argv) {
  const args = argv.slice(2);
  if (
    args.length === 0 ||
    args[0] === 'help' ||
    args[0] === '--help' ||
    args[0] === '-h'
  ) {
    printHelp();
    return;
  }

  if (args[0] !== 'install') {
    console.error(`error: unknown command: ${args[0]}`);
    printHelp();
    process.exit(1);
  }

  const rest = args.slice(1);
  if (rest.length === 0) {
    console.error('error: missing install target');
    printHelp();
    process.exit(1);
  }

  if (rest[0] === 'skill') {
    if (rest.length > 1) {
      console.error('error: install skill does not accept arguments');
      process.exit(1);
    }
    if (!isTTY()) {
      failNonTTYSkillsAdd();
    }
    console.log('This CLI installs hooks only. Install the skill with:');
    console.log(`  ${skillsAddCommandText()}`);
    await promptSkillsAddOrCancel();
    return;
  }

  if (rest[0] === 'hooks') {
    const raw = rest[1];
    if (!raw) {
      console.error('error: install hooks requires a harness argument');
      printHelp();
      process.exit(1);
    }
    if (rest.length > 2) {
      console.error(`error: unexpected argument: ${rest[2]}`);
      process.exit(1);
    }
    const harness = normalizeHarness(raw);
    if (!harness) {
      console.error(`error: unknown harness: ${raw}`);
      printHelp();
      process.exit(1);
    }
    installHooks(harness);
    return;
  }

  const harness = normalizeHarness(rest[0]);
  if (harness) {
    if (rest.length > 1) {
      console.error(`error: unexpected argument: ${rest[1]}`);
      process.exit(1);
    }
    await promptInstallChoice(harness);
    return;
  }

  console.error(`error: unknown install target: ${rest[0]}`);
  printHelp();
  process.exit(1);
}

main(process.argv).catch((err) => {
  console.error(err);
  process.exit(1);
});
