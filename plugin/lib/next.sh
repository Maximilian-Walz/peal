# shellcheck shell=bash
# /peal:next (docs/design.md, "Setting up a project"): what to adopt next, once
# /peal:setup has done the first stage. A pure core (peal_next_core) takes the facts
# already in hand (the storage's list records, the milestone lines, the config's stages
# and declined:) and the catalogue below, and prints one suggestion, up to three
# runners-up, or NONE; `peal next` gathers the facts and runs it, the SessionStart hint
# reuses the facts session_start already has.
#
# Catalogue, in the order they are offered (the stages of `peal init`, then review-task):
#   guardrails  not recorded, and a task done or a non-merge commit on main without [ID]
#   milestones  not recorded, and >=10 tasks done or >=8 open
#   belfry      not recorded, and >=5 tasks done
#   review-task a current milestone with no record holding it in milestone and
#               "milestone" in depends
# `tasks` is not in that loop: without it recorded nothing else can be, so it is the only
# thing ever suggested then.
#
# declined: {item: [DATE]} in .peal/config.yml blocks an item for 90 days from DATE (UTC
# civil dates), day 90 itself free again. An item outside the catalogue there warns and is
# skipped; a date that is not a real calendar date is refused, status 2, naming the item.

PEAL_NEXT_ITEMS="tasks guardrails milestones review-task belfry"

# _peal_next_valid_date DATE -> status 0 for a real calendar date, YYYY-MM-DD.
_peal_next_valid_date() {
  local s=$1 y m d dim=(31 28 31 30 31 30 31 31 30 31 30 31) days
  [[ "$s" =~ ^([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9])$ ]] || return 1
  y=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) d=$((10#${BASH_REMATCH[3]}))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] || return 1
  days=${dim[m - 1]}
  if [ "$m" -eq 2 ] && { [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; }; then
    days=29
  fi
  [ "$d" -ge 1 ] && [ "$d" -le "$days" ]
}

# _peal_next_days DATE -> days since 1970-01-01 for civil date DATE (already valid),
# Howard Hinnant's days_from_civil, plain integer arithmetic so every awk-free shell agrees.
_peal_next_days() {
  local y=$((10#${1:0:4})) m=$((10#${1:5:2})) d=$((10#${1:8:2})) era yoe doy doe
  [ "$m" -gt 2 ] || y=$((y - 1))
  era=$((y / 400))
  yoe=$((y - era * 400))
  if [ "$m" -gt 2 ]; then
    doy=$(((153 * (m - 3) + 2) / 5 + d - 1))
  else
    doy=$(((153 * (m + 9) + 2) / 5 + d - 1))
  fi
  doe=$((yoe * 365 + yoe / 4 - yoe / 100 + doy))
  echo $((era * 146097 + doe - 719468))
}

# _peal_next_declined -> the effective declined: as "item<TAB>date" lines, one of
# PEAL_NEXT_ITEMS each. An entry for something else warns (stderr) and is skipped; a
# malformed date refuses, status 2, naming the item. Reads $PEAL_CONFIG (peal_config_load
# already run), never the raw file.
_peal_next_declined() {
  local item date
  while IFS=$'\t' read -r item date; do
    [ -n "$item" ] || continue
    if [[ " $PEAL_NEXT_ITEMS " != *" $item "* ]]; then
      peal_err "next: declined.$item is not a next item, ignored"
      continue
    fi
    if ! _peal_next_valid_date "$date"; then
      peal_err "next: declined.$item: '$date' is not a date, YYYY-MM-DD"
      return 2
    fi
    printf '%s\t%s\n' "$item" "$date"
  done < <(printf '%s\n' "$PEAL_CONFIG" | awk -F '\t' '$1 ~ /^declined\./ { sub(/^declined\./, "", $1); print $1 "\t" $4 }')
}

# _peal_next_blocked ITEM DECLINED TODAY -> status 0 if ITEM is declined and fewer than 90
# days have passed since (day 90 itself is free again).
_peal_next_blocked() {
  local item=$1 declined=$2 today=$3 date since
  date=$(printf '%s\n' "$declined" | awk -F '\t' -v it="$item" '$1 == it { print $2; exit }')
  [ -n "$date" ] || return 1
  since=$(($(_peal_next_days "$today") - $(_peal_next_days "$date")))
  [ "$since" -lt 90 ]
}

# _peal_next_try ITEM -> the command that would take it up.
_peal_next_try() {
  case $1 in
    tasks) echo "/peal:setup" ;;
    guardrails) echo "/peal:setup guardrails" ;;
    milestones | review-task) echo "/peal:setup milestones" ;;
    belfry) echo "/peal:setup belfry" ;;
  esac
}

# peal_next_core RECORDS MILESTONES STAGES DECLINED UNTAGGED TODAY [ONLY [--all]]
#   RECORDS    peal_store_list's lines (id state ... milestone depends ...)
#   MILESTONES peal_store_milestones's lines (id title state order due name reason)
#   STAGES     the stages: setting, one per line
#   DECLINED   _peal_next_declined's lines
#   UNTAGGED   non-merge commits on main without [ID] (a local git log, counted once)
#   TODAY      YYYY-MM-DD
#   ONLY       an item: offer it regardless of the catalogue or a decline
#   --all      after ONLY (which may be empty): also print DECLINED item date lines
# Prints SUGGEST item try evidence, up to three ALSO item try evidence, or NONE; DECLINED
# lines last when asked. Evidence holds counts and ids only, never a task's own text.
peal_next_core() {
  local records=$1 milestones=$2 stages=$3 declined=$4 untagged=$5 today=$6 only=${7-} all=${8-}
  local done_n open_n current_id has_review item evidence picked="" also=0

  if [ -n "$only" ]; then
    if [[ " $PEAL_NEXT_ITEMS " != *" $only "* ]]; then
      peal_err "next: '$only' is not a next item; one of: $PEAL_NEXT_ITEMS"
      return 2
    fi
  elif ! printf '%s\n' "$stages" | grep -qx tasks; then
    echo "SUGGEST tasks $(_peal_next_try tasks)"
    return 0
  fi

  done_n=$(printf '%s\n' "$records" | awk -F '\t' '$1 != "" && $2 == "done" { n++ } END { print n + 0 }')
  open_n=$(printf '%s\n' "$records" | awk -F '\t' '$1 != "" && $2 != "done" { n++ } END { print n + 0 }')
  current_id=$(printf '%s\n' "$milestones" | awk -F '\t' '$3 == "current" { print $1; exit }')
  has_review=0
  if [ -n "$current_id" ]; then
    has_review=$(printf '%s\n' "$records" | awk -F '\t' -v id="$current_id" \
      '$6 == id && index("," $7 ",", ",milestone,") { print 1; exit }')
  fi

  _evidence() {
    case $1 in
      tasks) echo "" ;;
      guardrails) echo "$done_n done, $untagged untagged" ;;
      milestones) echo "$done_n done, $open_n open" ;;
      belfry) echo "$done_n done" ;;
      review-task) echo "$current_id current, no review task" ;;
    esac
  }
  _qualifies() {
    case $1 in
      guardrails) ! printf '%s\n' "$stages" | grep -qx guardrails && { [ "$done_n" -ge 1 ] || [ "$untagged" -ge 1 ]; } ;;
      milestones) ! printf '%s\n' "$stages" | grep -qx milestones && { [ "$done_n" -ge 10 ] || [ "$open_n" -ge 8 ]; } ;;
      belfry) ! printf '%s\n' "$stages" | grep -qx belfry && [ "$done_n" -ge 5 ] ;;
      review-task) [ -n "$current_id" ] && [ "$has_review" != 1 ] ;;
    esac
  }

  if [ -n "$only" ]; then
    evidence=$(_evidence "$only")
    printf 'SUGGEST %s %s%s\n' "$only" "$(_peal_next_try "$only")" "${evidence:+ $evidence}"
  else
    for item in guardrails milestones belfry review-task; do
      _qualifies "$item" || continue
      _peal_next_blocked "$item" "$declined" "$today" && continue
      evidence=$(_evidence "$item")
      if [ -z "$picked" ]; then
        picked=$item
        printf 'SUGGEST %s %s%s\n' "$item" "$(_peal_next_try "$item")" "${evidence:+ $evidence}"
      elif [ "$also" -lt 3 ]; then
        printf 'ALSO %s %s%s\n' "$item" "$(_peal_next_try "$item")" "${evidence:+ $evidence}"
        also=$((also + 1))
      fi
    done
    [ -n "$picked" ] || echo NONE
  fi

  if [ -n "$all" ]; then
    printf '%s\n' "$declined" | awk -F '\t' '$1 != "" { printf "DECLINED %s %s\n", $1, $2 }'
  fi
}

# _peal_next_untagged -> non-merge commits on the configured main not ending [NNNN], from
# one local `git log -n 200 --first-parent`; no fetch.
_peal_next_untagged() {
  local main n
  main=$(peal_config_get main) || main=main
  n=$(git log -n 200 --first-parent --no-merges --format=%s "$main" 2>/dev/null | grep -vc -E '\[[0-9]+\] *$')
  printf '%s\n' "${n:-0}"
}

# peal_next_hint RECORDS MILESTONES -> the SessionStart hint line ("Next to adopt: ..."),
# reusing RECORDS and MILESTONES session_start already gathered (no second list, no
# fetch, no gh) plus one local git log for guardrails' evidence. Nothing (status 0) for
# NONE, an item currently declined, or any problem (a malformed declined date included),
# so the hook is never held up by this; shown even without stages: recorded.
peal_next_hint() {
  local records=$1 milestones=$2 stages declined today untagged line item try prefix evidence
  stages=$(peal_config_get stages 2>/dev/null) || return 0
  declined=$(_peal_next_declined 2>/dev/null) || return 0
  today=${PEAL_TODAY:-$(date -u +%Y-%m-%d)}
  untagged=$(_peal_next_untagged 2>/dev/null)
  line=$(peal_next_core "$records" "$milestones" "$stages" "$declined" "$untagged" "$today" 2>/dev/null | head -n 1)
  case $line in
    "SUGGEST "*) ;;
    *) return 0 ;;
  esac
  item=$(printf '%s\n' "$line" | awk '{ print $2 }')
  try=$(_peal_next_try "$item")
  prefix="SUGGEST $item $try"
  evidence=${line#"$prefix"}
  evidence=${evidence# }
  if [ -n "$evidence" ]; then
    printf 'Next to adopt: %s, %s. For the human: /peal:next says more; nothing changes unasked.\n' "$item" "$evidence"
  else
    printf 'Next to adopt: %s. For the human: /peal:next says more; nothing changes unasked.\n' "$item"
  fi
}

# peal_next [--all | ITEM] -> peal_next_core on the facts gathered here: the list
# (--no-pr), the milestones, the config's stages and declined:, and, once the tasks stage
# is recorded, one local git log for guardrails' evidence.
peal_next() {
  local only="" all="" arg
  for arg in "$@"; do
    case $arg in
      --all) [ -z "$only$all" ] || { peal_err "next: --all or an item, not both"; return 2; } ; all=1 ;;
      -*) peal_err "next: unknown argument $arg"; return 2 ;;
      *) [ -z "$only$all" ] || { peal_err "next: --all or an item, not both"; return 2; }; only=$arg ;;
    esac
  done
  local stages declined today records milestones untagged
  stages=$(peal_config_get stages) || stages=""
  today=${PEAL_TODAY:-$(date -u +%Y-%m-%d)}
  if [ -z "$only" ] && ! printf '%s\n' "$stages" | grep -qx tasks; then
    echo "SUGGEST tasks $(_peal_next_try tasks)"
    return 0
  fi
  declined=$(_peal_next_declined) || return 2
  records=$(peal_store_list --no-pr 2>/dev/null)
  milestones=$(peal_store_milestones 2>/dev/null)
  untagged=$(_peal_next_untagged)
  peal_next_core "$records" "$milestones" "$stages" "$declined" "$untagged" "$today" "$only" "$all"
}

# peal_next_decline ITEM -> declined.ITEM set to today in .peal/config.yml, every other
# entry kept as it was; a repeat refreshes the date, never a second entry. Refused (status
# 2) for an item that is not one of PEAL_NEXT_ITEMS, or without .peal/config.yml yet.
peal_next_decline() {
  local item=${1-}
  if [[ " $PEAL_NEXT_ITEMS " != *" $item "* ]]; then
    peal_err "next: '$item' is not a next item; one of: $PEAL_NEXT_ITEMS"
    return 2
  fi
  [ -f "$PEAL_CONFIG_FILE" ] || { peal_err "next: no $PEAL_CONFIG_FILE yet; /peal:setup first"; return 2; }
  local today=${PEAL_TODAY:-$(date -u +%Y-%m-%d)} merged tmp status
  merged=$(
    {
      printf '%s\n' "$PEAL_CONFIG" | awk -F '\t' '$1 ~ /^declined\./ { sub(/^declined\./, "", $1); print $1 "\t" $4 }'
      printf '%s\t%s\n' "$item" "$today"
    } | awk -F '\t' -v order="$PEAL_NEXT_ITEMS" '
      { date[$1] = $2 }
      END {
        n = split(order, items, " ")
        for (i = 1; i <= n; i++) if (items[i] in date) print items[i] "\t" date[items[i]]
      }'
  )
  tmp=$(mktemp) || return 2
  {
    echo "declined:"
    printf '%s\n' "$merged" | awk -F '\t' '{ printf "  %s: [%s]\n", $1, $2 }'
  } >"$tmp"
  _peal_init_block declined "$tmp"
  status=$?
  rm -f "$tmp"
  [ $status -eq 0 ] || return 2
  echo "declined $item: $today"
}
