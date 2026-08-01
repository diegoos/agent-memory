# agent-memory shared helpers — source from session/sync hooks only.
# Deterministic, evidence-backed updates only (git + harness session ID).
#
# Hooks own ephemeral evidence in .hook-sync-state ONLY:
#   current_session_id, branch, session_touched_files, last_processed_head
# Hooks NEVER create or edit Markdown under .agents/memory/.
# See instructions.md → Harness parity — memory contract.
#
# Expects after agent_memory_init_context: cwd, memory, state_file globals.

# Filled by parse_hook_stdin (optional).
hook_stdin_session_id=""
hook_stdin_cwd=""

# Record separator for multi-path state values.
RS=$'\x1e'

# Read harness stdin without blocking forever when fd 0 is open but idle (CLI).
read_hook_stdin() {
  local line rest=""
  [ -t 0 ] && return 0
  if IFS= read -r -t 1 line; then
    rest="$line"
    while IFS= read -r -t 1 line; do
      rest+="$line"$'\n'
      [ ${#rest} -gt 1048576 ] && break
    done
  fi
  printf '%s' "$rest"
}

# Extract a quoted string value for a JSON field from a harness payload.
json_string_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

if [ -z "${_AMC_HAVE_JQ:-}" ]; then
  if command -v jq >/dev/null 2>&1; then _AMC_HAVE_JQ=1; else _AMC_HAVE_JQ=0; fi
fi

parse_hook_stdin() {
  local input="${1:-}"
  hook_stdin_session_id=""
  hook_stdin_cwd=""
  [ -n "$input" ] || return 0
  if [ "$_AMC_HAVE_JQ" -eq 1 ]; then
    local parsed rest
    parsed=$(printf '%s' "$input" | jq -r '
      [ (.session_id // .conversation_id // .sessionId // ""),
        (.cwd // (.workspace_roots[0] // ""))
      ] | @tsv')
    hook_stdin_session_id=${parsed%%$'\t'*}
    hook_stdin_cwd=${parsed#*$'\t'}
  else
    hook_stdin_session_id=$(json_string_field "$input" session_id)
    [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(json_string_field "$input" conversation_id)
    [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(json_string_field "$input" sessionId)
    hook_stdin_cwd=$(json_string_field "$input" cwd)
    if [ -z "$hook_stdin_cwd" ]; then
      hook_stdin_cwd=$(printf '%s' "$input" | sed -n \
        's/.*"workspace_roots"[[:space:]]*:\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi
  fi
}

agent_memory_resolve_realpath() {
  local p=$1
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || return 1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null || return 1
  else
    printf '%s\n' "$(cd "$(dirname "$p")" 2>/dev/null && pwd)/$(basename "$p")"
  fi
}

agent_memory_path_under_root() {
  local child=$1 root=$2
  case "$child" in
    "$root" | "$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

agent_memory_refuse_symlink_file() {
  local path=$1
  if [ -L "$path" ]; then
    printf 'agent-memory: refused symlink memory path: %s\n' "$path" >&2
    return 1
  fi
  return 0
}

agent_memory_refuse_symlink_parents_under_memory() {
  local dest=$1 cur rest part mem="$memory"
  case "$dest" in
    "$mem" | "$mem"/*) ;;
    *) return 0 ;;
  esac
  agent_memory_refuse_symlink_file "$dest" || return 1
  cur="$mem"
  rest="${dest#"$mem"/}"
  [ "$rest" = "$dest" ] && [ "$dest" != "$mem" ] && return 0
  while [ -n "$rest" ]; do
    if [ "${rest#*/}" != "$rest" ]; then
      part="${rest%%/*}"
      rest="${rest#*/}"
    else
      part="$rest"
      rest=""
    fi
    cur="$cur/$part"
    if { [ -e "$cur" ] || [ -L "$cur" ]; } && [ -L "$cur" ]; then
      printf 'agent-memory: refused symlink in memory path: %s\n' "$cur" >&2
      return 1
    fi
  done
  return 0
}

agent_memory_guard_memory_path() {
  agent_memory_refuse_symlink_parents_under_memory "$1"
}

agent_memory_init_context() {
  local hook_input="" cwd_real mem_real
  if [ ! -t 0 ]; then
    hook_input=$(read_hook_stdin)
  fi
  parse_hook_stdin "$hook_input"
  cwd=$(resolve_project_dir "$hook_stdin_cwd")
  memory="$cwd/.agents/memory"
  if [ -d "$memory" ] || [ -L "$memory" ]; then
    cwd_real=$(agent_memory_resolve_realpath "$cwd") || return 1
    mem_real=$(agent_memory_resolve_realpath "$memory") || return 1
    if ! agent_memory_path_under_root "$mem_real" "$cwd_real"; then
      printf 'agent-memory: memory path escapes project: %s\n' "$memory" >&2
      return 1
    fi
  fi
  state_file="$memory/.hook-sync-state"
}

resolve_project_dir() {
  local stdin_cwd="${1:-}"
  if [ -n "${AGENT_MEMORY_PROJECT_DIR:-}" ]; then printf '%s' "$AGENT_MEMORY_PROJECT_DIR"; return; fi
  if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then printf '%s' "$CURSOR_PROJECT_DIR"; return; fi
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s' "$CLAUDE_PROJECT_DIR"; return; fi
  if [ -n "${CODEX_PROJECT_DIR:-}" ]; then printf '%s' "$CODEX_PROJECT_DIR"; return; fi
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then printf '%s' "$GITHUB_WORKSPACE"; return; fi
  if [ -n "${GEMINI_PROJECT_DIR:-}" ]; then printf '%s' "$GEMINI_PROJECT_DIR"; return; fi
  if [ -n "$stdin_cwd" ]; then printf '%s' "$stdin_cwd"; return; fi
  printf '%s' "${PWD:-.}"
}

# Second arg: allow_state_fallback (1=sync default, 0=sessionStart — no stale ID).
NO_ID_SESSION_SENTINEL="__no_id__"

resolve_session_id() {
  local stdin_sid="${1:-}"
  local allow_state_fallback="${2:-1}"
  if [ -n "${AGENT_MEMORY_SESSION_ID:-}" ]; then printf '%s' "$AGENT_MEMORY_SESSION_ID"; return; fi
  if [ -n "${CURSOR_SESSION_ID:-}" ]; then printf '%s' "$CURSOR_SESSION_ID"; return; fi
  if [ -n "${GEMINI_SESSION_ID:-}" ]; then printf '%s' "$GEMINI_SESSION_ID"; return; fi
  if [ -n "$stdin_sid" ]; then printf '%s' "$stdin_sid"; return; fi
  if [ "$allow_state_fallback" = "1" ]; then
    # session_binding is canonical (reset_session_state_if_changed). Prefer it
    # over current_session_id so a stale current cannot resurrect the wrong
    # session or clear/retain paths incorrectly when the fields diverge.
    local from_current from_binding
    from_binding=$(read_state session_binding "")
    if [ -n "$from_binding" ]; then
      if [ "$from_binding" != "$NO_ID_SESSION_SENTINEL" ]; then
        printf '%s' "$from_binding"
      else
        printf ''
      fi
      return
    fi
    from_current=$(read_state current_session_id "")
    if [ -n "$from_current" ]; then printf '%s' "$from_current"; return; fi
    printf ''
  else
    printf ''
  fi
}

persist_session_id() {
  local sid="${1:-}"
  # Keep current_session_id aligned with the resolved id. Clearing on empty
  # prevents a stale current from surviving after binding moved to __no_id__.
  write_state current_session_id "$sid"
}

_clear_session_path_state() {
  agent_memory_with_state_lock _clear_session_path_state_body
}

_clear_session_path_state_body() {
  # Clearing wrong-branch/session paths is safety-critical: even under fail-open,
  # prefer emptying session_touched_files over keeping stale evidence.
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: clearing paths fail-open (lock not held)\n' >&2
  fi
  _write_state_unlocked session_touched_files ""
}

_write_state_body() {
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip write_state %s (lock not held)\n' "$1" >&2
    return 1
  fi
  _write_state_unlocked "$@"
}

_today_ymd() {
  date +%Y-%m-%d
}

_write_session_binding() {
  # Single lock + single rewrite for all three keys — avoid torn metadata.
  agent_memory_with_state_lock _write_session_binding_body "$1"
}

_write_session_binding_body() {
  # Under fail-open, skip full-file rewrite (stale snapshot could drop other keys).
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip session binding write (lock not held)\n' >&2
    return 0
  fi
  _rebind_session_state_unlocked 0 "$1"
}

# Atomically update session_binding (+ host/day) and optionally clear paths.
# Under fail-open, skips entirely — never wipe paths without updating binding.
_rebind_session_state() {
  agent_memory_with_state_lock _rebind_session_state_body "$1" "$2"
}

_rebind_session_state_body() {
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip session rebind (lock not held)\n' >&2
    return 0
  fi
  _rebind_session_state_unlocked "$1" "$2"
}

_rebind_session_state_unlocked() {
  local clear_paths=$1 sid=$2
  local host="${AGENT_MEMORY_HOST:-}"
  local day tmp
  day=$(_today_ymd)
  if [ -z "$host" ]; then
    host=$(read_state session_binding_host "")
  fi
  case "$sid" in
    *$'\n'* | *$'\r'*)
      printf 'agent-memory: write_session_binding refused newline in sid\n' >&2
      return 1
      ;;
  esac
  case "$host" in
    *$'\n'* | *$'\r'*)
      printf 'agent-memory: write_session_binding refused newline in host\n' >&2
      return 1
      ;;
  esac
  if [ -L "${state_file:-}" ]; then
    printf 'agent-memory: write_session_binding refused symlink state file: %s\n' \
      "$state_file" >&2
    return 1
  fi
  agent_memory_guard_memory_path "$state_file" || return 1
  tmp=$(mktemp "${state_file}.XXXXXX")
  if [ -f "$state_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "${line%%=*}" in
        session_binding | session_binding_host | session_binding_day) continue ;;
        session_touched_files)
          [ "$clear_paths" = "1" ] && continue
          ;;
      esac
      printf '%s\n' "$line"
    done <"$state_file" >"$tmp"
  else
    : >"$tmp"
  fi
  if [ "$clear_paths" = "1" ]; then
    printf 'session_touched_files=\n' >>"$tmp"
  fi
  printf 'session_binding=%s\n' "$sid" >>"$tmp"
  printf 'session_binding_host=%s\n' "$host" >>"$tmp"
  printf 'session_binding_day=%s\n' "$day" >>"$tmp"
  mv "$tmp" "$state_file"
}

# True when prior OpenCode binding is still on today's calendar day.
_opencode_binding_same_day() {
  local bound_day
  bound_day=$(read_state session_binding_day "")
  [ -n "$bound_day" ] && [ "$bound_day" = "$(_today_ymd)" ]
}

# True when rebinding session id should keep accumulated paths (same work stream).
# Clears on a real session change, cross-harness bind, or OpenCode day rollover.
_session_rebind_preserves_paths() {
  local sid=$1 last=$2
  local last_host
  # First bind or upgrade from unknown id — keep any paths already collected.
  if [ -z "$last" ] || [ "$last" = "$NO_ID_SESSION_SENTINEL" ]; then
    return 0
  fi
  # OpenCode: ses_* rotation and conversation_id ↔ ses_* only when the prior
  # binding was also written by OpenCode on the same calendar day.
  if [ "${AGENT_MEMORY_HOST:-}" = "opencode" ]; then
    last_host=$(read_state session_binding_host "")
    # Legacy state without host/day: do not preserve across ses_* churn.
    if [ -z "$last_host" ]; then
      return 1
    fi
    if [ "$last_host" = "opencode" ] && _opencode_binding_same_day; then
      case "$sid:$last" in
        ses_*:ses_* | ses_*:?* | ?*:ses_*)
          return 0
          ;;
      esac
    fi
  fi
  return 1
}

# Bind session and clear path accumulation when the session changes.
# State key: session_binding (legacy logged_files_session is migrated on read).
reset_session_state_if_changed() {
  local sid=$1 context="${2:-sync}"
  local last bound_day clear_paths
  sid="${sid:-}"
  last=$(read_state session_binding "")
  if [ -z "$last" ]; then
    last=$(read_state logged_files_session "")
  fi
  # Checkpoint without a resolvable session id (e.g. git pre-commit): keep the
  # current binding and paths — do not demote to __no_id__.
  if [ -z "$sid" ] && [ "$context" != "sessionStart" ]; then
    return 0
  fi
  if [ -n "$sid" ]; then
    if [ "$sid" = "$last" ]; then
      # Same id can still cross midnight — drop yesterday's OpenCode paths.
      # Missing session_binding_day (legacy) is treated as unknown/stale day.
      if [ "${AGENT_MEMORY_HOST:-}" = "opencode" ]; then
        bound_day=$(read_state session_binding_day "")
        if [ -z "$bound_day" ] || [ "$bound_day" != "$(_today_ymd)" ]; then
          _rebind_session_state 1 "$sid"
        fi
      fi
      return 0
    fi
    clear_paths=1
    if _session_rebind_preserves_paths "$sid" "$last"; then
      clear_paths=0
    fi
    _rebind_session_state "$clear_paths" "$sid"
    return 0
  fi
  if [ "$context" = "sessionStart" ]; then
    if [ "$last" = "$NO_ID_SESSION_SENTINEL" ]; then
      return 0
    fi
    _rebind_session_state 1 "$NO_ID_SESSION_SENTINEL"
    return 0
  fi
  [ "$last" = "$NO_ID_SESSION_SENTINEL" ] && return 0
  if [ -z "$last" ]; then
    _write_session_binding "$NO_ID_SESSION_SENTINEL"
    return 0
  fi
  _rebind_session_state 1 "$NO_ID_SESSION_SENTINEL"
}

refresh_branch_cache() {
  [ -n "${cwd:-}" ] || return 0
  local b
  b=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  [ -n "$b" ] || return 0
  agent_memory_with_state_lock _refresh_branch_cache_unlocked "$b"
}

_refresh_branch_cache_unlocked() {
  local b=$1 last
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip branch cache refresh (lock not held)\n' >&2
    return 0
  fi
  last=$(read_state branch "")
  if [ "$last" = "$b" ]; then
    return 0
  fi
  _write_state_unlocked branch "$b"
  if [ -n "$last" ]; then
    _write_state_unlocked session_touched_files ""
  fi
}

sanitize_branch() {
  local b="${1:-}"
  if [ -z "$b" ]; then
    b=$(read_state branch "")
    [ -z "$b" ] && b=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  fi
  printf '%s' "$b" | tr -c 'A-Za-z0-9._-' '-'
}

# Portable lock around state mutations. Fail-open after timeout so harnesses
# are never blocked. Only the process that acquired the lock may remove it.
# Sets AGENT_MEMORY_LOCK_ACQUIRED=1|0 for the locked body.
_state_lock_is_stale() {
  local lock_dir=$1
  local pid
  pid=$(cat "$lock_dir/pid" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  # No live holder (missing/dead pid) — safe to steal.
  return 0
}

agent_memory_with_state_lock() {
  local lock_dir="${state_file}.lock"
  local waited=0
  local max_wait=20
  local acquired=0
  local stole=0
  while true; do
    if mkdir "$lock_dir" 2>/dev/null; then
      printf '%s\n' "$$" >"$lock_dir/pid" 2>/dev/null || true
      acquired=1
      break
    fi
    waited=$((waited + 1))
    if [ "$waited" -ge "$max_wait" ]; then
      if [ "$stole" = "0" ] && _state_lock_is_stale "$lock_dir"; then
        printf 'agent-memory: removing stale state lock\n' >&2
        rm -rf "$lock_dir" 2>/dev/null || true
        stole=1
        waited=0
        continue
      fi
      printf 'agent-memory: state lock busy; proceeding fail-open\n' >&2
      break
    fi
    sleep 0.05 2>/dev/null || sleep 1
  done
  AGENT_MEMORY_LOCK_ACQUIRED=$acquired
  "$@"
  local status=$?
  unset AGENT_MEMORY_LOCK_ACQUIRED
  if [ "$acquired" = "1" ]; then
    rm -rf "$lock_dir" 2>/dev/null || true
  fi
  return $status
}

read_state() {
  local key=$1 default=$2
  if [ -L "${state_file:-}" ]; then
    printf 'agent-memory: read_state refused symlink state file: %s\n' "$state_file" >&2
    printf '%s' "$default"
    return 1
  fi
  [ -f "$state_file" ] || { printf '%s' "$default"; return; }
  awk -v k="$key" '
    {
      pos = index($0, "=")
      if (pos > 0 && substr($0, 1, pos - 1) == k) {
        print substr($0, pos + 1)
        found = 1
        exit
      }
    }
    END { if (!found) print "" }
  ' "$state_file"
}

_write_state_unlocked() {
  local key=$1 val=$2
  local tmp cur
  case "$key" in
    '' | *[!A-Za-z0-9_]* | *$'\n'* | *$'\r'*)
      printf 'agent-memory: write_state refused invalid key: %s\n' "$key" >&2
      return 1
      ;;
  esac
  case "$val" in
    *$'\n'* | *$'\r'*)
      printf 'agent-memory: write_state refused newline in %s\n' "$key" >&2
      return 1
      ;;
  esac
  if [ -L "${state_file:-}" ]; then
    printf 'agent-memory: write_state refused symlink state file: %s\n' "$state_file" >&2
    return 1
  fi
  agent_memory_guard_memory_path "$state_file" || return 1
  cur=$(read_state "$key" "")
  if [ -f "$state_file" ] && [ "$cur" = "$val" ]; then
    return 0
  fi
  tmp=$(mktemp "${state_file}.XXXXXX")
  if [ -f "$state_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ "${line%%=*}" = "$key" ] && continue
      printf '%s\n' "$line"
    done <"$state_file" >"$tmp"
  else
    : >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$state_file"
}

write_state() {
  agent_memory_with_state_lock _write_state_body "$@"
}

agent_memory_include_commit_files="${agent_memory_include_commit_files:-0}"

list_worktree_changes() {
  {
    git -C "$cwd" diff --name-only 2>/dev/null || true
    git -C "$cwd" diff --cached --name-only 2>/dev/null || true
    git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u | grep -vE '^\.agents/memory/|^$' || true
}

# Include every commit since last_processed_head (not only tip).
list_non_memory_changes() {
  {
    list_worktree_changes
    if [ "$agent_memory_include_commit_files" = "1" ]; then
      local current_head last_head
      current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
      last_head=$(read_state last_processed_head "")
      if [ -n "$current_head" ] && [ -n "$last_head" ] && [ "$current_head" != "$last_head" ]; then
        if git -C "$cwd" merge-base --is-ancestor "$last_head" "$current_head" 2>/dev/null; then
          git -C "$cwd" diff --name-only "$last_head".."$current_head" 2>/dev/null || true
        else
          # Rewritten history — fall back to tip commit only.
          git -C "$cwd" show --pretty=format: --name-only "$current_head" 2>/dev/null || true
        fi
      elif [ -n "$current_head" ] && [ -z "$last_head" ]; then
        git -C "$cwd" show --pretty=format: --name-only "$current_head" 2>/dev/null || true
      fi
    fi
  } | sort -u | grep -vE '^\.agents/memory/|^$' || true
}

path_already_in_list() {
  local f=$1 list=$2
  [ -n "$list" ] || return 1
  case $'\x1e'"${list}"$'\x1e' in
    *$'\x1e'"$f"$'\x1e'*) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_repo_rel_path() {
  local rel=$1
  case "$rel" in
    *$'\n'* | *$'\r'* | *$'\x1e'*) return 1 ;;
  esac
  case "$rel" in
    "$cwd"/*) rel=${rel#"$cwd"/} ;;
    /*) return 1 ;;
  esac
  case "$rel" in
    .agents/memory/*) return 1 ;;
  esac
  case "/$rel/" in
    */../*) return 1 ;;
  esac
  [ -n "$rel" ] || return 1
  printf '%s' "$rel"
}

merge_paths_into_session_touched() {
  agent_memory_with_state_lock _merge_paths_into_session_touched_unlocked "$1"
}

_merge_paths_into_session_touched_unlocked() {
  local list_tmp=$1 accumulated
  # Under fail-open, skip merge — git will re-supply paths on the next locked run.
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip path merge (lock not held)\n' >&2
    return 0
  fi
  [ -s "$list_tmp" ] || return 0
  accumulated=$(read_state session_touched_files "")
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    f=$(normalize_repo_rel_path "$f") || continue
    path_already_in_list "$f" "$accumulated" && continue
    if [ -z "$accumulated" ]; then accumulated="$f"
    else accumulated="$accumulated"$'\x1e'"$f"; fi
  done <"$list_tmp"
  _write_state_unlocked session_touched_files "$accumulated"
}

read_session_touched_paths_sorted() {
  local accumulated
  accumulated=$(read_state session_touched_files "")
  [ -n "$accumulated" ] || return 0
  printf '%s\n' "$accumulated" | tr $'\x1e' '\n' | sort -u | grep -v '^$' || true
}

mark_head_processed() {
  local current_head
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  [ -n "$current_head" ] || return 0
  write_state last_processed_head "$current_head"
}

# Merge paths + advance last_processed_head under one lock (or skip both).
apply_ephemeral_checkpoint() {
  local list_tmp=$1
  agent_memory_with_state_lock _apply_ephemeral_checkpoint_unlocked "$list_tmp"
}

_apply_ephemeral_checkpoint_unlocked() {
  local list_tmp=$1 accumulated current_head f
  if [ "${AGENT_MEMORY_LOCK_ACQUIRED:-0}" != "1" ]; then
    printf 'agent-memory: skip ephemeral checkpoint apply (lock not held)\n' >&2
    return 0
  fi
  if [ -s "$list_tmp" ]; then
    accumulated=$(read_state session_touched_files "")
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      f=$(normalize_repo_rel_path "$f") || continue
      path_already_in_list "$f" "$accumulated" && continue
      if [ -z "$accumulated" ]; then accumulated="$f"
      else accumulated="$accumulated"$'\x1e'"$f"; fi
    done <"$list_tmp"
    _write_state_unlocked session_touched_files "$accumulated"
  fi
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$current_head" ]; then
    _write_state_unlocked last_processed_head "$current_head"
  fi
}

# Contextual sessionStart message: obligation + branch/checkpoint/path status.
# Never writes Markdown. Safe when git or active-work is missing.
build_session_context_msg() {
  local branch sanitized aw head_full head_short ck_line ck_sha status bits path_count
  branch=""
  if command -v git >/dev/null 2>&1 && [ -n "${cwd:-}" ] &&
    git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  fi
  [ -n "$branch" ] || branch=$(read_state branch "")
  [ -n "$branch" ] || branch="local"
  sanitized=$(sanitize_branch "$branch")
  [ -n "$sanitized" ] || sanitized="local"

  status="branch=${branch}"
  aw="${memory}/active-work/${sanitized}.md"
  if [ -f "$aw" ]; then
    status="${status}; active-work=yes"
    ck_line=$(grep -E '^Checkpoint: [0-9]{4}-[0-9]{2}-[0-9]{2} @ ' "$aw" 2>/dev/null | head -1 || true)
    ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint: [0-9]{4}-[0-9]{2}-[0-9]{2} @ //' | tr -d '`"')
    head_full=""
    head_short=""
    if command -v git >/dev/null 2>&1 && [ -n "${cwd:-}" ]; then
      head_full=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
      head_short=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
    fi
    if [ -n "$ck_sha" ] && [ "$ck_sha" != "<short-sha>" ] && [ -n "$head_full" ]; then
      if [ "$(git -C "$cwd" rev-parse "$ck_sha" 2>/dev/null || true)" = "$head_full" ]; then
        status="${status}; Checkpoint=${head_short} (fresh)"
      else
        status="${status}; Checkpoint=${ck_sha} (behind HEAD ${head_short})"
      fi
    elif [ -n "$head_short" ]; then
      status="${status}; Checkpoint=missing/placeholder (HEAD ${head_short})"
    else
      status="${status}; Checkpoint=unknown"
    fi
  else
    status="${status}; active-work=no"
  fi

  path_count=0
  bits=$(read_state session_touched_files "")
  if [ -n "$bits" ]; then
    path_count=$(printf '%s' "$bits" | tr $'\x1e' '\n' | grep -c . || true)
  fi
  if [ "$path_count" -gt 0 ] 2>/dev/null; then
    status="${status}; pending paths=${path_count}"
  fi

  printf '%s' "Agent Memory: recall layer in .agents/memory/ — not a docs mirror. Before tasks: read instructions.md, index.md, current.md, and your branch active-work when it exists. Write links/deltas in-turn (primary); sync is catch-up. Hooks store ephemeral evidence only in .hook-sync-state. Status: ${status}. Update resume fields before ending durable work; run /agent-memory sync at checkpoints (or follow references/sync.md)."
}
