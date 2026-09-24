# shellcheck shell=bash
# Milestones as data: one Markdown file per milestone in the milestones directory
# (setting `milestones`), its data as frontmatter (lib/milestone-read.awk), and the rules
# the offer and the claim follow for a task's milestone state.

# peal_ms_load [ROOT] -> fills PEAL_MILESTONES with one "id<TAB>title<TAB>state<TAB>order<TAB>
# due<TAB>file" line per milestone, by order (those without one last), then id. Every
# problem found is reported, not only the first: status 2 then. A missing directory
# holds no milestones. ROOT is where the milestones directory is looked for, by default
# the work tree's top; the storage passes a copy of the main branch's.
peal_ms_load() {
  local top=${1-} dir file rel base records line lines="" bad=0
  PEAL_MILESTONES=""
  peal_config_load || return 2
  [ -n "$top" ] || top=$(peal_project_root) || return 2
  dir=$(peal_config_get milestones) || return 2
  [ -d "$top/$dir" ] || return 0
  for file in "$top/$dir"/*.md; do
    [ -f "$file" ] || continue
    rel=${file#"$top"/}
    base=$(basename "$file" .md)
    if ! records=$(awk -v mode=frontmatter -v name="$rel" -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/yaml-parse.awk" "$file"); then
      bad=1
      continue
    fi
    if line=$(printf '%s\n' "$records" | awk -F '\t' -v name="$rel" -v base="$base" \
        -f "$PEAL_ROOT/lib/milestone-read.awk" - "$file"); then
      lines="$lines$line"$'\n'
    else
      bad=1
    fi
  done
  printf '%s' "$lines" | awk -F '\t' '
    { if ($1 in file) {
        printf "peal: %s: milestone id %s is taken by %s\n", $6, $1, file[$1] > "/dev/stderr"
        bad = 1
      } else file[$1] = $6
      if ($3 == "current") { currents = currents (n++ ? ", " : "") $6 } }
    END {
      if (n > 1) printf "peal: more than one current milestone: %s\n", currents > "/dev/stderr"
      exit ((bad || n > 1) ? 2 : 0) }' || bad=1
  [ $bad -eq 0 ] || return 2
  PEAL_MILESTONES=$(printf '%s' "$lines" \
    | awk -F '\t' '{ printf "%d\t%s\t%s\n", ($4 == "" ? 1 : 0), ($4 == "" ? 0 : $4), $0 }' \
    | LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3 | cut -f3-)
}

# peal_ms_print -> "id state order due title" per milestone, "-" for an empty field.
peal_ms_print() {
  [ -n "$PEAL_MILESTONES" ] || return 0
  printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' '
    function f(v) { return v == "" ? "-" : v }
    { print $1, $3, f($4), f($5), f($2) }'
}

# peal_ms_json -> the board's milestone lines (lib/milestone-json.awk).
peal_ms_json() {
  [ -n "$PEAL_MILESTONES" ] || return 0
  printf '%s\n' "$PEAL_MILESTONES" \
    | awk -F '\t' -f "$PEAL_ROOT/lib/json.awk" -f "$PEAL_ROOT/lib/milestone-json.awk"
}

# peal_ms_state ID -> the state of milestone ID; status 1 if there is none.
peal_ms_state() {
  printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' -v id="$1" '
    $1 == id && id != "" { print $3; found = 1; exit }
    END { exit !found }'
}

# peal_ms_current -> the current milestone's id; status 1 if none is current.
peal_ms_current() {
  printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' '
    $3 == "current" { print $1; found = 1; exit }
    END { exit !found }'
}

# The rules, by a task's milestone state ("" for a task without a milestone):
#
#   state     bare offer      claimable
#   current   yes, first      yes
#   ""        yes, second     yes
#   open      no              yes
#   parked    no              no
#   done      no              no

# peal_ms_offer_rank STATE -> where a bare offer puts a task of that state: 1 for
# current, 2 for no milestone; status 1 for a state a bare offer leaves out.
peal_ms_offer_rank() {
  case $1 in
    current) echo 1 ;;
    "") echo 2 ;;
    *) return 1 ;;
  esac
}

# peal_ms_claimable STATE -> status 0 if a task of that state may be claimed by number.
peal_ms_claimable() {
  case $1 in
    current | open | "") return 0 ;;
    *) return 1 ;;
  esac
}
