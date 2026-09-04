// OpenCode plugin: ephemeral agent-memory checkpoints.
// Spawns the shared shell sync script — no LLM call, no Markdown writes.
//
// OpenCode has no native sessionStart hook JSON. Context comes from the
// AGENTS.md carrier wired by `/agent-memory init`. This plugin only runs
// end-of-turn / compact checkpoints into .hook-sync-state.
//
// Install (see hooks/README.md):
//   hooks/agent-memory-hooks/*.sh → .opencode/hooks/
//   this file + safe-script.ts → .opencode/plugins/ (OpenCode auto-load path)

import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  assertSafeHookScript,
  firstBindingId,
} from './safe-script';

const HOOKS_DIR = '.opencode/hooks';
const SYNC_SCRIPT = `${HOOKS_DIR}/agent-memory-sync.sh`;

type PluginCtx = {
  directory?: string;
  worktree?: string;
};

function resolveProjectDir(ctx?: PluginCtx): string {
  if (typeof ctx?.directory === 'string' && ctx.directory.length > 0) {
    return ctx.directory;
  }
  return process.cwd();
}

function hasMemory(projectDir: string): boolean {
  return fs.existsSync(path.join(projectDir, '.agents', 'memory'));
}

function bindingScopes(input: unknown): {
  root: Record<string, unknown>;
  event?: Record<string, unknown>;
  props?: Record<string, unknown>;
} | null {
  if (!input || typeof input !== 'object') return null;
  const root = input as Record<string, unknown>;
  const event = root.event as Record<string, unknown> | undefined;
  const props = event?.properties as Record<string, unknown> | undefined;
  return { root, event, props };
}

/** Payload only — never inherit process.env.AGENT_MEMORY_SESSION_ID (stale
 *  parent env must not rebind another workspace's .hook-sync-state). */
function extractBindingId(
  input: unknown,
  camel: string,
  snake: string
): string | undefined {
  const s = bindingScopes(input);
  if (!s) return undefined;
  return firstBindingId([
    s.root[camel],
    s.root[snake],
    s.event?.[camel],
    s.event?.[snake],
    s.props?.[camel],
    s.props?.[snake],
  ]);
}

/**
 * Env keys forwarded to hook scripts (avoid leaking full parent env).
 * Keep in sync with src/constants.ts ENV_ALLOWLIST_EXACT.
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
  // Locale (exact keys only — do not forward arbitrary LC_* names)
  'LC_ALL',
  'LC_CTYPE',
  'LC_MESSAGES',
  'LC_COLLATE',
  'LC_MONETARY',
  'LC_NUMERIC',
  'LC_TIME',
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
  // Git / XDG (paths to config files — intentional; see SECURITY.md)
  'XDG_CONFIG_HOME',
  'XDG_DATA_HOME',
  'GIT_CONFIG_GLOBAL',
  'GIT_CONFIG_SYSTEM',
  'GIT_CONFIG',
]);

function buildChildEnv(
  host: string,
  event: string,
  projectDir: string,
  sessionId?: string
): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const key of ENV_ALLOWLIST_EXACT) {
    const val = process.env[key];
    if (val !== undefined) env[key] = val;
  }
  env.AGENT_MEMORY_HOST = host;
  env.AGENT_MEMORY_EVENT = event;
  env.AGENT_MEMORY_PROJECT_DIR = projectDir;
  if (sessionId) env.AGENT_MEMORY_SESSION_ID = sessionId;
  return env;
}

function runScript(
  projectDir: string,
  script: string,
  event: string,
  host: string,
  sessionId?: string
): boolean {
  const scriptPath = assertSafeHookScript(projectDir, script, HOOKS_DIR);
  if (!scriptPath) {
    console.error(
      `agent-memory: OpenCode refusing unsafe or missing sync script (${script})`
    );
    return false;
  }
  const stdinPayload = sessionId
    ? JSON.stringify({ session_id: sessionId })
    : undefined;
  try {
    execFileSync('bash', [scriptPath], {
      cwd: projectDir,
      env: buildChildEnv(host, event, projectDir, sessionId),
      input: stdinPayload,
      stdio: ['pipe', 'ignore', 'pipe'],
      timeout: 15_000,
    });
    return true;
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    console.error(`agent-memory: OpenCode hook sync failed (${event}): ${detail}`);
    return false;
  }
}

function resolveBindingId(input: unknown): string | undefined {
  // Prefer conversation id — stable across OpenCode ses_* rotation within a
  // work stream. Fall back to session id when conversation is unavailable.
  return (
    extractBindingId(input, 'conversationID', 'conversation_id') ||
    extractBindingId(input, 'sessionID', 'session_id')
  );
}

function runSync(projectDir: string, event: string, input?: unknown): void {
  if (!hasMemory(projectDir)) return;
  const bindingId = resolveBindingId(input);
  // Pass binding as session_id so shared hooks treat it as the session key.
  runScript(projectDir, SYNC_SCRIPT, event, 'opencode', bindingId);
}

export const agentMemoryPlugin = async (ctx?: PluginCtx) => {
  const projectDir = resolveProjectDir(ctx);
  if (!hasMemory(projectDir)) return {};

  return {
    'experimental.session.compacting': async (input: unknown) => {
      runSync(projectDir, 'PreCompact', input);
    },
    event: async (input: { event: { type: string; sessionID?: string } }) => {
      const type = input?.event?.type;
      // idle = end of turn; compacted = after native compact (belt-and-suspenders
      // with experimental.session.compacting). DCP /dcp-compact does not emit these.
      if (type === 'session.idle' || type === 'session.compacted') {
        runSync(projectDir, type === 'session.compacted' ? 'PreCompact' : 'Stop', input);
      }
    },
  };
};

export default agentMemoryPlugin;
