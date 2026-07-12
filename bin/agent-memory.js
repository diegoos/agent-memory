#!/usr/bin/env node
'use strict';

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const VERSION = require('../package.json').version;
const INSTALL_HOOKS_SH = path.join(ROOT, 'hooks', 'install-hooks.sh');
const LOCAL_SKILL_DIR = path.join(ROOT, 'skills', 'agent-memory');
const PINNED_SKILL_URL = `https://github.com/diegoos/agent-memory/tree/v${VERSION}/skills/agent-memory`;

/** Safe charset for skills CLI --agent values (no shell metacharacters). */
const AGENT_NAME_RE = /^[A-Za-z0-9._-]+$/;

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

function normalizeHarness(name) {
  if (CANONICAL_HARNESSES.has(name)) return name;
  return HARNESS_ALIASES[name] || null;
}

function printHelp() {
  console.log(`agent-memory ${VERSION}

Usage:
  agent-memory install skill [-g|--global] [-a|--agent <agent> ...]
  agent-memory install hooks <harness>    # alias: install hook
  agent-memory install <harness> [skill flags...]  # skill + hooks
  agent-memory help

Harnesses: cursor, claude (claude-code), codex, opencode, copilot (github), gemini

Skill flags: -g/--global, -a/--agent <name>, -y/--yes, --all, --copy

Examples:
  npx --yes github:diegoos/agent-memory#v${VERSION} -- install cursor
  npx --yes github:diegoos/agent-memory#v${VERSION} -- install hooks cursor
  npx --yes github:diegoos/agent-memory#v${VERSION} -- install skill
`);
}

/** Always shell:false — argv must not be re-parsed by cmd.exe. */
function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: 'inherit',
    shell: false,
    ...options,
  });
  if (result.error) {
    console.error(`error: ${result.error.message}`);
    process.exit(1);
  }
  if (typeof result.status === 'number' && result.status !== 0) {
    process.exit(result.status);
  }
}

function assertAgentName(val, flag) {
  if (!AGENT_NAME_RE.test(val)) {
    console.error(
      `error: invalid agent name for ${flag}: ${val} (use [A-Za-z0-9._-]+ only)`
    );
    process.exit(1);
  }
}

/** Parse skill CLI flags; rejects unknown tokens. */
function parseSkillFlags(args) {
  const out = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (
      a === '-g' ||
      a === '--global' ||
      a === '-y' ||
      a === '--yes' ||
      a === '--all' ||
      a === '--copy'
    ) {
      out.push(a);
      continue;
    }
    if (a === '-a' || a === '--agent') {
      const val = args[i + 1];
      if (!val || val.startsWith('-')) {
        console.error(`error: ${a} requires a value`);
        process.exit(1);
      }
      assertAgentName(val, a);
      out.push(a, val);
      i++;
      continue;
    }
    if (a.startsWith('--agent=')) {
      const val = a.slice('--agent='.length);
      assertAgentName(val, '--agent');
      out.push(a);
      continue;
    }
    if (a.startsWith('-')) {
      console.error(`error: unknown flag: ${a}`);
      process.exit(1);
    }
    console.error(`error: unexpected argument: ${a}`);
    process.exit(1);
  }
  return out;
}

function skillSource() {
  if (fs.existsSync(path.join(LOCAL_SKILL_DIR, 'SKILL.md'))) {
    return LOCAL_SKILL_DIR;
  }
  return PINNED_SKILL_URL;
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

function installSkill(extraArgs) {
  const flags = parseSkillFlags(extraArgs);
  const source = skillSource();
  const args = ['--yes', 'skills', 'add', source, '--skill', 'agent-memory', ...flags];
  // On Windows, prefer npx.cmd so shell:false still resolves the shim.
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

function main(argv) {
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
    installSkill(rest.slice(1));
    return;
  }

  if (rest[0] === 'hooks' || rest[0] === 'hook') {
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
    installSkill(rest.slice(1));
    installHooks(harness);
    return;
  }

  console.error(`error: unknown install target: ${rest[0]}`);
  printHelp();
  process.exit(1);
}

main(process.argv);
