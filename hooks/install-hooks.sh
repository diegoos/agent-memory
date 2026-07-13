#!/usr/bin/env bash
# Install or refresh agent-memory lifecycle hooks for one harness.
# Usage: bash install-hooks.sh <harness>
# Run from the target project root (or set AGENT_MEMORY_PROJECT_DIR).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_ROOT="$SCRIPT_DIR"
SHARED_DIR="$HOOKS_ROOT/agent-memory-hooks"

# Prefer version from CLI / package; fall back for standalone checkout.
if [[ -n "${AGENT_MEMORY_VERSION:-}" ]]; then
  VERSION="$AGENT_MEMORY_VERSION"
elif [[ -f "$SCRIPT_DIR/../package.json" ]] && command -v node >/dev/null 2>&1; then
  VERSION="$(
    node -p 'require(process.argv[1]).version' "$SCRIPT_DIR/../package.json" 2>/dev/null || true
  )"
fi
VERSION="${VERSION:-0.0.13}"

# Resolve project dir (absolute). Relative AGENT_MEMORY_PROJECT_DIR is allowed.
# Require an existing directory so realpath and python3 agree (no mkdir surprise).
_raw_project="${AGENT_MEMORY_PROJECT_DIR:-$(pwd)}"
if [[ ! -d "$_raw_project" ]]; then
  echo "error: PROJECT_DIR does not exist: $_raw_project" >&2
  exit 1
fi
if command -v realpath >/dev/null 2>&1; then
  PROJECT_DIR="$(realpath "$_raw_project")"
elif command -v python3 >/dev/null 2>&1; then
  PROJECT_DIR="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$_raw_project")"
else
  PROJECT_DIR="$(cd "$_raw_project" && pwd)"
fi
unset _raw_project

usage() {
  cat <<EOF
Usage: bash install-hooks.sh <harness>

Install or refresh agent-memory lifecycle hooks into the current project.

Harnesses: cursor, claude (claude-code), codex, opencode, copilot (github), gemini

Version: ${VERSION}
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

resolve_realpath() {
  local p=$1
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p"
  else
    printf '%s\n' "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  fi
}

# Walk PROJECT_DIR → dest; refuse if any existing component is a symlink.
refuse_symlink_components() {
  local dest=$1 cur rest part
  if [[ "$dest" != "$PROJECT_DIR"/* ]]; then
    die "destination escapes project: $dest"
  fi
  cur="$PROJECT_DIR"
  rest="${dest#"$PROJECT_DIR"/}"
  while [[ -n "$rest" ]]; do
    if [[ "$rest" == */* ]]; then
      part="${rest%%/*}"
      rest="${rest#*/}"
    else
      part="$rest"
      rest=""
    fi
    cur="$cur/$part"
    if [[ -e "$cur" || -L "$cur" ]] && [[ -L "$cur" ]]; then
      die "refusing symlink in destination path: $cur"
    fi
  done
}

# After mkdir -p, ensure the resolved parent stays under PROJECT_DIR.
ensure_resolved_under_project() {
  local dest=$1 dir parent
  dir="$(dirname "$dest")"
  mkdir -p "$dir"
  parent="$(resolve_realpath "$dir")" || die "cannot resolve parent: $dir"
  case "$parent" in
    "$PROJECT_DIR" | "$PROJECT_DIR"/*) ;;
    *) die "resolved parent escapes project: $parent" ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

normalize_harness() {
  case "$1" in
    cursor) echo cursor ;;
    claude | claude-code) echo claude ;;
    codex) echo codex ;;
    opencode) echo opencode ;;
    copilot | github) echo copilot ;;
    gemini) echo gemini ;;
    *) return 1 ;;
  esac
}

prereq_dir_for() {
  case "$1" in
    cursor) echo .cursor ;;
    claude) echo .claude ;;
    codex) echo .codex ;;
    opencode) echo .opencode ;;
    copilot) echo .github ;;
    gemini) echo .gemini ;;
  esac
}

hooks_dir_for() {
  case "$1" in
    cursor) echo .cursor/hooks ;;
    claude) echo .claude/hooks ;;
    codex) echo .codex/hooks ;;
    opencode) echo .opencode/hooks ;;
    copilot) echo .github/hooks ;;
    gemini) echo .gemini/hooks ;;
  esac
}

# Copy src → dest without following a destination symlink (refuse + abort).
# Uses temp + mv so a regular-file replace does not follow links.
safe_install_file() {
  local src=$1 dest=$2 tmp
  [[ -f "$src" ]] || die "missing source: $src"
  if [[ -L "$dest" ]]; then
    die "refusing to overwrite symlink: $dest"
  fi
  refuse_symlink_components "$dest"
  ensure_resolved_under_project "$dest"
  tmp="$(mktemp "${dest}.XXXXXX")"
  cp "$src" "$tmp"
  mv "$tmp" "$dest"
}

# Merge agent-memory hook entries into an existing JSON config.
# Args: source_json target_json out_json mode
# mode: flat (cursor/copilot — hooks.<event> = array)
#       nested (claude/codex/gemini — hooks.<event> = [{matcher?, hooks: [...]}])
merge_hooks_json() {
  local source=$1 target=$2 out=$3 mode=$4
  need_cmd node
  node --input-type=module - "$source" "$target" "$out" "$mode" <<'NODE'
import fs from 'node:fs';

const [sourcePath, targetPath, outPath, mode] = process.argv.slice(2);
const src = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
let tgt = {};
if (fs.existsSync(targetPath)) {
  tgt = JSON.parse(fs.readFileSync(targetPath, 'utf8'));
}

/**
 * Product hook entries invoke our scripts by path/basename, optionally with
 * AGENT_MEMORY_* env prefixes. Do not match mere mentions of the filenames
 * (e.g. docs/agent-memory-sync.sh.example).
 */
const isOurs = (value) => {
  const s = typeof value === 'string' ? value : JSON.stringify(value);
  return /(?:^|[\s/"'=])(?:[\w./-]*\/)?agent-memory-(?:session|sync|common)\.sh(?:$|[\s"'])/.test(
    s
  );
};

const asHooksObject = (hooks) => {
  if (hooks && typeof hooks === 'object' && !Array.isArray(hooks)) return hooks;
  return {};
};

/** Nested groups: strip only our command entries; keep sibling custom hooks. */
const scrubNestedGroup = (group) => {
  if (!group || typeof group !== 'object' || Array.isArray(group)) return null;
  const next = { ...group };
  if (Array.isArray(next.hooks)) {
    next.hooks = next.hooks.filter((entry) => !isOurs(entry));
    if (next.hooks.length === 0) return null;
  } else if (isOurs(group)) {
    return null;
  }
  return next;
};

if (mode === 'flat') {
  if (src.version != null && tgt.version == null) tgt.version = src.version;
  tgt.hooks = asHooksObject(tgt.hooks);
  const srcHooks = src.hooks || {};
  for (const [event, entries] of Object.entries(srcHooks)) {
    const existing = Array.isArray(tgt.hooks[event]) ? tgt.hooks[event] : [];
    const kept = existing.filter((e) => !isOurs(e));
    tgt.hooks[event] = [...kept, ...(Array.isArray(entries) ? entries : [])];
  }
} else if (mode === 'nested') {
  tgt.hooks = asHooksObject(tgt.hooks);
  const srcHooks = src.hooks || {};
  for (const [event, groups] of Object.entries(srcHooks)) {
    const existing = Array.isArray(tgt.hooks[event]) ? tgt.hooks[event] : [];
    const kept = [];
    for (const group of existing) {
      const scrubbed = scrubNestedGroup(group);
      if (scrubbed) kept.push(scrubbed);
    }
    tgt.hooks[event] = [...kept, ...(Array.isArray(groups) ? groups : [])];
  }
} else {
  console.error(`unknown merge mode: ${mode}`);
  process.exit(1);
}

fs.writeFileSync(outPath, `${JSON.stringify(tgt, null, 2)}\n`);
NODE
}

# Write merged JSON to a temp file beside the target, then replace atomically.
# Refuse if the target path is a symlink (same trust rule as safe_install_file).
merge_into() {
  local src=$1 tgt=$2 mode=$3 tmp
  if [[ -L "$tgt" ]]; then
    die "refusing to overwrite symlink: $tgt"
  fi
  refuse_symlink_components "$tgt"
  ensure_resolved_under_project "$tgt"
  tmp="$(mktemp "${tgt}.XXXXXX")"
  # If target missing, merge still works (empty tgt).
  if ! merge_hooks_json "$src" "$tgt" "$tmp" "$mode"; then
    rm -f "$tmp"
    die "failed to merge hooks config into $tgt"
  fi
  mv "$tmp" "$tgt"
}

install_shared_scripts() {
  local dest=$1
  local f
  for f in agent-memory-common.sh agent-memory-sync.sh agent-memory-session.sh; do
    [[ -f "$SHARED_DIR/$f" ]] || die "missing shared script: $SHARED_DIR/$f"
    safe_install_file "$SHARED_DIR/$f" "$PROJECT_DIR/$dest/$f"
    chmod +x "$PROJECT_DIR/$dest/$f"
  done
  echo "copied shared scripts → $dest/"
}

install_cursor() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for cursor)"
  local src="$HOOKS_ROOT/cursor/hooks.json"
  local tgt="$PROJECT_DIR/.cursor/hooks.json"
  # Scripts first so a failed cp never leaves config pointing at missing files.
  install_shared_scripts "$hooks_dir"
  merge_into "$src" "$tgt" flat
  echo "merged cursor hooks → .cursor/hooks.json"
}

install_claude() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for claude)"
  local src="$HOOKS_ROOT/claude-code/settings.json"
  local tgt="$PROJECT_DIR/.claude/settings.json"
  install_shared_scripts "$hooks_dir"
  merge_into "$src" "$tgt" nested
  echo "merged claude settings → .claude/settings.json"
}

install_codex() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for codex)"
  local src="$HOOKS_ROOT/codex/hooks.json"
  local tgt="$PROJECT_DIR/.codex/hooks.json"
  install_shared_scripts "$hooks_dir"
  merge_into "$src" "$tgt" nested
  echo "merged codex hooks → .codex/hooks.json"
  echo "reminder: run /hooks in the Codex TUI to trust project hooks"
}

install_opencode() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for opencode)"
  install_shared_scripts "$hooks_dir"
  safe_install_file \
    "$HOOKS_ROOT/opencode/agent-memory.ts" \
    "$PROJECT_DIR/.opencode/plugin/agent-memory.ts"
  echo "copied OpenCode plugin → .opencode/plugin/agent-memory.ts"
}

install_copilot() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for copilot)"
  local src="$HOOKS_ROOT/copilot/agent-memory.json"
  local tgt="$PROJECT_DIR/.github/hooks/agent-memory.json"
  install_shared_scripts "$hooks_dir"
  if [[ ! -f "$tgt" ]]; then
    safe_install_file "$src" "$tgt"
    echo "copied copilot hooks → .github/hooks/agent-memory.json"
  else
    merge_into "$src" "$tgt" flat
    echo "merged copilot hooks → .github/hooks/agent-memory.json"
  fi
}

install_gemini() {
  local hooks_dir
  hooks_dir="$(hooks_dir_for gemini)"
  local src="$HOOKS_ROOT/gemini/settings.json"
  local tgt="$PROJECT_DIR/.gemini/settings.json"
  install_shared_scripts "$hooks_dir"
  merge_into "$src" "$tgt" nested
  echo "merged gemini settings → .gemini/settings.json"
}

main() {
  if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  [[ -d "$SHARED_DIR" ]] || die "shared hooks not found at $SHARED_DIR"

  local harness
  harness="$(normalize_harness "$1")" || die "unknown harness: $1 (see --help)"

  local prereq
  prereq="$(prereq_dir_for "$harness")"
  refuse_symlink_components "$PROJECT_DIR/$prereq"
  if [[ ! -d "$PROJECT_DIR/$prereq" ]]; then
    ensure_resolved_under_project "$PROJECT_DIR/$prereq/.install-sentinel"
    rm -f "$PROJECT_DIR/$prereq/.install-sentinel"
    echo "created $prereq/"
  fi

  case "$harness" in
    cursor) install_cursor ;;
    claude) install_claude ;;
    codex) install_codex ;;
    opencode) install_opencode ;;
    copilot) install_copilot ;;
    gemini) install_gemini ;;
  esac

  echo "done: agent-memory hooks installed for $harness (v${VERSION})"
}

main "$@"
