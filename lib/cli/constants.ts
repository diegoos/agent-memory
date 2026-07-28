/** Shared CLI types and harness constants for @dosx/agent-memory. */

export const CANONICAL_HARNESSES = [
  "cursor",
  "claude",
  "codex",
  "opencode",
  "copilot",
  "gemini",
] as const;

export type Harness = (typeof CANONICAL_HARNESSES)[number];

export const HARNESS_ALIASES: Record<string, Harness> = {
  "claude-code": "claude",
  github: "copilot",
};

export const HARNESS_SET = new Set<string>(CANONICAL_HARNESSES);

export const HARNESS_HOOKS_DIR: Record<Harness, string> = {
  cursor: ".cursor/hooks",
  claude: ".claude/hooks",
  codex: ".codex/hooks",
  opencode: ".opencode/hooks",
  copilot: ".github/hooks",
  gemini: ".gemini/hooks",
};

/**
 * Env keys forwarded to install-hooks.sh (keep in sync with OpenCode
 * ENV_ALLOWLIST_EXACT + prefixes in hooks/opencode/agent-memory.ts).
 */
export const ENV_ALLOWLIST_EXACT = new Set([
  "PATH",
  "HOME",
  "USER",
  "SHELL",
  "TMPDIR",
  "TMP",
  "TEMP",
  "LANG",
  "TZ",
  // Windows
  "SystemRoot",
  "SYSTEMROOT",
  "windir",
  "WINDIR",
  "USERPROFILE",
  "HOMEDRIVE",
  "HOMEPATH",
  "ComSpec",
  "COMSPEC",
  "PATHEXT",
  // Git / XDG
  "XDG_CONFIG_HOME",
  "XDG_DATA_HOME",
  "GIT_CONFIG_GLOBAL",
  "GIT_CONFIG_SYSTEM",
  "GIT_CONFIG",
]);

export type SelectOption<T extends string> = { label: string; value: T };

export type InstallReport = {
  skillPath?: string;
  hooks: Harness[];
};
