# shellcheck shell=bash
# Closing a task (docs/design.md, "Closing a task"): /peal:close's scripts. `begin`
# declares a close in progress with a sentinel in the worktree's git directory, which arms
# the Stop hook, and prints what the session needs for the review and the Outcome;
# `finish` runs the project's close checks, files the queued ideas, commits the task's
# move to done, pushes and opens the pull request; `abort` calls a close off; `verify`
# says in one line whether the session may leave; `wait` asks again until it is not WAIT.
# Everything but the storage's own step (peal_store_finish) is the same for every storage.

PEAL_CLOSE_SENTINEL=peal-close
PEAL_CLOSE_BODY=peal-pr-body.md
PEAL_CLOSE_ABORTS=peal-close-abort.log
PEAL_CLOSE_WITHDRAWN=peal-merge-withdrawn
PEAL_CLOSE_EMPTY="Fine for a task closed with nothing built; otherwise fill in what was agreed or built: the review checks the diff against it."

# _peal_close_gitdir -> this worktree's own git directory, absolute.
_peal_close_gitdir() {
  git rev-parse --absolute-git-dir 2>/dev/null
}

# peal_branch_base VERB -> PEAL_REMOTE, PEAL_MAIN, PEAL_MAIN_REF (the remote's main, else
# the local one) and PEAL_BASE (where this branch left it); status 2 if there is no main,
# the message VERB's.
peal_branch_base() {
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
    PEAL_MAIN_REF=$PEAL_REMOTE/$PEAL_MAIN
  elif git rev-parse -q --verify "refs/heads/$PEAL_MAIN" >/dev/null; then
    PEAL_MAIN_REF=$PEAL_MAIN
  else
    peal_err "$1: neither $PEAL_REMOTE/$PEAL_MAIN nor $PEAL_MAIN exists to compare against"
    return 2
  fi
  PEAL_BASE=$(git merge-base HEAD "$PEAL_MAIN_REF") || {
    peal_err "$1: this branch shares no history with $PEAL_MAIN_REF (a shallow clone needs its whole history)"
    return 2
  }
}

# _peal_close_sections -> "title<TAB>instruction" per item of pr.sections, an item being
# "Title: what to write" (or a title alone).
_peal_close_sections() {
  peal_config_get pr.sections | awk '
    $0 == "" { next }
    { i = index($0, ": ")
      if (i) print substr($0, 1, i - 1) "\t" substr($0, i + 2); else print $0 "\t" }'
}

# _peal_close_escalations FILE -> how many bullets "### Escalations" under FILE's Outcome
# holds.
_peal_close_escalations() {
  peal_text_section Outcome <"$1" | awk '
    $0 == "### Escalations" { in_ = 1; next }
    /^##/ { in_ = 0 }
    in_ && /^[-*+] / { n++ }
    END { print n + 0 }'
}

# _peal_close_outcome_ok FILE -> status 0 if FILE's Outcome is written, no placeholder left;
# else the reason on stderr.
_peal_close_outcome_ok() {
  if ! peal_text_outcome_filled <"$1"; then
    peal_err "$2: $1 has no Outcome yet: write what was built, what was decided, what was left and why"
    return 1
  fi
  if peal_text_outcome_placeholder <"$1"; then
    peal_err "$2: $1's Outcome still holds a placeholder (<!-- ... -->): replace it, or delete it"
    return 1
  fi
}

# peal_close SUBCOMMAND ARGS...
peal_close() {
  local sub=${1-}
  [ $# -eq 0 ] || shift
  case $sub in
    begin) peal_close_begin "$@" ;;
    finish) peal_close_finish "$@" ;;
    body) peal_close_body_cmd "$@" ;;
    abort) peal_close_abort "$@" ;;
    verify) [ $# -eq 0 ] || { peal_err "close verify takes no arguments"; return 2; }; peal_close_verify ;;
    wait) [ $# -eq 0 ] || { peal_err "close wait takes no arguments"; return 2; }; peal_close_wait ;;
    *) peal_err "close: begin, finish, body, abort, verify or wait"; return 2 ;;
  esac
}

# peal_close_begin -> the close of this worktree's task declared (the sentinel written),
# and what the session needs before it reviews and writes the Outcome: notes, the file to
# write the Outcome in, the PR sections finish asks for, the diff and the Done when list.
# Refused: no task held here, Peal's git hooks not installed, more than one task under
# doing/, and a branch that adds a backlog task file (those are filed onto main).
peal_close_begin() {
  local top task id file text tasks count added behind out status ideas empty ms gitdir sections
  [ $# -eq 0 ] || { peal_err "close begin takes no arguments"; return 2; }
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  task=$(PEAL_TASK_REFRESH=1 peal_session_task) || {
    peal_err "close begin: this worktree holds no task to close; /peal:work claims one"
    return 2
  }
  id=$(_peal_field "$task" 1)
  file=$(_peal_field "$task" 2)
  if ! peal_hooks_installed; then
    peal_err "close begin: Peal's git hooks are not installed here, so nothing would gate the close's commits; run: peal hooks install"
    return 2
  fi
  tasks=$(peal_config_get tasks) || return 2
  tasks=${tasks%/}
  count=$(find "$tasks/doing" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 1 ]; then
    peal_err "close begin: $count tasks under $tasks/doing/; one task, one branch:"
    find "$tasks/doing" -maxdepth 1 -name '*.md' | sort | sed 's/^/  /' >&2
    return 2
  fi
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null \
    || peal_err "warning: could not fetch $PEAL_REMOTE/$PEAL_MAIN; comparing with what is known here"
  peal_branch_base close || return 2
  added=$(git diff --name-only --no-renames --diff-filter=A "$PEAL_BASE" HEAD -- "$tasks/backlog/")
  if [ -n "$added" ]; then
    peal_err "close begin: this branch adds backlog task files, which are filed onto $PEAL_MAIN (peal idea), never on a branch:"
    printf '  %s\n' "$added" >&2
    peal_err "take them out of the branch (git rm, and queue each with peal idea), then begin again"
    return 2
  fi
  text=$(peal_store_close_text "$id") || { peal_err "close begin: no text of task $id here to write its Outcome in"; return 2; }
  gitdir=$(_peal_close_gitdir) || return 2
  printf '%s\n%s\n%s\n' "${CLAUDE_CODE_SESSION_ID-}" "$id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$gitdir/$PEAL_CLOSE_SENTINEL" || return 2
  rm -f "$gitdir/$PEAL_CLOSE_WITHDRAWN"

  echo "close begun: task $id. Until peal close finish (or abort), the Stop hook holds this session to a finished close."
  # The notes: nothing here refuses; each is the session's to weigh.
  behind=$(git rev-list --count "HEAD..$PEAL_MAIN_REF" -- . ":(exclude)$tasks/" 2>/dev/null)
  if [ "${behind:-0}" -gt 0 ]; then
    echo "NOTE: this branch is $behind commit(s) behind $PEAL_MAIN_REF, not counting task files. Merge it in if that matters here (git merge $PEAL_MAIN_REF); never rebase a pushed branch."
  fi
  out=$(git merge-tree --write-tree --name-only HEAD "$PEAL_MAIN_REF" 2>/dev/null)
  status=$?
  if [ $status = 1 ]; then
    echo "NOTE: merging $PEAL_MAIN_REF into this branch would conflict in:"
    printf '%s\n' "$out" | awk 'NR == 1 { next } /^$/ { exit } { print "  " $0 }'
  fi
  ms=$(peal_config_get milestones)
  ms=$(git diff --name-only "$PEAL_BASE" HEAD -- "${ms%/}/" 2>/dev/null)
  if [ -n "$ms" ]; then
    echo "NOTE: this branch changes milestone files, which only a milestone's review changes; say why in the Outcome, or take the change out:"
    printf '  %s\n' "$ms"
  fi
  empty=()
  peal_text_section_filled Scope <"$file" || empty+=("## Scope")
  peal_text_section_filled "Done when" <"$file" || empty+=("## Done when")
  case ${#empty[@]} in
    1) echo "NOTE: ${empty[0]} is empty in task $id. $PEAL_CLOSE_EMPTY" ;;
    2) echo "NOTE: ${empty[0]} and ${empty[1]} are empty in task $id. $PEAL_CLOSE_EMPTY" ;;
  esac
  ideas=$(peal_ideas)
  if [ -n "$ideas" ]; then
    echo "NOTE: $(printf '%s\n' "$ideas" | wc -l | tr -d ' ') idea(s) queued on this branch, filed by finish (peal ideas --export to read them, --drop N or --all to drop one now):"
    printf '%s\n' "$ideas" | awk -F '\t' '{ print "  " $1 " — " $2 }'
  fi
  if [ "$(peal_fm_get "$file" merge 2>/dev/null)" = auto ]; then
    echo "NOTE: task $id holds merge: auto. The reviewer's report ends in merge-auto: keep or withdraw; pass it to finish as --review-file FILE, and withdraw removes the field."
  fi
  echo
  echo "Outcome: write it in $text, under ## Outcome."
  sections=$(_peal_close_sections)
  if [ -n "$sections" ]; then
    echo "PR sections finish needs, each as --section TITLE TEXT:"
    printf '%s\n' "$sections" | awk -F '\t' '{ print "  " $1 ($2 == "" ? "" : ": " $2) }'
  fi
  echo
  echo "--- the diff since $PEAL_MAIN_REF ---"
  git diff --stat "$PEAL_BASE" HEAD
  echo
  echo "--- Done when, task $id ---"
  peal_text_section "Done when" <"$file" || echo "(no Done when section)"
}

# _peal_close_args ARGS... -> PEAL_SUMMARY and the PR sections (PEAL_SECTION_TITLES,
# PEAL_SECTION_TEXTS) from --summary TEXT | --summary-file FILE and --section TITLE TEXT |
# --section-file TITLE FILE; checked against pr.sections: every one given, no other.
# --review-file FILE, the reviewer's report: PEAL_REVIEW set (1), PEAL_MERGE_VERDICT its
# last line "merge-auto: keep|withdraw" (keep or withdraw; empty without one).
_peal_close_args() {
  local verb=$1 v known title i j
  shift
  PEAL_SUMMARY="" PEAL_SECTION_TITLES=() PEAL_SECTION_TEXTS=() PEAL_REVIEW="" PEAL_MERGE_VERDICT=""
  while [ $# -gt 0 ]; do
    case $1 in
      --review-file)
        [ $# -ge 2 ] || { peal_err "close $verb: $1 needs a file"; return 2; }
        if [ ! -r "$2" ] || [ -d "$2" ]; then peal_err "close $verb: no readable file $2"; return 2; fi
        [ -z "$PEAL_REVIEW" ] || { peal_err "close $verb: one review"; return 2; }
        PEAL_REVIEW=1
        PEAL_MERGE_VERDICT=$(awk '{ sub(/\r$/, "") }
          match($0, /^[ \t`*]*merge-auto:[ \t]*(keep|withdraw)[ \t`*]*$/) {
            v = $0; sub(/^[ \t`*]*merge-auto:[ \t]*/, "", v); sub(/[ \t`*]*$/, "", v) }
          END { print v }' "$2")
        shift 2
        ;;
      --summary | --summary-file)
        [ $# -ge 2 ] || { peal_err "close $verb: $1 needs a value"; return 2; }
        v=$2
        if [ "$1" = --summary-file ]; then
          if [ ! -r "$v" ] || [ -d "$v" ]; then peal_err "close $verb: no readable file $v"; return 2; fi
          v=$(cat "$v")
        fi
        [ -z "$PEAL_SUMMARY" ] || { peal_err "close $verb: one summary"; return 2; }
        PEAL_SUMMARY=$v
        shift 2
        ;;
      --section | --section-file)
        [ $# -ge 3 ] || { peal_err "close $verb: $1 needs a title and a value"; return 2; }
        v=$3
        if [ "$1" = --section-file ]; then
          if [ ! -r "$v" ] || [ -d "$v" ]; then peal_err "close $verb: no readable file $v"; return 2; fi
          v=$(cat "$v")
        fi
        PEAL_SECTION_TITLES+=("$2")
        PEAL_SECTION_TEXTS+=("$v")
        shift 3
        ;;
      *) peal_err "close $verb: unknown argument $1"; return 2 ;;
    esac
  done
  if [ -z "$(printf '%s' "$PEAL_SUMMARY" | tr -d ' \t\n')" ]; then
    peal_err "close $verb: no --summary: three to five bullets for the reviewer, one change each"
    return 2
  fi
  known=$(_peal_close_sections | cut -f1)
  for ((i = 0; i < ${#PEAL_SECTION_TITLES[@]}; i++)); do
    title=${PEAL_SECTION_TITLES[i]}
    if ! printf '%s\n' "$known" | grep -qxF -- "$title"; then
      peal_err "close $verb: '$title' is not one of the PR sections (pr.sections): ${known:-none}"
      return 2
    fi
    for ((j = 0; j < i; j++)); do
      [ "${PEAL_SECTION_TITLES[j]}" != "$title" ] || { peal_err "close $verb: section '$title' given twice"; return 2; }
    done
    if [ -z "$(printf '%s' "${PEAL_SECTION_TEXTS[i]}" | tr -d ' \t\n')" ]; then
      peal_err "close $verb: section '$title' is empty"
      return 2
    fi
  done
  while IFS= read -r title; do
    [ -n "$title" ] || continue
    for ((j = 0; j < ${#PEAL_SECTION_TITLES[@]}; j++)); do
      [ "${PEAL_SECTION_TITLES[j]}" != "$title" ] || continue 2
    done
    peal_err "close $verb: the PR section '$title' is missing: --section '$title' TEXT ($(_peal_close_sections | awk -F '\t' -v t="$title" '$1 == t { print $2 }'))"
    return 2
  done <<<"$known"
}

# _peal_close_context ID -> PEAL_TEXT (the text holding the Outcome), PEAL_TITLE,
# PEAL_PART_OF and PEAL_MERGE (its merge field) of task ID, for finish and the PR body.
_peal_close_context() {
  local id=$1 tmp
  PEAL_TEXT=$(peal_store_close_text "$id") || { peal_err "close: no text of task $id here"; return 2; }
  tmp=$(mktemp) || return 2
  if ! peal_store_read "$id" >"$tmp"; then
    rm -f "$tmp"
    return 2
  fi
  PEAL_TITLE=$(peal_text_title "$id" <"$tmp") || PEAL_TITLE="task $id"
  PEAL_PART_OF=$(peal_fm_get "$tmp" part-of 2>/dev/null)
  PEAL_MERGE=$(peal_fm_get "$tmp" merge 2>/dev/null)
  rm -f "$tmp"
}

# _peal_close_merge_check VERB -> status 0 unless the task holds merge: auto and no
# reviewer's report with its merge-auto line was given; then why on stderr, status 2.
_peal_close_merge_check() {
  [ "$PEAL_MERGE" = auto ] || return 0
  if [ -z "$PEAL_REVIEW" ]; then
    peal_err "close $1: task $PEAL_ID holds merge: auto, so the reviewer's report decides whether it stays: --review-file FILE, the report ending in merge-auto: keep or withdraw (for a review skipped, a file saying merge-auto: keep)"
    return 2
  fi
  if [ -z "$PEAL_MERGE_VERDICT" ]; then
    peal_err "close $1: task $PEAL_ID holds merge: auto, and the reviewer's report has no line merge-auto: keep or merge-auto: withdraw; ask the reviewer for it"
    return 2
  fi
}

# _peal_close_withdraw_merge -> merge: auto removed from the task where the storage keeps
# its frontmatter (peal_store_record: a commit on a task file's branch, the issue's label),
# and the withdrawal marked in the worktree's git directory for the PR body.
_peal_close_withdraw_merge() {
  local task file tmp status=0
  task=$(PEAL_TASK_REFRESH=1 peal_session_task) || return 2
  file=$(_peal_field "$task" 2)
  tmp=$(mktemp) || return 2
  if cp "$file" "$tmp" && peal_fm_unset "$tmp" merge; then
    peal_store_record "$PEAL_ID" "merge withdrawal" "$tmp" || status=$?
  else
    status=2
  fi
  rm -f "$tmp"
  if [ $status != 0 ]; then
    peal_err "close finish: merge: auto could not be withdrawn from task $PEAL_ID (above); nothing is moved. Fix it and finish again."
    return $status
  fi
  : >"$(_peal_close_gitdir)/$PEAL_CLOSE_WITHDRAWN"
  echo "withdrew merge: auto from task $PEAL_ID: the review found the diff larger or riskier than its plan"
}

# peal_close_body ID -> the pull request's body for task ID, from what the branch and the
# worktree hold: PEAL_SUMMARY; "Fixes #ID" for an issue; the split it is part of; the
# project's PR sections (PEAL_SECTION_*), in pr.sections' order; the Outcome; the ideas
# filed from this worktree; the branch's commits. A merge: auto the review withdrew is said
# first. Needs PEAL_TEXT, PEAL_PART_OF, PEAL_MERGE, PEAL_MERGE_VERDICT and PEAL_BASE.
peal_close_body() {
  local id=$1 escalations kind title i filed
  escalations=$(_peal_close_escalations "$PEAL_TEXT")
  kind=$(peal_config_get storage.kind)
  if [ "$escalations" -gt 0 ]; then
    printf '**Needs your judgement:** %s escalation(s), under the Outcome'\''s Escalations.\n\n' "$escalations"
  fi
  if [ -e "$(_peal_close_gitdir)/$PEAL_CLOSE_WITHDRAWN" ] || { [ "$PEAL_MERGE" = auto ] && [ "$PEAL_MERGE_VERDICT" = withdraw ]; }; then
    printf '**merge: auto withdrawn:** the review found the diff larger or riskier than the plan that earned it, so this pull request waits for a human.\n\n'
  fi
  printf '%s\n' "$PEAL_SUMMARY"
  echo
  if [ "$kind" = issues ]; then
    echo "Fixes #$id"
  else
    echo "Task $id."
  fi
  if [ -n "$PEAL_PART_OF" ]; then
    if [ "$kind" = issues ]; then echo "Part of #$PEAL_PART_OF."; else echo "Part of task $PEAL_PART_OF."; fi
  fi
  while IFS= read -r title; do
    [ -n "$title" ] || continue
    for ((i = 0; i < ${#PEAL_SECTION_TITLES[@]}; i++)); do
      [ "${PEAL_SECTION_TITLES[i]}" = "$title" ] || continue
      printf '\n## %s\n\n%s\n' "$title" "${PEAL_SECTION_TEXTS[i]}"
    done
  done < <(_peal_close_sections | cut -f1)
  echo
  echo "## Outcome"
  echo
  # The Outcome as written, its comments and the blank lines around it dropped.
  peal_text_section Outcome <"$PEAL_TEXT" | awk '
    { while (match($0, /<!--.*-->/)) $0 = substr($0, 1, RSTART - 1) substr($0, RSTART + RLENGTH)
      if (inc) { if (match($0, /-->/)) { $0 = substr($0, RSTART + RLENGTH); inc = 0 } else next }
      if (match($0, /<!--/)) { $0 = substr($0, 1, RSTART - 1); inc = 1 }
      line[++n] = $0 }
    END {
      first = 1; while (first <= n && line[first] ~ /^[ \t]*$/) first++
      last = n; while (last >= first && line[last] ~ /^[ \t]*$/) last--
      for (i = first; i <= last; i++) print line[i]
    }'
  filed=$(_peal_close_gitdir)/$PEAL_IDEAS_FILED
  if [ -s "$filed" ]; then
    echo
    echo "## Ideas filed"
    echo
    # "filed ID WHERE — milestone: M, plan: P, size: S — "Title"", as the storage says it.
    awk '$1 == "filed" {
      t = $0; sub(/^.* — "/, "", t); sub(/"$/, "", t)
      print "- " $2 ": " t " (" $3 ")" }' "$filed"
  fi
  echo
  echo "<details>"
  echo "<summary>Commits</summary>"
  echo
  git log --reverse --format=%s "$PEAL_BASE..HEAD" | awk '
    /^docs\(tasks\): (claim|record|close) / { next }
    { print "- " $0; n++ }
    END { if (!n) print "None but the task'\''s own." }'
  echo
  echo "</details>"
}

# _peal_close_task VERB -> PEAL_ID, the task of the close in progress here (the sentinel's),
# checked against the branch; status 2 without a close in progress.
_peal_close_task() {
  local gitdir own
  gitdir=$(_peal_close_gitdir) || { peal_err "close $1: not inside a git repository"; return 2; }
  if [ ! -f "$gitdir/$PEAL_CLOSE_SENTINEL" ]; then
    peal_err "close $1: no close in progress here; peal close begin first"
    return 2
  fi
  PEAL_ID=$(sed -n 2p "$gitdir/$PEAL_CLOSE_SENTINEL")
  own=$(peal_store_branch_task) || own=none
  if [ -z "$PEAL_ID" ] || [ "$own" != "$PEAL_ID" ]; then
    peal_err "close $1: the close in progress is of task ${PEAL_ID:-unknown}, but this branch is task $own's; begin again"
    return 2
  fi
}

# peal_close_body_cmd ARGS... -> the body finish would open the pull request with, printed.
peal_close_body_cmd() {
  local top
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  _peal_close_args body "$@" || return 2
  _peal_close_task body || return 2
  peal_branch_base close || return 2
  _peal_close_context "$PEAL_ID" || return 2
  _peal_close_merge_check body || return 2
  peal_close_body "$PEAL_ID"
}

# _peal_close_checks -> each of checks.close run from the top of the work tree; status 1
# at the first that fails.
_peal_close_checks() {
  local checks item
  checks=$(peal_config_get checks.close) || return 1
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    echo "close: running $item"
    # shellcheck disable=SC2046 # the names of the variables to unset
    if ! (unset $(compgen -v GIT_) && bash -c "$item") </dev/null; then
      peal_err "close finish: the close check '$item' failed; nothing is moved or filed. Fix it and finish again."
      return 1
    fi
  done <<<"$checks"
}

# peal_close_finish ARGS... -> the close begun here finished: refused, before anything
# changes, for a missing summary or PR section, an Outcome empty or holding a placeholder,
# more than three escalations, an uncommitted path other than the Outcome's text and the
# decision entries, a task holding merge: auto without the reviewer's merge-auto line
# (--review-file), git hooks not installed, decision entries out of order
# (_peal_dec_check), and a failing checks.close item; then the queued ideas filed in
# one push (a failure files nothing, or, where the storage files one by one, dequeues
# exactly those filed), merge: auto removed from the task when the review says
# withdraw, the uncommitted decision entries committed on their own
# (peal_decisions_commit), the storage's finish committed as "docs(tasks): close ID [ID]"
# (an empty commit when the branch holds nothing else: a pull request needs one), the
# branch pushed, the pull request opened or its title and body updated, the sentinel
# cleared. What fails after the flush leaves the sentinel: run finish again, it goes on
# from where it stopped.
peal_close_finish() {
  local top gitdir rel decisions dirty escalations out status branch ahead repo pr url title body
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  _peal_close_args finish "$@" || return 2
  _peal_close_task finish || return 2
  gitdir=$(_peal_close_gitdir) || return 2
  peal_branch_base close || return 2
  _peal_close_context "$PEAL_ID" || return 2
  _peal_close_outcome_ok "$PEAL_TEXT" "close finish" || return 2
  _peal_close_merge_check finish || return 2
  escalations=$(_peal_close_escalations "$PEAL_TEXT")
  if [ "$escalations" -gt 3 ]; then
    peal_err "close finish: $escalations escalations: more than three means the task was underspecified. Open no pull request; ask the human about them first."
    return 2
  fi
  rel=$PEAL_TEXT
  case $rel in /*) rel="" ;; esac
  decisions=$(peal_decisions_dir 2>/dev/null) || decisions=""
  dirty=$(git status --porcelain -- . ${rel:+":(exclude)$rel"} ${decisions:+":(exclude)$decisions/[0-9]*.md"})
  if [ -n "$dirty" ]; then
    peal_err "close finish: uncommitted changes besides ${rel:-nothing}${decisions:+ and the decision entries}; commit them (peal commit) or take them out first:"
    printf '%s\n' "$dirty" | sed 's/^/  /' >&2
    return 2
  fi
  if ! peal_hooks_installed; then
    peal_err "close finish: Peal's git hooks are not installed here; run: peal hooks install"
    return 2
  fi
  if [ -n "$decisions" ]; then
    # shellcheck disable=SC2034 # read by _peal_dec_check
    PEAL_DEC_DIR=$decisions
    if ! _peal_dec_check "$PEAL_BASE"; then
      peal_err "close finish: the decision entries are not in order (above); nothing is moved or filed. Fix them and finish again."
      return 2
    fi
  fi
  _peal_close_checks || return 2

  out=$(peal_ideas --flush)
  status=$?
  [ -z "$out" ] || printf '%s\n' "$out"
  if [ $status != 0 ]; then
    peal_err "close finish: the queued ideas were not all filed (above); what is still queued stays queued, nothing is moved. Fix it and finish again."
    return 2
  fi

  if [ "$PEAL_MERGE" = auto ] && [ "$PEAL_MERGE_VERDICT" = withdraw ]; then
    _peal_close_withdraw_merge || return 1
  fi
  # A decision made in the task lands as a commit of its own, right before the task's move.
  peal_decisions_commit "$PEAL_ID" || return 1
  peal_store_finish "$PEAL_ID" "done" || return 2
  PEAL_TEXT=$(peal_store_close_text "$PEAL_ID") || return 2
  # The text moved by the storage's finish is staged already; one still here is added.
  if [ -n "$rel" ] && [ -e "$rel" ]; then git add -- "$rel" || return 2; fi
  if ! git diff --cached --quiet; then
    git commit -q -m "docs(tasks): close $PEAL_ID [$PEAL_ID]" || {
      peal_err "close finish: the commit was refused (above); run finish again once it is fixed"
      return 1
    }
  fi
  ahead=$(git rev-list --count "$PEAL_BASE..HEAD")
  if [ "$ahead" = 0 ]; then
    git commit -q --allow-empty -m "docs(tasks): close $PEAL_ID with nothing built [$PEAL_ID]" || {
      peal_err "close finish: the commit was refused (above); run finish again once it is fixed"
      return 1
    }
  fi

  branch=$(git symbolic-ref -q --short HEAD) || return 2
  if git rev-parse -q --verify "$branch@{upstream}" >/dev/null; then
    set -- git push -q
  else
    set -- git push -q -u "$PEAL_REMOTE" "$branch"
  fi
  if ! "$@"; then
    peal_err "close finish: the push failed (above): the close is committed here, not on $PEAL_REMOTE. Run finish again once it can push."
    return 1
  fi

  body=$gitdir/$PEAL_CLOSE_BODY
  peal_close_body "$PEAL_ID" >"$body" || return 2
  title="$PEAL_TITLE [$PEAL_ID]"
  repo=$(peal_github_repo) || return 2
  if ! out=$(peal_gh "repos/$repo/pulls?state=open&head=${repo%%/*}:$(peal_urlencode "$branch")" \
      --jq '.[0] | select(. != null) | [(.number | tostring), .html_url] | @tsv'); then
    _peal_close_by_hand "$branch" "$title" "$body"
    return 1
  fi
  if [ -n "$out" ]; then
    pr=${out%%	*} url=${out#*	}
    if ! peal_json s:title "$title" f:body "$body" \
        | peal_gh --method PATCH "repos/$repo/pulls/$pr" --input - --jq '.number' >/dev/null; then
      _peal_close_by_hand "$branch" "$title" "$body"
      return 1
    fi
    echo "updated the title and body of pull request #$pr"
  else
    if ! out=$(peal_json s:title "$title" s:head "$branch" s:base "$PEAL_MAIN" f:body "$body" \
        | peal_gh --method POST "repos/$repo/pulls" --input - --jq '[(.number | tostring), .html_url] | @tsv'); then
      _peal_close_by_hand "$branch" "$title" "$body"
      return 1
    fi
    pr=${out%%	*} url=${out#*	}
  fi
  rm -f "$gitdir/$PEAL_CLOSE_SENTINEL" "$gitdir/$PEAL_CLOSE_WITHDRAWN"
  echo "closed $PEAL_ID: pull request #$pr $url"
  echo "Next: peal close wait, until its verdict is not WAIT."
}

# _peal_close_by_hand BRANCH TITLE BODY -> how to open the pull request without Peal.
_peal_close_by_hand() {
  peal_err "close finish: the pull request did not open or update (above). The close is committed and pushed; run finish again, or open it by hand:"
  printf '  gh pr create --base %s --head %s --title %q --body-file %s\n' "$PEAL_MAIN" "$1" "$2" "$3" >&2
}

# peal_close_abort REASON -> the close in progress here called off: the sentinel removed,
# REASON logged in the worktree's git directory (peal-close-abort.log). The queued ideas
# stay queued. Without a close in progress, says so.
peal_close_abort() {
  local reason=${1-} gitdir sentinel id
  if [ $# -ne 1 ] || [ -z "$(printf '%s' "$reason" | tr -d ' \t\n')" ]; then
    peal_err "close abort: REASON, why the close is off"
    return 2
  fi
  gitdir=$(_peal_close_gitdir) || { peal_err "close abort: not inside a git repository"; return 2; }
  sentinel=$gitdir/$PEAL_CLOSE_SENTINEL
  if [ ! -f "$sentinel" ]; then
    echo "no close in progress here: nothing to abort"
    return 0
  fi
  id=$(sed -n 2p "$sentinel")
  reason=$(printf '%s' "$reason" | tr '\n\t' '  ')
  printf '%s\ttask=%s\tbegun=%s\tsession=%s\treason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" \
    "$(sed -n 3p "$sentinel")" "${CLAUDE_CODE_SESSION_ID-}" "$reason" >>"$gitdir/$PEAL_CLOSE_ABORTS" \
    || peal_err "warning: could not log the abort in $gitdir/$PEAL_CLOSE_ABORTS"
  rm -f "$sentinel" || { peal_err "close abort: could not remove $sentinel; the close is still on"; return 2; }
  echo "aborted the close of task $id: $reason"
  echo "The Stop hook holds nothing now. Begin again (peal close begin) when the task is done."
  [ -z "$(peal_ideas 2>/dev/null)" ] || echo "The ideas queued on this branch stay queued, for the close that comes."
}

# peal_close_stop -> the Stop hook: silent unless a close is in progress here; then status
# 2 and why on stderr (which Claude Code shows the session) while the Outcome is empty or
# holds a placeholder, or work is uncommitted or unpushed. Never twice in a row (Claude
# Code's stop_hook_active), and a sentinel another session left is cleared, not enforced.
peal_close_stop() {
  local gitdir sentinel session id text problems=() branch ahead
  [ "$(peal_hook_field stop_hook_active)" != true ] || return 0
  peal_hook_project || return 0
  gitdir=$(_peal_close_gitdir) || return 0
  sentinel=$gitdir/$PEAL_CLOSE_SENTINEL
  [ -f "$sentinel" ] || return 0
  session=$(sed -n 1p "$sentinel")
  if [ -n "$session" ] && [ -n "$(peal_hook_field session_id)" ] && [ "$session" != "$(peal_hook_field session_id)" ]; then
    rm -f "$sentinel"
    return 0
  fi
  id=$(sed -n 2p "$sentinel")
  if ! peal_store_load 2>/dev/null; then
    problems+=("Peal's settings or storage do not load (peal config says why)")
  elif ! text=$(peal_store_close_text "$id" 2>/dev/null); then
    problems+=("task $id has no text here to hold its Outcome")
  elif ! peal_text_outcome_filled <"$text"; then
    problems+=("the Outcome in $text is empty")
  elif peal_text_outcome_placeholder <"$text"; then
    problems+=("the Outcome in $text still holds a placeholder (<!-- ... -->)")
  fi
  [ -z "$(git status --porcelain 2>/dev/null)" ] || problems+=("work is uncommitted (git status)")
  if branch=$(git symbolic-ref -q --short HEAD); then
    if ! git rev-parse -q --verify "$branch@{upstream}" >/dev/null; then
      problems+=("$branch was never pushed")
    else
      ahead=$(git rev-list --count "$branch@{upstream}..$branch" 2>/dev/null)
      [ "${ahead:-0}" = 0 ] || problems+=("$ahead commit(s) of $branch are not pushed")
    fi
  fi
  [ ${#problems[@]} -gt 0 ] || return 0
  {
    echo "Peal: the close of task $id is in progress (peal close begin) and not finished:"
    printf '  - %s\n' "${problems[@]}"
    echo "Finish it: write the Outcome, then peal close finish. If the close is off, peal close abort REASON."
  } >&2
  return 2
}

# peal_close_verify -> whether the session may leave this worktree, one line, status:
#   READY                    0  the pull request is open, its checks green, no conflict
#   READY:merged             0  merged already
#   READY:pr-closed          0  closed unmerged: the human's call
#   READY:no-checks          0  open, and the repository runs no GitHub Actions workflow
#   WAIT:checks-pending      3  a check is still running
#   WAIT:no-checks-yet       3  no check has registered yet
#   WAIT:mergeability-unknown  3  GitHub has not computed it yet
#   BLOCKED:<why>            1  not-a-repo, no-settings, detached-head, on-main,
#                               close-unfinished (finish has not run through), uncommitted,
#                               no-upstream, unpushed, no-gh, gh-failed, no-pr,
#                               conflicts, checks-failing: stay and fix it here
# The branch checked out here is the one checked; anything that cannot be verified is
# BLOCKED, never READY.
peal_close_verify() {
  local top branch main gitdir ahead repo pr state merged mergeable sha checks status
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "BLOCKED:not-a-repo"; return 1; }
  cd "$top" || { echo "BLOCKED:not-a-repo"; return 1; }
  peal_config_load 2>/dev/null || { echo "BLOCKED:no-settings"; return 1; }
  branch=$(git symbolic-ref -q --short HEAD) || { echo "BLOCKED:detached-head"; return 1; }
  main=$(peal_config_get main)
  [ "$branch" != "$main" ] || { echo "BLOCKED:on-main"; return 1; }
  gitdir=$(_peal_close_gitdir)
  [ ! -f "$gitdir/$PEAL_CLOSE_SENTINEL" ] || { echo "BLOCKED:close-unfinished"; return 1; }
  [ -z "$(git status --porcelain)" ] || { echo "BLOCKED:uncommitted"; return 1; }
  git rev-parse -q --verify "$branch@{upstream}" >/dev/null || { echo "BLOCKED:no-upstream"; return 1; }
  ahead=$(git rev-list --count "$branch@{upstream}..$branch")
  [ "$ahead" = 0 ] || { echo "BLOCKED:unpushed"; return 1; }
  command -v gh >/dev/null 2>&1 || { echo "BLOCKED:no-gh"; return 1; }
  repo=$(peal_github_repo) || { echo "BLOCKED:no-settings"; return 1; }
  pr=$(peal_gh "repos/$repo/pulls?state=all&head=${repo%%/*}:$(peal_urlencode "$branch")" \
    --jq '.[0] | select(. != null) | .number') || { echo "BLOCKED:gh-failed"; return 1; }
  [ -n "$pr" ] || { echo "BLOCKED:no-pr"; return 1; }
  state=$(peal_gh "repos/$repo/pulls/$pr" --jq '[.state, (.merged | tostring), (.mergeable | tostring)] | @tsv') \
    || { echo "BLOCKED:gh-failed"; return 1; }
  IFS="$(printf '\t')" read -r state merged mergeable <<<"$state"
  [ "$merged" != true ] || { echo "READY:merged"; return 0; }
  case $state in
    closed) echo "READY:pr-closed"; return 0 ;;
    open) ;;
    *) echo "BLOCKED:gh-failed"; return 1 ;;
  esac
  [ "$mergeable" != false ] || { echo "BLOCKED:conflicts"; return 1; }
  sha=$(git rev-parse HEAD)
  checks=$(peal_pr_checks "$repo" "$sha")
  status=$?
  [ "$checks" = READY ] || { echo "$checks"; return $status; }
  [ "$mergeable" = true ] || { echo "WAIT:mergeability-unknown"; return 3; }
  echo "READY"
}

# peal_close_wait -> peal_close_verify again every PEAL_CLOSE_WAIT_INTERVAL seconds (20)
# until its verdict is not WAIT, or until the next wait would pass PEAL_CLOSE_WAIT_BUDGET
# seconds (540, under a tool call's ten minutes); then its last line and status. Running
# out of budget is no verdict of its own: the last WAIT stands, and the caller runs wait
# again.
peal_close_wait() {
  local interval=${PEAL_CLOSE_WAIT_INTERVAL:-20} budget=${PEAL_CLOSE_WAIT_BUDGET:-540} start=$SECONDS line status
  case "$interval:$budget" in
    *[!0-9:]* | :* | *:) peal_err "close wait: PEAL_CLOSE_WAIT_INTERVAL and PEAL_CLOSE_WAIT_BUDGET are whole seconds"; return 2 ;;
  esac
  while :; do
    line=$(peal_close_verify)
    status=$?
    [ -n "$line" ] || { echo "BLOCKED:verify-failed"; return 1; }
    case $line in WAIT:*) ;; *) echo "$line"; return $status ;; esac
    if [ $((SECONDS - start + interval)) -gt "$budget" ]; then
      echo "$line"
      return $status
    fi
    sleep "$interval"
  done
}

# peal_check_outcomes -> for task files: every task under done/ in this work tree has an
# Outcome, and no placeholder left in it; a line on stderr for each that does not, and
# status 2.
peal_check_outcomes() {
  local top tasks file status=0
  [ "$(peal_config_get storage.kind)" = files ] || return 0
  top=$(peal_project_root) || return 2
  tasks=$(peal_config_get tasks) || return 2
  tasks=${tasks%/}
  for file in "$top/$tasks/done"/*.md; do
    [ -f "$file" ] || continue
    if ! peal_text_outcome_filled <"$file"; then
      peal_err "${file#"$top"/}: done, and its Outcome is empty"
      status=2
    elif peal_text_outcome_placeholder <"$file"; then
      peal_err "${file#"$top"/}: done, and its Outcome still holds a placeholder (<!-- ... -->)"
      status=2
    fi
  done
  return $status
}
