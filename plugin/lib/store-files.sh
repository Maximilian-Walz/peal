# shellcheck shell=bash
# The task-file storage (lib/store.sh has the interface): a task is the file
# <tasks>/<dir>/NNNN-slug.md, dir one of backlog, doing, done, and who holds it follows
# from refs. Everything is read from the remote's main branch and the refs, never from
# the calling worktree, so any worktree on any branch gets the same answer.
#
# Writes to the main branch never touch a worktree: the commit is built on a temporary
# index from the fetched main and pushed (lib/main-write.sh), or opened as a pull request
# where main refuses pushes. The push is the lock: one that loses a race is retried on the
# new main, a new task renumbered; a filing's pull request whose number an earlier one
# took is replaced by one with the next.

# _peal_files_settings -> PEAL_REMOTE, PEAL_MAIN, PEAL_TASKS, PEAL_PREFIX from the settings.
_peal_files_settings() {
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  PEAL_TASKS=$(peal_config_get tasks) || return 2
  PEAL_PREFIX=$(peal_config_get branch-prefix) || return 2
  PEAL_TASKS=${PEAL_TASKS%/}
}

# _peal_files_base -> the ref to read: the remote's main branch, else the local one with a
# warning; status 2 if neither exists.
_peal_files_base() {
  if git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
    printf '%s\n' "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN"
  elif git rev-parse --verify -q "refs/heads/$PEAL_MAIN" >/dev/null; then
    peal_err "warning: no $PEAL_REMOTE/$PEAL_MAIN; reading the local $PEAL_MAIN, which may be stale"
    printf '%s\n' "refs/heads/$PEAL_MAIN"
  else
    peal_err "neither $PEAL_REMOTE/$PEAL_MAIN nor $PEAL_MAIN exists: nothing to read"
    return 2
  fi
}

# _peal_files_fetch -> the remote's main fetched; status 2 and a message if that fails.
_peal_files_fetch() {
  if ! git remote get-url "$PEAL_REMOTE" >/dev/null 2>&1; then
    peal_err "no remote named $PEAL_REMOTE (setting remote)"
    return 2
  fi
  if ! git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null \
      || ! git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
    peal_err "could not fetch $PEAL_REMOTE/$PEAL_MAIN"
    return 2
  fi
}

# _peal_files_extract REF PATH DEST -> REF's PATH copied under DEST; nothing if absent.
_peal_files_extract() {
  git cat-file -e "$1:$2" 2>/dev/null || return 0
  git archive "$1" -- "$2" | tar -x -C "$3"
}

# _peal_files_scan REF -> task-scan.awk's records for REF's task files, by id.
_peal_files_scan() {
  local tmp status=0
  tmp=$(mktemp -d) || return 2
  _peal_files_extract "$1" "$PEAL_TASKS" "$tmp" || status=2
  if [ -d "$tmp/$PEAL_TASKS" ]; then
    find "$tmp/$PEAL_TASKS/backlog" "$tmp/$PEAL_TASKS/doing" "$tmp/$PEAL_TASKS/done" \
      -maxdepth 1 -type f -name '*.md' -exec awk -v root="$tmp" -v tasks="$PEAL_TASKS" \
      -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/task-scan.awk" {} + 2>&1 >"$tmp.out" \
      | LC_ALL=C grep -a -v '^find: ' >&2
    LC_ALL=C sort -t "$(printf '\t')" -k1,1 -s "$tmp.out"
    rm -f "$tmp.out"
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_files_ids REF -> the id of every task file at REF, one per line (a slug that breaks
# the rule makes no task file).
_peal_files_ids() {
  git ls-tree -r --name-only "$1" -- "$PEAL_TASKS/" 2>/dev/null | awk -v t="$PEAL_TASKS/" '
    index($0, t) == 1 {
      m = substr($0, length(t) + 1)
      if (m ~ /^(backlog|doing|done)\/[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$/) print substr(m, index(m, "/") + 1, 4)
    }' | sort -u
}

# _peal_files_find REF ID -> the path of task ID's file at REF, done/ before doing/ before
# backlog/; status 1 if there is none. A file whose slug breaks the rule is no task's.
_peal_files_find() {
  git ls-tree -r --name-only "$1" -- "$PEAL_TASKS/" 2>/dev/null | awk -v t="$PEAL_TASKS/" -v id="$2" '
    index($0, t) == 1 {
      m = substr($0, length(t) + 1)
      if (m !~ /^(backlog|doing|done)\/[0-9][0-9][0-9][0-9]-/) next
      if (substr(m, index(m, "/") + 1, 5) != id "-") next
      if (m !~ /^[a-z]+\/[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$/) {
        if (m ~ /\.md$/ && m !~ /^[a-z]+\/.*\//)
          print "peal: warning: " $0 ": the slug is not kebab-case words of a-z and 0-9; skipped" > "/dev/stderr"
        next
      }
      d = substr(m, 1, index(m, "/") - 1)
      r = d == "done" ? 3 : d == "doing" ? 2 : 1
      if (r > best) { best = r; path = $0 }
    }
    END { if (best) print path; exit !best }'
}

# _peal_files_branches -> "id<TAB>where<TAB>branch" for every task branch, where "local"
# or "remote" (on PEAL_REMOTE), branch without refs/heads/ or refs/remotes/<remote>/. A
# branch whose slug breaks the rule is no task's.
_peal_files_branches() {
  local ref name rest
  git for-each-ref --format='%(refname)' "refs/heads/$PEAL_PREFIX*" "refs/remotes/$PEAL_REMOTE/$PEAL_PREFIX*" \
    | while IFS= read -r ref; do
        case $ref in
          refs/heads/*) name=${ref#refs/heads/}; rest=local ;;
          *) name=${ref#"refs/remotes/$PEAL_REMOTE/"}; rest=remote ;;
        esac
        [[ "${name#"$PEAL_PREFIX"}" =~ ^([0-9][0-9][0-9][0-9])-[a-z0-9]+(-[a-z0-9]+)*$ ]] || continue
        printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "$rest" "$name"
      done
}

# _peal_files_worktrees -> "branch<TAB>path" for every worktree on a branch whose
# directory still exists.
_peal_files_worktrees() {
  git worktree list --porcelain | awk '
    /^worktree / { path = substr($0, 10) }
    /^branch refs\/heads\// { print substr($0, 19) "\t" path }' \
    | while IFS="$(printf '\t')" read -r branch path; do
        [ -d "$path" ] && printf '%s\t%s\n' "$branch" "$path"
      done
}

# _peal_files_claims BASE NOPR -> task-state.awk's claims: what each task branch says.
#   awaiting-merge  the branch's tip holds the task under done/; its detail pr:#N <url>
#                   (pr:unknown without gh or NOPR), wt:<path>, unpushed
#   claimed-live    the branch has a worktree (wt:<path>), or exists only on the remote
#   parked          a local branch ahead of main without a worktree
# A local branch with no worktree and nothing ahead of main claims nothing, unless the
# remote has it too.
_peal_files_claims() {
  local base=$1 nopr=$2 branches worktrees id lb rb ref wt ahead detail done_files out=""
  branches=$(_peal_files_branches)
  [ -n "$branches" ] || return 0
  worktrees=$(_peal_files_worktrees)
  for id in $(printf '%s\n' "$branches" | cut -f1 | sort -u); do
    lb=$(awk -F '\t' -v id="$id" '$1 == id && $2 == "local" { print $3; exit }' <<<"$branches")
    rb=$(awk -F '\t' -v id="$id" '$1 == id && $2 == "remote" { print $3; exit }' <<<"$branches")
    if [ -n "$lb" ]; then ref=refs/heads/$lb; else ref=refs/remotes/$PEAL_REMOTE/$rb; fi
    wt=""
    [ -z "$lb" ] || wt=$(awk -F '\t' -v b="$lb" '$1 == b { print $2; exit }' <<<"$worktrees")
    done_files=$(git ls-tree --name-only "$ref" -- "$PEAL_TASKS/done/")
    if grep -q "^$PEAL_TASKS/done/$id-" <<<"$done_files"; then
      detail=pr:unknown
      [ -z "$wt" ] || detail="$detail wt:$wt"
      if [ -n "$lb" ]; then
        if [ -z "$rb" ]; then
          detail="$detail unpushed"
        elif [ "$(git rev-list --count "refs/remotes/$PEAL_REMOTE/$rb..refs/heads/$lb")" -gt 0 ]; then
          detail="$detail unpushed"
        fi
      fi
      out="$out$id"$'\t'awaiting-merge$'\t'"$detail"$'\t'"${lb:-$rb}"$'\n'
    elif [ -n "$lb" ] && [ -n "$wt" ]; then
      out="$out$id"$'\t'claimed-live$'\t'"wt:$wt"$'\t'"$lb"$'\n'
    elif [ -n "$lb" ] && ahead=$(git rev-list --count "$base..refs/heads/$lb") && [ "$ahead" -gt 0 ]; then
      detail="$ahead commit(s) ahead, last $(git log -1 --format=%cd --date=short "refs/heads/$lb")"
      out="$out$id"$'\t'parked$'\t'"$detail"$'\t'"$lb"$'\n'
    elif [ -n "$rb" ]; then
      out="$out$id"$'\t'claimed-live$'\t'"remote:$PEAL_REMOTE"$'\t'"${lb:-$rb}"$'\n'
    else
      peal_err "warning: $lb has no worktree and nothing ahead of $PEAL_MAIN; task $id reads as unclaimed"
    fi
  done
  if [ "$nopr" = 0 ] && grep -q $'\tawaiting-merge\t' <<<"$out"; then
    out=$(printf '%s' "$out" | _peal_files_prs)
    out="$out"$'\n'
  fi
  printf '%s' "$out"
}

# _peal_files_prs -> the claims on stdin, an awaiting-merge claim's pr:unknown replaced by
# its open pull request from gh, "pr:#N <url>" and " draft" for a draft. Best effort: without
# gh, or when it fails or takes over 10 seconds, the claims stay as they are, with a warning.
_peal_files_prs() {
  local claims prs
  claims=$(cat)
  if ! command -v gh >/dev/null 2>&1; then
    peal_err "warning: gh not found; pull requests of tasks awaiting merge are unknown"
  else
    set -- gh pr list --state open --limit 200 --json number,headRefName,isDraft,url \
      --jq '.[] | [.headRefName, (.number|tostring), (.isDraft|tostring), .url] | @tsv'
    if command -v timeout >/dev/null 2>&1; then set -- timeout 10 "$@"; fi
    if ! prs=$("$@" 2>/dev/null); then
      peal_err "warning: gh pr list failed; pull requests of tasks awaiting merge are unknown"
      prs=""
    fi
  fi
  # Through the environment: awk -v refuses a value with newlines in some awks.
  PEAL_PRS=$prs awk -F '\t' -v OFS='\t' '
    BEGIN {
      n = split(ENVIRON["PEAL_PRS"], rows, "\n")
      for (i = 1; i <= n; i++) {
        split(rows[i], f, "\t")
        if (f[1] == "") continue
        num[f[1]] = f[2]; url[f[1]] = f[4]; draft[f[1]] = (f[3] == "true")
      }
    }
    $0 == "" { next }
    $2 == "awaiting-merge" && ($4 in num) {
      sub(/^pr:unknown/, "pr:#" num[$4] " " url[$4] (draft[$4] ? " draft" : ""), $3)
      $5 = "#" num[$4]
    }
    { print }' <<<"$claims" || printf '%s\n' "$claims"
}

peal_store_list() {
  local fetch=0 nopr=0 base tmp status=0
  while [ $# -gt 0 ]; do
    case $1 in
      --fetch) fetch=1 ;;
      --no-pr) nopr=1 ;;
      *) peal_err "list: unknown option $1"; return 2 ;;
    esac
    shift
  done
  _peal_files_settings || return 2
  if [ $fetch = 1 ] && ! git fetch -q "$PEAL_REMOTE" 2>/dev/null; then
    peal_err "warning: could not fetch $PEAL_REMOTE; reading what is known here"
  fi
  base=$(_peal_files_base) || return 2
  tmp=$(mktemp -d) || return 2
  _peal_files_scan "$base" >"$tmp/tasks" || status=2
  _peal_files_claims "$base" "$nopr" >"$tmp/claims"
  [ $status != 0 ] || awk -F '\t' -f "$PEAL_ROOT/lib/task-state.awk" "$tmp/claims" "$tmp/tasks" || status=2
  rm -rf "$tmp"
  return $status
}

peal_store_milestones() {
  local base
  _peal_files_settings || return 2
  base=$(_peal_files_base) || return 2
  _peal_files_milestones_at "$base"
}

peal_store_read() {
  local id=$1 base branch ref path
  _peal_files_settings || return 2
  base=$(_peal_files_base) || return 2
  for ref in $(_peal_files_branches | awk -F '\t' -v id="$id" -v r="$PEAL_REMOTE" '
      $1 == id { print ($2 == "local" ? "refs/heads/" : "refs/remotes/" r "/") $3 }') "$base"; do
    if path=$(_peal_files_find "$ref" "$id"); then
      git show "$ref:$path"
      return
    fi
  done
  peal_err "no task $id"
  peal_main_write_hint
  return 2
}

# _peal_files_check_context BASE -> task-check.awk's CONTEXT for filing onto BASE.
_peal_files_check_context() {
  peal_check_context
  _peal_files_milestones_at "$1" | awk -F '\t' '{ print "ms\t" $1 "\t" $3 }'
  _peal_files_ids "$1" | sed 's/^/id\t/'
}

# _peal_files_milestones_at BASE -> peal_ms_load's lines for BASE's milestone files.
_peal_files_milestones_at() {
  local tmp status=0
  tmp=$(mktemp -d) || return 2
  _peal_files_extract "$1" "$(peal_config_get milestones)" "$tmp" && peal_ms_load "$tmp" || status=2
  rm -rf "$tmp"
  [ $status = 0 ] && [ -n "$PEAL_MILESTONES" ] && printf '%s\n' "$PEAL_MILESTONES"
  return $status
}

# _peal_files_next_id BASE -> one past the highest task number in BASE's task files, in
# every task branch's name, local or on any remote, and in the task files of the main
# writes' branches fetched (a filing's pull request not merged yet): a claimed number
# stays taken.
_peal_files_next_id() {
  local ref
  {
    _peal_files_ids "$1"
    for ref in $(git for-each-ref --format='%(refname)' "refs/remotes/$PEAL_REMOTE/$PEAL_MW_PREFIX*"); do
      _peal_files_ids "$ref"
    done
    git for-each-ref --format='%(refname)' "refs/heads/$PEAL_PREFIX*" "refs/remotes/*/$PEAL_PREFIX*" \
      | while IFS= read -r ref; do
          case $ref in
            refs/heads/*) ref=${ref#refs/heads/} ;;
            *) ref=${ref#refs/remotes/*/} ;;
          esac
          [[ "${ref#"$PEAL_PREFIX"}" =~ ^([0-9][0-9][0-9][0-9])- ]] && printf '%s\n' "${BASH_REMATCH[1]}"
        done
  } | awk '{ n = $0 + 0; if (n > max) max = n } END { printf "%04d\n", max + 1 }'
}

# _peal_files_create_taken REF... -> status 0 when one of the numbers the filing took is
# a task's at one of the REFs: a filing that went there first.
_peal_files_create_taken() {
  local ref ids id
  ids=$(for ref; do _peal_files_ids "$ref"; done)
  for id in "${PEAL_CREATE_IDS[@]}"; do
    printf '%s\n' "$ids" | grep -qx "$id" && return 0
  done
  return 1
}

# peal_store_create MODE ORIGIN SLUG... -> the tasks whose texts are on stdin, one per
# SLUG, separated by lines "-----NEXT TASK-----", filed onto the main branch in one
# commit; a line per task: "filed NNNN PATH — milestone: M, plan: P, size: S — "Title"".
# Each text writes NNNN for its own number; pieces of a split write ORIGIN for the task
# split and PART1..n for each other. MODE: plain, split (ORIGIN the task split) or batch
# (ORIGIN the task whose close files them). Refused before anything is pushed: a text
# task-check.awk refuses, two identical texts, an ORIGIN that is no task.
peal_store_create() {
  local mode=$1 origin=$2 count i status=0 context summary
  shift 2
  case $mode in
    plain) [ $# -eq 1 ] || { peal_err "create: one slug"; return 2; } ;;
    split | batch)
      [[ "$origin" =~ ^[0-9][0-9][0-9][0-9]$ ]] || { peal_err "create: '$origin' is no task id"; return 2; } ;;
    *) peal_err "create: unknown mode $mode"; return 2 ;;
  esac
  [ $# -ge 1 ] || { peal_err "create: no slug"; return 2; }
  _peal_files_settings || return 2
  PEAL_CREATE_MODE=$mode PEAL_CREATE_ORIGIN=$origin
  count=$#
  peal_create_texts "$@" || status=2
  if [ $status = 0 ]; then
    _peal_files_fetch || status=2
  fi
  if [ $status = 0 ]; then
    context=$PEAL_CREATE_DIR/context
    _peal_files_check_context "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >"$context" || status=2
  fi
  if [ $status = 0 ] && [ "$mode" != plain ] && ! grep -q "^id	$origin\$" "$context"; then
    peal_err "create: task $origin does not exist"
    status=2
  fi
  PEAL_CREATE_SUMMARY=()
  for ((i = 1; i <= count && status == 0; i++)); do
    if summary=$(peal_task_check "$PEAL_CREATE_DIR/$i" "$mode" "${PEAL_CREATE_SLUGS[i - 1]}" "$context" "$i" "$count"); then
      PEAL_CREATE_SUMMARY+=("$summary")
    else
      status=2
    fi
  done
  if [ $status = 0 ]; then
    peal_cycle_check_create "$mode" "$origin" "$count" "$PEAL_CREATE_DIR" || status=$?
  fi
  if [ $status = 0 ]; then
    PEAL_MW_TAKEN=_peal_files_create_taken
    case $mode in
      plain) peal_push_main _peal_files_build_create create || status=$? ;;
      split) peal_push_main _peal_files_build_create "create --part-of" || status=$? ;;
      batch) peal_push_main _peal_files_build_create "create --batch" || status=$? ;;
    esac
    # shellcheck disable=SC2034 # read by peal_push_main
    PEAL_MW_TAKEN=""
  fi
  if peal_main_write_written $status; then
    for ((i = 0; i < count; i++)); do
      PEAL_TITLE=${PEAL_CREATE_TITLES[i]} awk -F '\t' -v id="${PEAL_CREATE_IDS[i]}" \
        -v path="${PEAL_CREATE_PATHS[i]}" '
        function f(v) { return v == "" ? "-" : v }
        { printf "filed %s %s — milestone: %s, plan: %s, size: %s — \"%s\"\n", id, path, f($1), f($2), f($3), ENVIRON["PEAL_TITLE"] }' \
        <<<"${PEAL_CREATE_SUMMARY[i]}"
    done
    peal_main_write_report "the number is final once it merges"
  elif [ -s "${PEAL_CREATE_DIR-}/1" ]; then
    peal_err "nothing was filed"
  fi
  [ -z "${PEAL_CREATE_DIR-}" ] || rm -rf "$PEAL_CREATE_DIR"
  return $status
}

# _peal_files_build_create BASE -> the new files numbered from BASE, in one tree.
_peal_files_build_create() {
  local base=$1 first i k count=${#PEAL_CREATE_SLUGS[@]} text args=() subject
  first=$(_peal_files_next_id "$base")
  PEAL_CREATE_IDS=() PEAL_CREATE_PATHS=() PEAL_CREATE_TITLES=()
  for ((i = 0; i < count; i++)); do
    PEAL_CREATE_IDS+=("$(printf '%04d' $((10#$first + i)))")
  done
  for ((i = 0; i < count; i++)); do
    text=$(cat "$PEAL_CREATE_DIR/$((i + 1))")
    text=${text//NNNN/${PEAL_CREATE_IDS[i]}}
    if [ "$PEAL_CREATE_MODE" = split ]; then
      text=${text//ORIGIN/$PEAL_CREATE_ORIGIN}
      # Down, not up: PART1 would eat the start of PART10.
      for ((k = count; k >= 1; k--)); do
        text=${text//PART$k/${PEAL_CREATE_IDS[k - 1]}}
      done
    fi
    printf '%s\n' "$text" >"$PEAL_CREATE_DIR/out$i"
    PEAL_CREATE_PATHS+=("$PEAL_TASKS/backlog/${PEAL_CREATE_IDS[i]}-${PEAL_CREATE_SLUGS[i]}.md")
    PEAL_CREATE_TITLES+=("$(peal_text_title "${PEAL_CREATE_IDS[i]}" <"$PEAL_CREATE_DIR/out$i")")
    args+=(add "${PEAL_CREATE_PATHS[i]}" "$PEAL_CREATE_DIR/out$i")
  done
  peal_write_tree "$base" "${args[@]}" || return 2
  subject=${PEAL_CREATE_IDS[0]}
  [ "$count" = 1 ] || subject="$subject-${PEAL_CREATE_IDS[count - 1]}"
  case $PEAL_CREATE_MODE in
    plain) PEAL_SUBJECT="docs(tasks): file $subject ${PEAL_CREATE_SLUGS[0]} [$subject]" ;;
    split) PEAL_SUBJECT="docs(tasks): file $subject, split of $PEAL_CREATE_ORIGIN [$PEAL_CREATE_ORIGIN]" ;;
    batch) PEAL_SUBJECT="docs(tasks): file $subject, found in $PEAL_CREATE_ORIGIN [$PEAL_CREATE_ORIGIN]" ;;
  esac
}

# _peal_files_unclaimed ID VERB -> PEAL_BASE (the fetched main), PEAL_PATH and PEAL_SLUG
# for task ID, if nobody has claimed it and it is in the backlog; else status 2 and why.
_peal_files_unclaimed() {
  local id=$1 verb=$2 refs
  if ! [[ "$id" =~ ^[0-9][0-9][0-9][0-9]$ ]]; then
    peal_err "$verb: '$id' is no task id"
    return 2
  fi
  _peal_files_settings || return 2
  refs=$(git for-each-ref --format='%(refname:short)' "refs/heads/$PEAL_PREFIX$id-*" "refs/remotes/*/$PEAL_PREFIX$id-*")
  if [ -n "$refs" ]; then
    peal_err "$verb: task $id is claimed ($(printf '%s' "$refs" | tr '\n' ' ' | sed 's/ $//')); $verb touches only a task nobody has claimed"
    return 2
  fi
  _peal_files_fetch || return 2
  PEAL_BASE=$(git rev-parse "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || return 2
  if ! PEAL_PATH=$(_peal_files_find "$PEAL_BASE" "$id"); then
    peal_err "$verb: no task $id on $PEAL_REMOTE/$PEAL_MAIN"
    peal_main_write_hint
    return 2
  fi
  case $PEAL_PATH in
    "$PEAL_TASKS"/backlog/*) ;;
    "$PEAL_TASKS"/done/*) peal_err "$verb: task $id is done ($PEAL_PATH)"; return 2 ;;
    *) peal_err "$verb: task $id is claimed ($PEAL_PATH)"; return 2 ;;
  esac
  PEAL_SLUG=${PEAL_PATH##*/}
  PEAL_SLUG=${PEAL_SLUG#"$id-"}
  PEAL_SLUG=${PEAL_SLUG%.md}
}

# _peal_files_build_edit BASE -> the edited text in place of PEAL_PATH, if main's copy is
# still the one read: an edit replaces text it does not own, so a concurrent change is
# refused, not overwritten.
_peal_files_build_edit() {
  local now
  now=$(git rev-parse -q --verify "$1:$PEAL_PATH")
  if [ "$now" != "$PEAL_EDIT_BLOB" ]; then
    peal_err "$PEAL_PATH changed on $PEAL_REMOTE/$PEAL_MAIN meanwhile; read it again and run again"
    return 2
  fi
  peal_write_tree "$1" add "$PEAL_PATH" "$PEAL_EDIT_FILE" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT=$PEAL_EDIT_SUBJECT
}

# _peal_files_text_checks VERB OLD NEW LABEL BASE ID -> the checks on a rewritten task
# text NEW (OLD the one before) against BASE: peal_edit_check's, a Notes section to record
# the reason in, and task-check.awk's in revise mode; then that it closes no depends cycle
# (peal_cycle_check). Status 2 with every problem reported, 1 for a cycle.
_peal_files_text_checks() {
  local verb=$1 old=$2 new=$3 label=$4 base=$5 id=$6 status=0 context
  peal_edit_check "$verb" "$old" "$new" "$label" || status=2
  if ! peal_text_has_section Notes <"$new"; then
    peal_err "$verb: no '## Notes' section to record the reason in"
    status=2
  fi
  context=$(mktemp) || return 2
  _peal_files_check_context "$base" >"$context" || status=2
  PEAL_CHECK_ID=$id PEAL_CHECK_OLDMS=$(peal_fm_get "$old" milestone 2>/dev/null) \
    peal_task_check "$new" revise "$label" "$context" >/dev/null || status=2
  rm -f "$context"
  [ $status != 0 ] || peal_cycle_check_text "$verb" "$id" "$new" || status=$?
  return $status
}

# peal_store_edit ID REASON [--dry-run] -> the unclaimed backlog task ID's text replaced by
# the one on stdin, with "Revised <date>: REASON" under its Notes, pushed onto the main
# branch; --dry-run prints the change instead. Refused: a claimed task, a changed heading
# number, a changed or added or dropped Raw section, a changed part-of, a filled Outcome
# (either side), an added or dropped Outcome heading, no Notes section, no change at all,
# and whatever task-check.awk refuses.
peal_store_edit() {
  local id=$1 reason=$2 dry=${3-} tmp old new status=0
  [ -n "$reason" ] || { peal_err "revise: give a reason"; return 2; }
  _peal_files_unclaimed "$id" revise || return 2
  tmp=$(mktemp -d) || return 2
  old=$tmp/old new=$tmp/new
  git show "$PEAL_BASE:$PEAL_PATH" >"$old"
  cat >"$new"
  PEAL_EDIT_BLOB=$(git rev-parse "$PEAL_BASE:$PEAL_PATH")
  if cmp -s "$old" "$new"; then
    peal_err "revise: the text is the same as $PEAL_PATH's: nothing to revise"
    status=2
  fi
  if [ $status = 0 ]; then
    _peal_files_text_checks revise "$old" "$new" "$PEAL_PATH" "$PEAL_BASE" "$id" || status=$?
  fi
  if [ $status = 0 ]; then
    peal_text_add_note "Revised $(date -u +%Y-%m-%d): $reason" <"$new" >"$tmp/edited"
    PEAL_EDIT_FILE=$tmp/edited
    PEAL_EDIT_SUBJECT="docs(tasks): revise $id $PEAL_SLUG [$id]"
    if [ "$dry" = --dry-run ]; then
      (cd "$tmp" && diff -u old edited)
      echo "revise: a dry run; nothing pushed"
    else
      peal_push_main _peal_files_build_edit revise || status=$?
      if peal_main_write_written $status; then
        echo "revised $id $PEAL_PATH"
        peal_main_write_report
      fi
    fi
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_files_only SHA PATH... -> status 0 if commit SHA changes something, and nothing
# but the PATHs.
_peal_files_only() {
  local sha=$1 changed p a ok
  shift
  changed=$(git diff-tree -r --no-commit-id --name-only --no-renames "$sha") || return 1
  [ -n "$changed" ] || return 1
  while IFS= read -r p; do
    ok=0
    for a in "$@"; do [ "$p" = "$a" ] && ok=1; done
    [ $ok = 1 ] || return 1
  done <<<"$changed"
}

# _peal_files_no_work ID BRANCH BASE BACKLOG DOING -> status 0 if the claim on BRANCH, here
# checked out, holds nothing but the claim itself: its oldest commit beyond BASE the claim
# (BACKLOG moved to DOING), every other a wip or docs(tasks) commit of DOING alone (an
# autosave, a plan or notes recorded, a revision), no merge, its remote branch nothing
# more, and nothing uncommitted but DOING. Status 2 and what is there else.
_peal_files_no_work() {
  local id=$1 branch=$2 base=$3 backlog=$4 doing=$5 sha subject first=1 dirty
  if [ -n "$(git rev-list --merges "$base..HEAD")" ]; then
    peal_err "defer: $branch holds a merge; that is work, which ends through its close"
    return 2
  fi
  if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$branch" >/dev/null \
      && ! git merge-base --is-ancestor "refs/remotes/$PEAL_REMOTE/$branch" HEAD; then
    peal_err "defer: $PEAL_REMOTE/$branch holds commits this worktree does not have"
    return 2
  fi
  for sha in $(git rev-list --reverse "$base..HEAD"); do
    subject=$(git show -s --format=%s "$sha")
    if [ $first = 1 ]; then
      first=0
      case $subject in "docs(tasks): claim $id "*) _peal_files_only "$sha" "$backlog" "$doing" && continue ;; esac
      peal_err "defer: the oldest commit on $branch is no claim of $id: $(git rev-parse --short "$sha") $subject"
      return 2
    fi
    case $subject in wip:* | "wip("* | "docs(tasks): "*) _peal_files_only "$sha" "$doing" && continue ;; esac
    peal_err "defer: $branch holds work beyond the claim: $(git rev-parse --short "$sha") $subject"
    peal_err "work ends through its close, with an Outcome; defer only gives back a claim nothing was built on"
    return 2
  done
  if [ $first = 1 ]; then
    peal_err "defer: $branch holds no claim commit beyond $PEAL_REMOTE/$PEAL_MAIN"
    return 2
  fi
  dirty=$(git status --porcelain --untracked-files=all | cut -c4- | grep -v -x -F -- "$doing")
  if [ -n "$dirty" ]; then
    peal_err "defer: uncommitted changes besides $doing, which would go with the claim:"
    printf '%s\n' "$dirty" | sed 's/^/  /' >&2
    return 2
  fi
}

# _peal_files_build_defer BASE -> PEAL_PATH on BASE replaced by the deferred text: the
# claim owns the task's text, so it goes on whatever main holds now.
_peal_files_build_defer() {
  if ! git cat-file -e "$1:$PEAL_PATH" 2>/dev/null; then
    peal_err "defer: $PEAL_PATH is gone from $PEAL_REMOTE/$PEAL_MAIN meanwhile"
    return 2
  fi
  peal_write_tree "$1" add "$PEAL_PATH" "$PEAL_EDIT_FILE" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT=$PEAL_EDIT_SUBJECT
}

# peal_store_defer ID REASON TEXT [--dry-run] -> the claim of task ID, checked out here,
# given back: the task text in the file TEXT, "Deferred <date> after a claim: REASON" under
# its Notes, pushed onto the task's backlog file on the main branch, under its number.
# Then an uncommitted change to the claim's own file is committed as wip, so the worktree
# can go clean. Refused: another branch, work on the branch (_peal_files_no_work), and the
# checks of a revise but "no change".
peal_store_defer() {
  local id=$1 reason=$2 text=$3 dry=${4-} top branch base doing tmp status=0
  [ -n "$reason" ] || { peal_err "defer: give a reason"; return 2; }
  _peal_files_settings || return 2
  top=$(peal_project_root) || return 2
  branch=$(git symbolic-ref -q --short HEAD)
  case $branch in
    "$PEAL_PREFIX$id"-*) ;;
    *) peal_err "defer: not on task $id's branch ($PEAL_PREFIX$id-...), but on ${branch:-a detached HEAD}"; return 2 ;;
  esac
  _peal_files_fetch || return 2
  base=$(git rev-parse "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || return 2
  if ! PEAL_PATH=$(_peal_files_find "$base" "$id"); then
    peal_err "defer: no task $id on $PEAL_REMOTE/$PEAL_MAIN"
    peal_main_write_hint
    return 2
  fi
  case $PEAL_PATH in
    "$PEAL_TASKS"/backlog/*) ;;
    *) peal_err "defer: task $id is not in the backlog on $PEAL_REMOTE/$PEAL_MAIN ($PEAL_PATH)"; return 2 ;;
  esac
  doing=$PEAL_TASKS/doing/${PEAL_PATH##*/}
  if [ ! -f "$top/$doing" ]; then
    peal_err "defer: no $doing here: a claim's file keeps the name it had in the backlog"
    return 2
  fi
  (cd "$top" && _peal_files_no_work "$id" "$branch" "$base" "$PEAL_PATH" "$doing") || return 2
  tmp=$(mktemp -d) || return 2
  git show "$base:$PEAL_PATH" >"$tmp/old"
  cp "$text" "$tmp/new"
  _peal_files_text_checks defer "$tmp/old" "$tmp/new" "$PEAL_PATH" "$base" "$id" || status=$?
  if [ $status = 0 ]; then
    peal_text_add_note "Deferred $(date -u +%Y-%m-%d) after a claim: $reason" <"$tmp/new" >"$tmp/deferred"
    PEAL_EDIT_FILE=$tmp/deferred
    PEAL_EDIT_SUBJECT="docs(tasks): defer $id ${branch#"$PEAL_PREFIX$id"-} [$id]"
    if [ "$dry" = --dry-run ]; then
      (cd "$tmp" && diff -u old deferred)
      echo "defer: a dry run; nothing pushed"
    else
      peal_push_main _peal_files_build_defer defer || status=$?
      if peal_main_write_written $status; then
        echo "deferred $id $PEAL_PATH"
        peal_main_write_report
        if [ -n "$(git -C "$top" status --porcelain -- "$doing")" ] \
            && ! git -C "$top" commit -q -m "wip: defer capture [$id]" -- "$doing" >/dev/null 2>&1; then
          peal_err "defer: the text is on its way to $PEAL_REMOTE/$PEAL_MAIN, but $doing could not be committed; commit it before the release"
          status=1
        fi
      fi
    fi
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_files_build_retire BASE -> PEAL_PATH moved to done/ with the retirement as its
# Outcome, from BASE's copy: a retirement only adds its line, so it goes on whatever main
# holds now.
_peal_files_build_retire() {
  local dest=$PEAL_TASKS/done/${PEAL_PATH##*/}
  if ! git cat-file -e "$1:$PEAL_PATH" 2>/dev/null; then
    peal_err "retire: $PEAL_PATH is gone from $PEAL_REMOTE/$PEAL_MAIN meanwhile"
    return 2
  fi
  git show "$1:$PEAL_PATH" >"$PEAL_EDIT_FILE.old"
  if peal_text_outcome_filled <"$PEAL_EDIT_FILE.old"; then
    peal_err "retire: $PEAL_PATH's Outcome is filled in: work happened, this is no plain backlog task"
    return 2
  fi
  peal_text_set_outcome "$PEAL_RETIRE_LINE" <"$PEAL_EDIT_FILE.old" >"$PEAL_EDIT_FILE"
  peal_write_tree "$1" remove "$PEAL_PATH" add "$dest" "$PEAL_EDIT_FILE" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT=$PEAL_EDIT_SUBJECT
}

# _peal_files_retire ID REASON -> the unclaimed backlog task ID moved to done/ on the main
# branch, its Outcome the dated REASON. Refused while a task not done names it in depends
# or part-of: re-point those first.
_peal_files_retire() {
  local id=$1 reason=$2 tmp dependents status=0
  [ -n "$reason" ] || { peal_err "retire: give a reason"; return 2; }
  _peal_files_unclaimed "$id" retire || return 2
  dependents=$(_peal_files_scan "$PEAL_BASE" 2>/dev/null | awk -F '\t' -v id="$id" '
    $2 != "done" && $1 != id && (index("," $7 ",", "," id ",") || $8 == id) {
      print "  " $12 (index("," $7 ",", "," id ",") ? " (depends)" : " (part-of)") }')
  if [ -n "$dependents" ]; then
    peal_err "retire: task $id is still named by:"
    printf '%s\n' "$dependents" >&2
    peal_err "re-point those (peal revise) before retiring $id"
    return 2
  fi
  tmp=$(mktemp -d) || return 2
  PEAL_EDIT_FILE=$tmp/retired
  PEAL_RETIRE_LINE="Retired $(date -u +%Y-%m-%d) without being claimed: $reason"
  PEAL_EDIT_SUBJECT="docs(tasks): retire $id $PEAL_SLUG [$id]"
  peal_push_main _peal_files_build_retire retire || status=$?
  if peal_main_write_written $status; then
    echo "retired $id $PEAL_TASKS/done/${PEAL_PATH##*/}"
    peal_main_write_report
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_files_finish_done ID -> the task's file moved from doing/ to done/ in this
# worktree, staged with its Outcome for the close's commit. Only on the task's own branch,
# and only with an Outcome written and no placeholder left in it. A file moved already
# (a close run again) is left as it is.
_peal_files_finish_done() {
  local id=$1 branch top file dest
  _peal_files_settings || return 2
  top=$(peal_project_root) || return 2
  branch=$(git symbolic-ref -q --short HEAD)
  case $branch in
    "$PEAL_PREFIX$id"-*) ;;
    *) peal_err "finish: not on task $id's branch ($PEAL_PREFIX$id-...), but on ${branch:-a detached HEAD}"; return 2 ;;
  esac
  for file in "$top/$PEAL_TASKS/doing/$id"-*.md; do break; done
  if [ ! -f "$file" ]; then
    for file in "$top/$PEAL_TASKS/done/$id"-*.md; do break; done
    if [ -f "$file" ] && git -C "$top" ls-files --error-unmatch -- "${file#"$top"/}" >/dev/null 2>&1; then
      echo "finished $id already: ${file#"$top"/}"
      return 0
    fi
    peal_err "finish: no $PEAL_TASKS/doing/$id-*.md here"
    return 2
  fi
  if ! peal_text_outcome_filled <"$file"; then
    peal_err "finish: ${file#"$top"/} has no Outcome yet"
    return 2
  fi
  if peal_text_outcome_placeholder <"$file"; then
    peal_err "finish: ${file#"$top"/}'s Outcome still holds a placeholder (<!-- ... -->)"
    return 2
  fi
  dest=$PEAL_TASKS/done/${file##*/}
  mkdir -p "$top/$PEAL_TASKS/done"
  git -C "$top" mv "${file#"$top"/}" "$dest" && git -C "$top" add -- "$dest" || return 2
  echo "finished $id $dest"
}

# The task's file on its branch: under doing/, or under done/ once the close moved it.
peal_store_close_text() {
  local file
  _peal_files_settings || return 2
  for file in "$PEAL_TASKS/doing/$1"-*.md "$PEAL_TASKS/done/$1"-*.md; do
    [ ! -f "$file" ] || { printf '%s\n' "$file"; return 0; }
  done
  return 1
}

peal_store_finish() {
  case ${2-} in
    done) [ $# -eq 2 ] || { peal_err "finish: ID done"; return 2; }; _peal_files_finish_done "$1" ;;
    retired) [ $# -eq 3 ] || { peal_err "finish: ID retired REASON"; return 2; }; _peal_files_retire "$1" "$3" ;;
    *) peal_err "finish: ID done, or ID retired REASON"; return 2 ;;
  esac
}

# _peal_files_build_rewrite BASE -> PEAL_PATH rewritten by PEAL_REWRITE (a function from
# the old text in $1 to the new in $2) from BASE's copy: a small edit goes on whatever
# main holds now.
_peal_files_build_rewrite() {
  if ! git cat-file -e "$1:$PEAL_PATH" 2>/dev/null; then
    peal_err "$PEAL_PATH is gone from $PEAL_REMOTE/$PEAL_MAIN meanwhile"
    return 2
  fi
  git show "$1:$PEAL_PATH" >"$PEAL_EDIT_FILE.old"
  "$PEAL_REWRITE" "$PEAL_EDIT_FILE.old" "$PEAL_EDIT_FILE" || return 2
  if cmp -s "$PEAL_EDIT_FILE.old" "$PEAL_EDIT_FILE"; then
    peal_err "$PEAL_PATH already reads so: nothing to change"
    return 2
  fi
  peal_write_tree "$1" add "$PEAL_PATH" "$PEAL_EDIT_FILE" || return 2
  # shellcheck disable=SC2034 # read by peal_push_main
  PEAL_SUBJECT=$PEAL_EDIT_SUBJECT
}

_peal_files_rewrite_milestone() {
  cp "$1" "$2"
  if [ -n "$PEAL_NEW_MILESTONE" ]; then
    peal_fm_set "$2" milestone "$PEAL_NEW_MILESTONE"
  else
    peal_fm_unset "$2" milestone
  fi
}

_peal_files_rewrite_comment() {
  if ! peal_text_has_section Notes <"$1"; then
    peal_err "comment: $PEAL_PATH has no '## Notes' section"
    return 2
  fi
  peal_text_add_note "$PEAL_COMMENT" <"$1" >"$2"
}

# _peal_files_rewrite ID VERB SUBJECT FUNCTION -> PEAL_PATH of the unclaimed task ID
# rewritten by FUNCTION and pushed.
_peal_files_rewrite() {
  local id=$1 verb=$2 tmp status=0
  _peal_files_unclaimed "$id" "$verb" || return 2
  tmp=$(mktemp -d) || return 2
  PEAL_EDIT_FILE=$tmp/new PEAL_REWRITE=$4
  PEAL_EDIT_SUBJECT="docs(tasks): $3 [$id]"
  peal_push_main _peal_files_build_rewrite "$verb" || status=$?
  rm -rf "$tmp"
  return $status
}

peal_store_set_milestone() {
  local id=$1 state status=0
  PEAL_NEW_MILESTONE=${2-}
  _peal_files_settings || return 2
  if [ -n "$PEAL_NEW_MILESTONE" ]; then
    _peal_files_fetch || return 2
    state=$(_peal_files_milestones_at "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" \
      | awk -F '\t' -v m="$PEAL_NEW_MILESTONE" '$1 == m { print $3 }') || return 2
    case $state in
      "") peal_err "set-milestone: milestone $PEAL_NEW_MILESTONE does not exist"; return 2 ;;
      done) peal_err "set-milestone: milestone $PEAL_NEW_MILESTONE is done"; return 2 ;;
    esac
  fi
  _peal_files_rewrite "$id" set-milestone "set milestone of $id to ${PEAL_NEW_MILESTONE:-none}" \
    _peal_files_rewrite_milestone || status=$?
  peal_main_write_written $status || return $status
  echo "task $id: milestone ${PEAL_NEW_MILESTONE:-none}"
  peal_main_write_report
  return $status
}

peal_store_comment() {
  local id=$1 status=0
  if [ -z "${2-}" ]; then
    peal_err "comment: no text"
    return 2
  fi
  PEAL_COMMENT="$(date -u +%Y-%m-%d): $2"
  _peal_files_rewrite "$id" comment "note on $id" _peal_files_rewrite_comment || status=$?
  peal_main_write_written $status || return $status
  echo "task $id: noted"
  peal_main_write_report
  return $status
}

# _peal_files_local_branch ID -> the local task branch of ID; status 1 if there is none.
_peal_files_local_branch() {
  _peal_files_branches | awk -F '\t' -v id="$1" '!found && $1 == id && $2 == "local" { print $3; found = 1 }
    END { exit !found }'
}

# _peal_files_rollback WT BRANCH -> a claim that failed half-way taken back: its worktree
# and its branch gone, or a message saying what is left.
_peal_files_rollback() {
  local ok=1
  git worktree remove --force "$1" >/dev/null 2>&1 || ok=0
  git branch -D "$2" >/dev/null 2>&1 || ok=0
  [ $ok = 1 ] || peal_err "could not take the claim back fully; remove it by hand: git worktree remove --force $1; git branch -D $2"
}

# peal_store_claim ID -> the free task ID claimed, or its parked claim resumed; one line
# "claimed ID BRANCH PATH" or "resumed ID BRANCH PATH", PEAL_CLAIM_PATH the worktree.
# A claim is the task's branch from the remote's main, in its own worktree under the
# worktrees setting, the task's file moved to doing/ in one commit, and the branch pushed:
# the push is the lock. Status 3 for a push that lost the race to another claim, with
# nothing left behind; 2 for anything else refused or failed, taken back as well.
peal_store_claim() {
  local id=$1 base path slug branch wt dir err nonce status=0
  _peal_files_settings || return 2
  dir=$(peal_worktrees_dir) || return 2
  if branch=$(_peal_files_local_branch "$id"); then
    _peal_files_resume "$id" "$branch" "$dir"
    return
  fi
  _peal_files_fetch || return 2
  base=$(git rev-parse "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || return 2
  if ! path=$(_peal_files_find "$base" "$id"); then
    peal_err "claim: no task $id on $PEAL_REMOTE/$PEAL_MAIN"
    peal_main_write_hint
    return 2
  fi
  case $path in
    "$PEAL_TASKS"/backlog/*) ;;
    *) peal_err "claim: task $id is not in the backlog on $PEAL_REMOTE/$PEAL_MAIN ($path)"; return 2 ;;
  esac
  slug=${path##*/}
  slug=${slug%.md}
  branch=$PEAL_PREFIX$slug
  wt=$dir/$slug
  if [ -e "$wt" ]; then
    peal_err "claim: $wt is in the way; move it, or remove it with git worktree remove"
    return 2
  fi
  mkdir -p "$dir" || return 2
  err=$(mktemp) || return 2
  # LC_ALL=C: git's own words are read below; translated, they would never match.
  if ! LC_ALL=C git worktree add -q -b "$branch" "$wt" "$base" 2>"$err"; then
    peal_err "claim: could not add the worktree $wt:"
    cat "$err" >&2
    rm -f "$err"
    return 2
  fi
  mkdir -p "$wt/$PEAL_TASKS/doing"
  # The nonce: two claims of the same task in the same second would otherwise make the
  # same commit, and the second push would pass as a no-op instead of losing.
  nonce=$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || nonce=""
  [ -n "$nonce" ] || nonce=$$-$RANDOM-$(date +%s)
  if ! git -C "$wt" mv "$path" "$PEAL_TASKS/doing/" \
      || ! git -C "$wt" commit -q -m "docs(tasks): claim $id ${slug#"$id"-} [$id]" \
        -m "Claimed-by: $(hostname 2>/dev/null || echo unknown)/$nonce"; then
    peal_err "claim: could not commit the claim of $id; taken back"
    _peal_files_rollback "$wt" "$branch"
    rm -f "$err"
    return 2
  fi
  if ! LC_ALL=C git -C "$wt" push -q -u "$PEAL_REMOTE" "$branch" 2>"$err"; then
    if [ -n "$(git ls-remote "$PEAL_REMOTE" "refs/heads/$PEAL_PREFIX$id-*" 2>/dev/null)" ]; then
      peal_err "claim: task $id was claimed elsewhere first: the push of $branch lost the race; taken back"
      status=3
    else
      peal_err "claim: the push of $branch failed; taken back, a claim not pushed is none:"
      cat "$err" >&2
      status=2
    fi
    _peal_files_rollback "$wt" "$branch"
    git fetch -q "$PEAL_REMOTE" 2>/dev/null
  fi
  rm -f "$err"
  [ $status = 0 ] || return $status
  PEAL_CLAIM_PATH=$(cd "$wt" && pwd -P)
  echo "claimed $id $branch $PEAL_CLAIM_PATH"
}

# _peal_files_resume ID BRANCH DIR -> the parked claim on the local BRANCH given its
# worktree back, and pushed when the remote lacks some of it.
_peal_files_resume() {
  local id=$1 branch=$2 dir=$3 wt ahead
  if [ -n "$(_peal_files_worktrees | awk -F '\t' -v b="$branch" '$1 == b')" ]; then
    peal_err "claim: $branch already has a worktree"
    return 2
  fi
  if [ "$(git rev-list --count "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN..refs/heads/$branch" 2>/dev/null)" = 0 ]; then
    peal_err "claim: the local $branch holds nothing beyond $PEAL_MAIN, so it claims nothing; delete it (git branch -D $branch) and claim again"
    return 2
  fi
  wt=$dir/${branch#"$PEAL_PREFIX"}
  if [ -e "$wt" ]; then
    peal_err "claim: $wt is in the way; move it, or remove it with git worktree remove"
    return 2
  fi
  mkdir -p "$dir" || return 2
  git worktree add -q "$wt" "$branch" || { peal_err "claim: could not add the worktree $wt"; return 2; }
  if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$branch" >/dev/null; then
    ahead=$(git rev-list --count "refs/remotes/$PEAL_REMOTE/$branch..refs/heads/$branch")
  else
    ahead=1
  fi
  if [ "$ahead" -gt 0 ] && ! git -C "$wt" push -q -u "$PEAL_REMOTE" "$branch" 2>/dev/null; then
    peal_err "warning: resumed $branch, but could not push it; until it is pushed, the claim holds on this machine only"
  fi
  PEAL_CLAIM_PATH=$(cd "$wt" && pwd -P)
  echo "resumed $id $branch $PEAL_CLAIM_PATH"
}

# peal_store_release ID -> task ID's claim on this machine ended: the local branch's tip
# kept as refs/reaped/<branch without its prefix>, its worktree removed (refused if
# anything in it is uncommitted), the local branch deleted, and the remote's too when it
# holds nothing the local one does not. One line "released ID BRANCH, tip kept as REF".
# Whether a claim may end is not the storage's to judge; the caller has (lib/claim.sh).
peal_store_release() {
  local id=$1 branch wt name tip
  _peal_files_settings || return 2
  if ! branch=$(_peal_files_local_branch "$id"); then
    peal_err "release: no local branch of task $id"
    return 2
  fi
  name=${branch#"$PEAL_PREFIX"}
  tip=$(git rev-parse "refs/heads/$branch") || return 2
  if ! peal_reaped_keep "$name" "$tip"; then
    peal_err "release: could not keep the tip as refs/reaped/$name; nothing removed"
    return 2
  fi
  wt=$(git worktree list --porcelain | awk -v b="branch refs/heads/$branch" '
    /^worktree / { path = substr($0, 10) }
    !f && $0 == b { print path; f = 1 }')
  if [ -n "$wt" ] && ! git worktree remove "$wt"; then
    peal_err "release: git worktree remove refused $wt; the tip is kept, nothing else removed"
    return 2
  fi
  git branch -q -D "$branch" || return 2
  if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$branch" >/dev/null; then
    if ! git merge-base --is-ancestor "refs/remotes/$PEAL_REMOTE/$branch" "$tip"; then
      peal_err "warning: $PEAL_REMOTE/$branch holds commits this machine never had; left in place"
    elif ! git push -q "$PEAL_REMOTE" --delete "$branch" 2>/dev/null; then
      peal_err "warning: could not delete $PEAL_REMOTE/$branch"
    fi
  fi
  echo "released $id $branch, tip kept as refs/reaped/$name"
}

peal_store_branch_task() {
  local branch
  _peal_files_settings || return 1
  branch=$(git symbolic-ref -q --short HEAD) || return 1
  [ "${branch#"$PEAL_PREFIX"}" != "$branch" ] || [ -z "$PEAL_PREFIX" ] || return 1
  [[ "${branch#"$PEAL_PREFIX"}" =~ ^([0-9][0-9][0-9][0-9])-[a-z0-9]+(-[a-z0-9]+)*$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# The task file under doing/ is what makes a worktree the task's: a branch alone may be
# a claim taken back, or one never made.
peal_store_session_task() {
  local id file
  _peal_files_settings || return 1
  id=$(peal_store_branch_task) || return 1
  for file in "$PEAL_TASKS/doing/$id"-*.md; do
    [ -f "$file" ] || return 1
    printf '%s\t%s\n' "$id" "$file"
    return 0
  done
}

peal_store_claim_worktrees() {
  _peal_files_settings || return 2
  git worktree list --porcelain | awk -v p="refs/heads/$PEAL_PREFIX" -v OFS='\t' '
    /^worktree / { path = substr($0, 10) }
    /^branch / {
      b = substr($0, 8)
      if (index(b, p) != 1) next
      rest = substr(b, length(p) + 1)
      if (rest ~ /^[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*$/) print substr(rest, 1, 4), substr(b, 12), path
    }'
}

peal_store_local_branch() {
  _peal_files_settings || return 2
  _peal_files_local_branch "$1"
}

# The claim's own copy: the task file under doing/ on the task's branch, committed there.
peal_store_record() {
  local id=$1 what=$2 text=$3 task file
  task=$(peal_store_session_task) || return 2
  file=$(_peal_field "$task" 2)
  cp "$text" "$file" || return 2
  peal_commit "docs(tasks): record the $what of $id [$id]" "$file"
}

# peal_store_milestone_text ID -> milestone ID's file as the main branch holds it.
peal_store_milestone_text() {
  local base file
  _peal_files_settings || return 2
  base=$(_peal_files_base) || return 2
  file=$(_peal_files_milestones_at "$base" | awk -F '\t' -v id="$1" '$1 == id { print $6 }') || return 2
  [ -n "$file" ] || { peal_err "no milestone $1"; return 2; }
  git show "$base:$file"
}

# _peal_files_build_ms_state BASE -> the milestone files of BASE rewritten: PEAL_MS_ID's
# state PEAL_MS_STATE, its reason PEAL_MS_REASON (parked only), PEAL_MS_REVIEW's text
# appended as its review; then, when no milestone is current, the first open one by
# order made current. PEAL_MS_REPORT says what changed; status 4 when nothing would.
_peal_files_build_ms_state() {
  local base=$1 root=$PEAL_MS_TMP/tree line file old next="" final args=()
  rm -rf "$root" && mkdir -p "$root" || return 2
  _peal_files_extract "$base" "$(peal_config_get milestones)" "$root" || return 2
  peal_ms_load "$root" || return 2
  line=$(printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' -v id="$PEAL_MS_ID" '$1 == id')
  [ -n "$line" ] || { peal_err "milestone-state: no milestone $PEAL_MS_ID on $PEAL_REMOTE/$PEAL_MAIN"; return 2; }
  file=$(_peal_field "$line" 6)
  old=$(_peal_field "$line" 3)
  if [ "$old" = "$PEAL_MS_STATE" ] || { [ "$old" = current ] && [ "$PEAL_MS_STATE" = open ]; }; then
    PEAL_MS_REPORT="milestone $PEAL_MS_ID: $old already, nothing changed"$'\n'
    return 4
  fi
  # The milestone that is current afterwards: the one there is, else the first open one.
  next=$(printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' -v id="$PEAL_MS_ID" -v st="$PEAL_MS_STATE" '
    { s = ($1 == id ? st : $3) }
    s == "current" { cur = $1 }
    s == "open" && first == "" { first = $1 }
    END { if (cur == "") print first }')
  final=$PEAL_MS_STATE
  [ "$next" != "$PEAL_MS_ID" ] || { final=current next=""; }
  cp "$root/$file" "$PEAL_MS_TMP/ms" || return 2
  peal_fm_set "$PEAL_MS_TMP/ms" state "$final" || return 2
  if [ "$final" = parked ] && [ -n "$PEAL_MS_REASON" ]; then
    peal_fm_set "$PEAL_MS_TMP/ms" reason "$PEAL_MS_REASON" || return 2
  else
    peal_fm_unset "$PEAL_MS_TMP/ms" reason || return 2
  fi
  if [ -n "$PEAL_MS_REVIEW" ]; then
    [ -z "$(tail -c 1 "$PEAL_MS_TMP/ms")" ] || echo >>"$PEAL_MS_TMP/ms"
    { printf '\n## Review, %s\n\n' "$(date -u +%Y-%m-%d)"
      cat "$PEAL_MS_REVIEW"
      [ -z "$(tail -c 1 "$PEAL_MS_REVIEW")" ] || echo
    } >>"$PEAL_MS_TMP/ms"
  fi
  args=(add "$file" "$PEAL_MS_TMP/ms")
  PEAL_SUBJECT="docs(tasks): milestone $PEAL_MS_ID $final"
  PEAL_MS_REPORT="milestone $PEAL_MS_ID: $final"$'\n'
  if [ -n "$next" ]; then
    file=$(printf '%s\n' "$PEAL_MILESTONES" | awk -F '\t' -v id="$next" '$1 == id { print $6 }')
    cp "$root/$file" "$PEAL_MS_TMP/next" && peal_fm_set "$PEAL_MS_TMP/next" state current || return 2
    args+=(add "$file" "$PEAL_MS_TMP/next")
    PEAL_SUBJECT="$PEAL_SUBJECT, $next current"
    PEAL_MS_REPORT="${PEAL_MS_REPORT}milestone $next: current"$'\n'
  fi
  peal_write_tree "$base" "${args[@]}"
}

# The milestone files rewritten on the main branch, in one commit
# "docs(tasks): milestone ID STATE[, NEXT current]".
peal_store_milestone_state() {
  local tmp status=0
  _peal_files_settings || return 2
  _peal_files_fetch || return 2
  tmp=$(mktemp -d) || return 2
  PEAL_MS_ID=$1 PEAL_MS_STATE=$2 PEAL_MS_REASON=$3 PEAL_MS_REVIEW=$4 PEAL_MS_TMP=$tmp PEAL_MS_REPORT=""
  peal_push_main _peal_files_build_ms_state milestone-state || status=$?
  [ $status = 4 ] && status=0
  if peal_main_write_written $status; then
    printf '%s' "$PEAL_MS_REPORT"
    peal_main_write_report
  fi
  rm -rf "$tmp"
  return $status
}
