#!/usr/bin/env bash
# shellcheck disable=SC2016 # awk programs and the scratch copies' literal shell
# Harness for the inventory of Peal's gh calls in docs/guides/belfry.md ("What a session
# can and cannot rely on"): every shell function under plugin/lib/*.sh (not the
# harnesses) that calls peal_gh, _peal_ship_gh or gh itself has a row there, and every
# row's function still calls one; every command (plugin/commands/*.md) with a `gh ...`
# code span is named there.
#
#   bash plugin/lib/gh-callers.test.sh
#
# A caller is found by awk, function by function (`name() {` to `}` at column 0):
# comment lines dropped, quoted strings holding no command substitution dropped, then
# the word peal_gh or _peal_ship_gh anywhere (peal_gh_failed is another word), or gh in
# command position (`gh api`, `set -- gh ...`, `timeout 60 gh ...`, `if`, `while`,
# `until` or `!` before it, `env` or NAME=value assignments before it; not `command -v
# gh`, not `wants gh`). Then the same on scratch copies, each mistake reported.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

REPO=$(cd "$PEAL_ROOT/.." && pwd)

# callers LIB -> "file:function" for each function of LIB/*.sh (not *.test.sh) that calls
# gh, sorted.
callers() {
  local files=()
  local f
  for f in "$1"/*.sh; do
    case $f in *.test.sh) ;; *) files+=("$f") ;; esac
  done
  awk -v q="'" '
    FNR == 1 { fn = ""; file = FILENAME; sub(/.*\//, "", file) }
    /^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/ { fn = $0; sub(/\(.*/, "", fn); next }
    /^}/ { fn = ""; next }
    /^[ \t]*#/ { next }
    {
      line = $0
      while (match(line, /"([^"\\$]|\\.|\$[^(])*"/)) line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
      while (match(line, q "[^" q "]*" q)) line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
      if (line ~ /(^|[^A-Za-z0-9_])(peal_gh|_peal_ship_gh)([^A-Za-z0-9_(]|$)/ \
          || line ~ /(^|[;&|(]|(^|[ \t])(then|do|else|if|while|until|!|--|env|timeout[ \t]+([^ \t]+[ \t]+)?))([ \t]*[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+)*[ \t]*gh([ \t]|$)/) {
        key = file ":" (fn == "" ? "-" : fn)
        if (!(key in seen)) { seen[key] = 1; print key }
      }
    }' "${files[@]}" | sort
}

# rows DOC -> "file:function" for each row of the inventory in DOC (between the
# gh-callers markers), from its first two columns, sorted.
rows() {
  awk '
    /^<!-- gh-callers -->$/ { on = 1; next }
    /^<!-- \/gh-callers -->$/ { on = 0 }
    on && /^\| `/ {
      n = split($0, c, "|")
      fn = c[2]; file = c[3]
      gsub(/[ `]/, "", fn); gsub(/[ `]/, "", file)
      print file ":" fn
    }' "$1" | sort
}

# inventory LIB DOC COMMANDS -> one line per problem: "missing row: file:function",
# "stale row: file:function", "command not listed: /peal:name"; nothing when complete.
inventory() {
  local lib=$1 doc=$2 commands=$3 have want f name
  want=$(callers "$lib")
  have=$(rows "$doc")
  comm -23 <(printf '%s\n' "$want" | sed '/^$/d') <(printf '%s\n' "$have" | sed '/^$/d') | sed 's/^/missing row: /'
  comm -13 <(printf '%s\n' "$want" | sed '/^$/d') <(printf '%s\n' "$have" | sed '/^$/d') | sed 's/^/stale row: /'
  for f in "$commands"/*.md; do
    grep -q '`gh ' "$f" || continue
    name=/peal:$(basename "$f" .md)
    awk '/^<!-- gh-callers -->$/ { on = 1 } /^<!-- \/gh-callers -->$/ { on = 0 } on' "$doc" \
      | grep -q -F -- "\`$name\`" || echo "command not listed: $name"
  done
}

# copy -> a scratch copy of the library, the guide and the commands: LIB, DOC, CMDS.
copy() {
  local dir
  dir=$(scratch_dir)
  mkdir -p "$dir/lib" "$dir/commands"
  cp "$PEAL_ROOT"/lib/*.sh "$dir/lib/"
  cp "$PEAL_ROOT"/commands/*.md "$dir/commands/"
  cp "$REPO/docs/guides/belfry.md" "$dir/belfry.md"
  LIB=$dir/lib DOC=$dir/belfry.md CMDS=$dir/commands
}

cases() {
  check "the inventory is complete" "" \
    "$(inventory "$PEAL_ROOT/lib" "$REPO/docs/guides/belfry.md" "$PEAL_ROOT/commands")"
  check "the inventory has rows" "1" "$([ "$(rows "$REPO/docs/guides/belfry.md" | wc -l)" -ge 30 ] && echo 1)"

  # A new caller without a row.
  copy
  printf '\n%s\n' '_peal_new_caller() {' '  peal_gh "repos/a/b" --jq .id' '}' >>"$LIB/github.sh"
  check "a new caller: missing row" "missing row: github.sh:_peal_new_caller" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # A new caller of gh itself, through set -- and timeout.
  copy
  printf '\n%s\n' '_peal_new_gh() {' '  set -- gh issue list' '  "$@"' '}' \
    '_peal_new_timeout() {' '  x=$(timeout "$T" gh auth status 2>&1)' '}' >>"$LIB/doctor.sh"
  check "gh in command position: missing rows" "missing row: doctor.sh:_peal_new_gh
missing row: doctor.sh:_peal_new_timeout" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # gh after if, while, until, !, env and assignments.
  copy
  printf '\n%s\n' '_peal_gh_if() {' '  if gh auth token >/dev/null; then :; fi' '}' \
    '_peal_gh_while() {' '  while gh api x; do :; done' '}' \
    '_peal_gh_until() {' '  until gh api x; do :; done' '}' \
    '_peal_gh_not() {' '  ! gh api x || return 1' '}' \
    '_peal_gh_env() {' '  env A=1 gh api x' '}' \
    '_peal_gh_assign() {' '  GH_HOST=x gh api y' '}' \
    '_peal_gh_assign_quoted() {' '  out=$(GH_HOST="$h" GH_TOKEN=t gh api y)' '}' >>"$LIB/doctor.sh"
  check "gh after a keyword or assignment: missing rows" "missing row: doctor.sh:_peal_gh_assign
missing row: doctor.sh:_peal_gh_assign_quoted
missing row: doctor.sh:_peal_gh_env
missing row: doctor.sh:_peal_gh_if
missing row: doctor.sh:_peal_gh_not
missing row: doctor.sh:_peal_gh_until
missing row: doctor.sh:_peal_gh_while" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # A row whose function no longer calls gh.
  copy
  printf '%s\n' '| `peal_github_repo_of` | `github.sh` | nothing | Stale. |' >"$DOC.row"
  awk -v row="$(cat "$DOC.row")" '{ print } /^\| `peal_gh` \|/ { print row }' "$DOC" >"$DOC.new" && mv "$DOC.new" "$DOC"
  check "a stale row" "stale row: github.sh:peal_github_repo_of" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # A row dropped.
  copy
  grep -v '^| `_peal_files_prs` |' "$DOC" >"$DOC.new" && mv "$DOC.new" "$DOC"
  check "a row dropped" "missing row: store-files.sh:_peal_files_prs" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # What is no call: a message naming gh, peal_gh_failed, command -v gh, a comment, a
  # word that merely holds gh.
  copy
  printf '\n%s\n' '_peal_no_caller() {' \
    '  # gh api in a comment' \
    '  peal_err "this needs gh api and gh release, logged in"' \
    "  peal_err 'gh pr list failed'" \
    '  command -v gh >/dev/null || return 2' \
    '  peal_gh_failed' \
    '  PEAL_GH_ERRFILE=x peal_gh_telemetry_env' \
    '  _peal_doctor_wants gh && echo ok' \
    '  local gh_state=open' \
    '  x=$(_peal_init_survey_gh issues y)' \
    '}' >>"$LIB/github.sh"
  check "no call: nothing missing" "" "$(inventory "$LIB" "$DOC" "$CMDS")"

  # A command that calls gh, not named.
  copy
  printf '%s\n' '---' 'description: x' '---' 'Run `gh api repos/x` once.' >"$CMDS/newcmd.md"
  check "a command not listed" "command not listed: /peal:newcmd" "$(inventory "$LIB" "$DOC" "$CMDS")"
}

for_each_awk cases
finish
