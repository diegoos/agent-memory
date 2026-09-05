#!/usr/bin/env bash
# Structural lint emitters for /agent-memory lint.
# Cwd must be .agents/memory/ (or a fixture with the same file names).
# Do not set -e: grep -q / missing files are expected misses.

report_empty_optional() {
  _file=$1
  _heading=$2
  grep -q -e "^${_heading}" -- "$_file" || return 0
  AM_LINT_FILE="$_file" AM_LINT_HEADING="$_heading" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"]; heading = ENVIRON["AM_LINT_HEADING"] }
    $0 == heading { in_sec=1; next }
    /^## / { in_sec=0 }
    in_sec && /^- / && $0 !~ /^- _none_$/ { has=1 }
    END {
      if (!has) print "empty-optional-section: " file " " heading " — omit empty optional sections (add only with content)"
    }
  ' "$_file"
}

# Heading → github-style slug (translit so único → unico, not nico)
memory_slug() {
  _s=$(printf '%s' "$1" | sed 's/^## //; s/`//g')
  _t=$(printf '%s' "$_s" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || true)
  [ -n "$_t" ] && _s=$_t
  _s=$(printf '%s' "$_s" | tr -d "'\`^~")
  printf '%s' "$_s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

_relates_slug_match() {
  _slug=$1
  _line=$2
  [ -n "$_slug" ] || return 1
  case "$_line" in
    "- Relates:"*) ;;
    *) return 1 ;;
  esac
  printf '%s' "$_line" | grep -qE -- "decisions\\.md#${_slug}([^a-z0-9-]|$)" && return 0
  _norm=$(printf '%s' "$_line" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\`^~")
  [ -n "$_norm" ] && printf '%s' "$_norm" | grep -qE -- "decisions\\.md#${_slug}([^a-z0-9-]|$)" && return 0
  return 1
}

learnings_point_at_heading() {
  _heading=$1
  _slug=$2
  for _lf in learnings.md learnings-*.md; do
    [ -f "$_lf" ] || continue
    while IFS= read -r _line; do
      _relates_slug_match "$_slug" "$_line" && return 0
    done < <(awk '/^```/{fence=!fence;next} fence{next} /^- Relates:/{print}' "$_lf")
  done
  return 1
}

_slug_file=
_slug_list=

_slug_in_cache() {
  _needle=$1
  [ -n "$_needle" ] || return 1
  while IFS= read -r _s; do
    [ -n "$_s" ] && [ "$_s" = "$_needle" ] && return 0
  done <<EOF
${_slug_list}
EOF
  return 1
}

target_has_heading_slug() {
  _t=$1
  _frag=$2
  [ -n "$_frag" ] && [ -f "$_t" ] || return 1
  if [ "$_slug_file" != "$_t" ]; then
    _slug_file=$_t
    _slug_list=
    while IFS= read -r _h; do
      _slug_list="${_slug_list}$(memory_slug "$_h")"$'\n'
    done < <(grep -E -e '^## ' -- "$_t" 2>/dev/null)
  fi
  _slug_in_cache "$_frag" && return 0
  _frag_slug=$(memory_slug "$_frag")
  _slug_in_cache "$_frag_slug" && return 0
  return 1
}

if [ ! -f index.md ] || [ ! -f current.md ]; then
  echo "wrong-cwd: run from .agents/memory/ (see references/lint-structural.md)"
  exit 0
fi

# Broken relative links inside memory (skip method placeholders; skip fenced examples)
find . -name '*.md' 2>/dev/null | while read -r _md; do
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    {
      s = $0
      while (match(s, /\]\(\.\/[^)]+\)/)) {
        print substr(s, RSTART + 4, RLENGTH - 5)
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$_md"
done | sort -u | while read -r f; do
    case "$f" in
      file) continue ;; # when editing: contract placeholder
    esac
    # Shape examples in index.md — e.g. learnings-<topic>.md
    printf '%s' "$f" | grep -qF -- '<' && continue
    test -e "$f" || echo "missing: $f"
  done

# Recall / legacy files present but not linked from index.md
for f in decisions.md log.md learnings.md \
         vision.md architecture.md patterns.md mistakes.md known-issues.md project.md; do
  [ -f "$f" ] || continue
  grep -qF -e "$(basename "$f")" -- index.md || echo "orphan: $f"
done
find . -maxdepth 1 -name 'learnings-*.md' 2>/dev/null | while read -r f; do
  grep -qF -e "$(basename "$f")" -- index.md || echo "orphan: $f"
done
for d in architecture domains components features episodes changes timeline; do
  [ -d "$d" ] || continue
  echo "graph-tree: $d/ — do not scaffold graph folders; pointer in index.md instead"
done
for d in domains features; do
  [ -d "$d" ] || continue
  find "$d" -name '*.md' 2>/dev/null | while read -r f; do
    grep -qF -e "$(basename "$f")" -- index.md || echo "orphan: $f"
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
    grep -q -e "^${h}" -- "$f" || echo "missing-heading: $f $h"
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
  AM_LINT_FILE="$f" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"] }
    /^## Next step/ { in_ns=1; next }
    /^## / { in_ns=0 }
    in_ns && /^-/ && /\/agent-memory[[:space:]]/ {
      print "stale-next-step: " file " — Next step cites /agent-memory; use a product action (skill cmds → Validation or report)"
      exit
    }
  ' "$f"
  grep -q '^## Touched files' "$f" && echo "legacy-touched-files: $f"
  AM_LINT_FILE="$f" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"] }
    /^## Hold$/ { in_h=1; next }
    /^## / { in_h=0 }
    in_h && /^- / && $0 !~ /^- _none_$/ { n++ }
    END {
      if (n > 3)
        print "hold-overflow: " file " — Hold max 3 bullets (branch scratch; not learnings)"
    }
  ' "$f"
  AM_LINT_FILE="$f" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"] }
    /^## Progress$/ { in_p=1; next }
    /^## / { in_p=0 }
    in_p && /^- / && $0 !~ /^- _none_$/ { n++ }
    END {
      if (n > 5)
        print "dup-progress-log: " file " — Progress has " n " bullets (max 5); keep current facts + at most one log pointer"
    }
  ' "$f"
  AM_LINT_FILE="$f" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"] }
    /^## Task$/ { in_t=1; next }
    /^## Next step$/ { in_n=1; in_t=0; next }
    /^## / { in_t=0; in_n=0 }
    in_t && /^- / && /(^Closed[[:space:]]|Closed —|Closed -)/ {
      print "closed-placeholder-resume: " file " — Task is Closed; delete if not the current git branch (lint --fix / consolidate Pass B)"
      exit
    }
    in_n && /^- / && /(delete this file|confirm branch merged)/ {
      print "closed-placeholder-resume: " file " — Next step is only delete/confirm-merged; delete if not the current git branch"
      exit
    }
  ' "$f"
done

# Session headings in log.md (ignore fenced examples, title, and Format docs)
if [ -f log.md ]; then
# Real entries: ## [YYYY-MM-DD] … — warn on other ## headings outside fences
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^# / { next }
  /^## Format($| )/ { in_format = 1; next }
  in_format && /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ { in_format = 0 }
  in_format { next }
  /^## / && $0 !~ /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    print "bad-log-heading: " $0
  }
' log.md

# Same calendar day + same [type] more than once (stale inventory left behind)
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## Format($| )/ { in_format = 1; next }
  in_format && /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ { in_format = 0 }
  in_format { next }
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
  /^## Format($| )/ { in_format = 1; next }
  in_format && /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ { in_format = 0 }
  in_format { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    if ($0 !~ /\[(feat|fix|chore|review|docs|refactor|test|perf|security|release|ingest|improve)\]/)
      print "log-unknown-type: " $0 " — rewrite [type] to a closed token (feat|fix|chore|review|docs|refactor|test|perf|security|release|ingest|improve)"
  }
' log.md

# Superseded body; live+Source wiki; live text still says superseded; live body after learnings Relates
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    heading = $0
    in_e = 1
    super = 0
    live = 0
    body = 0
    has_src = 0
    stale_txt = 0
    relates_learn = 0
    if (tolower($0) ~ /superseded by/) stale_txt = 1
    next
  }
  /^## / {
    flush()
    in_e = 0
    next
  }
  in_e && /\*\*Status:\*\*[[:space:]]*superseded/ { super = 1 }
  in_e && /\*\*Status:\*\*[[:space:]]*live/ { live = 1 }
  in_e && /\*\*(Context|Decision):\*\*/ { body = 1 }
  in_e && /\*\*Source:\*\*/ && /(docs\/|[Aa][Dd][Rr]-)/ { has_src = 1 }
  in_e && /^- Relates:/ && /learnings/ { relates_learn = 1 }
  in_e && tolower($0) ~ /superseded by/ { stale_txt = 1 }
  END { flush() }
  function flush() {
    if (in_e && super && body)
      print "decision-body-bloat: " heading " — collapse superseded to heading + Status + Superseded by:"
    if (in_e && live && has_src && body)
      print "decision-canonical-dup: " heading " — live Source to docs/ADR still has Context/Decision; collapse to pointer"
    if (in_e && live && stale_txt)
      print "decision-stale-live: " heading " — Status live but heading/Source says superseded"
    if (in_e && live && body && relates_learn)
      print "decision-lesson-dup: " heading " — live Context/Decision still present after a learnings Relates; collapse to Status + Relates"
  }
' decisions.md

# Live body with no Relates on the decision, but learnings already points at this heading
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    heading = $0
    in_e = 1
    live = 0
    body = 0
    relates_learn = 0
    next
  }
  /^## / {
    flush()
    in_e = 0
    next
  }
  in_e && /\*\*Status:\*\*[[:space:]]*live/ { live = 1 }
  in_e && /\*\*(Context|Decision):\*\*/ { body = 1 }
  in_e && /^- Relates:/ && /learnings/ { relates_learn = 1 }
  END { flush() }
  function flush() {
    if (in_e && live && body && !relates_learn)
      print heading
  }
' decisions.md | while IFS= read -r heading; do
  slug=$(memory_slug "$heading")
  learnings_point_at_heading "$heading" "$slug" && \
    echo "decision-lesson-dup: $heading — live Context/Decision still present after a learnings Relates; collapse to Status + Relates"
done

# Two live docs-layout headings without a supersede edge (identity = approach noun, not unique title)
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    heading = $0
    in_e = 1
    live = 0
    layout = 0
    has_sup = 0
    if (tolower(heading) ~ /reorganiz|spec-docs|make-docs|docs\/specs|docs suite|docs\/ follows/) layout = 1
    next
  }
  /^## / { flush(); in_e = 0; next }
  in_e && /\*\*Status:\*\*[[:space:]]*live/ { live = 1 }
  in_e && /\*\*Status:\*\*[[:space:]]*superseded/ { live = 0 }
  in_e && /(\*\*Superseded by:\*\*|- Relates:[[:space:]]*supersedes)/ { has_sup = 1 }
  END {
    flush()
    if (n > 1 && u > 1)
      print "live-dup-identity: " n " live docs-layout decisions without a supersede edge — keep the newest, supersede the rest (consolidate Pass A)"
  }
  function flush() {
    if (in_e && live && layout) {
      n++
      if (!has_sup) u++
    }
  }
' decisions.md

# INCIDENT_UNPROMOTED_PER_HEADING — one finding per incident decision with no matching learnings Relates/slug (a single H2 elsewhere does not skip the rest)
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    heading = $0
    in_e = 1
    pathish = 0
    incident = 0
    next
  }
  /^## / {
    flush()
    in_e = 0
    next
  }
  in_e && /(src\/|astro\.config)/ { pathish = 1 }
  in_e && /(rollback|workaround|[Ff]ragment|revert)/ { incident = 1 }
  END { flush() }
  function flush() {
    if (in_e && pathish && incident)
      print heading
  }
' decisions.md | while IFS= read -r heading; do
  slug=$(memory_slug "$heading")
  learnings_point_at_heading "$heading" "$slug" || \
    echo "incident-unpromoted: $heading — incident-shaped decision with src/config path and no matching learnings H2; consolidate Pass A (max 3)"
done

# Live decisions name repo paths but index decisions line has no when editing:
if awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ {
    flush()
    in_e = 1
    live = 0
    pathish = 0
    next
  }
  /^## / { flush(); in_e = 0; next }
  in_e && /\*\*Status:\*\*[[:space:]]*live/ { live = 1 }
  in_e && /(src\/|astro\.config)/ { pathish = 1 }
  END { flush(); exit found ? 0 : 1 }
  function flush() {
    if (in_e && live && pathish) found = 1
  }
' decisions.md 2>/dev/null; then
  if ! grep -qE -- '\[decisions\.md\].*when editing:' index.md 2>/dev/null; then
    echo "decision-hidden: index decisions.md line lacks when editing: while live decisions name src/config paths — consolidate Pass A"
  fi
fi

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
find . -name '*.md' 2>/dev/null | while read -r _md; do
  awk -v path="$_md" '
    /^```/ { fence = !fence; next }
    fence { next }
    /[[:space:]]*- Relates:|^[[:space:]]*- caused_by:|^Caused by:|^Contradicts:|^See:|^Supersedes:|^Superseded by:/ {
      print path ":" FNR ":" $0
    }
  ' "$_md"
done | while IFS= read -r line; do
  case "$line" in
    ./instructions.md:*) continue ;;
  esac
  path=${line%%:*}
  rest=${line#*:}
  body=${rest#*:}
  case "$path" in
    ./decisions.md) ;;
    *)
      [[ "$body" == *"- Relates:"* || "$body" == *"- caused_by:"* ]] || continue
      ;;
  esac
  verb=""
  if [[ "$body" == *"- Relates:"* ]]; then
    verb=${body#*- Relates:}
    verb=${verb#"${verb%%[![:space:]]*}"}
    verb=${verb%%[[:space:]]*}
    verb=${verb%%\[*}
    verb=${verb%%:*}
  elif [[ "$body" == *"- caused_by:"* ]]; then
    verb=caused_by
  elif [[ "$body" == "Caused by:"* ]]; then
    verb=caused_by
  elif [[ "$body" == "Contradicts:"* ]]; then
    verb=contradicts
  elif [[ "$body" == "See:"* ]]; then
    verb=see
  elif [[ "$body" == "Supersedes:"* ]]; then
    verb=supersedes
  elif [[ "$body" == "Superseded by:"* ]]; then
    verb=superseded_by
  fi
  [[ "$verb" == *'<'* ]] && continue
  [ -n "$verb" ] || continue
  case "$verb" in
    supersedes|superseded_by|caused_by|contradicts|see) ;;
    *) echo "unknown-relates-verb: $line" ;;
  esac
  printf '%s' "$body" | grep -oE '\[[^]]+\]\([^)]+\)' | while IFS= read -r md; do
    url=${md#*\](}
    url=${url%)}
    case "$url" in
      http*|https*|'#'*) continue ;;
    esac
    file_part=${url%%#*}
    [ -n "$file_part" ] || continue
    [[ "$file_part" == *'<'* ]] && continue
    target="$(dirname "$path")/$file_part"
    if [ ! -e "$target" ]; then
      echo "relates-missing: $line -> $file_part"
      continue
    fi
    case "$url" in
      *'#'*) ;;
      *) continue ;;
    esac
    frag=${url#*#}
    [ -n "$frag" ] || continue
    [[ "$frag" == *'<'* ]] && continue
    target_has_heading_slug "$target" "$frag" || \
      echo "relates-missing: $line -> ${file_part}#${frag}"
  done
done

# H2 learning/pitfall: Evidence names a recall file but no Relates (learning-missing-relates)
find . -maxdepth 1 \( -name 'learnings.md' -o -name 'learnings-*.md' \) 2>/dev/null | while read -r f; do
  AM_LINT_FILE="$f" awk '
    BEGIN { file = ENVIRON["AM_LINT_FILE"] }
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
  /^## Format($| )/ { in_format = 1; next }
  in_format && /^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]/ { in_format = 0 }
  in_format { next }
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
awk '
  /^```/ { fence = !fence; next }
  fence { next }
  /^- `[^`]+`$/ || /^- changed [0-9]+ files/ { print FILENAME ":" FNR ":" $0 }
' log.md | while read -r line; do echo "legacy-path-bullet: $line"; done
fi

# Stale per-branch active-work: a file whose branch no longer exists
# (skipped when git lists no branches — no commits yet / not a git repo)
branches=$(git branch --format='%(refname:short)' | sed 's#[^A-Za-z0-9._-]#-#g')
[ -n "$branches" ] && find active-work -name '*.md' ! -name 'TEMPLATE.md' 2>/dev/null | while read -r f; do
  printf '%s\n' "$branches" | grep -qx -- "$(basename "$f" .md)" || echo "stale: $f"
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
