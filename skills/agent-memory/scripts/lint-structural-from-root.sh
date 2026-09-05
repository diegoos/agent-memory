#!/usr/bin/env bash
# Structural lint emitters for /agent-memory lint.
# Cwd must be the project root (AGENTS.md, .agents/memory/, harness dirs).
# Do not set -e: grep -q / missing files are expected misses.

if [ ! -f AGENTS.md ] || [ ! -d .agents/memory ]; then
  echo "wrong-cwd: run from project root (see references/lint-structural.md)"
  exit 0
fi

branch=$(git branch --show-current 2>/dev/null || true)
branch=$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-')
[ -n "$branch" ] || branch=local
aw=".agents/memory/active-work/${branch}.md"
head_full=$(git rev-parse HEAD 2>/dev/null || true)
head_short=$(git rev-parse --short HEAD 2>/dev/null || true)
ck_sha=""
if [ -f "$aw" ] && [ -n "$head_full" ]; then
  ck_fresh=false
  ck_any_hex=false
  while IFS= read -r ck_line; do
    cand=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint:[[:space:]]*[`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]?[[:space:]]*@[[:space:]]*[`"]?([0-9a-fA-F]{4,40})[`"]?.*/\1/')
    if ! printf '%s' "$cand" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
      continue
    fi
    ck_any_hex=true
    ck_full=$(git rev-parse --verify "${cand}^{commit}" 2>/dev/null || true)
    if [ -n "$ck_full" ] && [ "$ck_full" = "$head_full" ]; then
      ck_sha=$cand
      ck_fresh=true
      break
    fi
    ck_sha=$cand
  done < <(grep -E '^Checkpoint:' "$aw" 2>/dev/null || true)
  if ! $ck_fresh; then
    if ! $ck_any_hex; then
      echo "stale-resume: $aw Checkpoint missing, placeholder, or non-hex (HEAD $head_short)"
      ck_sha=""
    else
      echo "stale-resume: $aw Checkpoint@$ck_sha != HEAD@$head_short — suggest /agent-memory sync"
    fi
  fi
fi
state=".agents/memory/.hook-sync-state"
if [ ! -f "$state" ]; then
  echo "hook-state-absent: .agents/memory/.hook-sync-state missing — hooks unused or not installed (info; not the same as evidence cleared)"
else
# Count pending paths only — never echo path values (W011).
  paths=$(grep '^session_touched_files=' "$state" | cut -d= -f2- || true)
  if [ -n "$paths" ]; then
    n=$(printf '%s' "$paths" | tr '\036' '\n' | grep -c . || true)
    if [ "${n:-0}" -gt 0 ]; then
      dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      ck_fresh=false
      if [ -n "$ck_sha" ] && [ -n "$head_full" ]; then
        ck_full=$(git rev-parse --verify "${ck_sha}^{commit}" 2>/dev/null || true)
        [ -n "$ck_full" ] && [ "$ck_full" = "$head_full" ] && ck_fresh=true
      fi
      if $ck_fresh && [ "${dirty:-1}" -eq 0 ]; then
        # Warning — consume was skipped after a covering sync
        echo "evidence-stale-uncleared: $n path(s) remain with Checkpoint@HEAD and clean tree — run consume-evidence (sync step)"
      elif $ck_fresh && [ "${dirty:-0}" -gt 0 ]; then
        # Info by default — hooks re-list dirty paths until commit; escalate in judgment only if meaning is missing
        echo "evidence-dirty-requeue: $n path(s) with Checkpoint@HEAD and dirty tree (info) — expected until commit when Task/Progress/log already cover those paths; escalate to evidence-pending only if meaning is missing"
      else
        # Warning — Checkpoint behind or no active-work; need catch-up meaning
        echo "evidence-pending: $n path(s) in .hook-sync-state — active-work/log lack covering meaning or Checkpoint behind HEAD; run /agent-memory sync then consume"
      fi
    fi
  fi
fi
# Memory claims hooks/state absent while FS shows otherwise
if grep -qiE 'hooks? (not |never )?installed|\.hook-sync-state.*(absent|missing)|checkpoint path evidence unavailable' \
  .agents/memory/current.md .agents/memory/log.md 2>/dev/null; then
  carrier=false
  { test -f .cursor/hooks.json || test -f .claude/hooks/agent-memory-sync.sh || \
    test -f .opencode/plugins/agent-memory.ts || test -f .opencode/plugin/agent-memory.ts || \
    test -f .codex/hooks/agent-memory-sync.sh || test -f .gemini/hooks/agent-memory-sync.sh || \
    test -f .github/hooks/agent-memory-sync.sh || test -f .github/hooks/agent-memory.json; } && carrier=true
  if [ -f "$state" ] || $carrier; then
    echo "blocker-hooks-contradiction: current.md/log claim hooks or .hook-sync-state absent, but state and/or harness carrier exists — suggest /agent-memory sync"
  fi
fi
# Scaffold placeholder left after real session headings exist
if grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' .agents/memory/log.md 2>/dev/null && \
  grep -q '_No entries yet\._' .agents/memory/log.md 2>/dev/null; then
  echo "log-placeholder-stale: _No entries yet._ coexists with a session heading — remove placeholder (bootstrap/sync)"
fi

# AGENTS.md is SoT for project docs — Canonical bullets that AGENTS already links
_am_hrefs=""
if [ -f AGENTS.md ]; then
  _am_hrefs=$(mktemp "${TMPDIR:-/tmp}/am-agents-hrefs.XXXXXX")
  trap 'rm -f "$_am_hrefs"' EXIT
  grep -oE '\[[^]]+\]\([^)]+\)' AGENTS.md | sed -E 's/^[^]]*\]\(//; s/\)$//' | while IFS= read -r u; do
    case "$u" in http*|https*|'#'*) continue ;; esac
    p=$(printf '%s' "$u" | sed 's/#.*//; s|^\./||; s|^/||')
    [ -n "$p" ] || continue
    printf '%s\n' "$p"
  done | sort -u > "$_am_hrefs"
fi
if [ -n "$_am_hrefs" ] && [ -f .agents/memory/index.md ]; then
  awk '
    /^## Canonical project sources/ { in_src=1; next }
    /^## / { in_src=0 }
    in_src && /^- / {
      if (match($0, /\[[^]]+\]\([^)]+\)/)) {
        u = substr($0, RSTART, RLENGTH)
        sub(/^\[[^]]*\]\(/, "", u)
        sub(/\)$/, "", u)
        print u
      }
    }
  ' .agents/memory/index.md | while IFS= read -r u; do
    case "$u" in http*|https*|'#'*) continue ;; esac
    rel=$(printf '%s' "$u" | sed 's/#.*//; s|^\./||')
    # index.md lives in .agents/memory/ — ../../docs/foo → docs/foo
    case "$rel" in
      ../../*) rel=${rel#../../} ;;
      ../*) rel=${rel#../} ;;
    esac
    grep -qxF -e "$rel" -- "$_am_hrefs" && \
      echo "index-dup-agents: Canonical source $rel is already linked from AGENTS.md — drop the index bullet"
  done
fi

# Live Source-only decisions whose path AGENTS.md already maps
if [ -n "$_am_hrefs" ] && [ -f .agents/memory/decisions.md ]; then
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
      flush()
      heading = $0
      in_e = 1
      live = 0
      body = 0
      src = ""
      next
    }
    /^## / {
      flush()
      in_e = 0
      next
    }
    in_e && /\*\*Status:\*\*[[:space:]]*live/ { live = 1 }
    in_e && /\*\*(Context|Decision):\*\*/ { body = 1 }
    in_e && /\*\*Source:\*\*/ { src = $0 }
    END { flush() }
    function flush() {
      if (in_e && live && src != "" && !body)
        print heading "\t" src
    }
  ' .agents/memory/decisions.md | while IFS=$(printf '\t') read -r heading src; do
    printf '%s\n' "$src" | grep -oE '\[[^]]+\]\([^)]+\)' | sed -E 's/^[^]]*\]\(//; s/\)$//' | while IFS= read -r u; do
      case "$u" in http*|https*|'#'*) continue ;; esac
      rel=$(printf '%s' "$u" | sed 's/#.*//; s|^\./||')
      case "$rel" in
        ../../*) rel=${rel#../../} ;;
        ../*) rel=${rel#../} ;;
      esac
      grep -qxF -e "$rel" -- "$_am_hrefs" && \
        echo "decision-docs-map: $heading — live Source-only and AGENTS.md already links $rel — drop or leave off memory"
    done
  done
fi
rm -f "$_am_hrefs"

# Ghost docs/ADR links in memory (skip instructions.md; skip fenced examples)
find .agents/memory -name '*.md' ! -name 'instructions.md' 2>/dev/null | while read -r f; do
  awk -v file="$f" '
    /^```/ { fence = !fence; next }
    fence { next }
    {
      s = $0
      while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        link = substr(s, RSTART, RLENGTH)
        pos = index(link, "](")
        u = substr(link, pos + 2)
        u = substr(u, 1, length(u) - 1)
        if (u !~ /^https?:/ && u !~ /^#/ && u ~ /(docs\/|adr\/)/) {
          file_part = u
          sub(/#.*$/, "", file_part)
          print file "\t" file_part
        }
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$f"
done | while IFS=$'\t' read -r f file_part; do
  dir=$(CDPATH= cd -- "$(dirname -- "$f")" && pwd)
  if ! ( CDPATH= cd -- "$dir" && test -e "$file_part" ); then
    echo "memory-ghost-docs: $f -> $file_part"
  fi
done

# Project-docs index exists but AGENTS.md omits it
if [ -f AGENTS.md ]; then
  agents_txt=$(cat AGENTS.md)
  check_gap() {
    path=$1
    if [ -e "$path" ]; then
      printf '%s' "$agents_txt" | grep -qF -- "$path" || \
        echo "agents-docs-gap: $path exists and AGENTS.md does not link it — docs map is AGENTS.md (init/update/consolidate)"
    fi
  }
  check_gap docs/README.md
  [ -d docs/architecture ] && [ -n "$(find docs/architecture -type f 2>/dev/null | head -1)" ] && \
    check_gap docs/architecture
  [ -d docs/specs ] && [ -n "$(find docs/specs -type f 2>/dev/null | head -1)" ] && \
    check_gap docs/specs
  for d in docs/architecture/decisions docs/decisions adr docs/adr; do
    if [ -d "$d" ] && [ -n "$(find "$d" -type f 2>/dev/null | head -1)" ]; then
      check_gap "$d"
      break
    fi
  done
fi

# Helper: true if file contains an agent-memory block
has_block() { grep -q '<agent-memory>' "$1" 2>/dev/null; }

# (a) Potential double-injection — block in AGENTS.md AND a harness-native file
# when AGENTS.md is not needed as a shared carrier
agents_block=false; has_block AGENTS.md && agents_block=true
codex_or_opencode=false
{ test -d .codex || test -d .opencode; } && codex_or_opencode=true
claude_delegates=false
test -f CLAUDE.md && grep -qE '@(\./)?AGENTS\.md' CLAUDE.md && claude_delegates=true
gemini_delegates=false
test -f GEMINI.md && grep -qE '@(\./)?AGENTS\.md' GEMINI.md && gemini_delegates=true
shared_carrier=false
{ $codex_or_opencode || $claude_delegates || $gemini_delegates; } && shared_carrier=true

if $agents_block; then
  has_block .cursor/rules/agent-memory.mdc && \
    ! $shared_carrier && echo "double-injection: AGENTS.md + .cursor/rules/agent-memory.mdc"
  has_block .github/instructions/agent-memory.instructions.md && \
    ! $shared_carrier && echo "double-injection: AGENTS.md + agent-memory.instructions.md"
fi

# (b) Delegation canary — block in BOTH delegator and AGENTS.md
for f in CLAUDE.md GEMINI.md; do
  test -f "$f" || continue
  grep -qE '@(\./)?AGENTS\.md' "$f" || continue
  has_block "$f" && has_block AGENTS.md && \
    echo "delegation-canary: block in $f and AGENTS.md (remove from $f)"
done

# Installed method missing write-floor / hop headings
inst=".agents/memory/instructions.md"
if [ -f "$inst" ]; then
  grep -q '^## Write floor' "$inst" || \
    echo "method-stale: $inst missing ## Write floor — suggest /agent-memory update"
  grep -q '^## Recall hop' "$inst" || \
    echo "method-stale: $inst missing ## Recall hop — suggest /agent-memory update"
fi

# Carrier block present but missing current write-floor tokens
for carrier in AGENTS.md CLAUDE.md GEMINI.md \
  .cursor/rules/agent-memory.mdc \
  .github/instructions/agent-memory.instructions.md; do
  test -f "$carrier" || continue
  has_block "$carrier" || continue
  if ! grep -q 'write floor' "$carrier" || ! grep -q 'Reusable lesson' "$carrier" || \
     ! grep -q 'Skip is the default' "$carrier"; then
    echo "carrier-stale: $carrier agent-memory block missing write floor / Reusable lesson / Skip is the default — suggest /agent-memory update"
  fi
done

# Five shared scripts travel together when any one is present
need="agent-memory-common.sh agent-memory-sync.sh agent-memory-session.sh agent-memory-consume-evidence.sh agent-memory-print-evidence.sh"
for dir in .cursor/hooks .claude/hooks .codex/hooks .opencode/hooks .github/hooks .gemini/hooks .git/hooks; do
  [ -d "$dir" ] || continue
  found=false
  for s in $need; do
    [ -f "$dir/$s" ] && found=true
  done
  $found || continue
  for s in $need; do
    [ -f "$dir/$s" ] || echo "hook-incomplete: $dir missing $s — re-run install hooks"
  done
done

# OpenCode plugin path
if [ -d .opencode/plugin ] && [ ! -f .opencode/plugins/agent-memory.ts ]; then
  echo "opencode-legacy-plugin: .opencode/plugin/ present without .opencode/plugins/agent-memory.ts — re-run install hooks opencode"
fi
if [ -f .opencode/plugins/agent-memory.ts ] && [ ! -f .opencode/plugins/safe-script.ts ]; then
  echo "hook-incomplete: .opencode/plugins/safe-script.ts missing — re-run install hooks opencode"
fi
