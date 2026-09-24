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


# peal_list [--fetch] [--no-pr] [--state STATE[,STATE...]] [ID...] -> "ID state slug
# detail" per task, by id; only those in one of the STATEs, and only the IDs, if given.
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
    { print $1, $2, $4 ($3 == "" ? "" : " " $3) }' <<<"$records"
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
