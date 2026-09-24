# shellcheck shell=bash
# What is the same for every storage: the checks on a task's text before it is filed,
# and the views on the store's list, `peal list`, `peal board` and `peal overview`.

PEAL_TASK_DELIMITER='-----NEXT TASK-----'

# peal_create_texts SLUG... -> the task texts on stdin, one per SLUG, separated by lines
# "-----NEXT TASK-----", as the files PEAL_CREATE_DIR/1..n (the caller removes the
# directory), PEAL_CREATE_SLUGS the slugs made of the SLUGs. Status 2, with every
# problem reported: a SLUG that makes no slug, a count that differs, an empty text, two
# identical texts.
peal_create_texts() {
  local count=$# i j slug status=0
  PEAL_CREATE_DIR=$(mktemp -d) || return 2
  PEAL_CREATE_SLUGS=()
  for i in "$@"; do
    slug=$(peal_slugify "$i") || status=2
    PEAL_CREATE_SLUGS+=("$slug")
  done
  awk -v dir="$PEAL_CREATE_DIR" -v delim="$PEAL_TASK_DELIMITER" '
    BEGIN { n = 1 }
    $0 == delim { close(dir "/" n); n++; next }
    { print > (dir "/" n) }
    END { print n > (dir "/count") }'
  if [ "$(cat "$PEAL_CREATE_DIR/count")" != "$count" ]; then
    peal_err "create: $count slug(s) but $(cat "$PEAL_CREATE_DIR/count") text(s) on stdin, separated by '$PEAL_TASK_DELIMITER'"
    status=2
  fi
  for ((i = 1; i <= count && status == 0; i++)); do
    [ -s "$PEAL_CREATE_DIR/$i" ] || { peal_err "create: the text for ${PEAL_CREATE_SLUGS[i - 1]} is empty"; status=2; }
    for ((j = 1; j < i; j++)); do
      if cmp -s "$PEAL_CREATE_DIR/$i" "$PEAL_CREATE_DIR/$j"; then
        peal_err "create: the texts for ${PEAL_CREATE_SLUGS[j - 1]} and ${PEAL_CREATE_SLUGS[i - 1]} are the same"
        status=2
      fi
    done
  done
  return $status
}

# peal_check_context -> task-check.awk's CONTEXT from the settings: the project's fields
# and the size tiers. The storage adds its milestones and task ids.
peal_check_context() {
  printf '%s\n' "$PEAL_CONFIG" | awk -F '\t' '
    index($1, "task.fields.") == 1 {
      f = substr($1, 13)
      if (!(f in seen)) { order[++n] = f; seen[f] = 1; values[f] = "" }
      if ($2 == "i") values[f] = values[f] (values[f] == "" ? "" : ",") $4
    }
    index($1, "sizes.") == 1 { print "size\t" substr($1, 7) }
    END { for (i = 1; i <= n; i++) print "field\t" order[i] "\t" values[order[i]] }'
}

# peal_task_check FILE MODE LABEL CONTEXT [PIECE PIECES] -> "milestone<TAB>plan<TAB>size" if
# the task text in FILE may be filed: the heading "# NNNN — Title" (the id for revise, in
# PEAL_CHECK_ID), a Raw section, and task-check.awk's checks on the frontmatter against
# CONTEXT (a file; ids and milestones checked only when it lists them, PEAL_CHECK_OFFLINE
# unset). Status 2 with every problem reported.
peal_task_check() {
  local file=$1 mode=$2 label=$3 context=$4 piece=${5:-1} pieces=${6:-1} records bad=0 online=1
  local id=${PEAL_CHECK_ID:-NNNN}
  [ -z "${PEAL_CHECK_OFFLINE-}" ] || online=0
  if ! peal_text_title "$id" <"$file" >/dev/null; then
    if [ "$id" = NNNN ]; then
      peal_err "$label: the first heading must be '# NNNN — Title', NNNN standing for the number to come"
    else
      peal_err "$label: the first heading must be '# $id — Title'"
    fi
    bad=1
  fi
  if ! peal_text_has_section Raw <"$file"; then
    peal_err "$label: no '## Raw' section: it keeps the human's own words"
    bad=1
  fi
  if ! records=$(awk -v mode=frontmatter -v name="$label" -f "$PEAL_ROOT/lib/yaml-lib.awk" \
      -f "$PEAL_ROOT/lib/yaml-parse.awk" "$file"); then
    return 2
  fi
  printf '%s\n' "$records" | awk -F '\t' -v mode="$mode" -v label="$label" -v piece="$piece" \
    -v pieces="$pieces" -v check_ids="$online" -v check_ms="$online" -v oldms="${PEAL_CHECK_OLDMS-}" \
    -f "$PEAL_ROOT/lib/task-check.awk" "$context" - || bad=1
  return $((bad * 2))
}


# A depends cycle leaves every task on it blocked for ever, so a text that would close one
# is refused (status 1, "refused: depends cycle 0042 → 0043 → 0042") where tasks are
# filed, revised and deferred. The graph is the read model's (task-state.awk), with the
# new texts in place: a cycle through a task the texts change or add, which that task
# was not on before, is one they close. A cycle there already is shown by list, board
# and check, and does not hold up a revise that leaves it as it is.

# peal_cycle_prefix -> what goes before a task's number where a cycle is shown: "#" for
# issues, nothing for task files.
peal_cycle_prefix() {
  [ "$(peal_config_get storage.kind 2>/dev/null)" != issues ] || printf '#'
}

# peal_cycles RECORDS -> task-state.awk's cycle lines ("id<TAB>members<TAB>cycle") for the
# store's list records in the file RECORDS: every task not done on a cycle.
peal_cycles() {
  awk -F '\t' -v OFS='\t' '$1 != "" {
      print $1, ($2 == "done" ? "done" : "backlog"), "-", $4, $5, $6, $7, $8, $9, $10, $11, $12, $15
    }' "$1" | _peal_cycles_of -
}

# _peal_cycles_of TASKS -> the cycle lines for task-state.awk's task records in TASKS.
_peal_cycles_of() {
  awk -F '\t' -v cycles=1 -v idprefix="$(peal_cycle_prefix)" \
    -f "$PEAL_ROOT/lib/task-state.awk" /dev/null "$1" 2>/dev/null
}

# peal_check_cycles -> a line on stderr per depends cycle among the tasks not done, and
# status 2 if there is one: for task files those of this work tree, for issues the
# storage's.
peal_check_cycles() {
  local tmp top tasks d status=0
  tmp=$(mktemp -d) || return 2
  if [ "$(peal_config_get storage.kind)" = files ]; then
    if ! top=$(peal_project_root) || ! tasks=$(peal_config_get tasks); then
      rm -rf "$tmp"
      return 2
    fi
    tasks=${tasks%/}
    for d in backlog doing "done"; do
      [ ! -d "$top/$tasks/$d" ] || find "$top/$tasks/$d" -maxdepth 1 -type f -name '*.md'
    done | LC_ALL=C sort >"$tmp/files"
    if [ -s "$tmp/files" ]; then
      tr '\n' '\0' <"$tmp/files" | xargs -0 awk -v root="$top" -v tasks="$tasks" \
        -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/task-scan.awk" 2>/dev/null \
        | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -s | _peal_cycles_of - >"$tmp/cycles"
    fi
  else
    if ! peal_store_load || ! peal_store_list --no-pr >"$tmp/records"; then
      rm -rf "$tmp"
      return 2
    fi
    peal_cycles "$tmp/records" >"$tmp/cycles"
  fi
  if [ -s "$tmp/cycles" ]; then
    awk -F '\t' '!seen[$2]++ { print "peal: depends cycle " $3 }' "$tmp/cycles" >&2
    status=2
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_cycle_row ID FILE [ORIGIN] -> "id<TAB>milestone<TAB>depends<TAB>part-of" for the
# task text in FILE as task ID, ORIGIN standing for ORIGIN and ID for NNNN.
_peal_cycle_row() {
  local id=$1 file=$2 origin=${3-}
  {
    printf 'milestone\t%s\n' "$(peal_fm_get "$file" milestone 2>/dev/null)"
    peal_fm_get "$file" depends 2>/dev/null | sed 's/^/depends\t/'
    printf 'part-of\t%s\n' "$(peal_fm_get "$file" part-of 2>/dev/null)"
  } | awk -F '\t' -v id="$id" -v origin="$origin" '
    function sub_(v) { return v == "ORIGIN" && origin != "" ? origin : v == "NNNN" ? id : v }
    $1 == "milestone" { m = $2 }
    $1 == "depends" && $2 != "" { d = d (d == "" ? "" : ",") sub_($2) }
    $1 == "part-of" { p = sub_($2) }
    END { printf "%s\t%s\t%s\t%s\n", id, m, d, p }'
}

# peal_cycle_check VERB RECORDS CHANGES -> status 1, with each cycle named, if the rows
# in the file CHANGES (_peal_cycle_row's; an id the RECORDS list replaces the task's
# fields, another is a task to come) close a depends cycle among the store's list
# records in the file RECORDS.
peal_cycle_check() {
  local verb=$1 records=$2 changes=$3 tmp refused
  tmp=$(mktemp -d) || return 2
  awk -F '\t' -v OFS='\t' '
    NR == FNR { if ($1 != "") { m[$1] = $2; d[$1] = $3; p[$1] = $4; o[++n] = $1 }; next }
    $1 == "" { next }
    ($1 in m) { $2 = "backlog"; $6 = m[$1]; $7 = d[$1]; $8 = p[$1]; hit[$1] = 1 }
    { print }
    END {
      for (i = 1; i <= n; i++)
        if (!(o[i] in hit)) print o[i], "backlog", "", "", "", m[o[i]], d[o[i]], p[o[i]], "", "", "", "", "", "", ""
    }' "$changes" "$records" >"$tmp/records"
  peal_cycles "$records" >"$tmp/before"
  peal_cycles "$tmp/records" >"$tmp/after"
  refused=$(awk -F '\t' '
    FILENAME == ARGV[1] { if ($1 != "") changed[$1] = 1; next }
    FILENAME == ARGV[2] { before[$1] = 1; next }
    ($1 in changed) && !($1 in before) && !seen[$2]++ { print $3 }' "$changes" "$tmp/before" "$tmp/after")
  rm -rf "$tmp"
  [ -n "$refused" ] || return 0
  printf '%s\n' "$refused" | while IFS= read -r cycle; do
    peal_err "$verb: refused: depends cycle $cycle"
  done
  peal_err "$verb: a task on a depends cycle waits for itself for ever; drop one of its depends"
  return 1
}

# _peal_cycle_records -> the store's list records; its warnings, which the caller's own
# reading has shown already, only when the listing fails.
_peal_cycle_records() {
  local err status=0
  err=$(mktemp) || return 2
  peal_store_list --no-pr 2>"$err" || { status=2; cat "$err" >&2; }
  rm -f "$err"
  return $status
}

# peal_cycle_check_text VERB ID FILE [RECORDS] -> peal_cycle_check for task ID's new text
# in FILE, against the store's list records RECORDS (a string), read when not given.
peal_cycle_check_text() {
  local verb=$1 id=$2 file=$3 tmp status=0
  tmp=$(mktemp -d) || return 2
  if [ $# -ge 4 ]; then
    printf '%s\n' "$4" >"$tmp/records"
  elif ! _peal_cycle_records >"$tmp/records"; then
    rm -rf "$tmp"
    return 2
  fi
  _peal_cycle_row "$id" "$file" >"$tmp/changes"
  peal_cycle_check "$verb" "$tmp/records" "$tmp/changes" || status=$?
  rm -rf "$tmp"
  return $status
}

# peal_cycle_check_create MODE ORIGIN COUNT DIR [RECORDS] -> peal_cycle_check for the
# texts DIR/1..COUNT peal_store_create is filing, as tasks NNNN (one plain text) or
# PART1..n, against the store's list records RECORDS (a string), read when not given.
peal_cycle_check_create() {
  local mode=$1 origin=$2 count=$3 dir=$4 tmp i id status=0
  tmp=$(mktemp -d) || return 2
  if [ $# -ge 5 ]; then
    printf '%s\n' "$5" >"$tmp/records"
  elif ! _peal_cycle_records >"$tmp/records"; then
    rm -rf "$tmp"
    return 2
  fi
  [ "$mode" = split ] || origin=""
  for ((i = 1; i <= count; i++)); do
    id=PART$i
    [ "$mode" != plain ] || id=NNNN
    _peal_cycle_row "$id" "$dir/$i" "$origin"
  done >"$tmp/changes"
  peal_cycle_check create "$tmp/records" "$tmp/changes" || status=$?
  rm -rf "$tmp"
  return $status
}

# peal_list [--fetch] [--no-pr] [--state STATE[,STATE...]] [ID...] -> "ID state slug
# detail" per task, by id, the detail ending in "priority:<p>" for a task not done whose
# priority is not normal; only those in one of the STATEs, and only the IDs, if given.
peal_list() {
  local states="" ids="" args=() records
  while [ $# -gt 0 ]; do
    case $1 in
      --fetch | --no-pr) args+=("$1") ;;
      --state)
        [ $# -ge 2 ] || { peal_err "list: --state needs states"; return 2; }
        states=$2
        shift ;;
      [0-9]*) [[ "$1" =~ ^[0-9]+$ ]] || { peal_err "list: '$1' is no task id"; return 2; }; ids="$ids,$1" ;;
      *) peal_err "list: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  # Only a task awaiting merge has a pull request to ask gh for.
  if [ -n "$states" ] && [[ ",$states," != *,awaiting-merge,* ]]; then args+=(--no-pr); fi
  records=$(peal_store_list ${args[@]+"${args[@]}"}) || return 2
  [ -n "$records" ] || return 0
  awk -F '\t' -v states=",$states," -v ids="$ids," '
    states != ",," && !index(states, "," $2 ",") { next }
    ids != "," && !index(ids, "," $1 ",") { next }
    { print $1, $2, $4 ($3 == "" ? "" : " " $3) ($16 == "" || $2 == "done" ? "" : " priority:" $16) }' <<<"$records"
}

# peal_board [--fetch] [--no-pr] -> the board: a JSON line per task (lib/board.awk), then
# a {"milestone":{...}} line per milestone.
peal_board() {
  local records milestones
  records=$(peal_store_list "$@") || return 2
  milestones=$(peal_store_milestones) || return 2
  [ -z "$records" ] || awk -F '\t' -f "$PEAL_ROOT/lib/json.awk" -f "$PEAL_ROOT/lib/board.awk" <<<"$records"
  [ -z "$milestones" ] || awk -F '\t' -f "$PEAL_ROOT/lib/json.awk" -f "$PEAL_ROOT/lib/milestone-json.awk" <<<"$milestones"
}

# peal_overview [--fetch] -> the tasks not done, grouped by milestone (lib/overview.awk).
peal_overview() {
  local records milestones
  records=$(peal_store_list --no-pr "$@") || return 2
  milestones=$(peal_store_milestones) || return 2
  if [ -z "$(awk -F '\t' '$2 != "done"' <<<"$records")" ]; then
    echo "No open tasks."
    return 0
  fi
  awk -F '\t' -f "$PEAL_ROOT/lib/overview.awk" <(printf '%s\n' "$milestones") <(printf '%s\n' "$records")
}

# peal_edit_check VERB OLD NEW LABEL -> the checks every rewrite of a task's text makes,
# OLD the text before and NEW the one after (files): the Raw section unchanged, and not
# added or dropped (the human's own words, never rewritten); the Outcome heading neither
# added nor dropped, and empty on both sides (a filled one means work happened); part-of
# unchanged (only a split writes it). Status 2 with every problem reported.
peal_edit_check() {
  local verb=$1 old=$2 new=$3 label=$4 status=0
  if [ "$(peal_text_has_section Raw <"$old"; echo $?)" != "$(peal_text_has_section Raw <"$new"; echo $?)" ] \
      || [ "$(peal_text_section Raw <"$old")" != "$(peal_text_section Raw <"$new")" ]; then
    peal_err "$verb: the Raw section changed: it holds the human's own words, never rewritten"
    status=2
  fi
  if [ "$(peal_text_has_section Outcome <"$old"; echo $?)" != "$(peal_text_has_section Outcome <"$new"; echo $?)" ]; then
    peal_err "$verb: the Outcome heading was added or dropped"
    status=2
  fi
  if peal_text_outcome_filled <"$old"; then
    peal_err "$verb: $label's Outcome is filled in: work happened, this is no plain backlog task"
    status=2
  elif peal_text_outcome_filled <"$new"; then
    peal_err "$verb: the new text fills in the Outcome: a task with an Outcome ends through its close"
    status=2
  fi
  if [ "$(peal_fm_get "$old" part-of 2>/dev/null)" != "$(peal_fm_get "$new" part-of 2>/dev/null)" ]; then
    peal_err "$verb: part-of changed: only a split writes it"
    status=2
  fi
  return $status
}
