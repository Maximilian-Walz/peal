# shellcheck shell=bash
# /peal:work's checks, so the command decides nothing a script can: whether this worktree
# already holds the task, what to claim or offer otherwise, where the task's plan stands,
# which models the subagents run on, each subagent's brief of the project, and what the
# human agreed recorded on the claim.

PEAL_WORK_ROLES="planner implementer reviewer"

# peal_work [ID | POOL] -> one of, as the last lines of the output:
#   TASK <id> <file>        this worktree holds the task (its branch and its claim), so
#   PLAN <state>            nothing is claimed: its plan required, agreed or skipped,
#   MODEL <role> <model>    and the model of each subagent
#   CLAIMED <id> <path>     task ID claimed (or claimed here already) into the worktree
#                           at path, after what peal claim said
#   CANDIDATE ... / MORE ...  peal offer's lines for POOL (current,unassigned); nothing
#                           at all for an empty pool
# Refused: an ID or POOL other than this worktree's own task, in a task's worktree; a
# human task (owner: human), which only the human works: peal claim makes its worktree;
# a worktree whose cached task text could not be read (an issue the write-access rule no
# longer admits, most likely), read's reason or "could not read".
peal_work() {
  local arg=${1-} task id path out status records
  [ $# -le 1 ] || { peal_err "work: [ID | POOL]"; return 2; }
  if task=$(PEAL_TASK_REFRESH=1 peal_session_task); then
    id=$(_peal_field "$task" 1)
    if [ -n "$arg" ] && [ "$arg" != "$id" ]; then
      peal_err "work: this worktree holds task $id; work on $arg from the main checkout"
      return 2
    fi
    _peal_work_here "$id" "$(_peal_field "$task" 2)"
    return
  fi
  case $arg in
    *[!0-9]* | "") peal_offer "${arg:-current,unassigned}" ;;
    *)
      records=$(peal_store_list --fetch --no-pr) || return 2
      if printf '%s\n' "$records" | awk -F '\t' -v id="$arg" '$1 == id && $17 == "human" { f = 1 } END { exit !f }'; then
        peal_err "work: task $arg is a human task (owner: human): the human works it; peal claim $arg makes its worktree"
        return 2
      fi
      out=$(peal_claim "$arg" --print-path)
      status=$?
      [ $status = 0 ] || { [ -z "$out" ] || printf '%s\n' "$out"; return $status; }
      path=$(printf '%s\n' "$out" | tail -n 1)
      printf '%s\n' "$out" | sed '$d'
      printf 'CLAIMED %s %s\n' "$arg" "$path"
      ;;
  esac
}

# _peal_work_here ID FILE -> the TASK, PLAN and MODEL lines of the task this worktree
# holds; refused, with read's reason (or "could not read") when the claim's cached copy
# is empty (the storage could not read it: an issue the write-access rule no longer
# admits, most likely).
_peal_work_here() {
  local id=$1 file=$2 plan model role err
  if [ ! -s "$file" ]; then
    err=$(peal_store_read "$id" 2>&1 >/dev/null)
    if [ -n "$err" ]; then printf '%s\n' "$err" >&2; else peal_err "work: could not read task $id"; fi
    return 2
  fi
  printf 'TASK %s %s\n' "$id" "$file"
  plan=$(peal_fm_get "$file" plan 2>/dev/null)
  case $plan in
    required) ! peal_text_section_filled Plan <"$file" || plan=agreed ;;
    *) plan=skipped ;;
  esac
  printf 'PLAN %s\n' "$plan"
  for role in $PEAL_WORK_ROLES; do
    model=""
    [ "$role" != implementer ] || model=$(peal_fm_get "$file" model 2>/dev/null)
    [ -n "$model" ] || model=$(peal_config_get "models.$role") || return 2
    printf 'MODEL %s %s\n' "$role" "$model"
  done
}

# peal_brief ROLE -> what the subagent ROLE (planner, implementer, reviewer) needs of the
# project, for the prompt that starts it in this worktree: the task, the main branch, the
# current milestone, the size tiers, the context documents to read; for the planner and
# the reviewer, with the decisions module on, the decisions that name a path of the task
# or of the diff (peal_decision_brief), and the project's own rules for them
# (.peal/ROLE.md) verbatim.
peal_brief() {
  local role=${1-} task id file remote main ms docs rules top
  if [ $# -ne 1 ] || [[ " $PEAL_WORK_ROLES " != *" $role "* ]]; then
    peal_err "brief: ROLE, one of: $PEAL_WORK_ROLES"
    return 2
  fi
  task=$(peal_session_task) || {
    peal_err "brief: this worktree holds no task; /peal:work claims one"
    return 2
  }
  id=$(_peal_field "$task" 1)
  file=$(_peal_field "$task" 2)
  remote=$(peal_config_get remote)
  main=$(peal_config_get main)
  ms=$(peal_store_milestones 2>/dev/null | awk -F '\t' '
    !f && $3 == "current" { printf "%s, %s (%s)", $1, $2, $6; f = 1 }')
  docs=$(peal_config_get context)
  echo "Peal brief for the $role of task $id."
  echo "Task: $file. It is the whole scope: read it first."
  echo "Main branch: $remote/$main. This task's work: git log $remote/$main..HEAD."
  echo "Current milestone: ${ms:-none}"
  peal_config_get sizes | awk -F ': ' '
    { s = s (s == "" ? "" : ", ") $1 " " $2 }
    END { print "Size tiers, tool calls per session: " s "." }'
  if [ -n "$docs" ]; then
    echo "Context documents, the project's own; read each that bears on the task:"
    printf '%s\n' "$docs" | sed 's/^/  /'
  else
    echo "Context documents: none listed."
  fi
  top=$(peal_project_root) || return 2
  if [ "$role" != implementer ] && peal_decisions_dir >/dev/null 2>&1; then
    case $file in /*) ;; *) file=$top/$file ;; esac
    echo
    if [ "$role" = planner ]; then
      (peal_decision_brief --task "$file")
    else
      (peal_decision_brief --diff)
    fi
  fi
  case $role in
    planner | reviewer)
      rules=.peal/$role.md
      [ -s "$top/$rules" ] || return 0
      echo
      echo "The project's rules for the $role ($rules), on top of Peal's:"
      echo
      cat "$top/$rules"
      ;;
  esac
}

# peal_record ID WHAT -> the text on stdin recorded as the task's, on the claim this
# worktree holds (peal_store_record): what the human agreed, WHAT plan (the text's Plan
# section filled) or notes (their answers). Refused: a task this worktree does not hold,
# a text the same as the task's, a changed Raw section, milestone, depends or part-of
# (the backlog commands' business), an Outcome filled in or its heading added or dropped,
# and whatever task-check.awk refuses in a revise.
peal_record() {
  local id=${1-} what=${2-} task tmp status=0 key
  if [ $# -ne 2 ] || [[ ! "$id" =~ ^[0-9]+$ ]] || { [ "$what" != plan ] && [ "$what" != notes ]; }; then
    peal_err "record: ID plan|notes, the task's text on stdin"
    return 2
  fi
  task=$(peal_session_task) || { peal_err "record: this worktree holds no task"; return 2; }
  if [ "$(_peal_field "$task" 1)" != "$id" ]; then
    peal_err "record: this worktree holds task $(_peal_field "$task" 1), not $id"
    return 2
  fi
  tmp=$(mktemp -d) || return 2
  cat >"$tmp/new"
  peal_store_read "$id" >"$tmp/old" || { rm -rf "$tmp"; return 2; }
  if cmp -s "$tmp/old" "$tmp/new"; then
    peal_err "record: the text is task $id's already: nothing to record"
    status=2
  fi
  if [ "$(peal_text_section Raw <"$tmp/old")" != "$(peal_text_section Raw <"$tmp/new")" ]; then
    peal_err "record: the Raw section changed: it holds the human's own words, never rewritten"
    status=2
  fi
  if [ "$(peal_text_has_section Outcome <"$tmp/old"; echo $?)" != "$(peal_text_has_section Outcome <"$tmp/new"; echo $?)" ]; then
    peal_err "record: the Outcome heading was added or dropped"
    status=2
  elif peal_text_outcome_filled <"$tmp/new"; then
    peal_err "record: the Outcome is written at close, not now"
    status=2
  fi
  for key in milestone depends part-of; do
    if [ "$(peal_fm_get "$tmp/old" "$key" 2>/dev/null)" != "$(peal_fm_get "$tmp/new" "$key" 2>/dev/null)" ]; then
      peal_err "record: $key changed: that is a backlog command's, not a plan's"
      status=2
    fi
  done
  if [ "$what" = plan ] && ! peal_text_section_filled Plan <"$tmp/new"; then
    peal_err "record: no Plan section with the agreed plan in it"
    status=2
  fi
  peal_check_context >"$tmp/context"
  PEAL_CHECK_ID=$id PEAL_CHECK_OFFLINE=1 \
    peal_task_check "$tmp/new" revise "task $id" "$tmp/context" >/dev/null || status=2
  [ $status != 0 ] || peal_store_record "$id" "$what" "$tmp/new" || status=$?
  rm -rf "$tmp"
  return $status
}
