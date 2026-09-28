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
  [ $status != 0 ] || peal_cycle_check_text revise "$id" "$tmp/new" "$PEAL_RECORDS" || status=$?
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

# peal_create_filed --owner OWNER --title TITLE [--origin outsider|writer] -> Belfry's
# tasks.commands.create contract: the task text on stdin filed as one task, above the
# storage (both implementations). The slug is the first five words of TITLE, after the
# same normalisation peal_slugify applies (fewer than two words refused); OWNER (ai or
# human) is written into the frontmatter's owner field, the flag winning over whatever
# the text itself set (owner: human kept or added for human, dropped for ai). ORIGIN
# outsider writes origin: outsider, marking the text as one Belfry's contract says came
# from outside the project; writer, or --origin left out, leaves the field out (absent,
# as today: the text is the project's own). Refused (status 2), nothing written: an
# option other than --owner, --title or --origin, either --owner or --title missing or
# given twice, --origin given twice, OWNER not ai or human, ORIGIN not outsider or
# writer, a slug of one word, no text on stdin, or a text that sets merge (only a human,
# editing the task itself, earns merge: auto) or holds the task delimiter (one task at a
# time here). PEAL_MAIN_WRITE_BUDGET is capped to about 90s unless the caller set it, so
# a caller waiting on this synchronously does not hang; an open pull request at that cap
# still counts as filed, status 0 like a merged one (the storage's own status 3 would
# read as "not filed, retry" to a caller and file it twice). Prints the storage's own
# lines, then "filed: <id>" as the very last line.
peal_create_filed() {
  local owner="" title="" origin="" origin_given="" slug words tmp outfile out status=0 id
  while [ $# -gt 0 ]; do
    case $1 in
      --owner)
        [ $# -ge 2 ] || { peal_err "create: --owner needs ai or human"; return 2; }
        [ -z "$owner" ] || { peal_err "create: --owner given twice"; return 2; }
        owner=$2; shift ;;
      --title)
        [ $# -ge 2 ] || { peal_err "create: --title needs a title"; return 2; }
        [ -z "$title" ] || { peal_err "create: --title given twice"; return 2; }
        title=$2; shift ;;
      --origin)
        [ $# -ge 2 ] || { peal_err "create: --origin needs outsider or writer"; return 2; }
        [ -z "$origin_given" ] || { peal_err "create: --origin given twice"; return 2; }
        origin=$2; origin_given=1; shift ;;
      *) peal_err "create: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  case $owner in
    ai | human) ;;
    "") peal_err "create: --owner is required (ai or human)"; return 2 ;;
    *) peal_err "create: owner must be ai or human, not '$owner'"; return 2 ;;
  esac
  case $origin in
    outsider | writer | "") ;;
    *) peal_err "create: origin must be outsider or writer, not '$origin'"; return 2 ;;
  esac
  [ -n "$title" ] || { peal_err "create: --title is required"; return 2; }
  # _peal_slug_normalise (task-text.sh): the same normalisation peal_slugify does, the
  # first five words kept before the word count is judged, so a long title is never
  # refused for having too many.
  slug=$(_peal_slug_normalise "$title" | cut -d- -f1-5)
  words=$(printf '%s' "$slug" | awk -F- '{ print ($0 == "" ? 0 : NF) }')
  if [ "$words" -lt 2 ]; then
    peal_err "create: title '$title' makes a slug of $words word(s); a slug is at least two kebab-case words"
    return 2
  fi
  tmp=$(mktemp) || return 2
  cat >"$tmp"
  if [ ! -s "$tmp" ]; then
    peal_err "create: no text on stdin"
    rm -f "$tmp"
    return 2
  fi
  if grep -qF -- "$PEAL_TASK_DELIMITER" "$tmp"; then
    peal_err "create: the text holds '$PEAL_TASK_DELIMITER'; one task at a time here"
    rm -f "$tmp"
    return 2
  fi
  if [ -n "$(peal_fm_get "$tmp" merge 2>/dev/null)" ]; then
    peal_err "create: the text sets merge; only a human, editing the task itself, sets merge: auto"
    rm -f "$tmp"
    return 2
  fi
  if [ "$owner" = human ]; then
    peal_fm_set "$tmp" owner human || status=2
  else
    peal_fm_unset "$tmp" owner || status=2
  fi
  if [ "$origin" = outsider ]; then
    peal_fm_set "$tmp" origin outsider || status=2
  else
    peal_fm_unset "$tmp" origin || status=2
  fi
  if [ $status != 0 ]; then
    rm -f "$tmp"
    return 2
  fi
  : "${PEAL_MAIN_WRITE_BUDGET:=90}"
  # Not out=$(peal_store_create ...): a command substitution is a subshell, so
  # PEAL_MW_STATE (main-write.sh's peal_push_main sets it as a plain global) would never
  # reach peal_main_write_written below, which reads it under set -u. The storage's own
  # stdout goes to a file instead, peal_store_create running in this shell.
  outfile=$(mktemp) || { rm -f "$tmp"; return 2; }
  peal_store_create plain "" "$slug" <"$tmp" >"$outfile"
  status=$?
  rm -f "$tmp"
  out=$(cat "$outfile")
  rm -f "$outfile"
  [ -z "$out" ] || printf '%s\n' "$out"
  if peal_main_write_written $status; then
    id=$(awk 'NR == 1 { print $2; exit }' <<<"$out")
    printf 'filed: %s\n' "$id"
    status=0
  fi
  return $status
}

# _peal_backlog_context -> task-check.awk's CONTEXT from the storage: the settings', every
# milestone and every task. Sets PEAL_RECORDS (the list records).
_peal_backlog_context() {
  local milestones
  milestones=$(peal_store_milestones) || return 2
  PEAL_RECORDS=$(peal_store_list --no-pr) || return 2
  peal_check_context
  [ -z "$milestones" ] || printf '%s\n' "$milestones" | awk -F '\t' '{ print "ms\t" $1 "\t" $3 }'
  [ -z "$PEAL_RECORDS" ] || printf '%s\n' "$PEAL_RECORDS" | cut -f1 | sed 's/^/id\t/'
}
