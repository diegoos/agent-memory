// OpenCode plugin: deterministic agent-memory checkpoints.
// Spawns the shared shell scripts — no LLM call.
//
// OpenCode has no native sessionStart hook JSON; this plugin bridges plugin
// events to the same scripts used by Cursor, Claude, Codex, and Copilot.
//
// Install (see hooks/README.md):
//   hooks/shared/agent-memory-common.sh
//   hooks/shared/agent-memory-session.sh
//   hooks/shared/agent-memory-sync.sh  → .opencode/hooks/
//   this file → .opencode/plugin/agent-memory.ts

import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';

const HOOKS_DIR = '.opencode/hooks';
const SESSION_SCRIPT = `${HOOKS_DIR}/agent-memory-session.sh`;
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
    if (typeof candidate === 'string' && candidate.length > 0) return candidate;
  }
  const fromEnv = process.env.AGENT_MEMORY_SESSION_ID;
  return fromEnv && fromEnv.length > 0 ? fromEnv : undefined;
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
    if (typeof candidate === 'string' && candidate.length > 0) return candidate;
  }
  return undefined;
}

function runScript(
  script: string,
  event: string,
  host: string,
  sessionId?: string,
  conversationId?: string
): boolean {
  const scriptPath = path.join(process.cwd(), script);
  if (!fs.existsSync(scriptPath)) return false;
  const payload: Record<string, string> = {};
  if (sessionId) payload.session_id = sessionId;
  else if (conversationId) payload.conversation_id = conversationId;
  const stdinPayload =
    Object.keys(payload).length > 0 ? JSON.stringify(payload) : undefined;
  try {
    execFileSync('bash', [scriptPath], {
      env: {
        ...process.env,
        AGENT_MEMORY_HOST: host,
        AGENT_MEMORY_EVENT: event,
        AGENT_MEMORY_PROJECT_DIR: process.cwd(),
        ...(sessionId ? { AGENT_MEMORY_SESSION_ID: sessionId } : {}),
      },
      input: stdinPayload,
      stdio: ['pipe', 'ignore', 'ignore'],
      timeout: 15_000,
    });
    return true;
  } catch {
    return false;
  }
}

const sessionInitializedFor = new Set<string>();
const NO_SESSION_ID_KEY = '__no_session_id__';
let activeConversationId: string | undefined;

function clearScopeAndNoIdDedupeKeys(): void {
  sessionInitializedFor.delete(NO_SESSION_ID_KEY);
  for (const key of sessionInitializedFor) {
    if (key.startsWith('scope:')) sessionInitializedFor.delete(key);
  }
}

function extractOpenCodeSessionScope(input: unknown): string | undefined {
  if (!input || typeof input !== 'object') return undefined;
  const root = input as Record<string, unknown>;
  const event = root.event as Record<string, unknown> | undefined;
  const session = (event?.session ?? root.session) as
    | Record<string, unknown>
    | undefined;
  for (const candidate of [
    session?.id,
    session?.sessionID,
    session?.session_id,
    event?.id,
  ]) {
    if (typeof candidate === 'string' && candidate.length > 0) return candidate;
  }
  return undefined;
}

function ensureSessionStart(sessionId?: string, input?: unknown): void {
  const conversationId = extractConversationId(input) ?? activeConversationId;
  const freshConversationId = extractConversationId(input);
  const scopeId = extractOpenCodeSessionScope(input);
  if (freshConversationId && freshConversationId !== activeConversationId) {
    if (activeConversationId) {
      sessionInitializedFor.delete(`conv:${activeConversationId}`);
    }
    clearScopeAndNoIdDedupeKeys();
    activeConversationId = freshConversationId;
  } else if (freshConversationId) {
    activeConversationId = freshConversationId;
  }

  if (conversationId) {
    const convKey = `conv:${conversationId}`;
    if (sessionInitializedFor.has(convKey)) {
      if (sessionId) sessionInitializedFor.add(sessionId);
      return;
    }
    if (
      runScript(
        SESSION_SCRIPT,
        'sessionStart',
        'opencode',
        sessionId,
        conversationId
      )
    ) {
      sessionInitializedFor.add(convKey);
      if (sessionId) sessionInitializedFor.add(sessionId);
    }
    return;
  }

  if (sessionId) {
    if (sessionInitializedFor.has(sessionId)) return;
    if (runScript(SESSION_SCRIPT, 'sessionStart', 'opencode', sessionId)) {
      sessionInitializedFor.add(sessionId);
    }
    return;
  }

  const scopeKey = scopeId ? `scope:${scopeId}` : NO_SESSION_ID_KEY;
  if (sessionInitializedFor.has(scopeKey)) return;
  if (runScript(SESSION_SCRIPT, 'sessionStart', 'opencode', undefined)) {
    sessionInitializedFor.add(scopeKey);
  }
}

function runSync(event: string, sessionId?: string, input?: unknown): void {
  if (!hasMemory()) return;
  const conversationId = extractConversationId(input);
  ensureSessionStart(sessionId, input);
  runScript(SYNC_SCRIPT, event, 'opencode', sessionId, conversationId);
}

export const agentMemoryPlugin = async () => {
  if (!hasMemory()) return {};

  return {
    'experimental.session.compacting': async (input: unknown) => {
      const sessionId = extractSessionId(input);
      runSync('PreCompact', sessionId, input);
    },
    event: async (input: { event: { type: string } }) => {
      if (input?.event?.type === 'session.idle') {
        const sessionId = extractSessionId(input);
        runSync('Stop', sessionId, input);
      }
    },
  };
};

export default agentMemoryPlugin;
