# shellcheck shell=bash
# Migrating an existing task-file process into Peal's (docs/migrating.md):
# converting a project's own task headers and milestone docs into Peal's frontmatter, in
# place, changing nothing else. Neither converter commits; both are safe to run again, since a file already in frontmatter is left alone.

# _peal_migrate_valid_pools LIST -> status 0 if every comma-separated pool name in LIST
# is safe to use as a milestone id and a file name (letters, digits, '.', '_' and '-',
# starting with a letter or digit, the same shape milestone-read.awk requires of an id);
# refused otherwise, naming the bad one, so a hostile pool name is never used to build a
# path (lib/migrate.sh writes <pool>.md straight under the milestones directory).
_peal_migrate_valid_pools() {
  local pool
  for pool in ${1//,/ }; do
    [[ "$pool" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { peal_refuse "pool name" "$pool"; return 2; }
  done
}

# _peal_migrate_pool_args VERB ARGS... -> PEAL_MIGRATE_PARKED, PEAL_MIGRATE_OPEN and,
# for headers only when has_none=1, PEAL_MIGRATE_NONE, each a comma list (possibly
# empty); status 2 on an unknown argument, a flag without a value, or a pool name that is
# not a safe milestone id.
_peal_migrate_pool_args() {
  local verb=$1 has_none=$2
  shift 2
  PEAL_MIGRATE_PARKED="" PEAL_MIGRATE_OPEN="" PEAL_MIGRATE_NONE=""
  while [ $# -gt 0 ]; do
    case $1 in
      --parked) [ $# -ge 2 ] || { peal_err "migrate $verb: --parked needs a pool list"; return 2; }; PEAL_MIGRATE_PARKED=$2; shift ;;
      --open) [ $# -ge 2 ] || { peal_err "migrate $verb: --open needs a pool list"; return 2; }; PEAL_MIGRATE_OPEN=$2; shift ;;
      --none)
        [ "$has_none" = 1 ] || { peal_err "migrate $verb: unknown argument $1"; return 2; }
        [ $# -ge 2 ] || { peal_err "migrate $verb: --none needs a pool list"; return 2; }
        PEAL_MIGRATE_NONE=$2; shift ;;
      *) peal_err "migrate $verb: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  _peal_migrate_valid_pools "$PEAL_MIGRATE_PARKED" || return 2
  _peal_migrate_valid_pools "$PEAL_MIGRATE_OPEN" || return 2
  _peal_migrate_valid_pools "$PEAL_MIGRATE_NONE" || return 2
}

# peal_migrate_headers [--parked P,...] [--open P,...] [--none P,...] -> every task file
# under the tasks directories with a reference-style header rewritten into frontmatter; a
# file already in frontmatter (first line ---) is left alone, so a second run is a no-op.
# A non-numbered file (TEMPLATE.md, ...) is skipped silently. A file the header cannot
# convert is left entirely untouched, named on stderr with why. Status 1 if any file was
# reported, 0 otherwise; 2 for a bad argument. Never commits.
peal_migrate_headers() {
  _peal_migrate_pool_args headers 1 "$@" || return 2
  local top tasksdir dir file rel base first tmp out bad=0
  peal_config_load || return 2
  top=$(peal_project_root) || return 2
  tasksdir=$(peal_config_get tasks) || return 2
  [ -d "$top/$tasksdir" ] || return 0
  for dir in backlog doing "done"; do
    [ -d "$top/$tasksdir/$dir" ] || continue
    for file in "$top/$tasksdir/$dir"/*.md; do
      [ -f "$file" ] || continue
      base=$(basename "$file")
      [[ "$base" =~ ^[0-9][0-9][0-9][0-9]-.+\.md$ ]] || continue
      rel=${file#"$top"/}
      IFS= read -r first <"$file" 2>/dev/null || first=""
      [ "$first" = "---" ] && continue
      tmp=$(mktemp "$top/$tasksdir/.migrate.XXXXXX") || return 2
      if out=$(awk -v name="$rel" -v parked="$PEAL_MIGRATE_PARKED" -v open="$PEAL_MIGRATE_OPEN" \
          -v none="$PEAL_MIGRATE_NONE" -f "$PEAL_ROOT/lib/yaml-render.awk" \
          -f "$PEAL_ROOT/lib/migrate-headers.awk" "$file" 2>"$tmp.err"); then
        printf '%s\n' "$out" >"$tmp"
        if peal_fm_check "$tmp" >/dev/null 2>"$tmp.err2"; then
          chmod "$(stat -c %a "$file" 2>/dev/null || stat -f %Lp "$file")" "$tmp" 2>/dev/null
          mv "$tmp" "$file"
        else
          peal_err "$rel: the converted frontmatter leaves Peal's YAML subset"
          cat "$tmp.err2" >&2
          rm -f "$tmp"
          bad=1
        fi
        rm -f "$tmp.err2"
      else
        cat "$tmp.err" >&2
        rm -f "$tmp"
        bad=1
      fi
      rm -f "$tmp.err"
    done
  done
  [ $bad -eq 0 ]
}

# _peal_migrate_pool_title POOL -> POOL with its first letter capitalised, for a pool
# file's one-line heading.
_peal_migrate_pool_title() {
  printf '%s' "$1" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }'
}

# peal_migrate_milestones [--parked P,...] [--open P,...] -> frontmatter added to every
# numbered milestone doc that has none (id from its file name's digits, state highest
# number current and the rest done, order the number), and a P.md made for every
# --parked or --open pool without a file already (state parked or open, a one-line "#
# Title" heading, no order, no reason). A doc without a number in its name, and a
# milestone id a task's frontmatter uses that has no milestone file, are reported on
# stderr; status 1 then. Refuses (status 2) to make a second current when one already
# exists, converting nothing. Safe to run again; never commits.
peal_migrate_milestones() {
  _peal_migrate_pool_args milestones 0 "$@" || return 2
  local top msdir tasksdir file base num first bad=0
  peal_config_load || return 2
  top=$(peal_project_root) || return 2
  msdir=$(peal_config_get milestones) || return 2
  mkdir -p "$top/$msdir" || { peal_err "migrate milestones: could not create $msdir"; return 2; }

  local files=() nums=() existing_current=""
  for file in "$top/$msdir"/*.md; do
    [ -f "$file" ] || continue
    IFS= read -r first <"$file" 2>/dev/null || first=""
    if [ "$first" = "---" ]; then
      if [ "$(peal_fm_get "$file" state 2>/dev/null)" = current ]; then
        existing_current=$file
      fi
      continue
    fi
    base=$(basename "$file" .md)
    if [[ "$base" =~ ([0-9]+)$ ]]; then
      files+=("$file")
      nums+=("${BASH_REMATCH[1]}")
    else
      peal_err "migrate milestones: $file: no number in the file name; not converted"
      bad=1
    fi
  done

  if [ ${#files[@]} -gt 0 ] && [ -n "$existing_current" ]; then
    peal_err "migrate milestones: refused: $existing_current is already current; converting the numbered docs would make another"
    return 2
  fi

  local i best=-1 bestnum=-1 n
  for i in "${!nums[@]}"; do
    n=$((10#${nums[$i]}))
    if [ "$n" -gt "$bestnum" ]; then bestnum=$n; best=$i; fi
  done
  for i in "${!files[@]}"; do
    file=${files[$i]}
    num=${nums[$i]}
    local state="done"
    [ "$i" -eq "$best" ] && state=current
    peal_fm_set "$file" id "m$num" || bad=1
    peal_fm_set "$file" state "$state" || bad=1
    peal_fm_set "$file" order "$((10#$num))" || bad=1
  done

  local pool state
  for pool in ${PEAL_MIGRATE_PARKED//,/ }; do
    file="$top/$msdir/$pool.md"
    [ -f "$file" ] || printf -- '---\nstate: parked\n---\n\n# %s\n' "$(_peal_migrate_pool_title "$pool")" >"$file"
  done
  for pool in ${PEAL_MIGRATE_OPEN//,/ }; do
    file="$top/$msdir/$pool.md"
    [ -f "$file" ] || printf -- '---\nstate: open\n---\n\n# %s\n' "$(_peal_migrate_pool_title "$pool")" >"$file"
  done

  # Every milestone id a task's frontmatter (already converted) names, checked against
  # every milestone file now on disk (including the ones this run just wrote).
  tasksdir=$(peal_config_get tasks) || return 2
  local known="," id d task rel used
  for file in "$top/$msdir"/*.md; do
    [ -f "$file" ] || continue
    IFS= read -r first <"$file" 2>/dev/null || first=""
    [ "$first" = "---" ] || continue
    id=$(peal_fm_get "$file" id 2>/dev/null) || id=$(basename "$file" .md)
    [ -n "$id" ] || id=$(basename "$file" .md)
    known="$known$id,"
  done
  if [ -d "$top/$tasksdir" ]; then
    for d in backlog doing "done"; do
      [ -d "$top/$tasksdir/$d" ] || continue
      for task in "$top/$tasksdir/$d"/*.md; do
        [ -f "$task" ] || continue
        IFS= read -r first <"$task" 2>/dev/null || first=""
        [ "$first" = "---" ] || continue
        used=$(peal_fm_get "$task" milestone 2>/dev/null) || used=""
        [ -n "$used" ] || continue
        case "$known" in
          *",$used,"*) ;;
          *)
            rel=${task#"$top"/}
            peal_err "migrate milestones: $rel: milestone $used has no milestone file"
            bad=1
            ;;
        esac
      done
    done
  fi

  [ $bad -eq 0 ]
}
