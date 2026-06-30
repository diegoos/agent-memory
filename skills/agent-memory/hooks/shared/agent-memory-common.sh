# agent-memory shared helpers — source from session/sync hooks only.
# Deterministic, evidence-backed updates only (git + harness session ID).
#
# Expects: cwd, memory, state_file (set by caller after resolve_project_dir).

# Filled by parse_hook_stdin (optional).
hook_stdin_session_id=""
hook_stdin_cwd=""

# Set to 1 by reset_logged_files_if_session_changed when sessionStart continues
# the same no-id session (logged_files_session was already __no_id__).
agent_memory_no_id_continuing=0

parse_hook_stdin() {
  local input="${1:-}"
  hook_stdin_session_id=""
  hook_stdin_cwd=""
  [ -n "$input" ] || return 0
  hook_stdin_session_id=$(printf '%s' "$input" | sed -n \
    's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(printf '%s' "$input" | sed -n \
    's/.*"conversation_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -z "$hook_stdin_session_id" ] && hook_stdin_session_id=$(printf '%s' "$input" | sed -n \
    's/.*"sessionId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  hook_stdin_cwd=$(printf '%s' "$input" | sed -n \
    's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [ -z "$hook_stdin_cwd" ]; then
    hook_stdin_cwd=$(printf '%s' "$input" | sed -n \
      's/.*"workspace_roots"[[:space:]]*:\[[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  fi
}

# Harness project roots — see hooks/README.md (Cursor, Claude, Codex, git, OpenCode).
resolve_project_dir() {
  local stdin_cwd="${1:-}"
  if [ -n "${AGENT_MEMORY_PROJECT_DIR:-}" ]; then printf '%s' "$AGENT_MEMORY_PROJECT_DIR"; return; fi
  if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then printf '%s' "$CURSOR_PROJECT_DIR"; return; fi
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s' "$CLAUDE_PROJECT_DIR"; return; fi
  if [ -n "${CODEX_PROJECT_DIR:-}" ]; then printf '%s' "$CODEX_PROJECT_DIR"; return; fi
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then printf '%s' "$GITHUB_WORKSPACE"; return; fi
  if [ -n "$stdin_cwd" ]; then printf '%s' "$stdin_cwd"; return; fi
  printf '%s' "${PWD:-.}"
}

# Canonical: AGENT_MEMORY_SESSION_ID (from sessionStart env), then stdin JSON,
# then .hook-sync-state (prior sessionStart; sync only). CURSOR_SESSION_ID is legacy.
# Second arg: allow_state_fallback (1=sync default, 0=sessionStart — no stale ID).
resolve_session_id() {
  local stdin_sid="${1:-}"
  local allow_state_fallback="${2:-1}"
  if [ -n "${AGENT_MEMORY_SESSION_ID:-}" ]; then printf '%s' "$AGENT_MEMORY_SESSION_ID"; return; fi
  if [ -n "${CURSOR_SESSION_ID:-}" ]; then printf '%s' "$CURSOR_SESSION_ID"; return; fi
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

# Log heading type tags — keep aligned with agent-memory/memory/log.md
LOG_TYPE_TAGS='chore|feat|fix|docs|test|refactor|review|perf|security|release|ingest|improve'

session_heading_exists_for() {
  session_heading_exists "$1"
}

reset_logged_files_if_session_changed() {
  local sid=$1 context="${2:-sync}"
  local last
  agent_memory_no_id_continuing=0
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
    write_state logged_files ""
    write_state logged_files_session "$sid"
    return 0
  fi
  if [ "$context" = "sessionStart" ]; then
    if [ "$last" = "$NO_ID_SESSION_SENTINEL" ]; then
      agent_memory_no_id_continuing=1
      return 0
    fi
    agent_memory_no_id_continuing=0
    write_state logged_files ""
    write_state logged_files_session "$NO_ID_SESSION_SENTINEL"
    return 0
  fi
  [ "$last" = "$NO_ID_SESSION_SENTINEL" ] && return 0
  write_state logged_files ""
  write_state logged_files_session "$NO_ID_SESSION_SENTINEL"
}

sanitize_branch() {
  local b
  b=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  printf '%s' "$b" | tr -c 'A-Za-z0-9._-' '-'
}

read_state() {
  local key=$1 default=$2
  [ -f "$state_file" ] || { printf '%s' "$default"; return; }
  awk -F= -v k="$key" '$1==k {print $2; found=1} END {if(!found) print ""}' "$state_file" | head -1
}

write_state() {
  local key=$1 val=$2
  local tmp
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
  } | sort -u | grep -v '^\.agents/memory/' | grep -v '^$' || true
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
  } | sort -u | grep -v '^\.agents/memory/' | grep -v '^$' || true
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
  branch=$(sanitize_branch)
  [ -n "$branch" ] || branch="local"
  aw="$memory/active-work/${branch}.md"
  if [ ! -f "$aw" ]; then
    real=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "local")
    if [ -f "$memory/active-work/TEMPLATE.md" ]; then
      cp "$memory/active-work/TEMPLATE.md" "$aw"
      sed -i.bak "s/<branch>/${real}/" "$aw" 2>/dev/null || \
        sed -i '' "s/<branch>/${real}/" "$aw" 2>/dev/null || true
      rm -f "${aw}.bak"
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

update_touched_files() {
  local aw=$1
  local list_tmp
  list_tmp=$(mktemp)
  list_non_memory_changes >"$list_tmp"
  [ -s "$list_tmp" ] || { rm -f "$list_tmp"; return 0; }

  awk -v list="$list_tmp" '
    BEGIN {
      while ((getline line < list) > 0) {
        if (line != "") { arr[++n] = line }
      }
      close(list)
      count = n
    }
    /^## Touched files/ { in_section = 1; print; next }
    in_section && /^## / {
      if (!bullets_done) {
        if (count == 0) print "- _none_"
        else for (i = 1; i <= n; i++) print "- `" arr[i] "`"
      }
      in_section = 0
    }
    in_section && /^- / {
      if (!bullets_done) {
        if (count == 0) print "- _none_"
        else for (i = 1; i <= n; i++) print "- `" arr[i] "`"
        bullets_done = 1
      }
      next
    }
    { print }
    END {
      if (in_section && !bullets_done) {
        if (count == 0) print "- _none_"
        else for (i = 1; i <= n; i++) print "- `" arr[i] "`"
      }
    }
  ' "$aw" >"${aw}.tmp" && mv "${aw}.tmp" "$aw"
  rm -f "$list_tmp"
}

update_task_stub() {
  local aw=$1 branch stub
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

session_log_heading_line() {
  local date sid
  date=$(today_date)
  sid="${1:-}"
  if [ -n "$sid" ]; then
    printf '## [%s] [%s] [chore] session work' "$date" "$sid"
  else
    printf '## [%s] [chore] session work' "$date"
  fi
}

session_heading_exists() {
  local log="$memory/log.md" sid="${1:-}" date
  date=$(today_date)
  [ -f "$log" ] || return 1
  if [ -n "$sid" ]; then
    awk -v sid="$sid" '
      $0 ~ "^## \\[[0-9]{4}-[0-9]{2}-[0-9]{2}\\] \\[" sid "\\]" { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$log"
  else
    awk -v date="$date" -v types="$LOG_TYPE_TAGS" '
      function is_no_id_heading(line) {
        if (line ~ "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-") return 0
        return line ~ "^## \\[" date "\\] \\[(" types ")\\]"
      }
      is_no_id_heading($0) { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$log"
  fi
}

# Any same-day session heading (UUID or type-tag stub) — for no-id reuse / bullet target.
same_day_session_heading_exists_any() {
  local log="$memory/log.md" date
  date=$(today_date)
  [ -f "$log" ] || return 1
  awk -v date="$date" -v types="$LOG_TYPE_TAGS" '
    function is_session_heading(line) {
      if (line ~ "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-") return 1
      return line ~ "^## \\[" date "\\] \\[(" types ")\\]"
    }
    is_session_heading($0) { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$log"
}

strip_log_placeholder() {
  local log="$memory/log.md"
  [ -f "$log" ] || return 0
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
  if ! awk -v date="$date" -v types="$LOG_TYPE_TAGS" '
    $0 ~ "^## \\[" date "\\] \\[(" types ")\\]" &&
    $0 !~ "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-" { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$log"; then
    return 0
  fi
  awk -v sid="$sid" -v date="$date" -v types="$LOG_TYPE_TAGS" '
    $0 ~ "^## \\[" date "\\] \\[(" types ")\\]" &&
    $0 !~ "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-" && !promoted {
      sub("^## \\[" date "\\] ", "## [" date "] [" sid "] ")
      promoted = 1
      print
      next
    }
    { print }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"
}

ensure_session_log_heading() {
  local log="$memory/log.md" line sid force_new="${2:-0}"
  sid="${1:-}"
  [ -n "$sid" ] && promote_session_log_heading "$sid"
  line=$(session_log_heading_line "$sid")
  if [ -n "$force_new" ] && [ "$force_new" != "0" ]; then
    if [ -n "$sid" ]; then
      session_heading_exists "$sid" && return 0
    elif [ "${agent_memory_no_id_continuing:-0}" = "1" ] \
        && same_day_session_heading_exists_any; then
      return 0
    elif session_heading_exists ""; then
      return 0
    fi
  elif [ -n "$sid" ]; then
    session_heading_exists "$sid" && return 0
  elif [ "$(read_state logged_files_session "")" = "$NO_ID_SESSION_SENTINEL" ] \
      && same_day_session_heading_exists_any; then
    return 0
  else
    session_heading_exists "" && return 0
  fi
  strip_log_placeholder
  if [ ! -f "$log" ]; then
    printf '# Log\n\n%s\n' "$line" >"$log"
    return 0
  fi
  printf '\n%s\n' "$line" >>"$log"
}

# Record separator–delimited logged paths for current session (logged_files).
file_already_logged() {
  local f=$1 logged
  logged=$(read_state logged_files "")
  case "${logged}"$'\x1e' in
    *$'\x1e'"$f"$'\x1e'*) return 0 ;;
    "$f"$'\x1e'*) return 0 ;;
    *$'\x1e'"$f") return 0 ;;
    "$f") return 0 ;;
    *) return 1 ;;
  esac
}

mark_files_logged() {
  local new=$1 logged
  logged=$(read_state logged_files "")
  if [ -z "$logged" ]; then
    write_state logged_files "$new"
  else
    write_state logged_files "${logged}"$'\x1e'"${new}"
  fi
}

append_log_file_bullets() {
  local sid=$1
  local log="$memory/log.md" list_tmp count pending_tmp bullets_tmp
  list_tmp=$(mktemp)
  pending_tmp=$(mktemp)
  list_non_memory_changes >"$list_tmp"
  [ -s "$list_tmp" ] || { rm -f "$list_tmp" "$pending_tmp"; return 0; }

  ensure_session_log_heading "$sid"
  reset_logged_files_if_session_changed "$sid"

  count=0
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    file_already_logged "$f" && continue
    printf '%s\n' "$f" >>"$pending_tmp"
    count=$((count + 1))
  done <"$list_tmp"
  rm -f "$list_tmp"
  [ "$count" -gt 0 ] || { rm -f "$pending_tmp"; return 0; }

  bullets_tmp=$(mktemp)
  if [ "$count" -le 8 ]; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      printf '%s\n' "- \`$f\`" >>"$bullets_tmp"
    done <"$pending_tmp"
  else
    printf '%s\n' "- changed ${count} files (see active-work Touched files)" >>"$bullets_tmp"
  fi

  if awk -v sid="$sid" -v date="$(today_date)" -v types="$LOG_TYPE_TAGS" -v bullets="$bullets_tmp" '
    BEGIN {
      while ((getline b < bullets) > 0) bullet[++bn] = b
      close(bullets)
      if (sid != "") {
        heading_pat = "^## \\[[0-9]{4}-[0-9]{2}-[0-9]{2}\\] \\[" sid "\\]"
      } else {
        type_pat = "^## \\[" date "\\] \\[(" types ")\\]"
        uuid_pat = "^## \\[" date "\\] \\[[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"
      }
    }
    function is_target_heading(line) {
      if (sid != "") return line ~ heading_pat
      return line ~ uuid_pat || line ~ type_pat
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
      for (i = 1; i <= nr; i++) {
        print buf[i]
        if (i == end_section && end_section > 0) {
          for (j = 1; j <= bn; j++) print bullet[j]
        }
      }
      if (end_section == 0) {
        for (j = 1; j <= bn; j++) print bullet[j]
      }
    }
  ' "$log" >"${log}.tmp" && mv "${log}.tmp" "$log"; then
    while IFS= read -r f || [ -n "$f" ]; do
      [ -n "$f" ] || continue
      mark_files_logged "$f"
    done <"$pending_tmp"
  fi
  rm -f "$bullets_tmp" "$pending_tmp"
}

extract_active_work_summary() {
  local aw=$1 branch
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
    END { }
  ' "$aw"
}

refresh_current_in_progress() {
  local current="$memory/current.md" tmp entries n=0
  [ -f "$current" ] || return 0

  tmp=$(mktemp)
  {
    for aw in "$memory"/active-work/*.md; do
      [ -f "$aw" ] || continue
      [ "$(basename "$aw")" = "TEMPLATE.md" ] && continue
      local base summary branch_line
      base=$(basename "$aw")
      summary=$(extract_active_work_summary "$aw")
      if [ -z "$summary" ]; then
        summary=$(branch_to_task_stub "$(basename "$aw" .md)")
      fi
      printf -- '- [`active-work/%s`](./active-work/%s) — %s\n' "$base" "$base" "$summary"
      n=$((n + 1))
    done
  } >"$tmp"

  awk -v list="$tmp" -v n="$n" '
    BEGIN {
      while ((getline line < list) > 0) entries[++c] = line
      close(list)
    }
    /^## In progress/ { in_section = 1; print; next }
    in_section && /^## / {
      if (!bullets_done) {
        if (c == 0) print "- _none_"
        else for (i = 1; i <= c; i++) print entries[i]
      }
      in_section = 0
    }
    in_section && /^- / {
      if (!bullets_done) {
        if (c == 0) print "- _none_"
        else for (i = 1; i <= c; i++) print entries[i]
        bullets_done = 1
      }
      next
    }
    { print }
    END {
      if (in_section && !bullets_done) {
        if (c == 0) print "- _none_"
        else for (i = 1; i <= c; i++) print entries[i]
      }
    }
  ' "$current" >"${current}.tmp" && mv "${current}.tmp" "$current"
  rm -f "$tmp"
}
