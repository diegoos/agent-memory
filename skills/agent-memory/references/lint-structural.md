# Lint structural checks

Disclosed from `references/lint.md` step 2. Run every script. Cwd is named on each block. Emit every matching finding ID. Skip listed placeholders. Do not fix here.

**Done when:** every block ran; stdout is the finding list for the Report.

## From `.agents/memory/`

````bash
report_empty_optional() {
  _file=$1
  _heading=$2
  grep -q "^${_heading}" "$_file" || return 0
  awk -v heading="$_heading" -v file="$_file" '
    $0 == heading { in_sec=1; next }
    /^## / { in_sec=0 }
    in_sec && /^- / && $0 !~ /^- _none_$/ { has=1 }
    END {
      if (!has) print "empty-optional-section: " file " " heading " — omit empty optional sections (add only with content)"
    }
  ' "$_file"
}

# Broken relative links inside memory (skip method placeholders)
grep -rhoE '\]\(\./[^)]+\)' . | sed -E 's/^\]\(\.\/([^)]+)\)$/\1/' \
  | sort -u | while read -r f; do
    case "$f" in
      file) continue ;; # when editing: contract placeholder
    esac
    # Shape examples in index.md — e.g. learnings-<topic>.md
    printf '%s' "$f" | grep -q '<' && continue
    test -e "$f" || echo "missing: $f"
  done

# Recall / legacy files present but not linked from index.md
for f in decisions.md log.md learnings.md \
         vision.md architecture.md patterns.md mistakes.md known-issues.md project.md; do
  [ -f "$f" ] || continue
  grep -q "$(basename "$f")" index.md || echo "orphan: $f"
done
find . -maxdepth 1 -name 'learnings-*.md' 2>/dev/null | while read -r f; do
  grep -q "$(basename "$f")" index.md || echo "orphan: $f"
done
for d in architecture domains components features episodes changes timeline; do
  [ -d "$d" ] || continue
  echo "graph-tree: $d/ — do not scaffold graph folders; pointer in index.md instead"
done
for d in domains features; do
  [ -d "$d" ] || continue
  find "$d" -name '*.md' 2>/dev/null | while read -r f; do
    grep -q "$(basename "$f")" index.md || echo "orphan: $f"
  done
done

# Required headings for resume (agent-owned) — core only
grep -q '^## In progress' current.md || echo "missing-heading: current.md ## In progress"
# In progress cites a missing active-work file (do not require listing every local active-work)
awk '
  /^## In progress/ { in_ip=1; next }
  /^## / { in_ip=0 }
  in_ip && /^- / && $0 !~ /^- _none_$/ { print }
' current.md | while IFS= read -r bullet; do
  printf '%s\n' "$bullet" | grep -oE 'active-work/[A-Za-z0-9._-]+(\.md)?' | while IFS= read -r p; do
    name=$(basename "$p" .md)
    [ "$name" = "TEMPLATE" ] && continue
    test -e "active-work/${name}.md" || echo "current-stale-branch: current.md In progress -> active-work/${name}.md"
  done
done
for h in '## Blockers / attention' '## Handoff'; do
  report_empty_optional current.md "$h"
done
[ -f active-work/TEMPLATE.md ] && echo "template-in-memory: active-work/TEMPLATE.md — delete; copy scaffold is the skill references/active-work-template.md"
find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
  for h in '## Task' '## Next step' '## Validation'; do
    grep -q "^${h}" "$f" || echo "missing-heading: $f $h"
  done
  # Optional sections: validate shape when present; empty (_none_ only) → suggest strip
  for h in '## Progress' '## Assumptions / open questions' '## Blockers' \
           '## Rejected approaches' '## References' '## Hold'; do
    report_empty_optional "$f" "$h"
  done
  # Allow optional backticks around date/sha (legacy); prefer plain form
  if ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}' "$f"; then
    echo "missing-checkpoint: $f"
  elif grep -qE '^Checkpoint: `' "$f"; then
    echo "checkpoint-backticks: $f — prefer Checkpoint: YYYY-MM-DD @ SHORT-SHA without backticks"
  elif ! grep -qE '^Checkpoint: [`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]? @ [`"]?[0-9a-fA-F]{4,40}[`"]?[[:space:]]*$' "$f"; then
    echo "checkpoint-prose: $f — Checkpoint line must be only date @ sha (no trailing TEMPLATE instructions)"
  fi
  # Next step action bullets must not be a memory skill command (ignore section blurbs)
  awk '
    /^## Next step/ { in_ns=1; next }
    /^## / { in_ns=0 }
    in_ns && /^-/ && /\/agent-memory[[:space:]]/ {
      print "stale-next-step: '"$f"' — Next step cites /agent-memory; use a product action (skill cmds → Validation or report)"
      exit
    }
  ' "$f"
  grep -q '^## Touched files' "$f" && echo "legacy-touched-files: $f"
  awk '
    /^## Hold$/ { in_h=1; next }
    /^## / { in_h=0 }
    in_h && /^- / && $0 !~ /^- _none_$/ { n++ }
    END {
      if (n > 3)
        print "hold-overflow: '"$f"' — Hold max 3 bullets (branch scratch; not learnings)"
    }
  ' "$f"
done

# Session headings in log.md (ignore fenced examples, title, and Format docs)
# Real entries: ## [YYYY-MM-DD] … — warn on other ## headings outside fences
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^# / { next }
  /^## Format($| )/ { next }
  /^## / && $0 !~ /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    print "bad-log-heading: " $0
  }
' log.md

# Same calendar day + same [type] more than once (stale inventory left behind)
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    date = substr($0, 5, 10)
    type = "unknown"
    if ($0 ~ /\[feat\]/) type = "feat"
    else if ($0 ~ /\[fix\]/) type = "fix"
    else if ($0 ~ /\[chore\]/) type = "chore"
    else if ($0 ~ /\[review\]/) type = "review"
    else if ($0 ~ /\[docs\]/) type = "docs"
    else if ($0 ~ /\[refactor\]/) type = "refactor"
    else if ($0 ~ /\[test\]/) type = "test"
    else if ($0 ~ /\[perf\]/) type = "perf"
    else if ($0 ~ /\[security\]/) type = "security"
    else if ($0 ~ /\[release\]/) type = "release"
    else if ($0 ~ /\[ingest\]/) type = "ingest"
    else if ($0 ~ /\[improve\]/) type = "improve"
    key = date " " type
    n[key]++
  }
  END {
    for (k in n) if (n[k] > 1)
      print "same-day-dup-log: " k " has " n[k] " headings — update today'\''s heading in place when the new outcome supersedes"
  }
' log.md

# Closed [type] missing from a session heading
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    if ($0 !~ /\[(feat|fix|chore|review|docs|refactor|test|perf|security|release|ingest|improve)\]/)
      print "log-unknown-type: " $0 " — rewrite [type] to a closed token (feat|fix|chore|review|docs|refactor|test|perf|security|release|ingest|improve)"
  }
' log.md

# Superseded decision still carrying Context/Decision body
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    heading = $0
    in_e = 1
    super = 0
    body = 0
    next
  }
  /^## / {
    flush()
    in_e = 0
    next
  }
  in_e && /\*\*Status:\*\*[[:space:]]*superseded/ { super = 1 }
  in_e && /\*\*(Context|Decision):\*\*/ { body = 1 }
  END { flush() }
  function flush() {
    if (in_e && super && body)
      print "decision-body-bloat: " heading " — collapse superseded to heading + Status + Superseded by:"
  }
' decisions.md

# Canonical source catalog (index is a short map, not a bibliography)
awk '
  /^## Canonical project sources/ { in_src = 1; next }
  /^## / { in_src = 0 }
  in_src && /^- / && $0 !~ /_None yet/ { n++ }
  END {
    if (n > 3)
      print "index-catalog: " n " canonical source bullets — max 3; project docs live on AGENTS.md; extra stay in Git or when editing:"
  }
' index.md

# Typed Relates: verbs (closed list — unknown-relates-verb) + dead targets (relates-missing)
grep -rnE --include='*.md' \
  '[[:space:]]*- Relates:|[[:space:]]*- caused_by:|^Caused by:|^Contradicts:|^See:|^Supersedes:|^Superseded by:' . 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    ./instructions.md:*) continue ;;
  esac
  path=$(printf '%s\n' "$line" | cut -d: -f1)
  body=$(printf '%s\n' "$line" | cut -d: -f3-)
  case "$path" in
    ./decisions.md) ;;
    *)
      printf '%s' "$body" | grep -qE '[[:space:]]*- Relates:|[[:space:]]*- caused_by:' || continue
      ;;
  esac
  verb=""
  if printf '%s' "$body" | grep -qE '[[:space:]]*- Relates:'; then
    verb=$(printf '%s\n' "$body" | sed -E 's/.*- Relates:[[:space:]]*//; s/[[:space:]].*$//; s/\[.*//; s/:.*//')
  elif printf '%s' "$body" | grep -qE '[[:space:]]*- caused_by:'; then
    verb=caused_by
  elif printf '%s' "$body" | grep -qE '^Caused by:'; then
    verb=caused_by
  elif printf '%s' "$body" | grep -qE '^Contradicts:'; then
    verb=contradicts
  elif printf '%s' "$body" | grep -qE '^See:'; then
    verb=see
  elif printf '%s' "$body" | grep -qE '^Supersedes:'; then
    verb=supersedes
  elif printf '%s' "$body" | grep -qE '^Superseded by:'; then
    verb=superseded_by
  fi
  printf '%s' "$verb" | grep -q '<' && continue
  [ -n "$verb" ] || continue
  printf '%s' "$verb" | grep -qE '^(supersedes|superseded_by|caused_by|contradicts|see)$' \
    || echo "unknown-relates-verb: $line"
  printf '%s' "$body" | grep -oE '\[[^]]+\]\([^)]+\)' | while IFS= read -r md; do
    url=$(printf '%s' "$md" | sed -E 's/^[^]]*\]\(//; s/\)$//')
    case "$url" in
      http*|https*|'#'*) continue ;;
    esac
    file_part=$(printf '%s' "$url" | sed 's/#.*//')
    [ -n "$file_part" ] || continue
    printf '%s' "$file_part" | grep -q '<' && continue
    target="$(dirname "$path")/$file_part"
    if [ ! -e "$target" ]; then
      echo "relates-missing: $line -> $file_part"
      continue
    fi
    # If the markdown link has #fragment, require it in the target (heading or fragment string)
    case "$url" in
      *'#'*) ;;
      *) continue ;;
    esac
    frag=$(printf '%s' "$url" | sed 's/^[^#]*#//')
    [ -n "$frag" ] || continue
    printf '%s' "$frag" | grep -q '<' && continue
    grep -qF "$frag" "$target" && continue
    slug_words=$(printf '%s' "$frag" | tr '-' ' ')
    grep -qiF "$slug_words" "$target" || echo "relates-missing: $line -> ${file_part}#${frag}"
  done
done

# H2 learning/pitfall: Evidence names a recall file but no Relates (learning-missing-relates)
find . -maxdepth 1 \( -name 'learnings.md' -o -name 'learnings-*.md' \) 2>/dev/null | while read -r f; do
  awk -v file="$f" '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\] \[(learning|pitfall)\]/ {
      flush()
      heading = $0
      in_h2 = 1
      evidence_recall = 0
      has_relates = 0
      next
    }
    /^## / {
      flush()
      in_h2 = 0
      next
    }
    in_h2 && /^- Evidence:/ && /(^|[^A-Za-z0-9_-])(decisions\.md|log\.md|learnings\.md|learnings-[A-Za-z0-9._-]+\.md)/ {
      evidence_recall = 1
    }
    in_h2 && /^- Relates:/ { has_relates = 1 }
    END { flush() }
    function flush() {
      if (in_h2 && evidence_recall && !has_relates)
        print "learning-missing-relates: " file " " heading
    }
  ' "$f"
done

# Empty closed-session headings (no bullets under heading)
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    if (heading && !has_bullet) print "empty-log-heading: " heading
    heading = $0; has_bullet = 0; next
  }
  heading && /^- / { has_bullet = 1 }
  END {
    if (heading && !has_bullet) print "empty-log-heading: " heading
  }
' log.md

# No session headings (scaffold / over-prune)
if ! grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' log.md 2>/dev/null; then
  echo "empty-log: no session headings — primary write or /agent-memory sync after durable work"
  if grep -qE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' learnings.md 2>/dev/null \
     || grep -qE 'learnings\.md' index.md 2>/dev/null; then
    echo "empty-log-after-scaffold: recall exists (learnings/index) but log has zero sessions — likely consolidate over-pruned current session; restore a short founding heading"
  fi
fi

# Legacy path-only bullets
grep -nE '^- `[^`]+`$|^- changed [0-9]+ files' log.md 2>/dev/null | \
  while read -r line; do echo "legacy-path-bullet: $line"; done

# Stale per-branch active-work: a file whose branch no longer exists
# (skipped when git lists no branches — no commits yet / not a git repo)
branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
[ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
  printf '%s\n' "$branches" | grep -qx "$(basename "$f" .md)" || echo "stale: $f"
done

# Method token typos (skip instructions.md — method text)
grep -rnE --include='*.md' \
  'when editting:|when-editing:|Checkpont:|Superceded|[[:space:]]Relate:|Relates to:' . 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    ./instructions.md:*) continue ;;
  esac
  echo "typo-token: $line"
done

# Required-heading misspellings
grep -rnE --include='*.md' \
  '^## In progres$|^## Next steps$|^## Validaton$|^## Checkpont$|^## Assumtions' . 2>/dev/null |
while IFS= read -r line; do echo "typo-heading: $line"; done

# Path-scoped topic splits listed without a when editing: hint
awk '
  /^## Recall files/ { in_r=1; next }
  /^## / { in_r=0 }
  in_r && /learnings-[A-Za-z0-9._-]+\.md/ && $0 !~ /when editing:/ {
    print "learning-hidden: " $0 " — path-scoped split needs when editing:"
  }
' index.md
````

## From project root

````bash
branch=$(git branch --show-current 2>/dev/null || true)
branch=$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-')
[ -n "$branch" ] || branch=local
aw=".agents/memory/active-work/${branch}.md"
head_full=$(git rev-parse HEAD 2>/dev/null || true)
head_short=$(git rev-parse --short HEAD 2>/dev/null || true)
ck_sha=""
if [ -f "$aw" ] && [ -n "$head_full" ]; then
  ck_line=$(grep -E '^Checkpoint:' "$aw" | head -1 || true)
  # Strip optional backticks around date/sha (legacy TEMPLATE copies)
  ck_sha=$(printf '%s' "$ck_line" | sed -E 's/^Checkpoint:[[:space:]]*[`"]?[0-9]{4}-[0-9]{2}-[0-9]{2}[`"]?[[:space:]]*@[[:space:]]*[`"]?([0-9a-fA-F]{4,40})[`"]?.*/\1/')
  if ! printf '%s' "$ck_sha" | grep -Eq '^[0-9a-fA-F]{4,40}$'; then
    echo "stale-resume: $aw Checkpoint missing, placeholder, or non-hex (HEAD $head_short)"
    ck_sha=""
  else
    ck_full=$(git rev-parse --verify "${ck_sha}^{commit}" 2>/dev/null || true)
    if [ -z "$ck_full" ] || [ "$ck_full" != "$head_full" ]; then
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
if [ -f AGENTS.md ] && [ -f .agents/memory/index.md ]; then
  grep -oE '\[[^]]+\]\([^)]+\)' AGENTS.md | sed -E 's/^[^]]*\]\(//; s/\)$//' | while IFS= read -r u; do
    case "$u" in http*|https*|'#'*) continue ;; esac
    p=$(printf '%s' "$u" | sed 's/#.*//; s|^\./||; s|^/||')
    [ -n "$p" ] || continue
    printf '%s\n' "$p"
  done | sort -u > /tmp/am-agents-hrefs.$$
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
    grep -qxF "$rel" /tmp/am-agents-hrefs.$$ && \
      echo "index-dup-agents: Canonical source $rel is already linked from AGENTS.md — drop the index bullet"
  done
  rm -f /tmp/am-agents-hrefs.$$
fi

# Ghost docs/ADR links in memory (skip instructions.md)
find .agents/memory -name '*.md' ! -name 'instructions.md' 2>/dev/null | while read -r f; do
  grep -oE '\[[^]]+\]\([^)]+\)' "$f" | sed -E 's/^[^]]*\]\(//; s/\)$//' | while IFS= read -r u; do
    case "$u" in http*|https*|'#'*) continue ;; esac
    file_part=$(printf '%s' "$u" | sed 's/#.*//')
    printf '%s' "$file_part" | grep -qE 'docs/|adr/' || continue
    dir=$(CDPATH= cd -- "$(dirname -- "$f")" && pwd)
    if ! ( CDPATH= cd -- "$dir" && test -e "$file_part" ); then
      echo "memory-ghost-docs: $f -> $file_part"
    fi
  done
done

# Project-docs index exists but AGENTS.md omits it
if [ -f AGENTS.md ]; then
  agents_txt=$(cat AGENTS.md)
  check_gap() {
    path=$1
    if [ -e "$path" ]; then
      printf '%s' "$agents_txt" | grep -qF "$path" || \
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
````
