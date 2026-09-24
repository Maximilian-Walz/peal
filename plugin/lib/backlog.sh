# shellcheck shell=bash
# The backlog commands' steps above the storage: a revise, which on the task's own claim
# narrows the claim's text (a split keeping its first piece), and defer.
#
# Defer gives a claim back without work, the task keeping its number. Two phases, since a
# session cannot remove the worktree it stands in:
#   1. `peal defer --reason R` in the claim's worktree: the task's text (on stdin, with
#      what the session learned) goes back to the storage (peal_store_defer), and the
#      worktree's git directory gets the marker peal-deferred.
#   2. `peal release ID` from anywhere else: a marked claim is released although its task
#      is not done (lib/claim.sh); the SessionStart reaping releases it too once idle.

PEAL_DEFERRED=peal-deferred

# peal_defer --reason R [--dry-run] -> phase 1 for the task whose claim this worktree holds,
# its new text on stdin; the release to run next.
peal_defer() {
  local reason="" dry="" id tmp gitdir queued status=0
  while [ $# -gt 0 ]; do
    case $1 in
      --reason) [ $# -ge 2 ] || { peal_err "defer: --reason needs a reason"; return 2; }; reason=$2; shift ;;
      --dry-run) dry=--dry-run ;;
      *) peal_err "defer: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  if [ -z "$reason" ]; then
    peal_err "defer: --reason R [--dry-run], the task's text on stdin"
    return 2
  fi
  if ! id=$(peal_store_session_task | cut -f1) || [ -z "$id" ]; then
    peal_err "defer: this worktree holds no claim; run it in the worktree of the claim to give back"
    return 2
  fi
  tmp=$(mktemp) || return 2
  cat >"$tmp"
  if [ ! -s "$tmp" ]; then
    peal_err "defer: no text on stdin: the task's text, read with peal read $id and brought up to date"
    rm -f "$tmp"
    return 2
  fi
  peal_store_defer "$id" "$reason" "$tmp" $dry || status=$?
  rm -f "$tmp"
  [ $status = 0 ] && [ -z "$dry" ] || return $status
  gitdir=$(git rev-parse --absolute-git-dir) || return 2
  { date -u +%Y-%m-%dT%H:%M:%SZ; printf '%s\n' "$reason"; } >"$gitdir/$PEAL_DEFERRED"
  queued=$(peal_ideas 2>/dev/null | wc -l | tr -d ' ')
  if [ "$queued" -gt 0 ]; then
    peal_err "warning: $queued idea(s) queued here go with the worktree; file them now: peal ideas --flush"
  fi
  echo "next, from outside this worktree: peal release $id"
}

# peal_deferred PATH -> status 0 if the worktree at PATH holds a claim phase 1 gave back.
peal_deferred() {
  local admin
  [ -n "$1" ] && admin=$(_peal_admin_dir "$1") && [ -f "$admin/$PEAL_DEFERRED" ]
}

# peal_revise ID REASON [--dry-run] -> task ID's text replaced by the one on stdin, with
# "Revised <date>: REASON" under its Notes: an unclaimed task's where the storage keeps
# it (peal_store_edit), or, in the worktree holding task ID's claim, the claim's
# (peal_store_record), as a split narrows its origin. The claim's is checked as a revise
# of an unclaimed task is.
peal_revise() {
  local id=$1 reason=$2 dry=${3-} task tmp status=0
  if ! task=$(peal_session_task 2>/dev/null) || [ "$(_peal_field "$task" 1)" != "$id" ]; then
    peal_store_edit "$id" "$reason" "$dry"
    return
  fi
  tmp=$(mktemp -d) || return 2
  cat >"$tmp/new"
  peal_store_read "$id" >"$tmp/old" || { rm -rf "$tmp"; return 2; }
  if cmp -s "$tmp/old" "$tmp/new"; then
    peal_err "revise: the text is task $id's already: nothing to revise"
    rm -rf "$tmp"
    return 2
  fi
  peal_edit_check revise "$tmp/old" "$tmp/new" "task $id" || status=2
  if ! peal_text_has_section Notes <"$tmp/new"; then
    peal_err "revise: no '## Notes' section to record the reason in"
    status=2
  fi
  _peal_backlog_context >"$tmp/context" || status=2
  PEAL_CHECK_ID=$id PEAL_CHECK_OLDMS=$(peal_fm_get "$tmp/old" milestone 2>/dev/null) \
    peal_task_check "$tmp/new" revise "task $id" "$tmp/context" >/dev/null || status=2
  if [ $status = 0 ]; then
    peal_text_add_note "Revised $(date -u +%Y-%m-%d): $reason" <"$tmp/new" >"$tmp/revised"
    if [ "$dry" = --dry-run ]; then
      (cd "$tmp" && diff -u old revised)
      echo "revise: a dry run; nothing recorded"
    else
      peal_store_record "$id" revision "$tmp/revised" || status=$?
    fi
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_backlog_context -> task-check.awk's CONTEXT from the storage: the settings', every
# milestone and every task.
_peal_backlog_context() {
  local milestones records
  milestones=$(peal_store_milestones) || return 2
  records=$(peal_store_list --no-pr) || return 2
  peal_check_context
  [ -z "$milestones" ] || printf '%s\n' "$milestones" | awk -F '\t' '{ print "ms\t" $1 "\t" $3 }'
  [ -z "$records" ] || printf '%s\n' "$records" | cut -f1 | sed 's/^/id\t/'
}
