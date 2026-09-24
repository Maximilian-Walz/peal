#!/usr/bin/env bash
# Harness for lib/milestones.sh and lib/milestone-read.awk, through `peal milestones`
# and `peal check`, and for the offer and claim rules as library functions:
#
#   bash plugin/lib/milestones.test.sh
#
# The defaults (id from the file name, title from the first heading), every refusal, the
# board's JSON line in the shape of Belfry's contract, and the order milestones come in.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=common.sh
. "$PEAL_ROOT/lib/common.sh"
# shellcheck source=config.sh
. "$PEAL_ROOT/lib/config.sh"
# shellcheck source=milestones.sh
. "$PEAL_ROOT/lib/milestones.sh"

# project -> a new repository with an empty milestones directory; prints its path.
project() {
  local dir
  dir=$(scratch_dir)
  git -C "$dir" init -q
  mkdir -p "$dir/docs/milestones"
  printf '%s\n' "$dir"
}

# milestone DIR NAME [LINE...] -> DIR/docs/milestones/NAME.md with LINEs as frontmatter
# and a body with a heading.
milestone() {
  local dir=$1 name=$2
  shift 2
  { echo ---; [ $# -eq 0 ] || printf '%s\n' "$@"; echo ---; echo; echo "# Heading of $name"; echo; echo "## Goal"; } \
    >"$dir/docs/milestones/$name.md"
}

ms() { (cd "$dir" && "$PEAL" milestones "$@"); }
pcheck() { (cd "$dir" && "$PEAL" check); }

cases() {
  local dir out

  # The design's example, as a line and as the board's JSON line of Belfry's contract.
  dir=$(project)
  milestone "$dir" combat "id: m08" "title: Combat" "state: current" "order: 8" "due: 2026-11-01"
  check "example: line" "m08 current 8 2026-11-01 Combat" "$(ms)"
  check "example: json" '{"milestone":{"id":"m08","title":"Combat","state":"current","order":8,"due":"2026-11-01"}}' \
    "$(ms --json)"
  out=$(pcheck 2>&1)
  check "example: check" "0:" "$?:$out"

  # Defaults: the id is the file name, the title the first heading; empty fields are left
  # out of the JSON line and shown as - in the list.
  dir=$(project)
  milestone "$dir" m01 "state: done"
  check "defaults: line" "m01 done - - Heading of m01" "$(ms)"
  check "defaults: json" '{"milestone":{"id":"m01","title":"Heading of m01","state":"done"}}' "$(ms --json)"
  printf -- '---\nstate: open\n---\nNo heading here.\n' >"$dir/docs/milestones/m02.md"
  check "no heading: no title" '{"milestone":{"id":"m02","state":"open"}}' "$(ms --json | sed -n 2p)"
  milestone "$dir" m03 "state: open" "title: ''"
  check "empty title: the heading" "m03 open - - Heading of m03" "$(ms | sed -n 3p)"
  printf '# Not a milestone\n' >"$dir/docs/milestones/notes.txt"
  mkdir "$dir/docs/milestones/renders"
  check "only .md files" "3" "$(ms | wc -l | tr -d ' ')"

  # JSON strings are escaped; order loses its leading zeros.
  dir=$(project)
  milestone "$dir" m1 "state: open" "title: 'Say \"hi\" \\ bye'" "order: 007"
  check "json: escaped, order a number" '{"milestone":{"id":"m1","title":"Say \"hi\" \\ bye","state":"open","order":7}}' \
    "$(ms --json)"
  milestone "$dir" m1 "state: open" "order: -02"
  check "json: negative order" '{"milestone":{"id":"m1","title":"Heading of m1","state":"open","order":-2}}' "$(ms --json)"

  # The order: by order, those without one last, then by id.
  dir=$(project)
  milestone "$dir" a "state: parked"
  milestone "$dir" b "state: done" "order: 10"
  milestone "$dir" c "state: current" "order: 9"
  milestone "$dir" d "state: open"
  milestone "$dir" e "state: open" "order: -1"
  check "order" "$(printf '%s\n' e c b a d)" "$(ms | cut -d' ' -f1)"
  check "order: json alike" "$(printf '%s\n' e c b a d)" "$(ms --json | sed 's/.*"id":"\([^"]*\)".*/\1/')"

  # No directory, or an empty one: no milestones and nothing wrong.
  dir=$(project)
  check "empty directory" ":0" "$(ms; echo ":$?")"
  rmdir "$dir/docs/milestones"
  check "no directory" ":0" "$(ms --json; echo ":$?")"
  out=$(pcheck 2>&1)
  check "no directory: check" "0:" "$?:$out"

  # The directory comes from the config.
  mkdir -p "$dir/.peal" "$dir/plan"
  printf 'milestones: plan\n' >"$dir/.peal/config.yml"
  printf -- '---\nstate: current\n---\n' >"$dir/plan/now.md"
  check "configured directory" "now current - - -" "$(ms)"

  # Refusals, each with the file and the reason, by `peal milestones` and `peal check`.
  dir=$(project)
  milestone "$dir" m1
  check_refused "no state" "docs/milestones/m1.md: no state" pcheck
  milestone "$dir" m1 "state:"
  check_refused "empty state" "docs/milestones/m1.md: no state" pcheck
  milestone "$dir" m1 "state: soon"
  check_refused "unknown state" "state 'soon' is not one of open, current, done, parked" pcheck
  milestone "$dir" m1 "state: open" "order: 1.5"
  check_refused "order not an integer" "order '1.5' is not an integer" pcheck
  local bad
  for bad in 2026-11-1 26-11-01 2026-13-01 2026-00-10 2026-04-31 2026-02-29 2026-11-01T10 soon; do
    milestone "$dir" m1 "state: open" "due: $bad"
    check_refused "due $bad" "due '$bad' is not a date, YYYY-MM-DD" pcheck
  done
  milestone "$dir" m1 "state: open" "due: 2028-02-29"
  check "due: a leap day" "m1 open - 2028-02-29 Heading of m1" "$(ms)"
  milestone "$dir" m1 "state: open" "due: 2000-02-29"
  check "due: a leap century" "m1 open - 2000-02-29 Heading of m1" "$(ms)"
  milestone "$dir" m1 "state: open" "due: 1900-02-29"
  check_refused "due: not a leap century" "due '1900-02-29' is not a date" pcheck
  milestone "$dir" m1 "state: open" "owner: me"
  check_refused "unknown key" "docs/milestones/m1.md: line 3: unknown key owner" pcheck
  milestone "$dir" m1 "state: [open]"
  check_refused "state as a list" "line 2: state must be a single value, not a list" pcheck
  milestone "$dir" m1 "state: open" "id: 'm 1'"
  check_refused "id with a space" "id 'm 1' must be letters, digits" pcheck
  milestone "$dir" m1 "state: open" "id: -m1"
  check_refused "id starting with -" "id '-m1' must be letters, digits" pcheck
  milestone "$dir" m1 "state: open" "title: |"
  check_refused "outside the YAML subset" "docs/milestones/m1.md:3: block scalars" pcheck
  check_refused "refused by milestones too" "block scalars" ms
  check_refused "refused by milestones --json too" "block scalars" ms --json
  check "nothing printed when refused" "" "$(ms 2>/dev/null)"

  # Across files: unique ids, at most one current.
  milestone "$dir" m1 "state: current"
  milestone "$dir" m2 "state: open" "id: m1"
  check_refused "duplicate id" "docs/milestones/m2.md: milestone id m1 is taken by docs/milestones/m1.md" pcheck
  milestone "$dir" m2 "state: current"
  check_refused "two current" "more than one current milestone: docs/milestones/m1.md, docs/milestones/m2.md" pcheck

  # Every problem is reported, not only the first.
  milestone "$dir" m2 "state: soon" "order: x"
  milestone "$dir" m3 "state: open" "due: never"
  out=$(pcheck 2>&1)
  check "all problems" "2:3" "$?:$(printf '%s\n' "$out" | grep -c '^peal: ')"

  check_refused "check takes no arguments" "usage: peal" "$PEAL" check extra
  check_refused "milestones: unknown flag" "usage: peal" "$PEAL" milestones --yaml
}

# The rules the offer and the claim follow, as library functions.
rules() {
  local state out status dir
  for state in current "" open parked "done"; do
    out=$(peal_ms_offer_rank "$state")
    status=$?
    check "offer rank of '$state'" "$(case $state in current) echo 0:1 ;; "") echo 0:2 ;; *) echo 1: ;; esac)" "$status:$out"
    peal_ms_claimable "$state"
    status=$?
    check "claimable '$state'" "$(case $state in parked | done) echo 1 ;; *) echo 0 ;; esac)" "$status"
  done

  dir=$(project)
  milestone "$dir" m1 "state: parked"
  milestone "$dir" m2 "state: current"
  loaded() { (cd "$dir" && peal_ms_load && "$@"); }
  check "state of an id" "parked" "$(loaded peal_ms_state m1)"
  out=$(loaded peal_ms_state m9)
  check "state of an unknown id: status 1" "1:" "$?:$out"
  out=$(loaded peal_ms_state "")
  check "state of no id: status 1" "1:" "$?:$out"
  check "current" "m2" "$(loaded peal_ms_current)"
  milestone "$dir" m2 "state: open"
  out=$(loaded peal_ms_current)
  check "no current: status 1" "1:" "$?:$out"
}

for_each_awk cases
for_each_awk rules

finish
