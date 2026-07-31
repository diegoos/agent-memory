// OpenCode plugin: ephemeral agent-memory checkpoints.
// Spawns the shared shell sync script — no LLM call, no Markdown writes.
//
// OpenCode has no native sessionStart hook JSON. Context comes from the
// AGENTS.md carrier wired by `/agent-memory init`. This plugin only runs
// end-of-turn / compact ephemeral checkpoints into .hook-sync-state.
//
// Install (see hooks/README.md):
//   hooks/agent-memory-hooks/agent-memory-common.sh
//   hooks/agent-memory-hooks/agent-memory-session.sh
//   hooks/agent-memory-hooks/agent-memory-sync.sh  → .opencode/hooks/
//   this file → .opencode/plugin/agent-memory.ts

import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  assertSafeHookScript,
  isValidBindingId,
} from './safe-script';

const HOOKS_DIR = '.opencode/hooks';
const SYNC_SCRIPT = `${HOOKS_DIR}/agent-memory-sync.sh`;

function hasMemory(): boolean {
  return fs.existsSync(path.join(process.cwd(), '.agents', 'memory'));
}

function extractSessionId(input: unknown): string | undefined {
  if (!input || typeof input !== 'object') return undefined;
  const root = input as Record<string, unknown>;
  const event = root.event as Record<string, unknown> | undefined;
  const props = event?.properties as Record<string, unknown> | undefined;
  for (const candidate of [
    root.sessionID,
    root.session_id,
    event?.sessionID,
    event?.session_id,
    props?.sessionID,
    props?.session_id,
  ]) {
    if (typeof candidate === 'string' && candidate.length > 0) {
      return isValidBindingId(candidate) ? candidate : undefined;
    }
  }
  const fromEnv = process.env.AGENT_MEMORY_SESSION_ID;
  return fromEnv && isValidBindingId(fromEnv) ? fromEnv : undefined;
}

function extractConversationId(input: unknown): string | undefined {
  if (!input || typeof input !== 'object') return undefined;
  const root = input as Record<string, unknown>;
  const event = root.event as Record<string, unknown> | undefined;
  const props = event?.properties as Record<string, unknown> | undefined;
  for (const candidate of [
    root.conversationID,
    root.conversation_id,
    event?.conversationID,
    event?.conversation_id,
    props?.conversationID,
    props?.conversation_id,
  ]) {
    if (typeof candidate === 'string' && candidate.length > 0) {
      return isValidBindingId(candidate) ? candidate : undefined;
    }
  }
  return undefined;
}

/**
 * Env keys forwarded to hook scripts (avoid leaking full parent env).
 * Keep in sync with install.ts ENV_ALLOWLIST_EXACT.
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
  // Git / XDG
  'XDG_CONFIG_HOME',
  'XDG_DATA_HOME',
  'GIT_CONFIG_GLOBAL',
  'GIT_CONFIG_SYSTEM',
  'GIT_CONFIG',
]);

function buildChildEnv(
  host: string,
  event: string,
  sessionId?: string
): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const key of Object.keys(process.env)) {
    if (ENV_ALLOWLIST_EXACT.has(key) || key.startsWith('LC_')) {
      const val = process.env[key];
      if (val !== undefined) env[key] = val;
    }
  }
  env.AGENT_MEMORY_HOST = host;
  env.AGENT_MEMORY_EVENT = event;
  env.AGENT_MEMORY_PROJECT_DIR = process.cwd();
  if (sessionId) env.AGENT_MEMORY_SESSION_ID = sessionId;
  return env;
}

function runScript(
  script: string,
  event: string,
  host: string,
  sessionId?: string,
  conversationId?: string
): boolean {
  const cwd = process.cwd();
  const scriptPath = assertSafeHookScript(cwd, script, HOOKS_DIR);
  if (!scriptPath) return false;
  const payload: Record<string, string> = {};
  if (sessionId) payload.session_id = sessionId;
  else if (conversationId) payload.conversation_id = conversationId;
  const stdinPayload =
    Object.keys(payload).length > 0 ? JSON.stringify(payload) : undefined;
  try {
    execFileSync('bash', [scriptPath], {
      cwd,
      env: buildChildEnv(host, event, sessionId),
      input: stdinPayload,
      stdio: ['pipe', 'ignore', 'ignore'],
      timeout: 15_000,
    });
    return true;
  } catch {
    return false;
  }
}

function resolveBindingId(input: unknown): string | undefined {
  // Prefer conversation id — stable across OpenCode ses_* rotation within a
  // work stream. Fall back to session id when conversation is unavailable.
  return extractConversationId(input) || extractSessionId(input);
}

function runSync(event: string, input?: unknown): void {
  if (!hasMemory()) return;
  const bindingId = resolveBindingId(input);
  // Pass binding as session_id so shared hooks treat it as the session key.
  runScript(SYNC_SCRIPT, event, 'opencode', bindingId);
}

export const agentMemoryPlugin = async () => {
  if (!hasMemory()) return {};

  return {
    'experimental.session.compacting': async (input: unknown) => {
      runSync('PreCompact', input);
    },
    event: async (input: { event: { type: string; sessionID?: string } }) => {
      if (input?.event?.type === 'session.idle') {
        runSync('Stop', input);
      }
    },
  };
};

export default agentMemoryPlugin;
