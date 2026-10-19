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
# A task, an on or a duplicate written "@<id>" is the task the file proposal <id> of the
# batch files; for task, an earlier one. The milestone kinds (milestone_create,
# milestone_update, milestone_state, split_milestone) are not there yet; fold and dismiss
# are Belfry's own and no backlog change. Both are answered invalid.
#
# Every proposal is checked against the main branch as the whole batch leaves it, every
# problem reported: a task in the backlog that nobody claimed, a milestone that exists,
# is not done and is no parked one moved into or out of, a frontmatter task-check.awk
# accepts, no depends cycle the batch closes, no task retired while one not done still
# names it. Any invalid proposal and nothing is written.
#
# Output: one JSON line per proposal, in input order: {"id", "status", "task", "detail",
# "change"}, status done, invalid (this one failed a check), not_applied (valid, but
# another was not) or failed (the write failed); change the pull request, when the write
# went through one. Exit 0 all done, 2 an invalid batch with nothing changed, 1 the write
# failed.

PEAL_APPLY_KINDS="file add move priority depends retire"

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
    milestone_create | milestone_update | milestone_state | split_milestone)
      _pa_bad "$i" "not yet: peal apply does not take the milestone kinds yet"
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
  _pa_ok "$i" || return

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
  if _pa_has "$i" milestone; then
    v=$(_pa_val "$i" milestone)
    [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] || _pa_bad "$i" "milestone ${v:0:40} is no milestone id"
  fi
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
  local id=$1 base=$2 refs path
  [ ! -f "$PA_S/t/$id.text" ] || return 0
  refs=$(git for-each-ref --format='%(refname:short)' "refs/heads/$PEAL_PREFIX$id-*" "refs/remotes/*/$PEAL_PREFIX$id-*")
  if [ -n "$refs" ]; then
    peal_err "task $id is claimed ($(printf '%s' "$refs" | tr '\n' ' ' | sed 's/ $//'))"
    return 2
  fi
  if ! path=$(_peal_files_find "$base" "$id" 2>/dev/null); then
    peal_err "no task $id on $PEAL_REMOTE/$PEAL_MAIN"
    return 2
  fi
  case $path in
    "$PEAL_TASKS"/backlog/*) ;;
    "$PEAL_TASKS"/done/*) peal_err "task $id is done ($path)"; return 2 ;;
    *) peal_err "task $id is claimed ($path)"; return 2 ;;
  esac
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
    if _pa_has "$i" milestone; then peal_fm_set "$file" milestone "$(_pa_val "$i" milestone)" || return 2
    else peal_fm_unset "$file" milestone || return 2; fi
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
      if ! peal_text_has_section Notes <"$f"; then
        peal_err "task $id has no '## Notes' section"
        return 2
      fi
      peal_text_add_note "$(date -u +%Y-%m-%d): $(cat "$PA_DIR/p/$i.text")" <"$f" >"$f.n" && mv "$f.n" "$f" || return 2
      if [ "$(_pa_val "$i" origin)" = outsider ]; then peal_fm_set "$f" origin outsider || return 2; fi
      printf 'noted on %s' "$id" >"$PA_S/res.$i.detail" ;;
    move)
      _pa_frontmatter "$i" "$f" || return 2
      v=$(_pa_val "$i" milestone)
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
        if ! printf '%s\n' "$deps" | grep -qxF -- "$on"; then
          # shellcheck disable=SC2046 # one item per line, none with a blank
          peal_fm_set_list "$f" depends $(printf '%s\n' "$deps" | sed '/^$/d') "$on" || return 2
        fi
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
      if peal_text_outcome_filled <"$f"; then
        peal_err "task $id's Outcome is filled in: work happened, this is no plain backlog task"
        return 2
      fi
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
        line="Retired $(date -u +%Y-%m-%d) without being claimed: duplicate of $on"
      else
        line="Retired $(date -u +%Y-%m-%d) without being claimed: $(_pa_val "$i" reason)"
      fi
      peal_text_set_outcome "$line" <"$f" >"$f.n" && mv "$f.n" "$f" || return 2
      echo "$i" >"$PA_S/t/$id.retired"
      v=$(cat "$PA_S/t/$id.path")
      printf 'retired %s' "$PEAL_TASKS/done/${v##*/}" >"$PA_S/res.$i.detail" ;;
  esac
}

# _pa_compose BASE CHECK -> every proposal not invalid applied, in order, to copies of
# BASE's task files under PA_S; the file proposals numbered from BASE (PEAL_CREATE_IDS).
# CHECK 1: a proposal that cannot apply is made invalid; 0: status 2 at the first.
_pa_compose() {
  local base=$1 check=$2 i first n=0 err
  PA_S=$PA_DIR/s
  rm -rf "$PA_S" && mkdir -p "$PA_S/t" || return 2
  : >"$PA_S/order"
  first=$(_peal_files_next_id "$base") || return 2
  PEAL_CREATE_IDS=()
  for ((i = 1; i <= PA_COUNT; i++)); do
    if ! _pa_ok "$i" || [ "$(_pa_val "$i" kind)" != file ]; then continue; fi
    PEAL_CREATE_IDS+=("$(printf '%04d' $((10#$first + n)))")
    printf '%s\n' "${PEAL_CREATE_IDS[n]}" >"$PA_S/new.$i"
    n=$((n + 1))
  done
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
  return 0
}

# _pa_check BASE -> the texts the compose made checked as the batch leaves them: each
# task's frontmatter (task-check.awk) and heading, no depends cycle the batch closes, no
# task retired while one not done still names it. A problem makes invalid the last
# proposal touching the task, or the depends or retire proposal it comes from.
_pa_check() {
  local base=$1 id i f context records changes after err label cycle members j ok
  context=$PA_DIR/context records=$PA_DIR/records changes=$PA_DIR/changes after=$PA_DIR/after err=$PA_DIR/err
  _peal_files_check_context "$base" >"$context" || return 2
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
      PEAL_CHECK_ID=$id PEAL_CHECK_OLDMS=$(peal_fm_get "$PA_S/t/$id.old" milestone 2>/dev/null) \
        peal_task_check "$f" revise "$label" "$context" >/dev/null 2>"$err" || _pa_bad "$i" "$(_pa_errs "$err")"
    fi
    _peal_cycle_row "$id" "$f" >>"$changes"
  done <"$PA_S/order"

  peal_store_list --no-pr >"$records" 2>/dev/null || return 2
  # The records as the batch leaves them: the changed rows in place, the new ones added,
  # the retired ones done.
  awk -F '\t' -v OFS='\t' -v dir="$PA_S/t" '
    FILENAME == ARGV[1] { if ($1 != "") { m[$1] = $2; d[$1] = $3; p[$1] = $4; o[++n] = $1 }; next }
    FILENAME == ARGV[2] { if ($1 != "") gone[$1] = 1; next }
    $1 == "" { next }
    ($1 in gone) { $2 = "done" }
    ($1 in m) { $2 = "backlog"; $6 = m[$1]; $7 = d[$1]; $8 = p[$1]; hit[$1] = 1 }
    { print }
    END {
      for (i = 1; i <= n; i++)
        if (!(o[i] in hit)) print o[i], "backlog", "", "", "", m[o[i]], d[o[i]], p[o[i]], "", "", "", "", "", "", ""
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
    members=$(awk -F '\t' -v id="$id" '
      $2 != "done" && $1 != id && (index("," $7 ",", "," id ",") || $8 == id) {
        out = out (out == "" ? "" : ", ") $1 (index("," $7 ",", "," id ",") ? " (depends)" : " (part-of)") }
      END { printf "%s", out }' "$after")
    [ -z "$members" ] || _pa_bad "$i" "task $id is still named by $members; re-point those in the batch first"
  done
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
  [ ${#args[@]} -gt 0 ] || return 4
  peal_write_tree "$base" "${args[@]}" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT="docs(tasks): apply $PA_COUNT proposal$([ "$PA_COUNT" = 1 ] || echo s)"
  PEAL_BODY=$(for ((i = 1; i <= PA_COUNT; i++)); do
    why=$(_pa_val "$i" why | tr '\n\r\t' '   ')
    printf -- '- %s (%s %s): %s\n' "$(_pa_val "$i" id | tr '\n\r\t' '   ')" "$(_pa_val "$i" kind)" \
      "$(cat "$PA_S/res.$i.task" 2>/dev/null)" "${why:-no reason given}"
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
      [ -n "$2" ] || [ "$1" != "done" ] || { cat "$PA_S/res.$i.detail" >"$PA_DIR/r/$i.detail" 2>/dev/null; cp "$PA_S/res.$i.task" "$PA_DIR/r/$i.task" 2>/dev/null; }
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
