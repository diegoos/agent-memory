#!/usr/bin/env bash
# Install or refresh agent-memory lifecycle hooks for one harness.
# Usage: bash install-hooks.sh <harness>
# Run from the target project root (or set AGENT_MEMORY_PROJECT_DIR).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/agent-memory-hooks"

# Prefer version from package.json when present; AGENT_MEMORY_VERSION only as
# fallback for standalone hooks-only checkouts (CLI always sets version from package).
if [[ -f "$SCRIPT_DIR/../package.json" ]] && command -v node >/dev/null 2>&1; then
  VERSION="$(
    node -p 'require(process.argv[1]).version' "$SCRIPT_DIR/../package.json" 2>/dev/null || true
  )"
fi
if [[ -z "${VERSION:-}" && -n "${AGENT_MEMORY_VERSION:-}" ]]; then
  VERSION="$AGENT_MEMORY_VERSION"
fi
VERSION="${VERSION:-0.2.1-rc.1}"

# No weak cd/pwd fallback: it skips symlink resolution, so a logical path
# could pass the under-project check while escaping it (parity with hooks).
resolve_realpath() {
  local p=$1
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p"
  else
    printf 'agent-memory: realpath or python3 required to resolve paths safely\n' >&2
    return 1
  fi
}

# Resolve project dir (absolute). Relative AGENT_MEMORY_PROJECT_DIR is allowed.
# Require an existing directory so realpath and python3 agree (no mkdir surprise).
_raw_project="${AGENT_MEMORY_PROJECT_DIR:-$(pwd)}"
if [[ ! -d "$_raw_project" ]]; then
  echo "error: PROJECT_DIR does not exist: $_raw_project" >&2
  exit 1
fi
PROJECT_DIR="$(resolve_realpath "$_raw_project")" || exit 1
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
  node "$SCRIPT_DIR/lib/merge-hooks.mjs" "$source" "$target" "$out" "$mode"
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
  for f in agent-memory-common.sh agent-memory-sync.sh agent-memory-session.sh \
    agent-memory-consume-evidence.sh agent-memory-print-evidence.sh; do
    [[ -f "$SHARED_DIR/$f" ]] || die "missing shared script: $SHARED_DIR/$f"
    safe_install_file "$SHARED_DIR/$f" "$PROJECT_DIR/$dest/$f"
    chmod +x "$PROJECT_DIR/$dest/$f"
  done
  echo "copied shared scripts → $dest/"
}

# Scripts first so a failed cp never leaves config pointing at missing files.
install_with_config() {
  local harness=$1 src=$2 tgt=$3 mode=$4
  install_shared_scripts "$(hooks_dir_for "$harness")"
  merge_into "$SCRIPT_DIR/$src" "$PROJECT_DIR/$tgt" "$mode"
  echo "merged $harness hooks config → $tgt"
}

install_cursor() {
  install_with_config cursor cursor/hooks.json .cursor/hooks.json flat
}

install_claude() {
  install_with_config claude claude-code/settings.json .claude/settings.json nested
}

install_codex() {
  install_with_config codex codex/hooks.json .codex/hooks.json nested
  echo "reminder: run /hooks in the Codex TUI to trust project hooks"
}

install_opencode() {
  install_shared_scripts "$(hooks_dir_for opencode)"
  # OpenCode auto-loads project plugins from .opencode/plugins/ (plural).
  local plugin_dir="$PROJECT_DIR/.opencode/plugins"
  safe_install_file \
    "$SCRIPT_DIR/opencode/agent-memory.ts" \
    "$plugin_dir/agent-memory.ts"
  safe_install_file \
    "$SCRIPT_DIR/opencode/safe-script.ts" \
    "$plugin_dir/safe-script.ts"
  echo "copied OpenCode plugin → .opencode/plugins/agent-memory.ts (+ safe-script.ts)"
  # Migrate pre-fix singular path (never auto-loaded by OpenCode).
  local legacy="$PROJECT_DIR/.opencode/plugin"
  local f
  for f in agent-memory.ts safe-script.ts; do
    if [[ -f "$legacy/$f" || -L "$legacy/$f" ]]; then
      if [[ -L "$legacy/$f" ]]; then
        die "refusing to remove symlink: $legacy/$f"
      fi
      rm -f "$legacy/$f"
      echo "removed legacy .opencode/plugin/$f"
    fi
  done
  if [[ -d "$legacy" ]] && [[ ! -L "$legacy" ]]; then
    rmdir "$legacy" 2>/dev/null || true
  fi
}

install_copilot() {
  install_shared_scripts "$(hooks_dir_for copilot)"
  local src="$SCRIPT_DIR/copilot/agent-memory.json"
  local tgt="$PROJECT_DIR/.github/hooks/agent-memory.json"
  if [[ ! -f "$tgt" ]]; then
    safe_install_file "$src" "$tgt"
    echo "copied copilot hooks → .github/hooks/agent-memory.json"
  else
    merge_into "$src" "$tgt" flat
    echo "merged copilot hooks → .github/hooks/agent-memory.json"
  fi
}

install_gemini() {
  install_with_config gemini gemini/settings.json .gemini/settings.json nested
}

main() {
  if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  [[ -d "$SHARED_DIR" ]] || die "shared hooks not found at $SHARED_DIR"

  local harness hooks_dir prereq
  harness="$(normalize_harness "$1")" || die "unknown harness: $1 (see --help)"
  hooks_dir="$(hooks_dir_for "$harness")"
  prereq="$(dirname "$hooks_dir")"

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

  # Same symlink refusal + temp+mv as safe_install_file (redirect would follow links).
  local version_file="$PROJECT_DIR/$hooks_dir/.version" version_tmp
  if [[ -L "$version_file" ]]; then
    die "refusing to overwrite symlink: $version_file"
  fi
  refuse_symlink_components "$version_file"
  ensure_resolved_under_project "$version_file"
  version_tmp="$(mktemp "${version_file}.XXXXXX")"
  printf '%s\n' "$VERSION" >"$version_tmp"
  mv "$version_tmp" "$version_file"
  echo "done: agent-memory hooks installed for $harness (v${VERSION})"
}

main "$@"
