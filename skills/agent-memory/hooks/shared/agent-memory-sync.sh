#!/bin/bash
# agent-memory deterministic checkpoint (all harnesses).
#
# Updates only evidence-backed fields from git — never invents task/progress text.
# Safe scope: active-work "Touched files"; log.md append on end-of-turn / compact /
# pre-commit when non-memory files changed. Never touches current.md. No LLM call.
#
# Set AGENT_MEMORY_EVENT (any host naming):
#   postToolUse | PostToolUse        — after Write/Edit/Bash; debounced
#   afterAgentResponse | Stop | agentStop — end of assistant turn
#   preCompact | PreCompact | precommit — before compaction or git commit
#
# Install per host — see hooks/README.md.

set -u

raw_event="${AGENT_MEMORY_EVENT:-afterAgentResponse}"
case "$raw_event" in
  postToolUse|PostToolUse|posttool) event=postToolUse ;;
  afterAgentResponse|Stop|stop|agentStop|afterresponse) event=afterAgentResponse ;;
  preCompact|PreCompact|precompact|precommit) event=preCompact ;;
  *) event=afterAgentResponse ;;
esac

cwd="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-${AGENT_MEMORY_PROJECT_DIR:-$PWD}}}}"
memory="$cwd/.agents/memory"
state_file="$memory/.hook-sync-state"
legacy_state="$memory/.cursor-hook-state"

[ -d "$memory" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

if [ ! -f "$state_file" ] && [ -f "$legacy_state" ]; then
  cp "$legacy_state" "$state_file"
fi

# --- helpers ---

sanitize_branch() {
  local b
  b=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
  printf '%s' "$b" | tr -c 'A-Za-z0-9._-' '-'
}

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
    if [ "$event" = "afterAgentResponse" ] || [ "$event" = "preCompact" ]; then
      local current_head last_head
      current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
      last_head=$(read_state last_processed_head "")
      if [ -n "$current_head" ] && [ "$current_head" != "$last_head" ]; then
        git -C "$cwd" show --pretty=format: --name-only "$current_head" 2>/dev/null || true
      fi
    fi
  } | sort -u | grep -v '^\.agents/memory/' | grep -v '^$' || true
}

mark_head_processed() {
  local current_head
  current_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
  [ -n "$current_head" ] || return 0
  write_state last_processed_head "$current_head"
}

files_hash() {
  list_non_memory_changes | shasum -a 256 2>/dev/null | awk '{print $1}' || echo "none"
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
    /^## Touched files/ {
      print
      if (count == 0) print "- _none_"
      else for (i = 1; i <= n; i++) print "- `" arr[i] "`"
      in_section = 1
      next
    }
    in_section && /^## / { in_section = 0 }
    in_section { next }
    { print }
  ' "$aw" >"${aw}.tmp" && mv "${aw}.tmp" "$aw"
  rm -f "$list_tmp"
}

append_log_checkpoint() {
  local count hash today
  count=$(list_non_memory_changes | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] || return 0
  hash=$(files_hash)
  today=$(date +%Y-%m-%d)
  if [ "$(read_state last_log_hash "")" = "$hash" ] && [ "$(read_state last_log_date "")" = "$today" ]; then
    return 0
  fi
  local log="$memory/log.md"
  local entry="## [${today}] chore | agent-memory hook checkpoint (${count} non-memory files touched)"
  if grep -qxF "$entry" "$log" 2>/dev/null; then
    write_state last_log_hash "$hash"
    write_state last_log_date "$today"
    return 0
  fi
  if grep -q '_No entries yet._' "$log" 2>/dev/null; then
    sed -i.bak '/_No entries yet._/d' "$log" 2>/dev/null || \
      sed -i '' '/_No entries yet._/d' "$log" 2>/dev/null || true
    rm -f "${log}.bak"
  fi
  printf '\n%s\n' "$entry" >>"$log"
  write_state last_log_hash "$hash"
  write_state last_log_date "$today"
}

should_skip_posttool() {
  local hash now last_ts min_interval=45
  hash=$(files_hash)
  [ "$hash" != "none" ] || return 0
  last_ts=$(read_state last_posttool_ts "0")
  now=$(date +%s)
  if [ "$hash" = "$(read_state last_posttool_hash "")" ] && [ $((now - last_ts)) -lt $min_interval ]; then
    return 0
  fi
  write_state last_posttool_hash "$hash"
  write_state last_posttool_ts "$now"
  return 1
}

# --- main ---

changes=$(list_non_memory_changes)
[ -n "$changes" ] || exit 0

case "$event" in
  postToolUse)
    should_skip_posttool && exit 0
    aw=$(ensure_active_work)
    update_touched_files "$aw"
    ;;
  afterAgentResponse|preCompact)
    aw=$(ensure_active_work)
    update_touched_files "$aw"
    append_log_checkpoint
    mark_head_processed
    ;;
  *)
    exit 0
    ;;
esac

exit 0
