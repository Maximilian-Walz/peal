# shellcheck shell=bash
# /peal:next (docs/design.md, "Setting up a project"): what to adopt next, once
# /peal:setup has done the first stage. A pure core (peal_next_core) takes the facts
# already in hand (the storage's list records, the milestone lines, the config's stages
# and declined:) and the catalogue below, and prints one suggestion, up to three
# runners-up, or NONE; `peal next` gathers the facts and runs it, the SessionStart hint
# reuses the facts session_start already has.
#
# Catalogue, in the order they are offered (the stages of `peal init`, then review-task,
# then the features within the stages):
#   guardrails   not recorded, and a task done or a non-merge commit on main without [ID]
#   milestones   not recorded, and >=10 tasks done or >=8 open
#   belfry       not recorded, and >=5 tasks done
#   review-task  a current milestone with no record holding it in milestone and
#                "milestone" in depends
#   decisions    the module off, and an ADR-like directory (docs/adr, docs/decisions,
#                doc/adr) or >=20 tasks done
#   drift        no .peal/drift.md, and (context: set, or other Markdown under docs/) and
#                >=10 tasks done
#   releases     no local tag under release.tag-prefix reachable from local main, and
#                >=5 tasks done
#   reviewer     no .peal/reviewer.md, and (context: empty with design-like docs) or
#                (CI files with checks.commit and checks.close both empty)
#   review-steps the milestones stage recorded, a milestone done, and no .peal/review.md
# `tasks` is not in that loop: without it recorded nothing else can be, so it is the only
# thing ever suggested then.
#
# Every check is cheap: local files already in the work tree and one local git log or
# tag list, no `gh` and no fetch, because the SessionStart hint runs it on every startup.
#
# declined: {item: [DATE]} in .peal/config.yml blocks an item for 90 days from DATE (UTC
# civil dates), day 90 itself free again. An item outside the catalogue there warns and is
# skipped; a date that is not a real calendar date is refused, status 2, naming the item.

PEAL_NEXT_ITEMS="tasks guardrails milestones review-task belfry decisions drift releases reviewer review-steps"

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

# _peal_next_try ITEM [FEATURES] -> the command, or the config line, that would take it
# up; decisions names the ADR-like directory FEATURES found, else docs/decisions.
_peal_next_try() {
  local item=$1 features=${2-} adr
  case $item in
    tasks) echo "/peal:setup" ;;
    guardrails) echo "/peal:setup guardrails" ;;
    milestones | review-task) echo "/peal:setup milestones" ;;
    belfry) echo "/peal:setup belfry" ;;
    decisions)
      adr=$(_peal_next_feat "$features" adr)
      echo "decisions: ${adr:-docs/decisions}"
      ;;
    drift) echo "/peal:drift" ;;
    releases) echo "/peal:release" ;;
    reviewer) echo ".peal/reviewer.md" ;;
    review-steps) echo ".peal/review.md" ;;
  esac
}

# _peal_next_feat FEATURES KEY -> KEY's value from FEATURES ("key<TAB>value" lines, one
# of _peal_next_features' facts); empty when it is not there.
_peal_next_feat() {
  printf '%s\n' "$1" | awk -F '\t' -v k="$2" '$1 == k { print $2; exit }'
}

# _peal_next_adr_dir -> the first of docs/adr, docs/decisions, doc/adr that is a
# directory here; empty for none.
_peal_next_adr_dir() {
  local d
  for d in docs/adr docs/decisions doc/adr; do
    [ -d "$d" ] && { printf '%s\n' "$d"; return; }
  done
}

# _peal_next_design_docs -> design*.md or architecture*.md (case-insensitive) at the top
# or in docs/, and docs/architecture/ itself when it is a directory, comma-joined.
_peal_next_design_docs() {
  local dir f base lower found=""
  for dir in . docs; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
      case $lower in
        design*.md | architecture*.md) found="${found:+$found,}${f#./}" ;;
      esac
    done
  done
  [ -d docs/architecture ] && found="${found:+$found,}docs/architecture"
  printf '%s\n' "$found"
}

# _peal_next_ci_files -> the CI configuration files peal_init_survey looks for
# (init.sh), that exist here, comma-joined: a project with a build already running has
# one less thing to explain to the reviewer.
_peal_next_ci_files() {
  local f found=""
  for f in .github/workflows/*.yml .github/workflows/*.yaml .gitlab-ci.yml .circleci/config.yml \
      .travis.yml Jenkinsfile azure-pipelines.yml .woodpecker.yml bitbucket-pipelines.yml; do
    [ -f "$f" ] && found="${found:+$found,}$f"
  done
  printf '%s\n' "$found"
}

# _peal_next_docs_md -> Markdown files under docs/, outside the configured milestones,
# tasks and decisions directories.
_peal_next_docs_md() {
  local milestones tasks decisions
  milestones=$(peal_config_get milestones 2>/dev/null) || milestones=""
  tasks=$(peal_config_get tasks 2>/dev/null) || tasks=""
  decisions=$(peal_decisions_dir 2>/dev/null) || decisions=""
  [ -d docs ] || { echo 0; return; }
  find docs -type f -iname '*.md' 2>/dev/null | awk -F '\t' \
    -v m="${milestones%/}/" -v t="${tasks%/}/" -v d="${decisions:+${decisions%/}/}" '
    index($0, m) != 1 && index($0, t) != 1 && (d == "" || index($0, d) != 1) { n++ }
    END { print n + 0 }'
}

# _peal_next_version_file -> the first of package.json, .claude-plugin/plugin.json at the
# repository's root that exists; empty for none (release.version-files takes only
# top-level fields, so a TOML manifest is never suggested).
_peal_next_version_file() {
  local f
  for f in package.json .claude-plugin/plugin.json; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return; }
  done
}

# _peal_next_release_tag -> a local tag under release.tag-prefix reachable from local
# main, if any; no fetch.
_peal_next_release_tag() {
  local main prefix
  main=$(peal_config_get main 2>/dev/null) || main=main
  prefix=$(peal_config_get release.tag-prefix 2>/dev/null) || prefix=v
  git rev-parse -q --verify "refs/heads/$main" >/dev/null 2>&1 || return 0
  git tag -l --merged "$main" "${prefix}*" 2>/dev/null | head -n 1
}

# _peal_next_features -> "key<TAB>value" lines, the local facts the reviewer, decisions,
# drift, releases and review-steps items check; empty (not an error) outside a work tree.
# Everything here is a file already in the work tree or one local git call: no gh, no
# fetch, so the SessionStart hint pays nothing extra for it.
_peal_next_features() {
  local top context close commit
  top=$(peal_project_root 2>/dev/null) || return 0
  (
    cd "$top" || exit 0
    context=$(peal_config_get context 2>/dev/null) || context=""
    close=$(peal_config_get checks.close 2>/dev/null) || close=""
    commit=$(peal_config_get checks.commit 2>/dev/null) || commit=""
    printf 'adr\t%s\n' "$(_peal_next_adr_dir)"
    if peal_decisions_dir >/dev/null 2>&1; then printf 'decisions_on\t1\n'; else printf 'decisions_on\t0\n'; fi
    printf 'drift_md\t%s\n' "$([ -f .peal/drift.md ] && echo 1 || echo 0)"
    printf 'reviewer_md\t%s\n' "$([ -f .peal/reviewer.md ] && echo 1 || echo 0)"
    printf 'review_md\t%s\n' "$([ -f .peal/review.md ] && echo 1 || echo 0)"
    printf 'docs_md\t%s\n' "$(_peal_next_docs_md)"
    printf 'design\t%s\n' "$(_peal_next_design_docs)"
    printf 'ci\t%s\n' "$(_peal_next_ci_files)"
    printf 'version_file\t%s\n' "$(_peal_next_version_file)"
    printf 'release_tag\t%s\n' "$(_peal_next_release_tag)"
    printf 'context_set\t%s\n' "$([ -n "$context" ] && echo 1 || echo 0)"
    printf 'checks_empty\t%s\n' "$([ -z "$close$commit" ] && echo 1 || echo 0)"
  )
}

# peal_next_core RECORDS MILESTONES STAGES DECLINED UNTAGGED TODAY FEATURES [ONLY [--all]]
#   RECORDS    peal_store_list's lines (id state ... milestone depends ...)
#   MILESTONES peal_store_milestones's lines (id title state order due name reason)
#   STAGES     the stages: setting, one per line
#   DECLINED   _peal_next_declined's lines
#   UNTAGGED   non-merge commits on main without [ID] (a local git log, counted once)
#   TODAY      YYYY-MM-DD
#   FEATURES   _peal_next_features' lines
#   ONLY       an item: offer it regardless of the catalogue or a decline
#   --all      after ONLY (which may be empty): also print DECLINED item date lines
# Prints SUGGEST item try evidence, up to three ALSO item try evidence, or NONE; DECLINED
# lines last when asked. Evidence holds counts and ids only, never a task's own text.
peal_next_core() {
  local records=$1 milestones=$2 stages=$3 declined=$4 untagged=$5 today=$6 features=$7
  local only=${8-} all=${9-}
  local done_n open_n current_id has_review item evidence picked="" also=0
  local adr decisions_on drift_md reviewer_md review_md docs_md design ci version_file
  local release_tag context_set checks_empty has_done_milestone

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
  adr=$(_peal_next_feat "$features" adr)
  decisions_on=$(_peal_next_feat "$features" decisions_on)
  drift_md=$(_peal_next_feat "$features" drift_md)
  reviewer_md=$(_peal_next_feat "$features" reviewer_md)
  review_md=$(_peal_next_feat "$features" review_md)
  docs_md=$(_peal_next_feat "$features" docs_md); docs_md=${docs_md:-0}
  design=$(_peal_next_feat "$features" design)
  ci=$(_peal_next_feat "$features" ci)
  version_file=$(_peal_next_feat "$features" version_file)
  release_tag=$(_peal_next_feat "$features" release_tag)
  context_set=$(_peal_next_feat "$features" context_set)
  checks_empty=$(_peal_next_feat "$features" checks_empty)
  has_done_milestone=$(printf '%s\n' "$milestones" | awk -F '\t' '$3 == "done" { print 1; exit }')

  _evidence() {
    case $1 in
      tasks) echo "" ;;
      guardrails) echo "$done_n done, $untagged untagged" ;;
      milestones) echo "$done_n done, $open_n open" ;;
      belfry) echo "$done_n done" ;;
      review-task) echo "$current_id current, no review task" ;;
      decisions) if [ -n "$adr" ]; then echo "$adr found"; else echo "$done_n done"; fi ;;
      drift) if [ "$context_set" = 1 ]; then echo "$done_n done, context set"; else echo "$done_n done, $docs_md docs"; fi ;;
      releases) if [ -n "$version_file" ]; then echo "$done_n done, $version_file"; else echo "$done_n done"; fi ;;
      reviewer)
        if [ "$context_set" != 1 ] && [ -n "$design" ]; then echo "$design, no context"
        else echo "$ci, no checks"
        fi
        ;;
      review-steps)
        printf '%s\n' "$milestones" | awk -F '\t' '$3 == "done" { print $1 " done"; exit }'
        ;;
    esac
  }
  _qualifies() {
    case $1 in
      guardrails) ! printf '%s\n' "$stages" | grep -qx guardrails && { [ "$done_n" -ge 1 ] || [ "$untagged" -ge 1 ]; } ;;
      milestones) ! printf '%s\n' "$stages" | grep -qx milestones && { [ "$done_n" -ge 10 ] || [ "$open_n" -ge 8 ]; } ;;
      belfry) ! printf '%s\n' "$stages" | grep -qx belfry && [ "$done_n" -ge 5 ] ;;
      review-task) [ -n "$current_id" ] && [ "$has_review" != 1 ] ;;
      decisions) [ "$decisions_on" != 1 ] && { [ -n "$adr" ] || [ "$done_n" -ge 20 ]; } ;;
      drift) [ "$drift_md" != 1 ] && { [ "$context_set" = 1 ] || [ "$docs_md" -gt 0 ]; } && [ "$done_n" -ge 10 ] ;;
      releases) [ -z "$release_tag" ] && [ "$done_n" -ge 5 ] ;;
      reviewer)
        [ "$reviewer_md" != 1 ] \
          && { { [ "$context_set" != 1 ] && [ -n "$design" ]; } || { [ -n "$ci" ] && [ "$checks_empty" = 1 ]; }; }
        ;;
      review-steps)
        printf '%s\n' "$stages" | grep -qx milestones && [ "$has_done_milestone" = 1 ] && [ "$review_md" != 1 ]
        ;;
    esac
  }

  if [ -n "$only" ]; then
    evidence=$(_evidence "$only")
    printf 'SUGGEST %s %s%s\n' "$only" "$(_peal_next_try "$only" "$features")" "${evidence:+ $evidence}"
  else
    for item in guardrails milestones belfry review-task decisions drift releases reviewer review-steps; do
      _qualifies "$item" || continue
      _peal_next_blocked "$item" "$declined" "$today" && continue
      evidence=$(_evidence "$item")
      if [ -z "$picked" ]; then
        picked=$item
        printf 'SUGGEST %s %s%s\n' "$item" "$(_peal_next_try "$item" "$features")" "${evidence:+ $evidence}"
      elif [ "$also" -lt 3 ]; then
        printf 'ALSO %s %s%s\n' "$item" "$(_peal_next_try "$item" "$features")" "${evidence:+ $evidence}"
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
# fetch, no gh), plus one local git log for guardrails' evidence and _peal_next_features'
# own local files and git calls. Nothing (status 0) for NONE, an item currently declined,
# or any problem (a malformed declined date included), so the hook is never held up by
# this; shown even without stages: recorded.
peal_next_hint() {
  local records=$1 milestones=$2 stages declined today untagged features line item try prefix evidence
  stages=$(peal_config_get stages 2>/dev/null) || return 0
  declined=$(_peal_next_declined 2>/dev/null) || return 0
  today=${PEAL_TODAY:-$(date -u +%Y-%m-%d)}
  untagged=$(_peal_next_untagged 2>/dev/null)
  features=$(_peal_next_features 2>/dev/null)
  line=$(peal_next_core "$records" "$milestones" "$stages" "$declined" "$untagged" "$today" "$features" 2>/dev/null | head -n 1)
  case $line in
    "SUGGEST "*) ;;
    *) return 0 ;;
  esac
  item=$(printf '%s\n' "$line" | awk '{ print $2 }')
  try=$(_peal_next_try "$item" "$features")
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
  local stages declined today records milestones untagged features
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
  features=$(_peal_next_features)
  peal_next_core "$records" "$milestones" "$stages" "$declined" "$untagged" "$today" "$features" "$only" "$all"
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
