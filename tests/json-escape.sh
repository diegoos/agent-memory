#!/usr/bin/env bash
# Unit checks for json_escape (sessionStart JSON stdout safety).
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../hooks/agent-memory-hooks/agent-memory-common.sh
. "$repo_root/hooks/agent-memory-hooks/agent-memory-common.sh"

fail() {
  printf 'fail - json-escape: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local got=$1 want=$2 label=$3
  [ "$got" = "$want" ] || fail "$label (got=$(printf '%q' "$got") want=$(printf '%q' "$want"))"
}

assert_json_string() {
  local escaped=$1 label=$2
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.loads("\"" + sys.argv[1] + "\"")' "$escaped" ||
      fail "$label: not valid inside a JSON string"
  elif command -v jq >/dev/null 2>&1; then
    printf '"%s"\n' "$escaped" | jq -e . >/dev/null ||
      fail "$label: not valid inside a JSON string"
  else
    fail "python3 or jq required to validate JSON round-trip"
  fi
}

assert_eq "$(json_escape 'hello')" 'hello' plain
assert_eq "$(json_escape 'a"b')" 'a\"b' quote
assert_eq "$(json_escape 'a\b')" 'a\\b' backslash
assert_eq "$(json_escape $'a\nb')" 'a\nb' newline
assert_eq "$(json_escape $'a\rb')" 'a\rb' cr
assert_eq "$(json_escape $'a\tb')" 'a\tb' tab
assert_eq "$(json_escape $'a\bb')" 'a\bb' backspace
assert_eq "$(json_escape $'a\fb')" 'a\fb' formfeed
assert_eq "$(json_escape $'a\x01b')" 'a\u0001b' soh
assert_eq "$(json_escape $'a\x1fb')" 'a\u001fb' unit_separator
assert_eq "$(json_escape $'a\x7fb')" 'a\u007fb' del
assert_eq "$(json_escape 'café')" 'café' utf8_latin
assert_eq "$(json_escape '日本語')" '日本語' utf8_cjk

payload=$'ctrl:\x01\x08 line\n quote:" slash:\\ end'
escaped=$(json_escape "$payload")
assert_json_string "$escaped" control_payload
# Round-trip via Python when available (exact Unicode restore).
if command -v python3 >/dev/null 2>&1; then
  restored=$(python3 -c 'import json,sys; print(json.loads("\"" + sys.argv[1] + "\""), end="")' "$escaped")
  [ "$restored" = "$payload" ] || fail "python round-trip mismatch"
fi

printf 'ok - json-escape\n'
