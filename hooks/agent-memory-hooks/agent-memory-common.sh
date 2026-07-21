# agent-memory shared helpers — source from session/sync hooks only.
# Deterministic, evidence-backed updates only (git + harness session ID).
#
# Hook-owned memory fields (the agent owns everything else — task meaning,
# semantic log bullets, decision pointers/learnings, blockers/handoff, index.md
# — see hooks/README.md "Safe write scope" and instructions.md):
#   active-work/<branch>.md → Touched files (session-cumulative git + stdin paths)
#   log.md                  → per-session heading (sessionStart), file-path bullets
#                             (full checkpoints only — not postToolUse/afterFileEdit)
#   current.md              → In progress list (sessionStart, from active-work/)
# Hooks never read/consult/copy docs, never write decisions/learnings, and
# never consolidate.
#
# Expects after agent_memory_init_context: cwd, memory, state_file globals.

# Filled by parse_hook_stdin (optional).
hook_stdin_session_id=""
hook_stdin_cwd=""

# Set to 1 by reset_logged_files_if_session_changed when sessionStart continues
# the same no-id session (logged_files_session was already __no_id__).
agent_memory_no_id_continuing=0

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
# Returns first match (head -1). Field name must be regex-safe (alnum/_).
json_string_field() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# jq is preferred for JSON parsing (spec-correct: handles escapes, nesting,
# unicode). Probe once per process; fall back to sed regex when jq is absent so
# the hooks stay zero-dependency and portable.
if [ -z "${_AMC_HAVE_JQ:-}" ]; then
  if command -v jq >/dev/null 2>&1; then _AMC_HAVE_JQ=1; else _AMC_HAVE_JQ=0; fi
fi

parse_hook_stdin() {
  local input="${1:-}"
  hook_stdin_session_id=""
  hook_stdin_cwd=""
  hook_stdin_tool_name=""
  hook_stdin_tool_file=""
  [ -n "$input" ] || return 0
  if [ "$_AMC_HAVE_JQ" -eq 1 ]; then
    local parsed rest
    parsed=$(printf '%s' "$input" | jq -r '
      [ (.session_id // .conversation_id // .sessionId // ""),
        (.cwd // (.workspace_roots[0] // "")),
        (.tool_name // ""),
        (.tool_input.file_path // .tool_input.path // .file_path // "")
      ] | @tsv')
    hook_stdin_session_id=${parsed%%$'\t'*}
    rest=${parsed#*$'\t'}; hook_stdin_cwd=${rest%%$'\t'*}
    rest=${rest#*$'\t'}; hook_stdin_tool_name=${rest%%$'\t'*}
    hook_stdin_tool_file=${rest#*$'\t'}
  else
    hook_stdin_session_id=$(json_string_field "$input" session_id)
    [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(json_string_field "$input" conversation_id)
    [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(json_string_field "$input" sessionId)
    hook_stdin_cwd=$(json_string_field "$input" cwd)
    if [ -z "$hook_stdin_cwd" ]; then
      hook_stdin_cwd=$(printf '%s' "$input" | sed -n \
        's/.*"workspace_roots"[[:space:]]*:\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    hook_stdin_tool_name=$(json_string_field "$input" tool_name)
    hook_stdin_tool_file=$(json_string_field "$input" file_path)
    if [ -z "$hook_stdin_tool_file" ]; then
      hook_stdin_tool_file=$(printf '%s' "$input" | sed -n \
        's/.*"tool_input"[[:space:]]*:[[:space:]]*{[^}]*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -1)
    fi
  fi
}

# Resolve to an absolute path (realpath when available).
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

# True when child is root or a path under root.
agent_memory_path_under_root() {
  local child=$1 root=$2
  case "$child" in
    "$root" | "$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Refuse if path is a symlink (memory trust boundary).
agent_memory_refuse_symlink_file() {
  local path=$1
  if [ -L "$path" ]; then
    printf 'agent-memory: refused symlink memory path: %s\n' "$path" >&2
    return 1
  fi
  return 0
}

# Walk memory root → path; refuse if any existing component is a symlink.
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

# Guard before read/write of a path under $memory.
agent_memory_guard_memory_path() {
  agent_memory_refuse_symlink_parents_under_memory "$1"
}

# Shared entry point for sync.sh and session.sh: read harness stdin, parse it,
# and resolve cwd/memory/state_file globals. Call once after sourcing common.sh.
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

# Harness project roots — see hooks/README.md (Cursor, Claude, Codex, Gemini, git, OpenCode).
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

# Canonical: AGENT_MEMORY_SESSION_ID (from sessionStart env), then stdin JSON,
# then .hook-sync-state (prior sessionStart; sync only). CURSOR_SESSION_ID is
# not set by Cursor natively (Cursor sends session_id via stdin JSON); kept as
# an interop fallback for third-party hooks that export it via sessionStart env.
# GEMINI_SESSION_ID is provided by Gemini CLI.
# Second arg: allow_state_fallback (1=sync default, 0=sessionStart — no stale ID).
resolve_session_id() {
  local stdin_sid="${1:-}"
  local allow_state_fallback="${2:-1}"
  if [ -n "${AGENT_MEMORY_SESSION_ID:-}" ]; then printf '%s' "$AGENT_MEMORY_SESSION_ID"; return; fi
  if [ -n "${CURSOR_SESSION_ID:-}" ]; then printf '%s' "$CURSOR_SESSION_ID"; return; fi
  if [ -n "${GEMINI_SESSION_ID:-}" ]; then printf '%s' "$GEMINI_SESSION_ID"; return; fi
  if [ -n "$stdin_sid" ]; then printf '%s' "$stdin_sid"; return; fi
  if [ "$allow_state_fallback" = "1" ]; then
    read_state current_session_id ""
  else
    printf ''
  fi
}

persist_session_id() {
  local sid="${1:-}"
  [ -n "$sid" ] || return 0
  write_state current_session_id "$sid"
}

# __no_id__: no session ID bound; same no-id session keeps dedupe.
NO_ID_SESSION_SENTINEL="__no_id__"

# Clear per-session checkpoint path sets (log dedupe + active-work accumulation).
_clear_session_path_state() {
  write_state logged_files ""
  write_state session_touched_files ""
  write_state log_summary_mode ""
}

# Keep logged_files (per-session dedupe set of already-bulleted paths) bound to
# the active session id (or __no_id__). Wipe it when the bound session changes,
# so a new session re-bullets paths. id_upgrade_from preserves the prior bound
# across a no-id→id promotion so a session that gains a real id mid-flight keeps
# its dedupe set (see promote_session_log_heading). Sets agent_memory_no_id_continuing
# so ensure_session_log_heading can reuse an existing same-day no-id heading.
# Also resets session_touched_files and log_summary_mode on session change.
reset_logged_files_if_session_changed() {
  local sid=$1 context="${2:-sync}"
  local last
  agent_memory_no_id_continuing=0
  sid=$(normalize_session_id_for_checkpoint "$sid")
  last=$(read_state logged_files_session "")
  if [ -n "$sid" ]; then
    [ "$sid" = "$last" ] && return 0
    if [ -z "$last" ] || [ "$last" = "$NO_ID_SESSION_SENTINEL" ]; then
      write_state logged_files_session "$sid"
      return 0
    fi
    if [ "$context" = "sync" ]; then
      pending=$(read_state id_upgrade_from "")
      if [ -n "$pending" ] && [ "$pending" = "$last" ] && [ "$sid" != "$last" ]; then
        write_state logged_files_session "$sid"
        write_state id_upgrade_from ""
        return 0
      fi
    fi
    _clear_session_path_state
    write_state logged_files_session "$sid"
    return 0
  fi
  if [ "$context" = "sessionStart" ]; then
    if [ "$last" = "$NO_ID_SESSION_SENTINEL" ]; then
      agent_memory_no_id_continuing=1
      return 0
    fi
    agent_memory_no_id_continuing=0
    _clear_session_path_state
    write_state logged_files_session "$NO_ID_SESSION_SENTINEL"
    return 0
  fi
  [ "$last" = "$NO_ID_SESSION_SENTINEL" ] && return 0
  if [ -z "$last" ]; then
    write_state logged_files_session "$NO_ID_SESSION_SENTINEL"
    return 0
  fi
  _clear_session_path_state
  write_state logged_files_session "$NO_ID_SESSION_SENTINEL"
}

# Resolve current branch from git and cache it in .hook-sync-state. Called at
# full checkpoints (sessionStart/afterAgentResponse/preCompact) so postToolUse
# can read the cached branch without spawning git. Caveat: a mid-session
# `git checkout` makes the cache stale until the next full checkpoint refreshes
# it; low impact (a stray bullet in the old branch's active-work, reconciled at
# afterAgentResponse).
refresh_branch_cache() {
  [ -n "${cwd:-}" ] || return 0
  local b last
  b=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  [ -n "$b" ] || return 0
  last=$(read_state branch "")
  write_state branch "$b"
  if [ -n "$last" ] && [ "$last" != "$b" ]; then
    _clear_session_path_state
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

write_state() {
  local key=$1 val=$2
  local tmp cur
  # Reject controls that would break key=value lines or forge extra keys.
  case "$key" in
    '' | *[!A-Za-z0-9_]* | *$'\n'* | *$'\r'*)
      printf 'agent-memory: write_state refused invalid key: %s\n' "$key" >&2
      return 1
      ;;
  esac
  # Values may use RS (\x1e) as a multi-path delimiter (session_touched_files,
  # logged_files). Individual paths must not contain \x1e — see normalize_repo_rel_path.
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
  cur=$(read_state "$key" "")
  if [ -f "$state_file" ] && [ "$cur" = "$val" ]; then
    return 0
  fi
  tmp=$(mktemp)
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

# When 1, list_non_memory_changes also includes files from the tip commit since
# last_processed_head (afterAgentResponse / preCompact only). Set by sync hook.
agent_memory_include_commit_files="${agent_memory_include_commit_files:-0}"

list_worktree_changes() {
  {
    git -C "$cwd" diff --name-only 2>/dev/null || true
    git -C "$cwd" diff --cached --name-only 2>/dev/null || true
    git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u | grep -vE '^\.agents/memory/|^$' || true
}

list_non_memory_changes() {
  {
    list_worktree_changes
    if [ "$agent_memory_include_commit_files" = "1" ]; then
      local current_head last_head
      current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
      last_head=$(read_state last_processed_head "")
      if [ -n "$current_head" ] && [ "$current_head" != "$last_head" ]; then
        git -C "$cwd" show --pretty=format: --name-only "$current_head" 2>/dev/null || true
      fi
    fi
  } | sort -u | grep -vE '^\.agents/memory/|^$' || true
}

branch_to_task_stub() {
  local branch=$1
  local prefix rest
  case "$branch" in
    feat-*|feature-*)
      prefix="Feature"
      rest=${branch#feat-}
      rest=${rest#feature-}
      ;;
    fix-*|bugfix-*)
      prefix="Fix"
      rest=${branch#fix-}
      rest=${rest#bugfix-}
      ;;
    chore-*)
      prefix="Chore"
      rest=${branch#chore-}
      ;;
    refactor-*)
      prefix="Refactor"
      rest=${branch#refactor-}
      ;;
    docs-*)
      prefix="Docs"
      rest=${branch#docs-}
      ;;
    test-*)
      prefix="Test"
      rest=${branch#test-}
      ;;
    *)
      printf '%s' "$branch"
      return
      ;;
  esac
  rest=${rest//-/ }
  printf '%s: %s' "$prefix" "$rest"
}

ensure_active_work() {
  local branch aw real
  # Prefer branch cache (refreshed at full checkpoints) so postToolUse /
  # afterFileEdit skip an extra git spawn on every edit.
  real=$(read_state branch "")
  if [ -z "$real" ]; then
    real=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "local")
  fi
  [ -n "$real" ] || real="local"
  branch=$(sanitize_branch "$real")
  [ -n "$branch" ] || branch="local"
  aw="$memory/active-work/${branch}.md"
  agent_memory_guard_memory_path "$aw" || return 1
  if [ ! -f "$aw" ]; then
    if [ -f "$memory/active-work/TEMPLATE.md" ]; then
      agent_memory_guard_memory_path "$memory/active-work/TEMPLATE.md" || return 1
      local content
      content=$(cat "$memory/active-work/TEMPLATE.md")
      printf '%s\n' "${content//<branch>/$real}" >"$aw"
    else
      cat >"$aw" <<EOF
# Active Work — Branch: \`${real}\`

## Task

- _No active task._

## Progress

- _none_

## Touched files

- _none_

## Blockers

- _none_

## Notes

- _none_
EOF
    fi
  fi
  printf '%s' "$aw"
}

# Replace the bullets of a `## <header>` markdown section with the non-empty
# lines from list_file (printed verbatim as bullets). Empty list → "- _none_".
# Used by update_touched_files and refresh_current_in_progress.
replace_section_bullets() {
  local file=$1 header=$2 list_file=$3
  agent_memory_guard_memory_path "$file" || return 1
  awk -v list="$list_file" -v hdr="$header" '
    BEGIN {
      while ((getline line < list) > 0) if (line != "") arr[++n] = line
      close(list)
    }
    $0 ~ hdr { in_section = 1; print; next }
    in_section && /^## / { if (!done) emit(); in_section = 0 }
    in_section && /^- / { if (!done) { emit(); done = 1 } next }
    { print }
    END { if (in_section && !done) emit() }
    function emit() {
      if (n == 0) print "- _none_"
      else for (i = 1; i <= n; i++) print arr[i]
    }
  ' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

# Merge repo-relative paths into session_touched_files (RS-delimited, like logged_files).
merge_paths_into_session_touched() {
  local list_tmp=$1 accumulated
  [ -s "$list_tmp" ] || return 0
  accumulated=$(read_state session_touched_files "")
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    file_already_logged "$f" "$accumulated" && continue
    if [ -z "$accumulated" ]; then accumulated="$f"
    else accumulated="$accumulated"$'\x1e'"$f"; fi
  done <"$list_tmp"
  write_state session_touched_files "$accumulated"
}

# Sorted unique paths accumulated for the current session (stdout, one per line).
read_session_touched_paths_sorted() {
  local accumulated
  accumulated=$(read_state session_touched_files "")
  [ -n "$accumulated" ] || return 0
  printf '%s\n' "$accumulated" | tr $'\x1e' '\n' | sort -u | grep -v '^$' || true
}

# Write the session-cumulative touched list to active-work (replaces section bullets).
write_active_work_touched_from_session() {
  local aw=$1 bullets_tmp paths_tmp
  paths_tmp=$(mktemp)
  read_session_touched_paths_sorted >"$paths_tmp"
  if [ ! -s "$paths_tmp" ]; then
    rm -f "$paths_tmp"
    return 0
  fi
  bullets_tmp=$(mktemp)
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    printf '%s\n' "- \`$f\`" >>"$bullets_tmp"
  done <"$paths_tmp"
  replace_section_bullets "$aw" '^## Touched files' "$bullets_tmp"
  rm -f "$paths_tmp" "$bullets_tmp"
}

update_touched_files() {
  local aw=$1 list_tmp=$2
  [ -s "$list_tmp" ] || return 0
  merge_paths_into_session_touched "$list_tmp"
  write_active_work_touched_from_session "$aw"
}

# Merge one path into session state and refresh active-work. Used by postToolUse /
# afterFileEdit (git-free). Does not write log.md bullets — full checkpoints only.
add_touched_file() {
  local aw=$1 rel=$2 single accumulated
  [ -n "$rel" ] || return 0
  accumulated=$(read_state session_touched_files "")
  file_already_logged "$rel" "$accumulated" && return 0
  single=$(mktemp)
  printf '%s\n' "$rel" >"$single"
  merge_paths_into_session_touched "$single"
  rm -f "$single"
  write_active_work_touched_from_session "$aw"
}

update_task_stub() {
  local aw=$1 branch stub
  agent_memory_guard_memory_path "$aw" || return 1
  branch=$(sanitize_branch)
  [ -n "$branch" ] || branch="local"
  stub=$(branch_to_task_stub "$branch")

  awk -v stub="$stub" '
    /^## Task/ { in_task = 1; print; next }
    in_task && /^## / {
      if (!replaced && !has_real) print "- " stub " _(refine in session)_"
      in_task = 0
    }
    in_task && /^- / {
      if ($0 ~ /_No active task\./ || $0 ~ /_none_/) {
        print "- " stub " _(refine in session)_"
        replaced = 1
      } else {
        print
        has_real = 1
      }
      next
    }
    { print }
    END {
      if (in_task && !replaced && !has_real) print "- " stub " _(refine in session)_"
    }
  ' "$aw" >"${aw}.tmp" && mv "${aw}.tmp" "$aw"
}

today_date() {
  date +%Y-%m-%d
}

# OpenCode rotates ses_* IDs across idle/compaction events within one work day.
# One log heading per calendar day; later ses_* IDs map to the bound heading id.
opencode_refresh_log_day() {
  [ "${AGENT_MEMORY_HOST:-}" = "opencode" ] || return 0
  local today last
  today=$(today_date)
  last=$(read_state opencode_log_date "")
  [ "$today" = "$last" ] && return 0
  write_state opencode_log_date "$today"
  write_state opencode_log_heading_id ""
}

# First ## [YYYY-MM-DD] [ses_*] heading on stdout, or empty.
find_opencode_log_heading_same_day() {
  local log="$memory/log.md" date
  date=$(today_date)
  [ -f "$log" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  grep -E "^## \\[${date}\\] \\[ses_" "$log" 2>/dev/null \
    | head -1 \
    | sed -n 's/^## \[[0-9-]*\] \[\(ses_[^]]*\)\].*/\1/p'
}

# Map a raw harness session id to the log heading id (OpenCode coalescence).
# Read-only — does not bind state or create headings (see ensure_log_heading_for_checkpoint).
normalize_session_id_for_checkpoint() {
  local sid="${1:-}"
  if [ "${AGENT_MEMORY_HOST:-}" = "opencode" ] && [ -n "$sid" ]; then
    opencode_refresh_log_day
    local bound existing
    bound=$(read_state opencode_log_heading_id "")
    if [ -n "$bound" ] && session_heading_exists "$bound"; then
      printf '%s' "$bound"
      return
    fi
    existing=$(find_opencode_log_heading_same_day)
    if [ -n "$existing" ]; then
      printf '%s' "$existing"
      return
    fi
  fi
  printf '%s' "$sid"
}

_opencode_bind_log_heading() {
  local id="${1:-}"
  [ "${AGENT_MEMORY_HOST:-}" = "opencode" ] || return 0
  [ -n "$id" ] || return 0
  case "$id" in
    ses_*)
      write_state opencode_log_heading_id "$id"
      write_state opencode_log_date "$(today_date)"
      ;;
  esac
}

# Create or resolve the log heading before a checkpoint append. Prints the heading id.
ensure_log_heading_for_checkpoint() {
  local sid="${1:-}" resolved log="$memory/log.md" line today
  [ -n "$sid" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  opencode_refresh_log_day
  resolved=$(normalize_session_id_for_checkpoint "$sid")
  if session_heading_exists "$resolved"; then
    _opencode_bind_log_heading "$resolved"
    if [ "${AGENT_MEMORY_HOST:-}" = "opencode" ]; then
      prune_empty_opencode_session_headings "$resolved"
    fi
    printf '%s' "$resolved"
    return 0
  fi
  if [ "${AGENT_MEMORY_HOST:-}" = "opencode" ]; then
    case "$resolved" in
      ses_*)
        today=$(today_date)
        local existing
        existing=$(find_opencode_log_heading_same_day)
        if [ -n "$existing" ]; then
          _opencode_bind_log_heading "$existing"
          prune_empty_opencode_session_headings "$existing"
          printf '%s' "$existing"
          return 0
        fi
        ;;
    esac
  fi
  promote_session_log_heading "$resolved"
  line=$(session_log_heading_line "$resolved")
  strip_log_placeholder
  if [ ! -f "$log" ]; then
    printf '# Log\n\n%s\n' "$line" >"$log"
  else
    printf '\n%s\n' "$line" >>"$log"
  fi
  _opencode_bind_log_heading "$resolved"
  printf '%s' "$resolved"
}

# Drop same-day empty OpenCode ses_* headings except the kept id (no bullets).
prune_empty_opencode_session_headings() {
  local keep="${1:-}" date log="$memory/log.md"
  [ "${AGENT_MEMORY_HOST:-}" = "opencode" ] || return 0
  [ -n "$keep" ] || return 0
  [ -f "$log" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  date=$(today_date)
  awk -v date="$date" -v keep="$keep" '
    function is_ses_heading(line,    id) {
      if (line !~ "^## \\[" date "\\] \\[ses_") return 0
      if (match(line, /\[ses_[^]]+\]/)) {
        id = substr(line, RSTART + 1, RLENGTH - 2)
        return id
      }
      return 0
    }
    {
      lines[++n] = $0
    }
    END {
      drop[0] = 0
      for (i = 1; i <= n; i++) {
        id = is_ses_heading(lines[i])
        if (!id) continue
        if (id == keep) continue
        empty = 1
        for (j = i + 1; j <= n; j++) {
          if (lines[j] ~ /^## /) break
          if (lines[j] ~ /^- /) { empty = 0; break }
        }
        if (empty) drop[i] = 1
      }
      for (i = 1; i <= n; i++) if (!drop[i]) print lines[i]
    }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"
}

session_log_heading_line() {
  local date sid
  date=$(today_date)
  sid="${1:-}"
  if [ -n "$sid" ]; then
    printf '## [%s] [%s]' "$date" "$sid"
  else
    printf '## [%s]' "$date"
  fi
}

session_heading_exists() {
  local log="$memory/log.md" sid="${1:-}" date
  date=$(today_date)
  [ -f "$log" ] || return 1
  agent_memory_guard_memory_path "$log" || return 1
  if [ -n "$sid" ]; then
    awk -v sid="$sid" '
      function is_sid_heading(line) {
        return line ~ "^## \\[[0-9]{4}-[0-9]{2}-[0-9]{2}\\] \\[" sid "\\]"
      }
      is_sid_heading($0) && $0 !~ /hook checkpoint/ { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$log"
  else
    awk -v date="$date" '
      function is_no_id_heading(line) {
        if (line !~ "^## \\[" date "\\]") return 0
        if (line ~ /hook checkpoint/) return 0
        if (line ~ "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-") return 0
        if (line ~ "^## \\[" date "\\]$") return 1
        return line ~ "^## \\[" date "\\] \\["
      }
      is_no_id_heading($0) { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$log"
  fi
}

# Any same-day session heading — for no-id reuse on sessionStart.
same_day_session_heading_exists_any() {
  local log="$memory/log.md" date
  date=$(today_date)
  [ -f "$log" ] || return 1
  agent_memory_guard_memory_path "$log" || return 1
  awk -v date="$date" '
    function is_session_heading(line) {
      if (line !~ "^## \\[" date "\\]") return 0
      if (line ~ /hook checkpoint/) return 0
      if (line ~ "^## \\[" date "\\]$") return 1
      return line ~ "^## \\[" date "\\] \\["
    }
    is_session_heading($0) { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$log"
}

session_log_has_target_heading() {
  local sid="${1:-}"
  sid=$(normalize_session_id_for_checkpoint "$sid")
  if [ -n "$sid" ]; then
    session_heading_exists "$sid"
  else
    same_day_session_heading_exists_any
  fi
}

strip_log_placeholder() {
  local log="$memory/log.md"
  [ -f "$log" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  awk '
    /^_No entries yet\._$/ { next }
    { print }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"
}

promote_session_log_heading() {
  local sid="${1:-}"
  local log="$memory/log.md" date prev_bound
  [ -n "$sid" ] || return 0
  [ -f "$log" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  date=$(today_date)
  session_heading_exists "$sid" && return 0
  prev_bound=$(read_state logged_files_session "")
  if [ -n "$prev_bound" ] && [ "$prev_bound" != "$sid" ] \
      && [ "$prev_bound" != "$NO_ID_SESSION_SENTINEL" ]; then
    if awk -v prev="$prev_bound" -v sid="$sid" -v date="$date" '
      $0 ~ "^## \\[" date "\\] \\[" prev "\\]" {
        sub("\\[" prev "\\]", "[" sid "]", $0)
        promoted = 1
        print
        next
      }
      { print }
      END { exit(promoted ? 0 : 1) }
    ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"; then
      write_state id_upgrade_from "$prev_bound"
    fi
    session_heading_exists "$sid" && return 0
  fi
  if ! awk -v date="$date" '
    $0 ~ "^## \\[" date "\\]$" && $0 !~ /hook checkpoint/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$log"; then
    return 0
  fi
  awk -v sid="$sid" -v date="$date" '
    $0 ~ "^## \\[" date "\\]$" && !promoted {
      print "## [" date "] [" sid "]"
      promoted = 1
      next
    }
    { print }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"
}

# sessionStart only — full checkpoints call ensure_log_heading_for_checkpoint directly.
ensure_session_log_heading() {
  local sid="${1:-}" context="${2:-}" line log="$memory/log.md"
  [ "$context" = "sessionStart" ] || return 0
  agent_memory_guard_memory_path "$log" || return 1
  if [ -n "$sid" ]; then
    ensure_log_heading_for_checkpoint "$sid" >/dev/null
    return 0
  fi
  if [ "${agent_memory_no_id_continuing:-0}" = "1" ] \
      && same_day_session_heading_exists_any; then
    return 0
  elif session_heading_exists ""; then
    return 0
  fi
  strip_log_placeholder
  line=$(session_log_heading_line "")
  if [ ! -f "$log" ]; then
    printf '# Log\n\n%s\n' "$line" >"$log"
  else
    printf '\n%s\n' "$line" >>"$log"
  fi
}

# Record separator–delimited logged paths for current session (logged_files).
# logged set ($2) is read once by the caller and passed in to avoid N+1 read_state.
file_already_logged() {
  local f=$1 logged=$2
  [ -n "$logged" ] || return 1
  case $'\x1e'"${logged}"$'\x1e' in
    *$'\x1e'"$f"$'\x1e'*) return 0 ;;
    *) return 1 ;;
  esac
}

append_log_file_bullets() {
  local sid=$1 list_tmp=$2
  local log="$memory/log.md" count pending_tmp bullets_tmp logged
  agent_memory_guard_memory_path "$log" || return 1
  pending_tmp=$(mktemp)
  [ -s "$list_tmp" ] || { rm -f "$pending_tmp"; return 0; }

  reset_logged_files_if_session_changed "$sid"
  session_log_has_target_heading "$sid" || {
    rm -f "$pending_tmp"
    return 0
  }

  logged=$(read_state logged_files "")
  count=0
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    file_already_logged "$f" "$logged" && continue
    printf '%s\n' "$f" >>"$pending_tmp"
    count=$((count + 1))
  done <"$list_tmp"
  [ "$count" -gt 0 ] || { rm -f "$pending_tmp"; return 0; }

  if [ "$(read_state log_summary_mode "")" = "1" ] && [ "$count" -le 8 ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      if [ -z "$logged" ]; then logged="$f"
      else logged="$logged"$'\x1e'"$f"; fi
    done <"$pending_tmp"
    write_state logged_files "$logged"
    rm -f "$pending_tmp"
    return 0
  fi

  bullets_tmp=$(mktemp)
  if [ "$count" -le 8 ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      printf '%s\n' "- \`$f\`" >>"$bullets_tmp"
    done <"$pending_tmp"
  else
    printf '%s\n' "- changed ${count} files (see active-work Touched files)" >>"$bullets_tmp"
    write_state log_summary_mode "1"
  fi

  if awk -v sid="$sid" -v date="$(today_date)" -v bullets="$bullets_tmp" '
    BEGIN {
      while ((getline b < bullets) > 0) bullet[++bn] = b
      close(bullets)
      if (sid != "") {
        heading_pat = "^## \\[[0-9]{4}-[0-9]{2}-[0-9]{2}\\] \\[" sid "\\]"
      }
    }
    function is_legacy_checkpoint(line) {
      return line ~ /hook checkpoint/
    }
    function is_target_heading(line) {
      if (is_legacy_checkpoint(line)) return 0
      if (sid != "") return line ~ heading_pat
      # no-id: target any same-day non-legacy heading, INCLUDING a UUID heading.
      # A no-id sync following a with-id session (state lost/cleared mid-
      # session) continues logging under the prior UUID heading rather than
      # fragmenting. This intentionally diverges from is_no_id_heading, which
      # excludes UUID as a sessionStart creation gate.
      if (line !~ "^## \\[" date "\\]") return 0
      if (line ~ "^## \\[" date "\\]$") return 1
      return line ~ "^## \\[" date "\\] \\["
    }
    {
      buf[++nr] = $0
    }
    END {
      end_section = 0
      for (i = 1; i <= nr; i++) {
        if (is_target_heading(buf[i])) {
          end_section = i
          for (j = i + 1; j <= nr; j++) {
            if (buf[j] ~ /^## /) break
            if (buf[j] ~ /^- /) end_section = j
          }
        }
      }
      if (end_section == 0) exit 1
      for (i = 1; i <= nr; i++) {
        print buf[i]
        if (i == end_section) {
          for (j = 1; j <= bn; j++) print bullet[j]
        }
      }
    }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      if [ -z "$logged" ]; then logged="$f"
      else logged="$logged"$'\x1e'"$f"; fi
    done <"$pending_tmp"
    write_state logged_files "$logged"
  fi
  rm -f "$bullets_tmp" "$pending_tmp"
}

extract_active_work_summary() {
  local aw=$1 branch
  agent_memory_guard_memory_path "$aw" || return 1
  branch=$(basename "$aw" .md)
  awk '
    /^## Task/ { in_task = 1; next }
    in_task && /^## / { exit }
    in_task && /^- / {
      line = $0
      sub(/^- /, "", line)
      if (line !~ /^_No active task\./ && line !~ /^_none_/ && line !~ /refine in session/) {
        print line
        exit
      }
    }
  ' "$aw"
}

refresh_current_in_progress() {
  local current="$memory/current.md" tmp
  [ -f "$current" ] || return 0
  agent_memory_guard_memory_path "$current" || return 1

  tmp=$(mktemp)
  {
    for aw in "$memory"/active-work/*.md; do
      [ -f "$aw" ] || continue
      [ "$(basename "$aw")" = "TEMPLATE.md" ] && continue
      agent_memory_guard_memory_path "$aw" || continue
      local base summary
      base=$(basename "$aw")
      summary=$(extract_active_work_summary "$aw")
      if [ -z "$summary" ]; then
        summary=$(branch_to_task_stub "$(basename "$aw" .md)")
      fi
      printf -- '- [`active-work/%s`](./active-work/%s) — %s\n' "$base" "$base" "$summary"
    done
  } >"$tmp"

  replace_section_bullets "$current" '^## In progress' "$tmp"
  rm -f "$tmp"
}
