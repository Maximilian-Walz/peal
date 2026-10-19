# shellcheck shell=bash
# peal apply (docs/reference/cli.md, "peal apply"): a batch of proposals a control plane's
# human accepted, read as one JSON document on stdin and written as one change. For task
# files (sourced by store-files.sh's peal_store_apply) that is one commit on the main
# branch, through lib/main-write.sh: one pull request where main takes pull requests only.
#
# Input: {"proposals": [{"id": ..., "kind": ..., ...}, ...]}, read by lib/apply.awk. The
# kinds and their fields (every kind also takes "why", the reason, which goes into the
# commit's body):
#   file      title, text (a task text as peal create takes it, NNNN for its number),
#             milestone, priority, owner (ai, human), origin (outsider, writer): those
#             four go into the frontmatter and win over the text's; title only gives the
#             slug, as create --title does
#   add       task, text (a dated line under its Notes, no '---' or '## ' line), origin
#             (outsider marks the task origin: outsider)
#   move      task, milestone (null: none)
#   priority  task, priority (urgent, high, normal, low; normal removes the field)
#   depends   task, on, op (add, remove)
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
# A task, an on or a duplicate written "@<id>" is the task the file proposal <id> of the
# batch files; for task, an earlier one. A milestone written "@<id>" (in file, move,
# milestone_update, milestone_state) is the milestone an earlier milestone_create <id>
# makes. split_milestone is not there yet; fold and dismiss are Belfry's own and no
# backlog change. Both are answered invalid.
#
# Every proposal is checked against the main branch as the whole batch leaves it, every
# problem reported: a task in the backlog that nobody claimed, a milestone that exists,
# is not done and is no parked one moved into or out of (parked as the batch leaves it;
# out of, parked at the start as well), a frontmatter task-check.awk accepts, no depends
# cycle the batch closes, no task retired while one not done still names it, no
# milestone closed while a task not done (its review task aside) names it, milestone
# files peal_ms_load accepts. Any invalid proposal and nothing is written.
#
# Output: one JSON line per proposal, in input order: {"id", "status", "task",
# "milestone", "detail", "change"}, status done, invalid (this one failed a check),
# not_applied (valid, but another was not) or failed (the write failed); milestone the
# milestone a milestone kind acted on (a new one's id); change the pull request, when the
# write went through one. Exit 0 all done, 2 an invalid batch with nothing changed, 1 the
# write failed.

PEAL_APPLY_KINDS="file add move priority depends retire milestone_create milestone_update milestone_state"

# _pa_type I KEY -> the type of proposal I's field KEY (s, n, true, false, null); status 1
# if it has none.
_pa_type() {
  awk -F '\t' -v i="$1" -v k="$2" '$1 == i && $2 == k { print $3; found = 1; exit } END { exit !found }' "$PA_DIR/manifest"
}

# _pa_val I KEY -> the value of proposal I's field KEY; nothing for null or none.
_pa_val() {
  [ ! -f "$PA_DIR/p/$1.$2" ] || cat "$PA_DIR/p/$1.$2"
}

# _pa_has I KEY -> status 0 when proposal I has field KEY, not null.
_pa_has() {
  local t
  t=$(_pa_type "$1" "$2") && [ "$t" != null ]
}

# _pa_bad I MESSAGE -> proposal I invalid, MESSAGE added to its detail.
_pa_bad() {
  local f=$PA_DIR/r/$1
  if [ "$(cat "$f.status" 2>/dev/null)" = invalid ]; then
    printf '; %s' "$2" >>"$f.detail"
  else
    echo invalid >"$f.status"
    printf '%s' "$2" >"$f.detail"
  fi
  PA_INVALID=1
}

# _pa_ok I -> status 0 while proposal I is not invalid.
_pa_ok() {
  [ "$(cat "$PA_DIR/r/$1.status" 2>/dev/null)" != invalid ]
}

# _pa_errs FILE -> the messages in FILE (peal_err's lines) as one line, "; " between them.
_pa_errs() {
  sed -e 's/^peal: //' "$1" | awk 'NF { out = out (out == "" ? "" : "; ") $0 } END { printf "%s", out }'
}

# _pa_file_index ID [BEFORE] -> the index of the file proposal whose id is ID (numbered
# below BEFORE, when given); status 1 if there is none.
_pa_file_index() {
  local ref=$1 before=${2:-0} j
  for ((j = 1; j <= PA_COUNT; j++)); do
    [ "$before" = 0 ] || [ "$j" -lt "$before" ] || break
    if [ "$(_pa_val "$j" kind)" != file ] || [ "$(_pa_val "$j" id)" != "$ref" ]; then continue; fi
    printf '%s\n' "$j"
    return 0
  done
  return 1
}

# _pa_ms_index ID BEFORE -> the index of the milestone_create proposal numbered below
# BEFORE whose id is ID; status 1 if there is none.
_pa_ms_index() {
  local j
  for ((j = 1; j < $2; j++)); do
    if [ "$(_pa_val "$j" kind)" != milestone_create ] || [ "$(_pa_val "$j" id)" != "$1" ]; then continue; fi
    printf '%s\n' "$j"
    return 0
  done
  return 1
}

# _pa_ms_ref I -> status 0 when proposal I's milestone is a milestone id or the "@<id>"
# of an earlier milestone_create of the batch; else invalid.
_pa_ms_ref() {
  local i=$1 v
  v=$(_pa_val "$i" milestone)
  if [ "${v#@}" != "$v" ]; then
    _pa_ms_index "${v#@}" "$i" >/dev/null && return 0
    _pa_bad "$i" "milestone ${v:0:40} names no earlier milestone_create proposal of the batch"
    return 1
  fi
  [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] && return 0
  _pa_bad "$i" "milestone ${v:0:40} is no milestone id or @<proposal id>"
  return 1
}

# _pa_line I KEY -> status 0 when proposal I's KEY is one line, not empty, with no tab;
# else invalid.
_pa_line() {
  local v
  v=$(_pa_val "$1" "$2"; echo x)
  v=${v%x}
  if [ -z "$v" ]; then _pa_bad "$1" "an empty $2"; return 1; fi
  [[ "$v" != *[$'\n\r\t']* ]] && return 0
  _pa_bad "$1" "the $2 is one line, with no tab"
  return 1
}

# _pa_date TEXT -> status 0 when TEXT is a calendar date written YYYY-MM-DD.
_pa_date() {
  local y m d days=(31 28 31 30 31 30 31 31 30 31 30 31)
  [[ "$1" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]] || return 1
  y=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) d=$((10#${BASH_REMATCH[3]}))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] || return 1
  if [ "$m" = 2 ] && { [ $((y % 4)) = 0 ] && [ $((y % 100)) != 0 ] || [ $((y % 400)) = 0 ]; }; then
    [ "$d" -le 29 ]
  else
    [ "$d" -le "${days[m - 1]}" ]
  fi
}

# _pa_task_ref I KEY [EARLIER] -> status 0 when proposal I's KEY is a task id or a
# "@<id>" of a file proposal of the batch (an earlier one, EARLIER given); else invalid.
_pa_task_ref() {
  local i=$1 key=$2 earlier=${3-} v
  v=$(_pa_val "$i" "$key")
  if [[ "$v" =~ ^[0-9][0-9][0-9][0-9]$ ]]; then
    return 0
  elif [ "${v#@}" != "$v" ]; then
    if [ -n "$earlier" ]; then
      _pa_file_index "${v#@}" "$i" >/dev/null || { _pa_bad "$i" "$key ${v:0:40} names no earlier file proposal of the batch"; return 1; }
    else
      _pa_file_index "${v#@}" >/dev/null || { _pa_bad "$i" "$key ${v:0:40} names no file proposal of the batch"; return 1; }
    fi
    return 0
  fi
  _pa_bad "$i" "$key ${v:0:40} is no task id (NNNN) or @<proposal id>"
  return 1
}

# _pa_static I -> proposal I checked on its own: its kind, its fields, their values.
_pa_static() {
  local i=$1 kind id allowed required k t j v slug words
  kind=$(_pa_val "$i" kind)
  id=$(_pa_val "$i" id)
  case $(_pa_type "$i" id) in
    s | n) [ -n "$id" ] || _pa_bad "$i" "an empty id" ;;
    *) _pa_bad "$i" "no id" ;;
  esac
  for ((j = 1; j < i; j++)); do
    if [ -n "$id" ] && [ "$(_pa_val "$j" id)" = "$id" ]; then
      _pa_bad "$i" "the id of proposal $j as well"
      break
    fi
  done
  [ "$(_pa_type "$i" kind)" = s ] || { _pa_bad "$i" "no kind"; return; }
  case $kind in
    file) allowed="title text milestone priority owner origin" required="title text" ;;
    add) allowed="task text origin" required="task text" ;;
    move) allowed="task milestone" required="task" ;;
    priority) allowed="task priority" required="task priority" ;;
    depends) allowed="task on op" required="task on op" ;;
    retire) allowed="task reason duplicate" required="task" ;;
    milestone_create) allowed="title goal due order" required="title" ;;
    milestone_update) allowed="milestone title due order" required="milestone" ;;
    milestone_state) allowed="milestone state reason" required="milestone state" ;;
    split_milestone)
      _pa_bad "$i" "not yet: peal apply does not take split_milestone yet"
      return ;;
    fold | dismiss)
      _pa_bad "$i" "not a backlog change; Belfry carries it out"
      return ;;
    *)
      _pa_bad "$i" "unknown kind \"$(printf '%s' "${kind:0:40}" | LC_ALL=C tr -c '[:print:]' '?')\" (Peal's: $PEAL_APPLY_KINDS)"
      return ;;
  esac
  while IFS=$'\t' read -r k t; do
    case " id kind why $allowed " in
      *" $k "*) ;;
      *) _pa_bad "$i" "field $k is not one $kind takes"; continue ;;
    esac
    case $k:$t in
      order:n) ;;
      order:*) [ "$kind:$t" = milestone_update:null ] || _pa_bad "$i" "order is not an integer" ;;
      due:null) [ "$kind" = milestone_update ] || _pa_bad "$i" "due is not a date, YYYY-MM-DD" ;;
      *:s | id:n) ;;
      why:null | origin:null | milestone:null | priority:null | owner:null) ;;
      *) _pa_bad "$i" "field $k is not a string" ;;
    esac
  done < <(awk -F '\t' -v i="$i" -v OFS='\t' '$1 == i && $2 != "error" { print $2, $3 }' "$PA_DIR/manifest")
  for k in $required; do
    _pa_has "$i" "$k" || _pa_bad "$i" "no $k"
  done
  [ "$kind" != move ] || _pa_type "$i" milestone >/dev/null || _pa_bad "$i" "no milestone (null for none)"
  if [ "$kind" = priority ] && [ "$(_pa_type "$i" priority)" = null ]; then _pa_bad "$i" "no priority"; fi
  if [ "$kind" = milestone_update ] && ! _pa_type "$i" title >/dev/null && ! _pa_type "$i" due >/dev/null \
      && ! _pa_type "$i" order >/dev/null; then
    _pa_bad "$i" "nothing to update: give a title, a due or an order"
  fi
  _pa_ok "$i" || return

  case $kind in
    milestone_*) _pa_static_ms "$i" "$kind"; return ;;
  esac
  if [ "$kind" = file ]; then
    slug=$(_peal_slug_normalise "$(_pa_val "$i" title)" | cut -d- -f1-5)
    words=$(printf '%s' "$slug" | awk -F- '{ print ($0 == "" ? 0 : NF) }')
    [ "$words" -ge 2 ] || _pa_bad "$i" "the title makes a slug of $words word(s); a slug is at least two kebab-case words"
    printf '%s' "$slug" >"$PA_DIR/r/$i.slug"
    [ -s "$PA_DIR/p/$i.text" ] || _pa_bad "$i" "an empty text"
    ! grep -qF -- "$PEAL_TASK_DELIMITER" "$PA_DIR/p/$i.text" || _pa_bad "$i" "the text holds '$PEAL_TASK_DELIMITER'; one task per proposal"
  else
    _pa_task_ref "$i" task earlier || true
    v=$(_pa_val "$i" task)
    [ "$kind" != retire ] || [ "${v#@}" = "$v" ] || _pa_bad "$i" "retires a task the batch files"
  fi
  if _pa_has "$i" milestone; then _pa_ms_ref "$i" || true; fi
  if _pa_has "$i" priority; then
    case $(_pa_val "$i" priority) in
      urgent | high | normal | low) ;;
      *) _pa_bad "$i" "priority $(_pa_val "$i" priority | cut -c1-40) is not urgent, high, normal or low" ;;
    esac
  fi
  if _pa_has "$i" owner; then
    case $(_pa_val "$i" owner) in ai | human) ;; *) _pa_bad "$i" "owner must be ai or human" ;; esac
  fi
  if _pa_has "$i" origin; then
    case $(_pa_val "$i" origin) in outsider | writer) ;; *) _pa_bad "$i" "origin must be outsider or writer" ;; esac
  fi
  case $kind in
    add)
      if grep -n -m1 -e '^---[[:space:]]*$' -e '^## ' "$PA_DIR/p/$i.text" >/dev/null; then
        _pa_bad "$i" "the text holds a '---' or '## ' line; a note is prose, not structure"
      fi ;;
    depends)
      case $(_pa_val "$i" op) in add | remove) ;; *) _pa_bad "$i" "op must be add or remove" ;; esac
      _pa_task_ref "$i" on || true ;;
    retire)
      if _pa_has "$i" reason && _pa_has "$i" duplicate; then
        _pa_bad "$i" "a reason or a duplicate, not both"
      elif _pa_has "$i" reason; then
        v=$(_pa_val "$i" reason)
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
  local i=$1 kind=$2 v
  [ "$kind" = milestone_create ] || _pa_ms_ref "$i" || true
  if _pa_has "$i" title; then _pa_line "$i" title || true; fi
  if _pa_has "$i" due; then
    v=$(_pa_val "$i" due)
    _pa_date "$v" || _pa_bad "$i" "due ${v:0:40} is not a date, YYYY-MM-DD"
  fi
  if _pa_has "$i" order; then
    v=$(_pa_val "$i" order)
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
    case $(_pa_val "$i" state) in
      park | unpark | close | reopen) ;;
      *) _pa_bad "$i" "state must be park, unpark, close or reopen" ;;
    esac
    if _pa_has "$i" reason; then
      [ "$(_pa_val "$i" state)" = park ] || _pa_bad "$i" "a reason is for park"
      _pa_line "$i" reason || true
    fi
  fi
}

# _pa_resolve I KEY -> the task id proposal I's KEY names: a task id as it is, "@<id>"
# the number the file proposal <id> got in this compose.
_pa_resolve() {
  local v j
  v=$(_pa_val "$1" "$2")
  if [ "${v#@}" != "$v" ]; then
    j=$(_pa_file_index "${v#@}") || return 1
    [ -f "$PA_S/new.$j" ] || { peal_err "$2 $v: that file proposal is invalid"; return 1; }
    cat "$PA_S/new.$j"
  else
    printf '%s\n' "$v"
  fi
}

# _pa_load ID BASE -> task ID's text at BASE into the compose (once): refused unless it
# is in the backlog there and nobody has claimed it.
_pa_load() {
  local id=$1 base=$2 path
  [ ! -f "$PA_S/t/$id.text" ] || return 0
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
  if _pa_type "$i" milestone >/dev/null; then
    if _pa_has "$i" milestone; then
      v=$(_pa_ms_resolve "$i" milestone) || return 2
      peal_fm_set "$file" milestone "$v" || return 2
    else
      peal_fm_unset "$file" milestone || return 2
    fi
  fi
  if _pa_has "$i" priority; then
    v=$(_pa_val "$i" priority)
    if [ "$v" = normal ]; then peal_fm_unset "$file" priority || return 2
    else peal_fm_set "$file" priority "$v" || return 2; fi
  fi
  if _pa_has "$i" owner; then
    if [ "$(_pa_val "$i" owner)" = human ]; then peal_fm_set "$file" owner human || return 2
    else peal_fm_unset "$file" owner || return 2; fi
  fi
  if _pa_has "$i" origin; then
    if [ "$(_pa_val "$i" origin)" = outsider ]; then peal_fm_set "$file" origin outsider || return 2
    else peal_fm_unset "$file" origin || return 2; fi
  fi
}

# _pa_item I BASE -> proposal I applied to the compose; status 2 with the problem on
# stderr.
_pa_item() {
  local i=$1 base=$2 kind id on text f deps v line
  kind=$(_pa_val "$i" kind)
  case $kind in
    milestone_*) _pa_ms_item "$i"; return ;;
  esac
  if [ "$kind" = file ]; then
    id=$(cat "$PA_S/new.$i")
    f=$PA_S/t/$id.text
    text=$(cat "$PA_DIR/p/$i.text")
    printf '%s\n' "${text//NNNN/$id}" >"$f"
    if [ -n "$(peal_fm_get "$f" merge 2>/dev/null)" ]; then
      peal_err "the text sets merge; only a human, editing the task itself, sets merge: auto"
      return 2
    fi
    _pa_frontmatter "$i" "$f" || return 2
    printf '%s\n' "$PEAL_TASKS/backlog/$id-$(cat "$PA_DIR/r/$i.slug").md" >"$PA_S/t/$id.path"
    echo "$i" >"$PA_S/t/$id.file"
    echo "$id" >>"$PA_S/order"
    printf '%s' "$id" >"$PA_S/res.$i.task"
    printf 'filed %s' "$(cat "$PA_S/t/$id.path")" >"$PA_S/res.$i.detail"
    echo "$i" >"$PA_S/t/$id.last"
    return 0
  fi
  id=$(_pa_resolve "$i" task) || return 2
  _pa_load "$id" "$base" || return 2
  if [ -f "$PA_S/t/$id.retired" ]; then
    peal_err "task $id is retired by an earlier proposal"
    return 2
  fi
  f=$PA_S/t/$id.text
  printf '%s' "$id" >"$PA_S/res.$i.task"
  echo "$i" >"$PA_S/t/$id.last"
  case $kind in
    add)
      PEAL_PATH=$(cat "$PA_S/t/$id.path") PEAL_COMMENT="$(date -u +%Y-%m-%d): $(cat "$PA_DIR/p/$i.text")" \
        PEAL_COMMENT_ORIGIN=$(_pa_val "$i" origin) _peal_files_rewrite_comment "$f" "$f.n" && mv "$f.n" "$f" || return 2
      printf 'noted on %s' "$id" >"$PA_S/res.$i.detail" ;;
    move)
      _pa_frontmatter "$i" "$f" || return 2
      v=$(peal_fm_get "$f" milestone 2>/dev/null)
      printf 'task %s: milestone %s' "$id" "${v:-none}" >"$PA_S/res.$i.detail" ;;
    priority)
      _pa_frontmatter "$i" "$f" || return 2
      printf 'task %s: priority %s' "$id" "$(_pa_val "$i" priority)" >"$PA_S/res.$i.detail" ;;
    depends)
      on=$(_pa_resolve "$i" on) || return 2
      if [ "$on" = "$id" ]; then
        peal_err "task $id cannot wait for itself"
        return 2
      fi
      deps=$(peal_fm_get "$f" depends 2>/dev/null | sed '/^$/d')
      if [ "$(_pa_val "$i" op)" = add ]; then
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
        on=$(_pa_resolve "$i" duplicate) || return 2
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
        line=$(_pa_val "$i" reason)
      fi
      _peal_files_retire_text "$f" "$f.n" "$line" "task $id" && mv "$f.n" "$f" || return 2
      echo "$i" >"$PA_S/t/$id.retired"
      v=$(cat "$PA_S/t/$id.path")
      printf 'retired %s' "$PEAL_TASKS/done/${v##*/}" >"$PA_S/res.$i.detail" ;;
  esac
}

# _pa_ms_resolve I KEY -> the milestone id proposal I's KEY names: an id as it is,
# "@<id>" the id the milestone_create <id> got in this compose.
_pa_ms_resolve() {
  local v j
  v=$(_pa_val "$1" "$2")
  if [ "${v#@}" != "$v" ]; then
    j=$(_pa_ms_index "${v#@}" "$1") || return 1
    [ -f "$PA_S/msnew.$j" ] || { peal_err "$2 $v: that milestone_create proposal is invalid"; return 1; }
    cat "$PA_S/msnew.$j"
  else
    printf '%s\n' "$v"
  fi
}

# _pa_ms_path ID -> milestone ID's file, relative to the compose's milestones root; status
# 1 if there is none.
_pa_ms_path() {
  awk -F '\t' -v id="$1" '$1 == id { print $2; found = 1; exit } END { exit !found }' "$PA_S/ms.idx"
}

# _pa_ms_ids BASE -> the milestone_create proposals not invalid given their ids
# (PA_S/msnew.I): m<N>, N one past the highest numeric id, zero-padded to their width
# when every numeric id has the same one, a name a milestone file has skipped.
_pa_ms_ids() {
  local i max width id
  read -r max width < <(cut -f1 "$PA_S/ms.idx" | awk '
    /^m[0-9]+$/ { n = substr($0, 2); if (n + 0 > max) max = n + 0; w = length(n); if (seen && w != width) mixed = 1; width = w; seen = 1 }
    END { print max + 0, (mixed || !seen ? 1 : width) }')
  for ((i = 1; i <= PA_COUNT; i++)); do
    if ! _pa_ok "$i" || [ "$(_pa_val "$i" kind)" != milestone_create ]; then continue; fi
    while :; do
      max=$((max + 1))
      id=$(printf 'm%0*d' "$width" "$max")
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

# _pa_ms_item I -> milestone proposal I applied to the compose's milestone files; status
# 2 with the problem on stderr.
_pa_ms_item() {
  local i=$1 kind id rel f v order old target what="" st
  kind=$(_pa_val "$i" kind)
  if [ "$kind" = milestone_create ]; then
    id=$(cat "$PA_S/msnew.$i")
    rel=$PA_MSDIR/$id.md
    f=$PA_S/ms/$rel
    if _pa_has "$i" order; then order=$(_pa_val "$i" order); else order=$(_pa_ms_order) || return 2; fi
    mkdir -p "${f%/*}" || return 2
    peal_ms_text open "$order" "$(_pa_val "$i" title)" "$(_pa_val "$i" goal)" >"$f" || return 2
    if _pa_has "$i" due; then peal_fm_set "$f" due "$(_pa_val "$i" due)" || return 2; fi
    printf '%s\t%s\n' "$id" "$rel" >>"$PA_S/ms.idx"
    printf 'created milestone %s (%s)' "$id" "$rel" >"$PA_S/res.$i.detail"
  else
    id=$(_pa_ms_resolve "$i" milestone) || return 2
    rel=$(_pa_ms_path "$id") || { peal_err "milestone $id does not exist"; return 2; }
    f=$PA_S/ms/$rel
    if [ "$kind" = milestone_update ]; then
      if _pa_has "$i" title; then
        v=$(_pa_val "$i" title)
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
        _pa_type "$i" "$v" >/dev/null || continue
        if _pa_has "$i" "$v"; then
          peal_fm_set "$f" "$v" "$(_pa_val "$i" "$v")" || return 2
          what="${what:+$what, }$v $(_pa_val "$i" "$v")"
        else
          peal_fm_unset "$f" "$v" || return 2
          what="${what:+$what, }no $v"
        fi
      done
      printf 'milestone %s: %s' "$id" "$what" >"$PA_S/res.$i.detail"
    else
      case $(_pa_val "$i" state) in
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
          peal_fm_set "$f" reason "$(_pa_val "$i" reason)" || return 2
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
  i=$(cat "$PA_S/ms.state")
  printf '; milestone %s: current' "$next" >>"$PA_S/res.$i.detail"
}

# _pa_compose BASE CHECK -> every proposal not invalid applied, in order, to copies of
# BASE's task and milestone files under PA_S; the file proposals numbered from BASE
# (PEAL_CREATE_IDS), the milestone_create ones given ids (_pa_ms_ids). CHECK 1: a
# proposal that cannot apply is made invalid; 0: status 2 at the first.
_pa_compose() {
  local base=$1 check=$2 i first n=0 err
  PA_S=$PA_DIR/s
  rm -rf "$PA_S" && mkdir -p "$PA_S/t" "$PA_S/ms" || return 2
  : >"$PA_S/order"
  first=$(_peal_files_next_id "$base") || return 2
  PEAL_CREATE_IDS=()
  for ((i = 1; i <= PA_COUNT; i++)); do
    if ! _pa_ok "$i" || [ "$(_pa_val "$i" kind)" != file ]; then continue; fi
    PEAL_CREATE_IDS+=("$(printf '%04d' $((10#$first + n)))")
    printf '%s\n' "${PEAL_CREATE_IDS[n]}" >"$PA_S/new.$i"
    n=$((n + 1))
  done
  PA_MSDIR=$(peal_config_get milestones) || return 2
  _peal_files_extract "$base" "$PA_MSDIR" "$PA_S/ms" || return 2
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
    _pa_bad "$(cat "$PA_S/ms.last")" "$(_pa_errs "$err")"
    PEAL_MILESTONES=$(cat "$PA_S/ms.start")
  fi
  { peal_check_context
    printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' 'NF { print "ms\t" $1 "\t" $3 }'
    _peal_files_ids "$base" | sed 's/^/id\t/'
  } >"$context" || return 2
  printf 'id\t%s\n' "${PEAL_CREATE_IDS[@]+"${PEAL_CREATE_IDS[@]}"}" | sed '/^id\t$/d' >>"$context"
  : >"$changes"
  while IFS= read -r id; do
    f=$PA_S/t/$id.text
    i=$(cat "$PA_S/t/$id.last")
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
    printf '%s\t%s\n' "$(_peal_cycle_row "$id" "$f")" "$(cat "$PA_S/t/$id.path")" >>"$changes"
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
  peal_cycles "$after" | awk -F '\t' -v OFS='\t' '
    FILENAME == ARGV[1] { if ($1 != "") changed[$1] = 1; next }
    FILENAME == ARGV[2] { before[$1] = 1; next }
    ($1 in changed) && !($1 in before) && !seen[$2]++ { print $2, $3 }' "$changes" "$PA_DIR/before" - \
    | while IFS=$'\t' read -r members cycle; do
        ok=0
        for ((j = 1; j <= PA_COUNT; j++)); do
          if [ "$(_pa_val "$j" kind)" != depends ] || [ "$(_pa_val "$j" op)" != add ]; then continue; fi
          id=$(cat "$PA_S/res.$j.task" 2>/dev/null) || continue
          [[ ",$members," == *",$id,"* ]] || continue
          _pa_bad "$j" "refused: depends cycle $cycle"
          ok=1
        done
        if [ $ok = 0 ]; then
          for id in $(printf '%s' "$members" | tr ',' '\n'); do
            [ -f "$PA_S/t/$id.last" ] || continue
            _pa_bad "$(cat "$PA_S/t/$id.last")" "refused: depends cycle $cycle"
            break
          done
        fi
        echo x >"$PA_DIR/invalid"
      done
  [ ! -f "$PA_DIR/invalid" ] || PA_INVALID=1

  # A retired task still named by one not done.
  for f in "$PA_S"/t/*.retired; do
    [ -f "$f" ] || continue
    id=${f##*/}
    id=${id%.retired}
    i=$(cat "$f")
    members=$(_peal_files_dependents "$id" <"$after" | sed 's/^  //' | awk '{ out = out (NR > 1 ? ", " : "") $0 } END { printf "%s", out }')
    [ -z "$members" ] || _pa_bad "$i" "task $id is still named by $members; re-point those in the batch first"
  done

  # A milestone closed while a task not done, its review task aside, names it.
  for ((i = 1; i <= PA_COUNT; i++)); do
    if [ "$(_pa_val "$i" kind)" != milestone_state ] || [ "$(_pa_val "$i" state)" != close ]; then continue; fi
    id=$(cat "$PA_S/res.$i.milestone" 2>/dev/null) || continue
    members=$(awk -F '\t' -v id="$id" '$6 == id && $2 != "done" && !index("," $11 ",", ",milestone,") {
        out = out (out == "" ? "" : ", ") $1 } END { printf "%s", out }' "$after")
    [ -z "$members" ] || _pa_bad "$i" "milestone $id still has tasks not done: $members; move them in the batch first"
  done
}

# _pa_defuse TEXT -> TEXT made inert for GitHub, for the commit's and the pull request's
# body: a zero-width joiner after every '#' and '@', and after "issues/" and "pull/", so
# no closing keyword ("Fixes #12", "closes owner/repo#3", "fixes https://.../issues/3")
# closes anything and no @mention pings anyone once it merges. Outside text, as a
# proposal's id and why may be.
_pa_defuse() {
  local zwj=$'\xe2\x80\x8d' t=$1
  t=${t//#/#$zwj}
  t=${t//@/@$zwj}
  t=${t//issues\//issues/$zwj}
  t=${t//pull\//pull/$zwj}
  printf '%s' "$t"
}

# _pa_build BASE -> the batch composed on BASE, in one tree (peal_push_main's BUILD);
# status 4 when it changes nothing.
_pa_build() {
  local base=$1 id f path args=() i why
  _pa_compose "$base" 0 || return 2
  while IFS= read -r id; do
    f=$PA_S/t/$id.text
    path=$(cat "$PA_S/t/$id.path")
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
  PEAL_SUBJECT="docs(tasks): apply $PA_COUNT proposal$([ "$PA_COUNT" = 1 ] || echo s)"
  PEAL_BODY=$(for ((i = 1; i <= PA_COUNT; i++)); do
    why=$(_pa_defuse "$(_pa_val "$i" why | tr '\n\r\t' '   ')")
    printf -- '- %s (%s %s): %s\n' "$(_pa_defuse "$(_pa_val "$i" id | tr '\n\r\t' '   ')")" "$(_pa_val "$i" kind)" \
      "$(cat "$PA_S/res.$i.task" "$PA_S/res.$i.milestone" 2>/dev/null)" "${why:-no reason given}"
  done)
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_BODY="Proposals applied:"$'\n\n'"$PEAL_BODY"
}

# _pa_json TEXT -> TEXT as a JSON string.
_pa_json() {
  local s=$1 out="" c
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
        [$'\001'-$'\037']) out="$out$(printf '\\u%04x' "'$c")" ;;
        *) out="$out$c" ;;
      esac
    done
    s=$out
  fi
  printf '"%s"' "$s"
}

# _pa_answer I -> proposal I's line of the answer.
_pa_answer() {
  local r=$PA_DIR/r/$1 v
  printf '{"id": %s, "status": %s' "$(_pa_json "$(_pa_val "$1" id)")" "$(_pa_json "$(cat "$r.status")")"
  v=$(cat "$r.task" 2>/dev/null) && [ -n "$v" ] && printf ', "task": %s' "$(_pa_json "$v")"
  v=$(cat "$r.milestone" 2>/dev/null) && [ -n "$v" ] && printf ', "milestone": %s' "$(_pa_json "$v")"
  v=$(cat "$r.detail" 2>/dev/null) && [ -n "$v" ] && printf ', "detail": %s' "$(_pa_json "$v")"
  [ -z "$PA_CHANGE" ] || printf ', "change": %s' "$(_pa_json "$PA_CHANGE")"
  printf '}\n'
}

# _pa_finish STATUS DETAIL -> every proposal not invalid given STATUS (and DETAIL, when
# it has none of its own), the answer printed.
_pa_finish() {
  local i
  for ((i = 1; i <= PA_COUNT; i++)); do
    if _pa_ok "$i"; then
      echo "$1" >"$PA_DIR/r/$i.status"
      [ -n "$2" ] || [ "$1" != "done" ] || {
        cat "$PA_S/res.$i.detail" >"$PA_DIR/r/$i.detail" 2>/dev/null
        cp "$PA_S/res.$i.task" "$PA_DIR/r/$i.task" 2>/dev/null
        cp "$PA_S/res.$i.milestone" "$PA_DIR/r/$i.milestone" 2>/dev/null
      }
      [ -z "$2" ] || printf '%s' "$2" >"$PA_DIR/r/$i.detail"
    fi
    _pa_answer "$i"
  done
}

# _peal_apply_files -> peal apply on the task-file storage: the proposals on stdin.
_peal_apply_files() {
  local status=0 i line base
  [ $# -eq 0 ] || { peal_err "apply: no arguments; the proposals are a JSON document on stdin"; return 2; }
  _peal_files_settings || return 2
  PA_DIR=$(mktemp -d) || return 2
  mkdir -p "$PA_DIR/p" "$PA_DIR/r"
  PA_INVALID="" PA_CHANGE="" PA_COUNT=0 PA_S=$PA_DIR/s
  LC_ALL=C awk -v dir="$PA_DIR/p" -f "$PEAL_ROOT/lib/apply.awk" >"$PA_DIR/manifest"
  line=$(awk -F '\t' '$1 == "doc" { print $3; exit }' "$PA_DIR/manifest")
  if [ -n "$line" ] || ! grep -q '^count	' "$PA_DIR/manifest"; then
    printf '{"id": "", "status": "invalid", "detail": %s}\n' \
      "$(_pa_json "the proposals are no JSON document Peal reads: ${line:-unreadable}")"
    peal_err "apply: the proposals are no JSON document Peal reads: ${line:-unreadable}"
    rm -rf "$PA_DIR"
    return 2
  fi
  PA_COUNT=$(awk -F '\t' '$1 == "count" { print $2 }' "$PA_DIR/manifest")
  while IFS=$'\t' read -r i _ line; do
    _pa_bad "$i" "$line"
  done < <(awk -F '\t' -v OFS='\t' '$2 == "error" && $1 != "doc"' "$PA_DIR/manifest")
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
    [ "$(_pa_val "$i" kind)" != file ] || { PEAL_MW_TAKEN=_peal_files_create_taken; break; }
  done
  peal_push_main _pa_build apply || status=$?
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_MW_TAKEN=""
  [ "$status" != 4 ] || status=0
  if peal_main_write_written $status; then
    PA_CHANGE=${PEAL_MW_URL-}
    _pa_finish "done" ""
    peal_main_write_report "the numbers are final once it merges" >&2
    status=0
  else
    _pa_finish failed "the write failed (above); nothing was written"
    status=1
  fi
  rm -rf "$PA_DIR"
  return $status
}
