#!/usr/bin/env bash
# Harness for peal merge-gate (lib/merge-gate.sh, lib/merge-gate.awk), under every awk:
#
#   bash plugin/lib/merge-gate.test.sh
#
# - refused (status 1, the file named): any change to a task keeping its agreed merge,
#   a second file of an id holding merge, merge added in backlog/ and in doing/, quoted
#   either way, a value other than auto, a new task file with it, a done task moved back,
#   a slug renamed with it added, a changed file whose frontmatter does not parse, the
#   tasks folder moved in HEAD's settings with merge under the new folder;
# - passed (status 0): no change, an unrelated edit, a task with merge moved or
#   renamed unchanged, a change with merge dropped, merge removed, the close shape (doing/ without it to done/ with
#   it), a new done/ file with it, an old malformed file left alone, issues storage;
# - fails closed (status 2): BASE empty, all zeros, unknown, starting with "-"; BASE
#   settings that do not parse; no arguments.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"

dir=$(scratch_dir)
git -C "$dir" init -q
git -C "$dir" config user.email t@example.com
git -C "$dir" config user.name t
mkdir -p "$dir/tasks/backlog" "$dir/tasks/doing" "$dir/tasks/done"
# task ID SLUG DIR [FRONTMATTER LINE...] -> a task file.
task() {
  local id=$1 slug=$2 d=$3
  shift 3
  { printf -- '---\nmilestone: m1\n'; [ $# -eq 0 ] || printf '%s\n' "$@"; printf -- '---\n\n# %s — %s\n' "$id" "$slug"; } \
    >"$dir/tasks/$d/$id-$slug.md"
}
task 0001 one backlog
task 0002 two backlog "merge: auto"
task 0003 three doing
task 0004 four "done" "merge: auto"
task 0005 five doing "merge: auto"
printf -- '---\nmilestone: [m1\n---\n# 0006 — six\n' >"$dir/tasks/backlog/0006-six.md"
git -C "$dir" add -A && git -C "$dir" commit -qm base
base=$(git -C "$dir" rev-parse HEAD)

# gate [BASE] -> "status|stdout" of peal merge-gate BASE HEAD after committing the
# caller's change.
gate() {
  local out status
  git -C "$dir" add -A && git -C "$dir" commit -qm change --allow-empty
  out=$(cd "$dir" && "$PEAL" merge-gate "${1-$base}" HEAD 2>/dev/null)
  status=$?
  printf '%s|%s' "$status" "$out"
}
reset() { git -C "$dir" reset -q --hard "$base"; git -C "$dir" clean -qfd; }
# refused NAME FILE -> the gate refuses, naming FILE.
refused() {
  local r
  r=$(gate)
  check "$1: status 1" 1 "${r%%|*}"
  check "$1: names $2" yes "$(case $r in *"refused: $2:"*) echo yes ;; *) echo "no: $r" ;; esac)"
  reset
}
passed() {
  local r
  r=$(gate)
  check "$1: status 0" 0 "${r%%|*}"
  reset
}
closed() {
  local r
  r=$(gate "$2")
  check "$1: status 2" 2 "${r%%|*}"
  reset
}

cases() {
  # Refused.
  task 0001 one backlog "merge: auto"
  refused "merge added in backlog" tasks/backlog/0001-one.md
  task 0003 three doing "merge: auto"
  refused "merge added in doing" tasks/doing/0003-three.md
  task 0001 one backlog 'merge: "auto"'
  refused "double-quoted auto" tasks/backlog/0001-one.md
  task 0001 one backlog "merge: 'auto'"
  refused "single-quoted auto" tasks/backlog/0001-one.md
  task 0001 one backlog "merge: yes"
  refused "a value other than auto" tasks/backlog/0001-one.md
  task 0001 one backlog "merge:"
  refused "an empty merge key" tasks/backlog/0001-one.md
  task 0002 two backlog "merge: [auto]"
  refused "auto made a list" tasks/backlog/0002-two.md
  task 0009 nine backlog "merge: auto"
  refused "a new backlog file with merge" tasks/backlog/0009-nine.md
  git -C "$dir" mv tasks/done/0004-four.md tasks/backlog/0004-four.md
  refused "a done task moved back to backlog" tasks/backlog/0004-four.md
  git -C "$dir" rm -q tasks/backlog/0001-one.md
  task 0001 renamed backlog "merge: auto"
  refused "a slug renamed, merge added" tasks/backlog/0001-renamed.md
  printf -- '---\nmerge: auto\nmerge: auto\n---\n# 0001 — one\n' >"$dir/tasks/backlog/0001-one.md"
  refused "a duplicate merge key" tasks/backlog/0001-one.md
  printf -- '---\nmilestone: m1\n# 0001 — one\n' >"$dir/tasks/backlog/0001-one.md"
  refused "a changed file that does not parse" tasks/backlog/0001-one.md
  printf '\n## Plan\n\nnew plan\n' >>"$dir/tasks/backlog/0002-two.md"
  refused "a Plan added to a task with merge" tasks/backlog/0002-two.md
  printf 'more\n' >>"$dir/tasks/backlog/0002-two.md"
  refused "an edit to a task with merge" tasks/backlog/0002-two.md
  printf '\n## Scope\n\nchanged\n' >>"$dir/tasks/doing/0005-five.md"
  refused "a Scope changed on a doing task with merge" tasks/doing/0005-five.md
  task 0002 two backlog "merge: auto" "needs: [x]"
  refused "a frontmatter change, merge kept" tasks/backlog/0002-two.md
  git -C "$dir" mv tasks/backlog/0002-two.md tasks/backlog/0002-renamed.md
  printf 'more\n' >>"$dir/tasks/backlog/0002-renamed.md"
  refused "renamed with a body change" tasks/backlog/0002-renamed.md
  git -C "$dir" mv tasks/backlog/0002-two.md tasks/doing/0002-two.md
  printf 'more\n' >>"$dir/tasks/doing/0002-two.md"
  refused "moved to doing with a body change" tasks/doing/0002-two.md
  task 0002 other backlog "merge: auto"
  refused "a second file of an agreed id, with merge" tasks/backlog/0002-other.md
  task 0002 other backlog
  refused "a second file of an agreed id, without merge" tasks/backlog/0002-other.md
  # A file BASE holds outside its tasks folder is no task of BASE's: HEAD moving the
  # folder onto it gives it its merge.
  mkdir -p "$dir/work/backlog"
  printf -- '---\nmerge: auto\n---\n# 0007 — seven\n' >"$dir/work/backlog/0007-seven.md"
  git -C "$dir" add -A && git -C "$dir" commit -qm work
  local before r
  before=$(git -C "$dir" rev-parse HEAD)
  mkdir -p "$dir/.peal"
  printf 'tasks: work\n' >"$dir/.peal/config.yml"
  r=$(gate "$before")
  check "the tasks folder moved onto a file with merge: refused" "1|merge-gate: refused: work/backlog/0007-seven.md:" \
    "$(printf '%s' "$r" | head -n 1 | cut -d: -f1-3 | sed 's/$/:/')"
  reset

  # Passed.
  passed "no change"
  printf 'more\n' >>"$dir/tasks/backlog/0001-one.md"
  passed "an unrelated edit, an old malformed file (0006) left alone"
  git -C "$dir" mv tasks/backlog/0002-two.md tasks/doing/0002-two.md
  passed "a task with merge moved from backlog to doing"
  git -C "$dir" mv tasks/backlog/0002-two.md tasks/backlog/0002-renamed.md
  passed "a task with merge renamed"
  task 0002 two backlog
  passed "merge removed"
  printf '\n## Plan\n\nnew plan\n' >>"$dir/tasks/backlog/0002-two.md"
  sed -i '/^merge:/d' "$dir/tasks/backlog/0002-two.md"
  passed "a Plan changed with merge dropped"
  git -C "$dir" rm -q tasks/doing/0003-three.md
  task 0003 three "done" "merge: auto"
  passed "the close shape: doing without merge, done with it"
  task 0010 ten "done" "merge: auto"
  passed "a new done file with merge"
  mkdir -p "$dir/.peal"
  printf 'storage:\n  kind: issues\n' >"$dir/.peal/config.yml"
  task 0001 one backlog "merge: auto"
  r=$(gate)
  check "issues storage: passes" "0|merge-gate: issues storage, nothing to check" "$r"
  reset

  # Fails closed.
  closed "an empty BASE" ""
  closed "an all-zero BASE" 0000000000000000000000000000000000000000
  closed "an unknown BASE" 1234567890123456789012345678901234567890
  closed "a BASE that names no ref" no-such-branch
  closed "a BASE starting with -" --output=x
  check "a BASE starting with -: no file written" no "$([ -e "$dir/x" ] && echo yes || echo no)"
  mkdir -p "$dir/.peal"
  printf 'nosuchkey: 1\n' >"$dir/.peal/config.yml"
  git -C "$dir" add -A && git -C "$dir" commit -qm badconfig
  local bad
  bad=$(git -C "$dir" rev-parse HEAD)
  git -C "$dir" reset -q --hard "$base"
  closed "BASE settings that do not load" "$bad"
  r=$(cd "$dir" && "$PEAL" merge-gate 2>&1)
  check "no arguments: status 2" 2 "$?"
}
for_each_awk cases

finish
