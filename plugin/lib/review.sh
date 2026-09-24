# shellcheck shell=bash
# A milestone's end (docs/design.md, "Milestones"): the review /peal:milestone-review
# walks, told by `peal milestone-review` what a script can know, and the state change
# the human decides, `peal milestone-state`, which Belfry's milestone actions call too.

PEAL_MS_STATES="done parked open"

# peal_milestone_state ID STATE [--reason R] [--review FILE] -> milestone ID made done,
# parked or open in the storage (peal_store_milestone_state): R says why a parked one
# waits ("until #12, other/repo#43"), FILE's text (- for stdin) goes in as its review.
# The last line names the milestone current afterwards. A state it has already changes
# nothing.
peal_milestone_state() {
  local id=${1-} state=${2-} reason="" review="" tmp="" cur status=0
  if [ $# -lt 2 ]; then
    peal_err "milestone-state: ID done|parked|open [--reason R] [--review FILE]"
    return 2
  fi
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
      --reason) [ $# -ge 2 ] || { peal_err "milestone-state: --reason needs a reason"; return 2; }; reason=$2; shift ;;
      --review) [ $# -ge 2 ] || { peal_err "milestone-state: --review needs a file"; return 2; }; review=$2; shift ;;
      *) peal_err "milestone-state: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  if [[ " $PEAL_MS_STATES " != *" $state "* ]]; then
    peal_err "milestone-state: '$state' is not one of: $PEAL_MS_STATES (which one is current follows)"
    return 2
  fi
  if [ -n "$reason" ] && [ "$state" != parked ]; then
    peal_err "milestone-state: a reason is for parking"
    return 2
  fi
  if [[ "$reason" == *$'\n'* || "$reason" == *$'\t'* ]]; then
    peal_err "milestone-state: the reason is one line"
    return 2
  fi
  if [ -n "$review" ]; then
    tmp=$(mktemp) || return 2
    if [ "$review" = - ]; then cat >"$tmp"; else cat -- "$review" >"$tmp" 2>/dev/null; fi
    if [ ! -s "$tmp" ]; then
      rm -f "$tmp"
      peal_err "milestone-state: no review in $review"
      return 2
    fi
  fi
  peal_store_milestone_state "$id" "$state" "$reason" "$tmp" || status=$?
  [ -z "$tmp" ] || rm -f "$tmp"
  [ $status = 0 ] || return $status
  cur=$(peal_store_milestones | awk -F '\t' '$3 == "current" { print $1; exit }') || return 2
  echo "current milestone: ${cur:-none}"
}

# peal_milestone_review [ID] -> what the review of milestone ID needs (by default this
# worktree's task's milestone, else the current one): the milestone, its review task, its
# tasks not done yet, the milestone that becomes current once it is done, the parked
# milestones and the tasks without one for the triage, the milestone's text, and the
# project's review steps (.peal/review.md) verbatim. The last line is READY when every
# task but the review's own is done, else OPEN <count>. Refused: a done milestone.
peal_milestone_review() {
  local id=${1-} task ms line state list top text steps=.peal/review.md
  [ $# -le 1 ] || { peal_err "milestone-review: [ID]"; return 2; }
  ms=$(peal_store_milestones) || return 2
  task=$(peal_session_task 2>/dev/null) || task=""
  if [ -z "$id" ] && [ -n "$task" ]; then
    id=$(peal_fm_get "$(_peal_field "$task" 2)" milestone 2>/dev/null)
  fi
  [ -n "$id" ] || id=$(printf '%s\n' "$ms" | awk -F '\t' '$3 == "current" { print $1; exit }')
  [ -n "$id" ] || { peal_err "milestone-review: name a milestone; none is current"; return 2; }
  line=$(printf '%s\n' "$ms" | awk -F '\t' -v id="$id" '$1 == id')
  [ -n "$line" ] || { peal_err "milestone-review: no milestone $id"; return 2; }
  state=$(_peal_field "$line" 3)
  [ "$state" != "done" ] || { peal_err "milestone-review: milestone $id is done already"; return 2; }
  list=$(peal_store_list --fetch) || return 2
  top=$(peal_project_root) || return 2

  printf '%s\n' "$line" | awk -F '\t' '{
    printf "Milestone %s, \"%s\", %s (%s)", $1, $2, $3, $6
    if ($7 != "") printf ", parked: %s", $7
    print "." }'
  printf '%s\n' "$list" | awk -F '\t' -v id="$id" -v here="${task%%$'\t'*}" '
    $6 == id && index("," $7 ",", ",milestone,") {
      r = r (r == "" ? "" : ", ") $1 ($1 == here ? " (this worktree'"'"'s)" : "") }
    END { print "Review task: " (r == "" ? "none" : r) "." }'
  echo "Tasks of $id not done, its review task aside:"
  printf '%s\n' "$list" | awk -F '\t' -v id="$id" '
    $6 == id && $2 != "done" && !index("," $7 ",", ",milestone,") {
      printf "  %s %s %s\n", $1, $2, $5; n++ }
    END { if (!n) print "  none" }'
  printf '%s\n' "$ms" | awk -F '\t' -v id="$id" -v st="$state" '
    $3 == "current" && $1 != id { cur = $1 " \"" $2 "\"" }
    $3 == "open" && $1 != id && first == "" { first = $1 " \"" $2 "\"" }
    END {
      if (st != "current") print "Current milestone: " (cur == "" ? "none" : cur) ", staying current."
      else if (first != "") print "Next: " first " becomes current once " id " is done."
      else print "Next: no open milestone; none will be current once " id " is done." }'
  echo "Parked milestones:"
  printf '%s\n' "$ms" | awk -F '\t' '
    $3 == "parked" { printf "  %s \"%s\"%s\n", $1, $2, ($7 == "" ? "" : ": " $7); n++ }
    END { if (!n) print "  none" }'
  printf '%s\n' "$list" | awk -F '\t' '
    $6 == "" && $2 != "done" { n++ }
    END { print "Tasks without a milestone, not done: " n + 0 " (peal overview lists them)." }'
  echo
  echo "The milestone's text:"
  echo
  text=$(peal_store_milestone_text "$id") || return 2
  printf '%s\n' "${text:-(empty)}"
  echo
  if [ -s "$top/$steps" ]; then
    echo "The project's review steps ($steps):"
    echo
    cat "$top/$steps"
  else
    echo "The project's review steps: none ($steps does not exist)."
  fi
  echo
  printf '%s\n' "$list" | awk -F '\t' -v id="$id" '
    $6 == id && $2 != "done" && !index("," $7 ",", ",milestone,") { n++ }
    END { print (n ? "OPEN " n : "READY") }'
}
