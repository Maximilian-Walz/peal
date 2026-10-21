# shellcheck shell=bash
# peal apply (docs/reference/cli.md, "peal apply"): a batch of proposals a control plane's
# human accepted, read as one JSON document on stdin and written as one change. For task
# files (sourced by store-files.sh's peal_store_apply) that is one commit on the main
# branch, through lib/main-write.sh: one pull request where main takes pull requests only.
#
# Input: {"proposals": [{"id": ..., "kind": ..., ...}, ...]}, read by lib/apply.awk, as
# Belfry's tasks.commands.apply sends it. The kinds and their fields (every kind also
# takes "why", the reason, which goes into the commit's body, and "origin", outsider or
# writer, "" as none, which only file and add act on; "ref", "item" and "into" are
# Belfry's own and ignored, whatever their value; Belfry leaves empty fields out, so an
# absent optional field is none):
#   file      title, text (a task text as peal create takes it, NNNN for its number),
#             milestone, priority, owner (ai, human), origin (outsider, writer): those
#             four go into the frontmatter and win over the text's; title only gives the
#             slug, as create --title does
#   add       task, text (a dated line under its Notes, no '---' or '## ' line), origin
#             (outsider marks the task origin: outsider)
#   vouch     task (a human vouches for an outsider's task: its origin: outsider goes and
#             a dated line "Vouched for by a writer: <why>" goes under its Notes, a
#             Notes section added when it has none; a task that is a writer's already is
#             answered done, nothing written; no "@<id>" task, no origin: outsider)
#   move      task, milestone (absent or null: none)
#   priority  task, priority (urgent, high, normal, low; normal removes the field)
#   depends   task, on, remove (true takes the dependency out; absent, false or null
#             adds it)
#   retire    task, reason or duplicate (the Outcome "Retired <date> without being
#             claimed: <reason>", or "...: duplicate of <id>")
#   milestone_create  title (one line), goal (no '---' or '## ' line), due (YYYY-MM-DD),
#             order (an integer, by default one past the highest): a new open milestone
#             in the milestones directory, id m<N> one past the highest numeric one
#             (zero-padded when all of them are), its text peal init's (peal_ms_text)
#   milestone_update  milestone, title, due, order (null removes due or order; at least
#             one of the three): a title goes into the frontmatter's title when the file
#             has one, else its "# " heading
#   milestone_state  milestone, state (park: parked, unpark and reopen: open, close:
#             done), reason (park only, one line); then, when none is current, the first
#             open milestone by order made current
#   split_milestone  milestone (the one split), tasks (an array of task ids, each in any
#             milestone or none), title, goal, due, order (as milestone_create's; by
#             default milestone's + 1, else one past the highest): a new milestone, as
#             milestone_create makes it, and those tasks moved to it. The one array Peal
#             reads, each item a string of its own (lib/apply.awk)
# A task, an on or a duplicate written "@<id>" is the task the file proposal <id> of the
# batch files; for task, an earlier one. A milestone written "@<id>" (in file, move,
# milestone_update, milestone_state) is the milestone an earlier milestone_create <id>
# makes (a split_milestone's too, and its "milestone" may name one); an item of tasks is
# a task id or an "@<id>" of an earlier file proposal. fold and dismiss are Belfry's own and no
# backlog change; both are answered not done.
#
# Every proposal is checked against the main branch as the whole batch leaves it, every
# problem reported: a task in the backlog that nobody claimed, a milestone that exists,
# is not done and is no parked one moved into or out of (parked as the batch leaves it;
# out of, parked at the start as well), a frontmatter task-check.awk accepts, no depends
# cycle the batch closes, no task retired while one not done still names it, no
# milestone closed while a task not done (its review task aside) names it, milestone
# files peal_ms_load accepts. Any invalid proposal and nothing is written.
#
# Output: one JSON line per proposal, in input order, as Belfry's ApplyResult reads it:
# {"id", "done", "outcome", "task", "milestone", "change"}; done true only when it was
# carried out, outcome one line (what was done, or why not: this one failed a check,
# another did, or the write failed); task the task a kind acted on (a file's new one);
# milestone the milestone a milestone kind acted on (a new one's id); change the pull
# request, when the write went through one. Exit 0 all done, 2 an invalid batch with nothing changed, 1 the
# write failed.

PEAL_APPLY_KINDS="file add vouch move priority depends retire milestone_create milestone_update milestone_state split_milestone"

# The proposals live in variables, not files read by a process each time (bash 3.2: no
# associative arrays): PA_T_<I>_<KEY> the type of proposal I's field KEY, PA_V_<I>_<KEY>
# its value, PA_K_<I> its keys in order, PA_ST_<I> and PA_DET_<I> its status and detail,
# PA_RT_<I> and PA_RM_<I> the task and milestone of its answer. A name is only ever built
# from a proposal index (digits) and a key of a-z and _ (_pa_load_manifest checks both
# again); a value is only ever data, never part of a name or a command.

# _pa_slurp FILE -> PA_F, FILE's content as it is (a NUL byte dropped, as $(cat) drops it).
_pa_slurp() {
  local piece=""
  PA_F=""
  while IFS= read -r -d '' piece; do PA_F=$PA_F$piece; done <"$1"
  PA_F=$PA_F$piece
}

# _pa_chomp NAME -> the variable NAME without its trailing newlines, as $(...) leaves a
# value. In time linear in its length (times a logarithm): the run of newlines at its end
# is measured by doubling a suffix that holds only newlines, then by bisection; stripping
# one newline at a time, or a pattern or a regular expression anchored at the end, takes
# time quadratic in the count of newlines (a run of them inside, for the expression). Bytes
# (LC_ALL=C), so a value that is no UTF-8 is cut where $(...) cuts it.
_pa_chomp() {
  local _pc_v=${!1} _pc_len _pc_lo=1 _pc_hi _pc_n=2 _pc_mid LC_ALL=C
  [[ "$_pc_v" == *$'\n' ]] || return 0
  _pc_len=${#_pc_v}
  while [ "$_pc_n" -le "$_pc_len" ] && [[ "${_pc_v:_pc_len-_pc_n}" != *[!$'\n']* ]]; do
    _pc_lo=$_pc_n
    _pc_n=$((_pc_n * 2))
  done
  if [ "$_pc_n" -gt "$_pc_len" ]; then
    _pc_hi=$_pc_len
    [[ "$_pc_v" == *[!$'\n']* ]] || _pc_lo=$_pc_len
  else
    _pc_hi=$_pc_n
  fi
  # The last _pc_lo bytes are newlines, the last _pc_hi are not all newlines.
  while [ $((_pc_hi - _pc_lo)) -gt 1 ]; do
    _pc_mid=$(((_pc_lo + _pc_hi) / 2))
    if [[ "${_pc_v:_pc_len-_pc_mid}" != *[!$'\n']* ]]; then _pc_lo=$_pc_mid; else _pc_hi=$_pc_mid; fi
  done
  printf -v "$1" '%s' "${_pc_v:0:_pc_len-_pc_lo}"
}

# _pa_read FILE -> PA_F, FILE's content without its trailing newlines, as $(cat FILE)
# gives it; status 1 (PA_F empty) if there is no FILE.
_pa_read() {
  PA_F=""
  [ -f "$1" ] || return 1
  _pa_slurp "$1"
  _pa_chomp PA_F
  return 0
}

# _pa_load_manifest -> the manifest apply.awk wrote, loaded: the fields' types, their
# values (from their files), each proposal's keys, the problems apply.awk found made
# invalid (_pa_bad); PA_COUNT, PA_DOCERR (the document's problem) and PA_GOTCOUNT (the
# manifest ends with its count).
_pa_load_manifest() {
  local i k t kn
  PA_COUNT=0 PA_DOCERR="" PA_GOTCOUNT=""
  while IFS=$'\t' read -r i k t; do
    case $i in
      doc) [ "$k" != error ] || [ -n "$PA_DOCERR" ] || PA_DOCERR=$t; continue ;;
      count) PA_GOTCOUNT=1 PA_COUNT=$k; continue ;;
      "" | *[!0123456789]*) continue ;;
    esac
    if [ "$k" = error ]; then
      _pa_bad "$i" "$t"
      continue
    fi
    case $k in "" | *[!abcdefghijklmnopqrstuvwxyz_]*) continue ;; esac
    printf -v "PA_T_${i}_$k" '%s' "$t"
    kn=PA_K_$i
    printf -v "$kn" '%s%s ' "${!kn-}" "$k"
    case $t in
      s | n) _pa_slurp "$PA_DIR/p/$i.$k"; printf -v "PA_V_${i}_$k" '%s' "$PA_F" ;;
    esac
  done <"$PA_DIR/manifest"
}

# _pa_items I KEY -> the files of proposal I's array KEY, one per item, in order; items
# are only ever read from them, matched whole, never split into words.
_pa_items() {
  local n=1
  while [ -f "$PA_DIR/p/$1.$2.$n" ]; do
    printf '%s\n' "$PA_DIR/p/$1.$2.$n"
    n=$((n + 1))
  done
}

# _pa_t I KEY -> PA_T, the type of proposal I's field KEY (s, n, true, false, null);
# status 1 (PA_T empty) if it has none.
_pa_t() {
  local n=PA_T_$1_$2
  PA_T=${!n-}
  [ -n "$PA_T" ]
}

# _pa_type I KEY -> the type of proposal I's field KEY, printed; status 1 if it has none.
_pa_type() {
  _pa_t "$1" "$2" || return 1
  printf '%s\n' "$PA_T"
}

# _pa_val I KEY -> the value of proposal I's field KEY, printed as it is; nothing for null
# or none.
_pa_val() {
  local n=PA_V_$1_$2
  printf '%s' "${!n-}"
}

# _pa_get I KEY -> PA_V, the value of proposal I's field KEY without its trailing
# newlines, as $(_pa_val I KEY) gives it.
_pa_get() {
  local n=PA_V_$1_$2
  PA_V=${!n-}
  _pa_chomp PA_V
}

# _pa_get_raw I KEY -> PA_V, the value of proposal I's field KEY as it is.
_pa_get_raw() {
  local n=PA_V_$1_$2
  PA_V=${!n-}
}

# _pa_has I KEY -> status 0 when proposal I has field KEY, not null.
_pa_has() {
  _pa_t "$1" "$2" && [ "$PA_T" != null ]
}

# _pa_removes I -> status 0 when proposal I (a depends) takes the dependency out: its
# remove is true; absent, false or null adds it.
_pa_removes() {
  _pa_t "$1" remove && [ "$PA_T" = true ]
}

# _pa_bad I MESSAGE -> proposal I invalid, MESSAGE added to its detail.
_pa_bad() {
  local st=PA_ST_$1 det=PA_DET_$1
  if [ "${!st-}" = invalid ]; then
    printf -v "$det" '%s; %s' "${!det-}" "$2"
  else
    printf -v "$st" '%s' invalid
    printf -v "$det" '%s' "$2"
  fi
  PA_INVALID=1
}

# _pa_ok I -> status 0 while proposal I is not invalid.
_pa_ok() {
  local st=PA_ST_$1
  [ "${!st-}" != invalid ]
}

# _pa_errs FILE -> the messages in FILE (peal_err's lines) as one line, "; " between them.
_pa_errs() {
  sed -e 's/^peal: //' "$1" | awk 'NF { out = out (out == "" ? "" : "; ") $0 } END { printf "%s", out }'
}

# _pa_file_index ID [BEFORE] -> PA_IDX, the index of the file proposal whose id is ID
# (numbered below BEFORE, when given); status 1 if there is none.
_pa_file_index() {
  local ref=$1 before=${2:-0} j
  for ((j = 1; j <= PA_COUNT; j++)); do
    [ "$before" = 0 ] || [ "$j" -lt "$before" ] || break
    _pa_get "$j" kind
    [ "$PA_V" = file ] || continue
    _pa_get "$j" id
    [ "$PA_V" = "$ref" ] || continue
    PA_IDX=$j
    return 0
  done
  return 1
}

# _pa_ms_index ID BEFORE -> PA_IDX, the index of the milestone_create or split_milestone
# proposal numbered below BEFORE whose id is ID; status 1 if there is none.
_pa_ms_index() {
  local j
  for ((j = 1; j < $2; j++)); do
    _pa_get "$j" kind
    case $PA_V in milestone_create | split_milestone) ;; *) continue ;; esac
    _pa_get "$j" id
    [ "$PA_V" = "$1" ] || continue
    PA_IDX=$j
    return 0
  done
  return 1
}

# _pa_ms_ref I KEY -> status 0 when proposal I's KEY is a milestone id or the "@<id>"
# of an earlier milestone_create or split_milestone of the batch; else invalid.
_pa_ms_ref() {
  local i=$1 key=$2 v
  _pa_get "$i" "$key"
  v=$PA_V
  if [ "${v#@}" != "$v" ]; then
    _pa_ms_index "${v#@}" "$i" && return 0
    _pa_bad "$i" "$key ${v:0:40} names no earlier milestone_create or split_milestone proposal of the batch"
    return 1
  fi
  [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] && return 0
  _pa_bad "$i" "$key ${v:0:40} is no milestone id or @<proposal id>"
  return 1
}

# _pa_line I KEY -> status 0 when proposal I's KEY is one line, not empty, with no tab;
# else invalid.
_pa_line() {
  local v
  _pa_get_raw "$1" "$2"
  v=$PA_V
  if [ -z "$v" ]; then _pa_bad "$1" "an empty $2"; return 1; fi
  [[ "$v" != *[$'\n\r\t']* ]] && return 0
  _pa_bad "$1" "the $2 is one line, with no tab"
  return 1
}

# _pa_task_ref I KEY [EARLIER] -> status 0 when proposal I's KEY is a task id or a
# "@<id>" of a file proposal of the batch (an earlier one, EARLIER given); else invalid.
_pa_task_ref() {
  local i=$1 key=$2 earlier=${3-} v
  _pa_get "$i" "$key"
  v=$PA_V
  if [[ "$v" =~ ^[0-9][0-9][0-9][0-9]$ ]]; then
    return 0
  elif [ "${v#@}" != "$v" ]; then
    if [ -n "$earlier" ]; then
      _pa_file_index "${v#@}" "$i" || { _pa_bad "$i" "$key ${v:0:40} names no earlier file proposal of the batch"; return 1; }
    else
      _pa_file_index "${v#@}" || { _pa_bad "$i" "$key ${v:0:40} names no file proposal of the batch"; return 1; }
    fi
    return 0
  fi
  _pa_bad "$i" "$key ${v:0:40} is no task id (NNNN) or @<proposal id>"
  return 1
}

# _pa_static I -> proposal I checked on its own: its kind, its fields, their values.
_pa_static() {
  local i=$1 kind id allowed required k t j v slug words kn tn
  _pa_get "$i" kind
  kind=$PA_V
  _pa_get "$i" id
  id=$PA_V
  _pa_t "$i" id
  case $PA_T in
    s | n) [ -n "$id" ] || _pa_bad "$i" "an empty id" ;;
    *) _pa_bad "$i" "no id" ;;
  esac
  for ((j = 1; j < i; j++)); do
    [ -n "$id" ] || break
    _pa_get "$j" id
    if [ "$PA_V" = "$id" ]; then
      _pa_bad "$i" "the id of proposal $j as well"
      break
    fi
  done
  _pa_t "$i" kind
  [ "$PA_T" = s ] || { _pa_bad "$i" "no kind"; return; }
  case $kind in
    file) allowed="title text milestone priority owner origin" required="title text" ;;
    add) allowed="task text origin" required="task text" ;;
    vouch) allowed="task origin" required="task" ;;
    move) allowed="task milestone origin" required="task" ;;
    priority) allowed="task priority origin" required="task priority" ;;
    depends) allowed="task on remove origin" required="task on" ;;
    retire) allowed="task reason duplicate origin" required="task" ;;
    milestone_create) allowed="title goal due order origin" required="title" ;;
    milestone_update) allowed="milestone title due order origin" required="milestone" ;;
    milestone_state) allowed="milestone state reason origin" required="milestone state" ;;
    split_milestone) allowed="milestone tasks title goal due order origin" required="milestone tasks title" ;;
    fold | dismiss)
      _pa_bad "$i" "not a backlog change; Belfry carries it out"
      return ;;
    *)
      _pa_bad "$i" "unknown kind \"$(printf '%s' "${kind:0:40}" | LC_ALL=C tr -c '[:print:]' '?')\" (Peal's: $PEAL_APPLY_KINDS)"
      return ;;
  esac
  kn=PA_K_$i
  # shellcheck disable=SC2086 # keys of a-z and _, a space after each
  for k in ${!kn-}; do
    tn=PA_T_${i}_$k
    t=${!tn}
    # Belfry's own fields (the card, the item, the milestone it files into), whatever
    # their value.
    case $k in ref | item | into) continue ;; esac
    case " id kind why $allowed " in
      *" $k "*) ;;
      *) _pa_bad "$i" "field $k is not one $kind takes"; continue ;;
    esac
    case $k:$t in
      tasks:a) ;;
      tasks:*) [ "$kind" != split_milestone ] || _pa_bad "$i" "tasks is not an array of strings" ;;
      order:n) ;;
      order:*) [ "$kind:$t" = milestone_update:null ] || _pa_bad "$i" "order is not an integer" ;;
      due:null) [ "$kind" = milestone_update ] || _pa_bad "$i" "due is not a date, YYYY-MM-DD" ;;
      remove:true | remove:false | remove:null) ;;
      remove:*) _pa_bad "$i" "remove is not true or false" ;;
      *:s | id:n) ;;
      why:null | origin:null | milestone:null | priority:null | owner:null) ;;
      *) _pa_bad "$i" "field $k is not a string" ;;
    esac
  done
  for k in $required; do
    _pa_has "$i" "$k" || _pa_bad "$i" "no $k"
  done
  if _pa_has "$i" origin; then
    _pa_get "$i" origin
    case $PA_V in outsider | writer | "") ;; *) _pa_bad "$i" "origin must be outsider or writer" ;; esac
  fi
  if [ "$kind" = vouch ] && _pa_has "$i" origin; then
    _pa_get "$i" origin
    [ "$PA_V" != outsider ] || _pa_bad "$i" "a vouch is a writer's, not an outsider's"
  fi
  if [ "$kind" = priority ] && _pa_t "$i" priority && [ "$PA_T" = null ]; then _pa_bad "$i" "no priority"; fi
  if [ "$kind" = milestone_update ] && ! _pa_t "$i" title && ! _pa_t "$i" due && ! _pa_t "$i" order; then
    _pa_bad "$i" "nothing to update: give a title, a due or an order"
  fi
  _pa_ok "$i" || return

  case $kind in
    milestone_* | split_milestone) _pa_static_ms "$i" "$kind"; return ;;
  esac
  if [ "$kind" = file ]; then
    _pa_get "$i" title
    slug=$(_peal_slug_normalise "$PA_V" | cut -d- -f1-5)
    words=$(printf '%s' "$slug" | awk -F- '{ print ($0 == "" ? 0 : NF) }')
    [ "$words" -ge 2 ] || _pa_bad "$i" "the title makes a slug of $words word(s); a slug is at least two kebab-case words"
    printf -v "PA_SLUG_$i" '%s' "$slug"
    [ -s "$PA_DIR/p/$i.text" ] || _pa_bad "$i" "an empty text"
    ! grep -qF -- "$PEAL_TASK_DELIMITER" "$PA_DIR/p/$i.text" || _pa_bad "$i" "the text holds '$PEAL_TASK_DELIMITER'; one task per proposal"
  else
    _pa_task_ref "$i" task earlier || true
    _pa_get "$i" task
    v=$PA_V
    [ "$kind" != retire ] || [ "${v#@}" = "$v" ] || _pa_bad "$i" "retires a task the batch files"
    [ "$kind" != vouch ] || [ "${v#@}" = "$v" ] || _pa_bad "$i" "vouches for a task the batch files"
  fi
  if _pa_has "$i" milestone; then _pa_ms_ref "$i" milestone || true; fi
  if _pa_has "$i" priority; then
    _pa_get "$i" priority
    case $PA_V in
      urgent | high | normal | low) ;;
      *) _pa_bad "$i" "priority $(_pa_val "$i" priority | cut -c1-40) is not urgent, high, normal or low" ;;
    esac
  fi
  if _pa_has "$i" owner; then
    _pa_get "$i" owner
    case $PA_V in ai | human) ;; *) _pa_bad "$i" "owner must be ai or human" ;; esac
  fi
  case $kind in
    add)
      if grep -n -m1 -e '^---[[:space:]]*$' -e '^## ' "$PA_DIR/p/$i.text" >/dev/null; then
        _pa_bad "$i" "the text holds a '---' or '## ' line; a note is prose, not structure"
      fi ;;
    depends)
      _pa_task_ref "$i" on || true ;;
    retire)
      if _pa_has "$i" reason && _pa_has "$i" duplicate; then
        _pa_bad "$i" "a reason or a duplicate, not both"
      elif _pa_has "$i" reason; then
        _pa_get "$i" reason
        v=$PA_V
        [ -n "$v" ] || _pa_bad "$i" "an empty reason"
        [[ "$v" != *$'\n'* ]] || _pa_bad "$i" "the reason is one line"
      elif _pa_has "$i" duplicate; then
        _pa_task_ref "$i" duplicate || true
      else
        _pa_bad "$i" "no reason or duplicate"
      fi ;;
  esac
}

# _pa_static_ms I KIND -> the fields of proposal I, of the milestone kind KIND, checked.
_pa_static_ms() {
  local i=$1 kind=$2 v f n=0 seen=$'\n'
  case $kind in
    milestone_create) ;;
    *) _pa_ms_ref "$i" milestone || true ;;
  esac
  if [ "$kind" = split_milestone ] && _pa_has "$i" tasks; then
    while IFS= read -r f; do
      n=$((n + 1))
      _pa_slurp "$f"
      v=$PA_F
      if [[ "$v" =~ ^[0-9][0-9][0-9][0-9]$ ]]; then
        :
      elif [[ "$v" =~ ^@[^[:cntrl:]]+$ ]]; then
        _pa_file_index "${v#@}" "$i" || _pa_bad "$i" "tasks item $n (${v:0:40}) names no earlier file proposal of the batch"
      else
        _pa_bad "$i" "tasks item $n (${v:0:40}) is no task id (NNNN) or @<proposal id>"
      fi
      case $seen in
        *$'\n'"$v"$'\n'*) _pa_bad "$i" "tasks names ${v:0:40} twice" ;;
      esac
      seen="$seen$v"$'\n'
    done < <(_pa_items "$i" tasks)
    [ "$n" -gt 0 ] || _pa_bad "$i" "tasks is empty"
  fi
  if _pa_has "$i" title; then _pa_line "$i" title || true; fi
  if _pa_has "$i" due; then
    _pa_get "$i" due
    v=$PA_V
    peal_valid_date "$v" || _pa_bad "$i" "due ${v:0:40} is not a date, YYYY-MM-DD"
  fi
  if _pa_has "$i" order; then
    _pa_get "$i" order
    v=$PA_V
    if ! [[ "$v" =~ ^-?[0-9]+$ ]] || [ ${#v} -gt 9 ]; then _pa_bad "$i" "order ${v:0:40} is not an integer"; fi
  fi
  if _pa_has "$i" goal; then
    if [ ! -s "$PA_DIR/p/$i.goal" ]; then
      _pa_bad "$i" "an empty goal"
    elif grep -n -m1 -e '^---[[:space:]]*$' -e '^## ' "$PA_DIR/p/$i.goal" >/dev/null; then
      _pa_bad "$i" "the goal holds a '---' or '## ' line; a goal is prose, not structure"
    fi
  fi
  if [ "$kind" = milestone_state ]; then
    _pa_get "$i" state
    case $PA_V in
      park | unpark | close | reopen) ;;
      *) _pa_bad "$i" "state must be park, unpark, close or reopen" ;;
    esac
    if _pa_has "$i" reason; then
      _pa_get "$i" state
      [ "$PA_V" = park ] || _pa_bad "$i" "a reason is for park"
      _pa_line "$i" reason || true
    fi
  fi
}

# _pa_resolve I KEY -> PA_RES, the task id proposal I's KEY names: a task id as it is,
# "@<id>" the number the file proposal <id> got in this compose.
_pa_resolve() {
  local v
  _pa_get "$1" "$2"
  v=$PA_V
  if [ "${v#@}" != "$v" ]; then
    _pa_file_index "${v#@}" || return 1
    _pa_read "$PA_S/new.$PA_IDX" || { peal_err "$2 $v: that file proposal is invalid"; return 1; }
    PA_RES=$PA_F
  else
    PA_RES=$v
  fi
}

# _pa_load ID BASE [KIND I] -> task ID's text at BASE into the compose (once): refused
# unless it is in the backlog there and nobody has claimed it. Exception: for a depends
# proposal I (KIND), the claim of this clone's own worktree (_peal_files_own_claim) is
# given back, as peal defer does: nothing built on it (_peal_files_no_work), a "Deferred"
# note in the text, and $PA_DIR/giveback holding the claim's file here (_peal_apply_files
# commits it after the write).
_pa_load() {
  local id=$1 base=$2 kind=${3-} i=${4-} path top doing branch why
  if [ -f "$PA_S/t/$id.text" ]; then
    # Loaded already; a claim given back by this batch takes depends proposals only.
    if [ -f "$PA_S/t/$id.giveback" ] && [ "$kind" != depends ]; then
      peal_err "apply: task $id is claimed (this worktree's); only a depends proposal gives it back"
      return 2
    fi
    return 0
  fi
  if [ "$kind" = depends ] && _peal_files_own_claim "$id"; then
    _peal_files_in_backlog "$base" "$id" apply 2>"$PA_DIR/err.find" || { grep -v 'warning:' "$PA_DIR/err.find" >&2; return 2; }
    path=$PEAL_PATH
    top=$(peal_project_root) || return 2
    doing=$PEAL_TASKS/doing/${path##*/}
    if [ ! -f "$top/$doing" ]; then
      peal_err "apply: no $doing here: a claim's file keeps the name it had in the backlog"
      return 2
    fi
    branch=$(git symbolic-ref -q --short HEAD)
    (cd "$top" && _peal_files_no_work "$id" "$branch" "$base" "$path" "$doing") || return 2
    git show "$base:$path" >"$PA_S/t/$id.text" || return 2
    cp "$PA_S/t/$id.text" "$PA_S/t/$id.old"
    _pa_get "$i" why
    why=${PA_V//[$'\n\r\t']/ }
    if [ -z "${why//[ ]/}" ]; then
      _pa_resolve "$i" on || return 2
      why="waits for $PA_RES"
      ! _pa_removes "$i" || why="no longer waits for $PA_RES"
    fi
    peal_text_add_note "Deferred $(date -u +%Y-%m-%d) after a claim: $why" <"$PA_S/t/$id.text" >"$PA_S/t/$id.text.n" \
      && mv "$PA_S/t/$id.text.n" "$PA_S/t/$id.text" || return 2
    printf '%s\n' "$doing" >"$PA_DIR/giveback"
    : >"$PA_S/t/$id.giveback"
    printf '%s\n' "$path" >"$PA_S/t/$id.path"
    echo "$id" >>"$PA_S/order"
    return 0
  fi
  _peal_files_no_claim "$id" apply || return 2
  _peal_files_in_backlog "$base" "$id" apply 2>"$PA_DIR/err.find" || { grep -v 'warning:' "$PA_DIR/err.find" >&2; return 2; }
  path=$PEAL_PATH
  git show "$base:$path" >"$PA_S/t/$id.text" || return 2
  cp "$PA_S/t/$id.text" "$PA_S/t/$id.old"
  printf '%s\n' "$path" >"$PA_S/t/$id.path"
  echo "$id" >>"$PA_S/order"
}

# _pa_frontmatter I FILE -> proposal I's milestone, priority, owner and origin written
# into the text FILE, those it has.
_pa_frontmatter() {
  local i=$1 file=$2 v
  if _pa_t "$i" milestone; then
    if _pa_has "$i" milestone; then
      _pa_ms_resolve "$i" milestone || return 2
      v=$PA_RES
      peal_fm_set "$file" milestone "$v" || return 2
    else
      peal_fm_unset "$file" milestone || return 2
    fi
  fi
  if _pa_has "$i" priority; then
    _pa_get "$i" priority
    v=$PA_V
    if [ "$v" = normal ]; then peal_fm_unset "$file" priority || return 2
    else peal_fm_set "$file" priority "$v" || return 2; fi
  fi
  if _pa_has "$i" owner; then
    _pa_get "$i" owner
    if [ "$PA_V" = human ]; then peal_fm_set "$file" owner human || return 2
    else peal_fm_unset "$file" owner || return 2; fi
  fi
  # Only a file acts on its origin; "" is as good as none.
  _pa_get "$i" kind
  if [ "$PA_V" = file ] && _pa_has "$i" origin; then
    _pa_get "$i" origin
    case $PA_V in
      outsider) peal_fm_set "$file" origin outsider || return 2 ;;
      writer) peal_fm_unset "$file" origin || return 2 ;;
    esac
  fi
}

# _pa_item I BASE -> proposal I applied to the compose; status 2 with the problem on
# stderr.
_pa_item() {
  local i=$1 base=$2 kind id on text f deps v line sn
  _pa_get "$i" kind
  kind=$PA_V
  case $kind in
    milestone_* | split_milestone) _pa_ms_item "$i" "$base"; return ;;
  esac
  if [ "$kind" = file ]; then
    _pa_read "$PA_S/new.$i"
    id=$PA_F
    f=$PA_S/t/$id.text
    _pa_get "$i" text
    text=$PA_V
    printf '%s\n' "${text//NNNN/$id}" >"$f"
    if [ -n "$(peal_fm_get "$f" merge 2>/dev/null)" ]; then
      peal_err "the text sets merge; only a human, editing the task itself, sets merge: auto"
      return 2
    fi
    _pa_frontmatter "$i" "$f" || return 2
    sn=PA_SLUG_$i
    printf '%s\n' "$PEAL_TASKS/backlog/$id-${!sn-}.md" >"$PA_S/t/$id.path"
    echo "$i" >"$PA_S/t/$id.file"
    echo "$id" >>"$PA_S/order"
    printf '%s' "$id" >"$PA_S/res.$i.task"
    _pa_read "$PA_S/t/$id.path"
    printf 'filed %s' "$PA_F" >"$PA_S/res.$i.detail"
    echo "$i" >"$PA_S/t/$id.last"
    return 0
  fi
  _pa_resolve "$i" task || return 2
  id=$PA_RES
  _pa_load "$id" "$base" "$kind" "$i" || return 2
  if [ -f "$PA_S/t/$id.retired" ]; then
    peal_err "task $id is retired by an earlier proposal"
    return 2
  fi
  f=$PA_S/t/$id.text
  printf '%s' "$id" >"$PA_S/res.$i.task"
  echo "$i" >"$PA_S/t/$id.last"
  case $kind in
    add)
      _pa_read "$PA_S/t/$id.path"
      v=$PA_F
      _pa_get "$i" text
      text=$PA_V
      _pa_get "$i" origin
      PEAL_PATH=$v PEAL_COMMENT="$(date -u +%Y-%m-%d): $text" \
        PEAL_COMMENT_ORIGIN=$PA_V _peal_files_rewrite_comment "$f" "$f.n" && mv "$f.n" "$f" || return 2
      printf 'noted on %s' "$id" >"$PA_S/res.$i.detail" ;;
    vouch)
      if [ "$(peal_fm_get "$f" origin 2>/dev/null)" != outsider ]; then
        printf 'task %s: already a writer'"'"'s' "$id" >"$PA_S/res.$i.detail"
        return 0
      fi
      _pa_get "$i" why
      v=${PA_V//[$'\n\r\t']/ }
      v=${v%"${v##*[! ]}"}
      line="$(date -u +%Y-%m-%d): Vouched for by a writer"
      if [ -n "${v//[ ]/}" ]; then line="$line: $v"; else line="$line."; fi
      peal_fm_unset "$f" origin || return 2
      peal_text_add_note_or_section "$line" <"$f" >"$f.n" && mv "$f.n" "$f" || return 2
      printf 'task %s: vouched for, a writer'"'"'s now' "$id" >"$PA_S/res.$i.detail" ;;
    move)
      _pa_frontmatter "$i" "$f" || return 2
      # Belfry leaves an empty milestone out: none.
      if ! _pa_t "$i" milestone; then peal_fm_unset "$f" milestone || return 2; fi
      v=$(peal_fm_get "$f" milestone 2>/dev/null)
      printf 'task %s: milestone %s' "$id" "${v:-none}" >"$PA_S/res.$i.detail" ;;
    priority)
      _pa_frontmatter "$i" "$f" || return 2
      _pa_get "$i" priority
      printf 'task %s: priority %s' "$id" "$PA_V" >"$PA_S/res.$i.detail" ;;
    depends)
      _pa_resolve "$i" on || return 2
      on=$PA_RES
      if [ "$on" = "$id" ]; then
        peal_err "task $id cannot wait for itself"
        return 2
      fi
      deps=$(peal_fm_get "$f" depends 2>/dev/null | sed '/^$/d')
      if ! _pa_removes "$i"; then
        _peal_files_add_depend "$f" "$on" || return 2
        printf 'task %s: waits for %s' "$id" "$on" >"$PA_S/res.$i.detail"
      else
        deps=$(printf '%s\n' "$deps" | grep -vxF -- "$on")
        if [ -z "$deps" ]; then
          peal_fm_unset "$f" depends || return 2
        else
          # shellcheck disable=SC2086 # one item per line, none with a blank
          peal_fm_set_list "$f" depends $deps || return 2
        fi
        printf 'task %s: no longer waits for %s' "$id" "$on" >"$PA_S/res.$i.detail"
      fi ;;
    retire)
      if _pa_has "$i" duplicate; then
        _pa_resolve "$i" duplicate || return 2
        on=$PA_RES
        if [ "$on" = "$id" ]; then
          peal_err "task $id cannot be a duplicate of itself"
          return 2
        fi
        if [ ! -f "$PA_S/t/$on.file" ] && ! _peal_files_find "$base" "$on" >/dev/null 2>&1; then
          peal_err "duplicate: no task $on"
          return 2
        fi
        line="duplicate of $on"
      else
        _pa_get "$i" reason
        line=$PA_V
      fi
      _peal_files_retire_text "$f" "$f.n" "$line" "task $id" && mv "$f.n" "$f" || return 2
      echo "$i" >"$PA_S/t/$id.retired"
      _pa_read "$PA_S/t/$id.path"
      v=$PA_F
      printf 'retired %s' "$PEAL_TASKS/done/${v##*/}" >"$PA_S/res.$i.detail" ;;
  esac
}

# _pa_ms_resolve I KEY -> PA_RES, the milestone id proposal I's KEY names: an id as it
# is, "@<id>" the id the milestone_create <id> got in this compose.
_pa_ms_resolve() {
  local v
  _pa_get "$1" "$2"
  v=$PA_V
  if [ "${v#@}" != "$v" ]; then
    _pa_ms_index "${v#@}" "$1" || return 1
    _pa_read "$PA_S/msnew.$PA_IDX" || { peal_err "$2 $v: that milestone_create proposal is invalid"; return 1; }
    PA_RES=$PA_F
  else
    PA_RES=$v
  fi
}

# _pa_ms_path ID -> milestone ID's file, relative to the compose's milestones root; status
# 1 if there is none.
_pa_ms_path() {
  awk -F '\t' -v id="$1" '$1 == id { print $2; found = 1; exit } END { exit !found }' "$PA_S/ms.idx"
}

# _pa_ms_ids BASE -> the milestone_create and split_milestone proposals not invalid given their ids
# (PA_S/msnew.I): m<N>, N one past the highest numeric id, zero-padded to their width
# when every numeric id has the same one, a name a milestone file has skipped.
_pa_ms_ids() {
  local i max width id
  read -r max width < <(cut -f1 "$PA_S/ms.idx" | awk '
    /^m[0-9]+$/ { n = substr($0, 2); if (n + 0 > max) max = n + 0; w = length(n); if (seen && w != width) mixed = 1; width = w; seen = 1 }
    END { print max + 0, (mixed || !seen ? 1 : width) }')
  for ((i = 1; i <= PA_COUNT; i++)); do
    if ! _pa_ok "$i"; then continue; fi
    _pa_get "$i" kind
    case $PA_V in milestone_create | split_milestone) ;; *) continue ;; esac
    while :; do
      max=$((max + 1))
      printf -v id 'm%0*d' "$width" "$max"
      [ -e "$PA_S/ms/$PA_MSDIR/$id.md" ] || _pa_ms_path "$id" >/dev/null || break
    done
    printf '%s\n' "$id" >"$PA_S/msnew.$i"
  done
}

# _pa_ms_order -> one past the highest order of the compose's milestones (1 for none).
_pa_ms_order() {
  local rel max=""
  while IFS=$'\t' read -r _ rel; do
    peal_fm_get "$PA_S/ms/$rel" order 2>/dev/null || true
  done <"$PA_S/ms.idx" | awk '/^-?[0-9]+$/ && (max == "" || $0 + 0 > max) { max = $0 + 0 } END { print max + 1 }'
}

# _pa_ms_item I BASE -> milestone proposal I applied to the compose's milestone files; status
# 2 with the problem on stderr.
_pa_ms_item() {
  local i=$1 base=$2 kind id rel f v order old target what="" st from frel tid tf j moved="" ids=() title goal
  _pa_get "$i" kind
  kind=$PA_V
  if [ "$kind" = milestone_create ] || [ "$kind" = split_milestone ]; then
    _pa_read "$PA_S/msnew.$i"
    id=$PA_F
    rel=$PA_MSDIR/$id.md
    f=$PA_S/ms/$rel
    if [ "$kind" = split_milestone ]; then
      _pa_ms_resolve "$i" milestone || return 2
      from=$PA_RES
      frel=$(_pa_ms_path "$from") || { peal_err "milestone $from does not exist"; return 2; }
    fi
    if _pa_has "$i" order; then
      _pa_get "$i" order
      order=$PA_V
    elif [ "$kind" = split_milestone ]; then
      order=$(peal_fm_get "$PA_S/ms/$frel" order 2>/dev/null) || order=""
      if [[ "$order" =~ ^-?[0-9]+$ ]] && [ ${#order} -le 9 ]; then order=$((order + 1)); else order=$(_pa_ms_order) || return 2; fi
    else
      order=$(_pa_ms_order) || return 2
    fi
    if [ "$kind" = split_milestone ]; then
      # Every task is judged before anything is written.
      while IFS= read -r tf; do
        _pa_read "$tf"
        v=$PA_F
        if [ "${v#@}" != "$v" ]; then
          _pa_file_index "${v#@}" "$i" || { peal_err "tasks item $v: no earlier file proposal"; return 2; }
          j=$PA_IDX
          _pa_read "$PA_S/new.$j" || { peal_err "tasks item $v: that file proposal is invalid"; return 2; }
          tid=$PA_F
        else
          tid=$v
        fi
        _pa_load "$tid" "$base" || return 2
        if [ -f "$PA_S/t/$tid.retired" ]; then
          peal_err "task $tid is retired by an earlier proposal"
          return 2
        fi
        case " ${ids[*]-} " in *" $tid "*) peal_err "task $tid is listed twice"; return 2 ;; esac
        ids+=("$tid")
      done < <(_pa_items "$i" tasks)
    fi
    mkdir -p "${f%/*}" || return 2
    _pa_get "$i" title
    title=$PA_V
    _pa_get "$i" goal
    goal=$PA_V
    peal_ms_text open "$order" "$title" "$goal" >"$f" || return 2
    if _pa_has "$i" due; then
      _pa_get "$i" due
      peal_fm_set "$f" due "$PA_V" || return 2
    fi
    printf '%s\t%s\n' "$id" "$rel" >>"$PA_S/ms.idx"
    printf 'created milestone %s (%s)' "$id" "$rel" >"$PA_S/res.$i.detail"
    for tid in "${ids[@]+"${ids[@]}"}"; do
      peal_fm_set "$PA_S/t/$tid.text" milestone "$id" || return 2
      echo "$i" >"$PA_S/t/$tid.last"
      moved="${moved:+$moved, }$tid"
    done
    [ -z "$moved" ] || printf '; moved %s' "$moved" >>"$PA_S/res.$i.detail"
  else
    _pa_ms_resolve "$i" milestone || return 2
    id=$PA_RES
    rel=$(_pa_ms_path "$id") || { peal_err "milestone $id does not exist"; return 2; }
    f=$PA_S/ms/$rel
    if [ "$kind" = milestone_update ]; then
      if _pa_has "$i" title; then
        _pa_get "$i" title
        v=$PA_V
        st=0
        peal_fm_get "$f" title >/dev/null 2>&1 || st=$?
        if [ $st = 0 ]; then
          peal_fm_set "$f" title "$v" || return 2
        elif [ $st = 1 ] && PA_TITLE=$v awk '
            NR == 1 && $0 == "---" { fm = 1; print; next }
            fm { if ($0 == "---") fm = 0; print; next }
            !done && /^# / { print "# " ENVIRON["PA_TITLE"]; done = 1; next }
            { print }
            END { exit !done }' "$f" >"$f.n"; then
          mv "$f.n" "$f" || return 2
        else
          rm -f "$f.n"
          peal_fm_set "$f" title "$v" || return 2
        fi
        what="title"
      fi
      for v in due order; do
        _pa_t "$i" "$v" || continue
        if _pa_has "$i" "$v"; then
          _pa_get "$i" "$v"
          peal_fm_set "$f" "$v" "$PA_V" || return 2
          what="${what:+$what, }$v $PA_V"
        else
          peal_fm_unset "$f" "$v" || return 2
          what="${what:+$what, }no $v"
        fi
      done
      printf 'milestone %s: %s' "$id" "$what" >"$PA_S/res.$i.detail"
    else
      _pa_get "$i" state
      case $PA_V in
        park) target=parked ;;
        close) target="done" ;;
        *) target=open ;;
      esac
      old=$(peal_fm_get "$f" state 2>/dev/null)
      if [ "$old" = "$target" ] || { [ "$old" = current ] && [ "$target" = open ]; }; then
        printf 'milestone %s: %s already' "$id" "$old" >"$PA_S/res.$i.detail"
      else
        peal_fm_set "$f" state "$target" || return 2
        if [ "$target" = parked ] && _pa_has "$i" reason; then
          _pa_get "$i" reason
          peal_fm_set "$f" reason "$PA_V" || return 2
        else
          peal_fm_unset "$f" reason || return 2
        fi
        printf 'milestone %s: %s' "$id" "$target" >"$PA_S/res.$i.detail"
      fi
      echo "$i" >"$PA_S/ms.state"
    fi
  fi
  printf '%s' "$id" >"$PA_S/res.$i.milestone"
  echo "$i" >"$PA_S/ms.last"
}

# _pa_ms_next -> after a batch with a milestone_state proposal: when no milestone is
# current, the first open one by order made current (peal_ms_next_current), said in the
# last milestone_state proposal's detail. Milestone files peal_ms_load refuses are left
# to the check.
_pa_ms_next() {
  local next rel i
  [ -f "$PA_S/ms.state" ] || return 0
  peal_ms_load "$PA_S/ms" 2>/dev/null || return 0
  next=$(printf '%s\n' "$PEAL_MILESTONES" | peal_ms_next_current)
  [ -n "$next" ] || return 0
  rel=$(_pa_ms_path "$next") || return 2
  peal_fm_set "$PA_S/ms/$rel" state current || return 2
  _pa_read "$PA_S/ms.state"
  printf '; milestone %s: current' "$next" >>"$PA_S/res.$PA_F.detail"
}

# _pa_compose BASE CHECK -> every proposal not invalid applied, in order, to copies of
# BASE's task and milestone files under PA_S; the file proposals numbered from BASE
# (PEAL_CREATE_IDS), the milestone_create ones given ids (_pa_ms_ids). CHECK 1: a
# proposal that cannot apply is made invalid; 0: status 2 at the first.
_pa_compose() {
  local base=$1 check=$2 i first n=0 err id
  PA_S=$PA_DIR/s
  rm -rf "$PA_S" && mkdir -p "$PA_S/t" "$PA_S/ms" || return 2
  : >"$PA_S/order"
  first=$(_peal_files_next_id "$base") || return 2
  PEAL_CREATE_IDS=()
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_ok "$i" || continue
    _pa_get "$i" kind
    [ "$PA_V" = file ] || continue
    printf -v id '%04d' $((10#$first + n))
    PEAL_CREATE_IDS+=("$id")
    printf '%s\n' "${PEAL_CREATE_IDS[n]}" >"$PA_S/new.$i"
    n=$((n + 1))
  done
  PA_MSDIR=$(peal_config_get milestones) || return 2
  peal_extract_tree "$base" "$PA_MSDIR" "$PA_S/ms" || return 2
  peal_ms_load "$PA_S/ms" || return 2
  printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' -v OFS='\t' 'NF { print $1, $6 }' >"$PA_S/ms.idx"
  printf '%s\n' "$PEAL_MILESTONES" | sed '/^$/d' >"$PA_S/ms.start"
  cp -R "$PA_S/ms" "$PA_S/ms0" || return 2
  _pa_ms_ids
  err=$PA_DIR/err
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_ok "$i" || continue
    if ! _pa_item "$i" "$base" 2>"$err"; then
      if [ "$check" = 1 ]; then
        _pa_bad "$i" "$(_pa_errs "$err")"
      else
        cat "$err" >&2
        return 2
      fi
    fi
  done
  _pa_ms_next || return 2
  return 0
}

# _pa_check BASE -> the texts the compose made checked as the batch leaves them: the
# milestone files (peal_ms_load), each task's frontmatter (task-check.awk, against the
# milestones as the batch leaves them) and heading, no depends cycle the batch closes, no
# task retired while one not done still names it, no milestone closed while a task not
# done names it. A problem makes invalid the last proposal touching the task or the
# milestones, or the depends, retire or milestone_state proposal it comes from.
_pa_check() {
  local base=$1 id i f context records changes after err label cycle members j ok oldms
  context=$PA_DIR/context records=$PA_DIR/records changes=$PA_DIR/changes after=$PA_DIR/after err=$PA_DIR/err
  if ! peal_ms_load "$PA_S/ms" 2>"$err"; then
    _pa_read "$PA_S/ms.last"
    _pa_bad "$PA_F" "$(_pa_errs "$err")"
    _pa_read "$PA_S/ms.start"
    PEAL_MILESTONES=$PA_F
  fi
  { peal_check_context
    printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' 'NF { print "ms\t" $1 "\t" $3 }'
    _peal_files_ids "$base" | sed 's/^/id\t/'
  } >"$context" || return 2
  printf 'id\t%s\n' "${PEAL_CREATE_IDS[@]+"${PEAL_CREATE_IDS[@]}"}" | sed '/^id\t$/d' >>"$context"
  : >"$changes"
  while IFS= read -r id; do
    f=$PA_S/t/$id.text
    _pa_read "$PA_S/t/$id.last"
    i=$PA_F
    _pa_ok "$i" || continue
    if [ -f "$PA_S/t/$id.retired" ]; then
      continue
    fi
    label="task $id"
    if [ -f "$PA_S/t/$id.file" ]; then
      PEAL_CHECK_ID=$id peal_task_check "$f" plain "$label" "$context" >/dev/null 2>"$err" \
        || _pa_bad "$i" "$(_pa_errs "$err")"
    else
      # Moved out of a milestone not parked at the start: not out of a parked one, even
      # when the batch parks it.
      oldms=$(peal_fm_get "$PA_S/t/$id.old" milestone 2>/dev/null)
      if [ "$oldms" != "$(peal_fm_get "$f" milestone 2>/dev/null)" ] \
          && [ "$(awk -F '\t' -v id="$oldms" '$1 == id { print $3 }' "$PA_S/ms.start")" != parked ]; then
        oldms=""
      fi
      PEAL_CHECK_ID=$id PEAL_CHECK_OLDMS=$oldms peal_task_check "$f" revise "$label" "$context" >/dev/null 2>"$err" || _pa_bad "$i" "$(_pa_errs "$err")"
    fi
    _pa_read "$PA_S/t/$id.path"
    printf '%s\t%s\n' "$(_peal_cycle_row "$id" "$f")" "$PA_F" >>"$changes"
  done <"$PA_S/order"

  peal_store_list --no-pr >"$records" 2>/dev/null || return 2
  # The records as the batch leaves them: the changed rows in place, the new ones added,
  # the retired ones done.
  awk -F '\t' -v OFS='\t' -v dir="$PA_S/t" '
    FILENAME == ARGV[1] { if ($1 != "") { m[$1] = $2; d[$1] = $3; p[$1] = $4; path[$1] = $5; o[++n] = $1 }; next }
    FILENAME == ARGV[2] { if ($1 != "") gone[$1] = 1; next }
    $1 == "" { next }
    ($1 in gone) { $2 = "done" }
    ($1 in m) { $2 = "backlog"; $6 = m[$1]; $7 = d[$1]; $8 = p[$1]; hit[$1] = 1 }
    { print }
    END {
      for (i = 1; i <= n; i++)
        if (!(o[i] in hit)) print o[i], "backlog", "", "", "", m[o[i]], d[o[i]], p[o[i]], "", "", "", path[o[i]], "", "", ""
    }' "$changes" <(for f in "$PA_S"/t/*.retired; do [ -f "$f" ] || continue; f=${f##*/}; echo "${f%.retired}"; done) \
    "$records" >"$after"

  # A cycle through a task the batch changed or added that was not on one before: made
  # invalid, the depends proposals adding to it, else the last proposal of its tasks.
  peal_cycles "$records" >"$PA_DIR/before"
  while IFS=$'\t' read -r members cycle; do
    ok=0
    for ((j = 1; j <= PA_COUNT; j++)); do
      _pa_get "$j" kind
      [ "$PA_V" = depends ] || continue
      ! _pa_removes "$j" || continue
      _pa_read "$PA_S/res.$j.task" || continue
      id=$PA_F
      [[ ",$members," == *",$id,"* ]] || continue
      _pa_bad "$j" "refused: depends cycle $cycle"
      ok=1
    done
    if [ $ok = 0 ]; then
      # shellcheck disable=SC2086 # task ids, a comma between them
      for id in ${members//,/ }; do
        _pa_read "$PA_S/t/$id.last" || continue
        _pa_bad "$PA_F" "refused: depends cycle $cycle"
        break
      done
    fi
    PA_INVALID=1
  done < <(peal_cycles "$after" | awk -F '\t' -v OFS='\t' '
    FILENAME == ARGV[1] { if ($1 != "") changed[$1] = 1; next }
    FILENAME == ARGV[2] { before[$1] = 1; next }
    ($1 in changed) && !($1 in before) && !seen[$2]++ { print $2, $3 }' "$changes" "$PA_DIR/before" -)

  # A retired task still named by one not done.
  for f in "$PA_S"/t/*.retired; do
    [ -f "$f" ] || continue
    id=${f##*/}
    id=${id%.retired}
    _pa_read "$f"
    i=$PA_F
    members=$(_peal_files_dependents "$id" <"$after" | sed 's/^  //' | awk '{ out = out (NR > 1 ? ", " : "") $0 } END { printf "%s", out }')
    [ -z "$members" ] || _pa_bad "$i" "task $id is still named by $members; re-point those in the batch first"
  done

  # A milestone closed while a task not done, its review task aside, names it.
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_get "$i" kind
    [ "$PA_V" = milestone_state ] || continue
    _pa_get "$i" state
    [ "$PA_V" = close ] || continue
    _pa_read "$PA_S/res.$i.milestone" || continue
    id=$PA_F
    members=$(peal_ms_open_tasks "$id" <"$after" | awk -F '\t' '{ out = out (out == "" ? "" : ", ") $1 } END { printf "%s", out }')
    [ -z "$members" ] || _pa_bad "$i" "milestone $id still has tasks not done: $members; move them in the batch first"
  done
}

# _pa_defuse TEXT -> PA_D, TEXT made inert for GitHub, for the commit's and the pull
# request's body: a zero-width joiner after every '#' and '@', and after "issues/" and
# "pull/", so no closing keyword ("Fixes #12", "closes owner/repo#3", "fixes
# https://.../issues/3") closes anything and no @mention pings anyone once it merges.
# Outside text, as a proposal's id and why may be.
_pa_defuse() {
  local zwj=$'\xe2\x80\x8d' t=$1
  t=${t//#/#$zwj}
  t=${t//@/@$zwj}
  t=${t//issues\//issues/$zwj}
  t=${t//pull\//pull/$zwj}
  PA_D=$t
}

# _pa_build BASE -> the batch composed on BASE, in one tree (peal_push_main's BUILD);
# status 4 when it changes nothing.
_pa_build() {
  local base=$1 id f path args=() i why pid kind res
  _pa_compose "$base" 0 || return 2
  while IFS= read -r id; do
    f=$PA_S/t/$id.text
    _pa_read "$PA_S/t/$id.path"
    path=$PA_F
    if [ -f "$PA_S/t/$id.retired" ]; then
      args+=(remove "$path" add "$PEAL_TASKS/done/${path##*/}" "$f")
    elif [ -f "$PA_S/t/$id.file" ] || ! cmp -s "$f" "$PA_S/t/$id.old"; then
      args+=(add "$path" "$f")
    fi
  done <"$PA_S/order"
  while IFS=$'\t' read -r _ path; do
    if [ ! -f "$PA_S/ms0/$path" ] || ! cmp -s "$PA_S/ms/$path" "$PA_S/ms0/$path"; then
      args+=(add "$path" "$PA_S/ms/$path")
    fi
  done <"$PA_S/ms.idx"
  [ ${#args[@]} -gt 0 ] || return 4
  peal_write_tree "$base" "${args[@]}" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT="docs(tasks): apply $PA_COUNT proposal"
  # shellcheck disable=SC2034 # read by peal_push_main
  [ "$PA_COUNT" = 1 ] || PEAL_SUBJECT=${PEAL_SUBJECT}s
  # One line per proposal; why and id with their line breaks and tabs made spaces.
  PEAL_BODY=""
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_get_raw "$i" why
    _pa_defuse "${PA_V//[$'\n\r\t']/ }"
    why=$PA_D
    _pa_get_raw "$i" id
    _pa_defuse "${PA_V//[$'\n\r\t']/ }"
    pid=$PA_D
    _pa_get "$i" kind
    kind=$PA_V
    res=""
    ! _pa_read "$PA_S/res.$i.task" || res=$PA_F
    ! _pa_read "$PA_S/res.$i.milestone" || res=$res$PA_F
    printf -v PEAL_BODY -- '%s- %s (%s %s): %s\n' "$PEAL_BODY" "$pid" "$kind" "$res" "${why:-no reason given}"
  done
  _pa_chomp PEAL_BODY
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_BODY="Proposals applied:"$'\n\n'"$PEAL_BODY"
}

# _pa_json TEXT -> TEXT as a JSON string, printed.
_pa_json() {
  _pa_json_v "$1"
  printf '%s' "$PA_J"
}

# _pa_json_v TEXT -> PA_J, TEXT as a JSON string.
_pa_json_v() {
  local s=$1 out="" c u
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  if [[ "$s" == *[$'\001'-$'\037']* ]]; then
    while [ -n "$s" ]; do
      c=${s:0:1}
      s=${s:1}
      case $c in
        [$'\001'-$'\037']) printf -v u '\\u%04x' "'$c"; out=$out$u ;;
        *) out="$out$c" ;;
      esac
    done
    s=$out
  fi
  PA_J="\"$s\""
}

# _pa_answer I -> proposal I's line of the answer.
_pa_answer() {
  local i=$1 n v
  _pa_get "$i" id
  _pa_json_v "$PA_V"
  printf '{"id": %s, "done": ' "$PA_J"
  n=PA_ST_$i
  if [ "${!n-}" = "done" ]; then printf true; else printf false; fi
  for v in outcome:PA_DET task:PA_RT milestone:PA_RM; do
    n=${v#*:}_$i
    n=${!n-}
    _pa_chomp n
    [ -n "$n" ] || continue
    _pa_json_v "$n"
    printf ', "%s": %s' "${v%%:*}" "$PA_J"
  done
  if [ -n "$PA_CHANGE" ]; then
    _pa_json_v "$PA_CHANGE"
    printf ', "change": %s' "$PA_J"
  fi
  printf '}\n'
}

# _pa_finish STATUS DETAIL -> every proposal not invalid given STATUS (and DETAIL, when
# it has none of its own), the answer printed.
_pa_finish() {
  local i
  for ((i = 1; i <= PA_COUNT; i++)); do
    if _pa_ok "$i"; then
      printf -v "PA_ST_$i" '%s' "$1"
      [ -n "$2" ] || [ "$1" != "done" ] || {
        _pa_read "$PA_S/res.$i.detail"
        printf -v "PA_DET_$i" '%s' "$PA_F"
        ! _pa_read "$PA_S/res.$i.task" || printf -v "PA_RT_$i" '%s' "$PA_F"
        ! _pa_read "$PA_S/res.$i.milestone" || printf -v "PA_RM_$i" '%s' "$PA_F"
      }
      [ -z "$2" ] || printf -v "PA_DET_$i" '%s' "$2"
    fi
    _pa_answer "$i"
  done
}

# _pa_giveback_capture -> a claim given back by the batch: its uncommitted file here
# committed as wip, so the worktree can go clean (as peal defer does).
_pa_giveback_capture() {
  local doing top id
  [ -f "$PA_DIR/giveback" ] || return 0
  read -r doing <"$PA_DIR/giveback"
  id=${doing##*/}
  id=${id%%-*}
  top=$(peal_project_root) || return 0
  if [ -n "$(git -C "$top" status --porcelain -- "$doing")" ] \
      && ! git -C "$top" commit -q -m "wip: defer capture [$id]" -- "$doing" >/dev/null 2>&1; then
    peal_err "apply: the claim is given back on $PEAL_REMOTE/$PEAL_MAIN, but $doing could not be committed; commit it before the release"
  fi
}

# _peal_apply_files -> peal apply on the task-file storage: the proposals on stdin.
_peal_apply_files() {
  local status=0 i line base
  [ $# -eq 0 ] || { peal_err "apply: no arguments; the proposals are a JSON document on stdin"; return 2; }
  _peal_files_settings || return 2
  PA_DIR=$(mktemp -d) || return 2
  mkdir -p "$PA_DIR/p"
  PA_INVALID="" PA_CHANGE="" PA_COUNT=0 PA_S=$PA_DIR/s
  LC_ALL=C awk -v dir="$PA_DIR/p" -v arrays="tasks" -f "$PEAL_ROOT/lib/apply.awk" >"$PA_DIR/manifest"
  _pa_load_manifest
  line=$PA_DOCERR
  if [ -n "$line" ] || [ -z "$PA_GOTCOUNT" ]; then
    printf '{"id": "", "done": false, "outcome": %s}\n' \
      "$(_pa_json "the proposals are no JSON document Peal reads: ${line:-unreadable}")"
    peal_err "apply: the proposals are no JSON document Peal reads: ${line:-unreadable}"
    rm -rf "$PA_DIR"
    return 2
  fi
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_ok "$i" && _pa_static "$i"
  done

  if ! _peal_files_fetch; then
    _pa_finish failed "could not fetch $PEAL_REMOTE/$PEAL_MAIN; nothing was written"
    rm -rf "$PA_DIR"
    return 1
  fi
  base=$(git rev-parse "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || { rm -rf "$PA_DIR"; return 2; }
  _pa_compose "$base" 1 || status=2
  [ $status != 0 ] || _pa_check "$base" || status=2
  if [ $status != 0 ]; then
    _pa_finish failed "the checks could not run (above); nothing was written"
    rm -rf "$PA_DIR"
    return 1
  fi
  if [ -n "$PA_INVALID" ]; then
    _pa_finish not_applied "valid, but another proposal is not; nothing was written"
    peal_err "apply: an invalid proposal; nothing was written"
    rm -rf "$PA_DIR"
    return 2
  fi

  : "${PEAL_MAIN_WRITE_BUDGET:=90}"
  export PEAL_MAIN_WRITE_BUDGET
  # A batch that files tasks takes numbers a rival filing may take first.
  PEAL_MW_TAKEN=""
  for ((i = 1; i <= PA_COUNT; i++)); do
    _pa_get "$i" kind
    [ "$PA_V" != file ] || { PEAL_MW_TAKEN=_peal_files_create_taken; break; }
  done
  peal_push_main _pa_build apply || status=$?
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_MW_TAKEN=""
  [ "$status" != 4 ] || status=0
  if peal_main_write_written $status; then
    PA_CHANGE=${PEAL_MW_URL-}
    _pa_finish "done" ""
    _pa_giveback_capture
    peal_main_write_report "the numbers are final once it merges" >&2
    status=0
  else
    _pa_finish failed "the write failed (above); nothing was written"
    status=1
  fi
  rm -rf "$PA_DIR"
  return $status
}
