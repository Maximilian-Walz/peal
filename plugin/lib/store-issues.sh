# shellcheck shell=bash
# The issues storage (lib/store.sh has the interface): a task is one of the repository's
# GitHub issues, its id the issue's number, read and written with `gh api`. What an
# issue says as a task (lib/issues-lib.awk): its milestone; "Depends on #3, #7" and
# "Part of #3" lines in its body; labels "needs: <capability>", "size: M", "plan:
# required", "model: opus", "priority: high", "owner: human", "breaking: true",
# "release-note: none", "touches: docs/api.md", "merge: auto" and "<field>: <value>" for the project's
# own fields.
#
# A claim is Belfry's, so that either recognises the other's: the label "in progress",
# the branch issue/N in the worktree {worktrees}/issue-N (continuing the remote's
# issue/N when an earlier session pushed one). The label is no lock: two claims in the
# same moment can both add it. The states:
#
#   done            the issue is closed
#   awaiting-merge  an open pull request says "Fixes #N" (closes, resolves ...), opened
#                   from this repository or by someone with write access
#   claimed-live    issue/N has a worktree here, or the issue carries the label
#   parked          a local issue/N ahead of main without a worktree
#   blocked, free   as for every storage (lib/task-state.awk)
#
# The tasks are the open issues and the 100 closed most recently, with the filter label
# (storage.issues.label) when one is set, else those opened by someone with write
# access; an issue a task depends on beyond those is read on its own.

PEAL_ISSUES_CLAIMED="in progress"
PEAL_ISSUES_CLOSED=${PEAL_ISSUES_CLOSED:-100}
# One issue's fields as issues-lib.awk reads them.
PEAL_ISSUES_ROW='[(.number | tostring), .state, .title, (.milestone.title // ""), ([.labels[].name] | join(",")), (.author_association // ""), .html_url, (.body // "")] | @tsv'

# _peal_issues_settings -> PEAL_REMOTE, PEAL_MAIN, PEAL_LABEL and PEAL_REPO (owner/name:
# peal_github_repo) from the settings. A warning when main-writes is set to something but
# its default while nothing writes onto main: issues live on GitHub, and only the
# decisions module publishes onto main.
_peal_issues_settings() {
  PEAL_REMOTE=$(peal_config_get remote) || return 2
  PEAL_MAIN=$(peal_config_get main) || return 2
  PEAL_LABEL=$(peal_config_get storage.issues.label) || return 2
  PEAL_REPO=$(peal_github_repo) || return 2
  if [ "$(peal_config_get main-writes)" != auto ] && [ "$(peal_config_get decisions)" = false ]; then
    peal_err "warning: main-writes does nothing here: the issues storage writes no task onto $PEAL_MAIN"
  fi
}

# _peal_issues_issue N -> issue N as an issues-lib.awk row; status 2 if it cannot be read.
_peal_issues_issue() {
  peal_gh "repos/$PEAL_REPO/issues/$1" --jq "$PEAL_ISSUES_ROW"
}

# _peal_issues_listed -> the rows of the issues that are tasks: open ones, and the most
# recently updated closed ones.
_peal_issues_listed() {
  local q="per_page=100"
  [ -z "$PEAL_LABEL" ] || q="$q&labels=$(peal_urlencode "$PEAL_LABEL")"
  peal_gh --paginate "repos/$PEAL_REPO/issues?state=open&$q" \
    --jq ".[] | select(.pull_request == null) | $PEAL_ISSUES_ROW" || return 2
  peal_gh "repos/$PEAL_REPO/issues?state=closed&sort=updated&direction=desc&${q/per_page=100/per_page=$PEAL_ISSUES_CLOSED}" \
    --jq ".[] | select(.pull_request == null) | $PEAL_ISSUES_ROW" || return 2
}

# _peal_issues_prs -> issues-prs.awk's lines for the open pull requests that may close an
# issue: from a branch of the repository itself, or by someone with write access.
_peal_issues_prs() {
  peal_gh --paginate "repos/$PEAL_REPO/pulls?state=open&per_page=100" --jq '.[]
    | select(.head.repo.full_name == .base.repo.full_name or .author_association == "OWNER"
        or .author_association == "MEMBER" or .author_association == "COLLABORATOR")
    | [(.number | tostring), .html_url, (.draft | tostring), (.body // "")] | @tsv' \
    | awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" -f "$PEAL_ROOT/lib/issues-prs.awk"
  return "${PIPESTATUS[0]}"
}

# _peal_issues_scan DIR -> DIR/scan: issues-scan.awk's records for the tasks and the
# issues their depends and part-of name, by id.
_peal_issues_scan() {
  local dir=$1 n
  _peal_issues_listed >"$dir/listed" || return 2
  : >"$dir/extra"
  _peal_issues_scan_awk "$dir"
  # What a task names but the listing left out: an older closed issue, most likely.
  for n in $(awk -F '\t' '$15 == "" { print $7 "," $8 }' "$dir/scan" | tr ',' '\n' | grep -E '^[0-9]+$' | sort -un); do
    awk -F '\t' -v n="$n" '$1 == n { found = 1 } END { exit !found }' "$dir/scan" && continue
    _peal_issues_issue "$n" >>"$dir/extra" 2>/dev/null || true
  done
  [ ! -s "$dir/extra" ] || _peal_issues_scan_awk "$dir"
}

_peal_issues_scan_awk() {
  awk -F '\t' -v label="$PEAL_LABEL" -v claimed="$PEAL_ISSUES_CLAIMED" -f "$PEAL_ROOT/lib/issues-lib.awk" \
    -f "$PEAL_ROOT/lib/issues-scan.awk" "$1/listed" "$1/extra" | LC_ALL=C sort -t "$(printf '\t')" -k1,1n >"$1/scan"
}

# _peal_issues_base -> the remote's main branch, else the local one; status 1 if neither.
_peal_issues_base() {
  git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null && { printf '%s\n' "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN"; return; }
  git rev-parse --verify -q "refs/heads/$PEAL_MAIN" >/dev/null && { printf '%s\n' "refs/heads/$PEAL_MAIN"; return; }
  return 1
}

# _peal_issues_claims SCAN PRS -> task-state.awk's claims for the open issues (SCAN's
# records) from their pull requests (PRS, issues-prs.awk's lines), the label and the
# refs: "id<TAB>state<TAB>detail<TAB>ref<TAB>pr".
_peal_issues_claims() {
  local scan=$1 prs=$2 base id labelled pr url draft wt lb rb detail ahead worktrees
  base=$(_peal_issues_base) || base=""
  worktrees=$(peal_store_claim_worktrees)
  {
    awk -F '\t' '$2 != "done" && $15 == "" && $14 == 1 { print $1 }' "$scan"
    cut -f1 "$prs"
    printf '%s\n' "$worktrees" | cut -f1
    git for-each-ref --format='%(refname:lstrip=3)' 'refs/heads/issue/*'
  } | grep -E '^[0-9]+$' | sort -un | while IFS= read -r id; do
    awk -F '\t' -v id="$id" '$1 == id && $2 != "done" && $15 == "" { found = 1 } END { exit !found }' "$scan" || continue
    labelled=$(awk -F '\t' -v id="$id" '$1 == id { print $14 }' "$scan")
    lb="" rb="" wt=""
    git rev-parse -q --verify "refs/heads/issue/$id" >/dev/null && lb=issue/$id
    git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/issue/$id" >/dev/null && rb=issue/$id
    [ -z "$lb" ] || wt=$(printf '%s\n' "$worktrees" | awk -F '\t' -v id="$id" '$1 == id { p = $3 } END { print p }')
    [ -z "$wt" ] || [ -d "$wt" ] || wt=""
    if IFS="$(printf '\t')" read -r _ pr url draft < <(awk -F '\t' -v id="$id" '$1 == id' "$prs") && [ -n "$pr" ]; then
      detail="pr:$pr $url"
      [ "$draft" != true ] || detail="$detail draft"
      [ -z "$wt" ] || detail="$detail wt:$wt"
      if [ -n "$lb" ] && { [ -z "$rb" ] || [ "$(git rev-list --count "refs/remotes/$PEAL_REMOTE/$rb..refs/heads/$lb")" -gt 0 ]; }; then
        detail="$detail unpushed"
      fi
      printf '%s\tawaiting-merge\t%s\t%s\t%s\n' "$id" "$detail" "issue/$id" "$pr"
    elif [ -n "$wt" ]; then
      printf '%s\tclaimed-live\twt:%s\t%s\t\n' "$id" "$wt" "$lb"
    elif [ -n "$lb" ] && [ -n "$base" ] && ahead=$(git rev-list --count "$base..refs/heads/$lb") && [ "$ahead" -gt 0 ]; then
      printf '%s\tparked\t%s commit(s) ahead, last %s\t%s\t\n' "$id" "$ahead" \
        "$(git log -1 --format=%cd --date=short "refs/heads/$lb")" "$lb"
    elif [ "$labelled" = 1 ]; then
      if [ -n "$rb" ]; then detail="remote:$PEAL_REMOTE"; else detail=labelled; fi
      printf '%s\tclaimed-live\t%s\t%s\t\n' "$id" "$detail" "issue/$id"
    fi
  done
}

# An issue's state depends on its pull requests: --no-pr is taken, and the pull requests
# read all the same.
peal_store_list() {
  local fetch=0 tmp status=0
  while [ $# -gt 0 ]; do
    case $1 in
      --fetch) fetch=1 ;;
      --no-pr) ;;
      *) peal_err "list: unknown option $1"; return 2 ;;
    esac
    shift
  done
  _peal_issues_settings || return 2
  if [ $fetch = 1 ] && ! git fetch -q "$PEAL_REMOTE" 2>/dev/null; then
    peal_err "warning: could not fetch $PEAL_REMOTE; reading what is known here"
  fi
  tmp=$(mktemp -d) || return 2
  if _peal_issues_scan "$tmp" && _peal_issues_prs >"$tmp/prs"; then
    _peal_issues_claims "$tmp/scan" "$tmp/prs" >"$tmp/claims"
    cut -f1-13,16-19 "$tmp/scan" >"$tmp/tasks"
    awk -F '\t' -v idprefix="#" -f "$PEAL_ROOT/lib/task-state.awk" "$tmp/claims" "$tmp/tasks" >"$tmp/out" || status=2
    # The issues read only for their state are no tasks.
    [ $status != 0 ] || awk -F '\t' 'NR == FNR { if ($15 == 1) extra[$1] = 1; next } !($1 in extra)' "$tmp/scan" "$tmp/out"
  else
    status=2
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_issues_milestone_rows -> "number<TAB>title<TAB>state<TAB>due_on<TAB>description<TAB>url"
# per milestone of the repository.
_peal_issues_milestone_rows() {
  peal_gh --paginate "repos/$PEAL_REPO/milestones?state=all&per_page=100" \
    --jq '.[] | [(.number | tostring), .title, .state, (.due_on // ""), (.description // ""), .html_url] | @tsv'
}

peal_store_milestones() {
  local rows
  _peal_issues_settings || return 2
  rows=$(_peal_issues_milestone_rows) || return 2
  [ -n "$rows" ] || return 0
  printf '%s\n' "$rows" | awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" -f "$PEAL_ROOT/lib/issues-milestones.awk"
}

# _peal_issues_fields -> the project's own fields (task.fields), comma-joined.
_peal_issues_fields() {
  peal_check_context | awk -F '\t' '$1 == "field" { s = s (s == "" ? "" : ",") $2 } END { print s }'
}

# _peal_issues_text ROW -> the task text of the issue in ROW (lib/issues-text.awk).
_peal_issues_text() {
  printf '%s\n' "$1" | awk -F '\t' -v label="$PEAL_LABEL" -v claimed="$PEAL_ISSUES_CLAIMED" \
    -v fields="$(_peal_issues_fields)" -f "$PEAL_ROOT/lib/yaml-render.awk" \
    -f "$PEAL_ROOT/lib/issues-lib.awk" -f "$PEAL_ROOT/lib/issues-text.awk"
}

peal_store_read() {
  local row
  if ! [[ "${1-}" =~ ^[0-9]+$ ]]; then
    peal_err "read: '${1-}' is no issue number"
    return 2
  fi
  _peal_issues_settings || return 2
  row=$(_peal_issues_issue "$1") || { peal_err "no task $1"; return 2; }
  _peal_issues_text "$row"
}

# _peal_issues_managed LABEL -> status 0 for a label the task text's frontmatter owns:
# needs, size, plan, model, priority, owner, merge, breaking, release-note, touches and the
# project's fields, as "<key>: <value>".
_peal_issues_managed() {
  local key
  case $1 in *:*) ;; *) return 1 ;; esac
  key=$(printf '%s' "${1%%:*}" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')
  case ",needs,size,plan,model,priority,owner,merge,breaking,release-note,touches,$PEAL_FIELDS," in *",$key,"*) return 0 ;; esac
  return 1
}

# _peal_issues_from_text FILE ID DIR -> the issue the task text in FILE (headed "# ID —
# Title") makes: DIR/title, DIR/body (its "Part of" and "Depends on" lines, then the
# text after the heading), DIR/labels (one per line) and DIR/milestone.
_peal_issues_from_text() {
  local file=$1 id=$2 dir=$3 key item deps="" part
  peal_text_title "$id" <"$file" >"$dir/title" || return 2
  : >"$dir/labels"
  for key in plan size model breaking release-note $(printf '%s' "$PEAL_FIELDS" | tr ',' ' '); do
    peal_fm_get "$file" "$key" 2>/dev/null | while IFS= read -r item; do
      [ -z "$item" ] || printf '%s: %s\n' "$key" "$item"
    done >>"$dir/labels"
  done
  item=$(peal_fm_get "$file" priority 2>/dev/null)
  case $item in urgent | high | low) printf 'priority: %s\n' "$item" >>"$dir/labels" ;; esac
  [ "$(peal_fm_get "$file" owner 2>/dev/null)" != human ] || printf 'owner: human\n' >>"$dir/labels"
  [ "$(peal_fm_get "$file" merge 2>/dev/null)" != auto ] || printf 'merge: auto\n' >>"$dir/labels"
  for key in needs touches; do
    peal_fm_get "$file" "$key" 2>/dev/null | while IFS= read -r item; do
      [ -z "$item" ] || printf '%s: %s\n' "$key" "$item"
    done >>"$dir/labels"
  done
  peal_fm_get "$file" milestone >"$dir/milestone" 2>/dev/null || : >"$dir/milestone"
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    case $item in [0-9]*) item="#$item" ;; esac
    deps=${deps:+$deps, }$item
  done < <(peal_fm_get "$file" depends 2>/dev/null)
  part=$(peal_fm_get "$file" part-of 2>/dev/null)
  {
    [ -z "$part" ] || printf 'Part of #%s\n' "$part"
    [ -z "$deps" ] || printf 'Depends on %s\n' "$deps"
    [ -z "$part$deps" ] || echo
  } >"$dir/body"
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm { if ($0 == "---") fm = 0; next }
    !head { if (/^# /) head = 1; next }
    { lines[++n] = $0 }
    END {
      first = 1
      while (first <= n && lines[first] ~ /^[ \t]*$/) first++
      last = n
      while (last >= first && lines[last] ~ /^[ \t]*$/) last--
      for (j = first; j <= last; j++) print lines[j]
    }' "$file" >>"$dir/body"
  return 0
}

# _peal_issues_milestone_number TITLE -> the number of the milestone titled TITLE, from
# PEAL_MS_ROWS; status 1 if there is none.
_peal_issues_milestone_number() {
  PEAL_MS_FIND=$1 awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" -f "$PEAL_ROOT/lib/issues-milestones.awk" <<<"$PEAL_MS_ROWS"
}

# _peal_issues_context DIR TEXT... -> DIR/context, task-check.awk's CONTEXT for filing
# the TEXTs: the milestones, the tasks, and the issues the TEXTs' depends name. Sets
# PEAL_MS_ROWS and PEAL_RECORDS (the list records).
_peal_issues_context() {
  local dir=$1 file n
  shift
  PEAL_MS_ROWS=$(_peal_issues_milestone_rows) || return 2
  PEAL_RECORDS=$(peal_store_list --fetch) || return 2
  {
    peal_check_context
    [ -z "$PEAL_MS_ROWS" ] || printf '%s\n' "$PEAL_MS_ROWS" \
      | awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" -f "$PEAL_ROOT/lib/issues-milestones.awk" \
      | awk -F '\t' '{ print "ms\t" $1 "\t" $3 }'
    [ -z "$PEAL_RECORDS" ] || printf '%s\n' "$PEAL_RECORDS" | cut -f1 | sed 's/^/id\t/'
  } >"$dir/context"
  for file in "$@"; do
    peal_fm_get "$file" depends 2>/dev/null
  done | grep -E '^[0-9]+$' | sort -un | while IFS= read -r n; do
    grep -q "^id	$n\$" "$dir/context" && continue
    _peal_issues_issue "$n" >/dev/null 2>&1 && printf 'id\t%s\n' "$n" >>"$dir/context"
  done
  return 0
}

# _peal_issues_post DIR [NUMBER] -> the issue DIR describes created (NUMBER empty) or its
# title, body and milestone set; the new issue's "number<TAB>url" for a creation.
_peal_issues_post() {
  local dir=$1 n=${2-} ms="null" labels
  if [ -s "$dir/milestone" ]; then
    ms=$(_peal_issues_milestone_number "$(cat "$dir/milestone")") || {
      peal_err "no milestone $(cat "$dir/milestone")"; return 2; }
  fi
  if [ -z "$n" ]; then
    labels=$(cat "$dir/labels")
    [ -z "$PEAL_LABEL" ] || labels=$(printf '%s\n%s\n' "$PEAL_LABEL" "$labels")
    peal_json s:title "$(cat "$dir/title")" f:body "$dir/body" l:labels "$labels" r:milestone "$ms" \
      | peal_gh --method POST "repos/$PEAL_REPO/issues" --input - --jq '[(.number | tostring), .html_url] | @tsv'
  else
    peal_json s:title "$(cat "$dir/title")" f:body "$dir/body" r:milestone "$ms" \
      | peal_gh --method PATCH "repos/$PEAL_REPO/issues/$n" --input - --jq '.number' >/dev/null
  fi
}

# peal_store_create MODE ORIGIN SLUG... -> the tasks whose texts are on stdin (as for
# task files) opened as issues, a line each: "filed N URL — milestone: M, plan: P,
# size: S — "Title"". The frontmatter goes to the milestone, labels and reference lines;
# NNNN, ORIGIN and PART1..n become the numbers GitHub gives, a text naming a number not
# known when its issue opens is edited once they all are. The slugs name nothing on
# GitHub; they are checked all the same. A batch's issues say where they were found.
peal_store_create() {
  local mode=$1 origin=$2 count i k status=0 summary text row created urls titles texts dirs
  created=() urls=() titles=() texts=()
  shift 2
  case $mode in
    plain) [ $# -eq 1 ] || { peal_err "create: one slug"; return 2; } ;;
    split | batch)
      [[ "$origin" =~ ^[0-9]+$ ]] || { peal_err "create: '$origin' is no issue number"; return 2; } ;;
    *) peal_err "create: unknown mode $mode"; return 2 ;;
  esac
  [ $# -ge 1 ] || { peal_err "create: no slug"; return 2; }
  _peal_issues_settings || return 2
  PEAL_FIELDS=$(_peal_issues_fields)
  count=$#
  peal_create_texts "$@" || status=2
  dirs=$PEAL_CREATE_DIR
  if [ $status = 0 ]; then
    texts=()
    for ((i = 1; i <= count; i++)); do texts+=("$dirs/$i"); done
    _peal_issues_context "$dirs" "${texts[@]}" || status=2
  fi
  if [ $status = 0 ] && [ "$mode" != plain ] && ! grep -q "^id	$origin\$" "$dirs/context"; then
    peal_err "create: task $origin does not exist"
    status=2
  fi
  PEAL_CREATE_SUMMARY=()
  for ((i = 1; i <= count && status == 0; i++)); do
    if summary=$(peal_task_check "$dirs/$i" "$mode" "${PEAL_CREATE_SLUGS[i - 1]}" "$dirs/context" "$i" "$count"); then
      PEAL_CREATE_SUMMARY+=("$summary")
    else
      status=2
    fi
  done
  if [ $status = 0 ]; then
    peal_cycle_check_create "$mode" "$origin" "$count" "$dirs" "$PEAL_RECORDS" || status=$?
  fi
  # Open them, ORIGIN known already.
  for ((i = 1; i <= count && status == 0; i++)); do
    text=$(cat "$dirs/$i")
    [ "$mode" != split ] || text=${text//ORIGIN/$origin}
    printf '%s\n' "$text" >"$dirs/text$i"
    if [ "$mode" = batch ] && peal_text_has_section Notes <"$dirs/text$i"; then
      peal_text_add_note "Found while working on #$origin." <"$dirs/text$i" >"$dirs/noted$i" && mv "$dirs/noted$i" "$dirs/text$i"
    fi
    mkdir -p "$dirs/issue$i"
    if ! _peal_issues_from_text "$dirs/text$i" NNNN "$dirs/issue$i"; then
      status=2
      break
    fi
    if ! row=$(_peal_issues_post "$dirs/issue$i"); then
      status=1
      break
    fi
    created+=("${row%%	*}")
    urls+=("${row#*	}")
  done
  # Then every issue whose text named a number not known when it opened, again.
  for ((i = 1; i <= ${#created[@]} && status == 0; i++)); do
    text=$(cat "$dirs/text$i")
    text=${text//NNNN/${created[i - 1]}}
    for ((k = count; k >= 1; k--)); do
      text=${text//PART$k/${created[k - 1]}}
    done
    printf '%s\n' "$text" >"$dirs/final$i"
    mkdir -p "$dirs/final-issue$i"
    _peal_issues_from_text "$dirs/final$i" "${created[i - 1]}" "$dirs/final-issue$i" || { status=2; break; }
    titles+=("$(cat "$dirs/final-issue$i/title")")
    if ! cmp -s "$dirs/issue$i/title" "$dirs/final-issue$i/title" || ! cmp -s "$dirs/issue$i/body" "$dirs/final-issue$i/body"; then
      _peal_issues_post "$dirs/final-issue$i" "${created[i - 1]}" || status=1
    fi
  done
  for ((i = 0; i < ${#created[@]}; i++)); do
    PEAL_TITLE=${titles[i]-$(cat "$dirs/issue$((i + 1))/title")} awk -F '\t' -v id="${created[i]}" -v url="${urls[i]}" '
      function f(v) { return v == "" ? "-" : v }
      { printf "filed %s %s — milestone: %s, plan: %s, size: %s — \"%s\"\n", id, url, f($1), f($2), f($3), ENVIRON["PEAL_TITLE"] }' \
      <<<"${PEAL_CREATE_SUMMARY[i]}"
  done
  if [ $status != 0 ] && [ ${#created[@]} = 0 ] && [ -s "$dirs/1" ]; then
    peal_err "nothing was filed"
  elif [ $status != 0 ] && [ ${#created[@]} != 0 ]; then
    peal_err "create: stopped after filing ${created[*]}; the rest is not filed"
  fi
  rm -rf "$dirs"
  return $status
}

# _peal_issues_unclaimed ID VERB -> PEAL_RECORDS (the list) and PEAL_RECORD (task ID's) if
# task ID is open and nobody has claimed it; else status 2 and why.
_peal_issues_unclaimed() {
  local id=$1 verb=$2 state detail
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    peal_err "$verb: '$id' is no issue number"
    return 2
  fi
  _peal_issues_settings || return 2
  PEAL_RECORDS=$(peal_store_list --fetch) || return 2
  PEAL_RECORD=$(printf '%s\n' "$PEAL_RECORDS" | awk -F '\t' -v id="$id" '$1 == id')
  if [ -z "$PEAL_RECORD" ]; then
    peal_err "$verb: no task $id"
    return 2
  fi
  state=$(_peal_field "$PEAL_RECORD" 2)
  detail=$(_peal_field "$PEAL_RECORD" 3)
  case $state in
    free | blocked) ;;
    done) peal_err "$verb: task $id is done"; return 2 ;;
    *) peal_err "$verb: task $id is $state ($detail); $verb touches only a task nobody has claimed"; return 2 ;;
  esac
}

# _peal_issues_comment ID TEXT -> TEXT as a comment on issue ID.
_peal_issues_comment() {
  peal_json s:body "$2" | peal_gh --method POST "repos/$PEAL_REPO/issues/$1/comments" --input - --jq '.id' >/dev/null
}

# _peal_issues_labels ID OLD NEW -> the labels of issue ID the task text manages brought
# from those in OLD to those in NEW (one per line each); others are left alone.
_peal_issues_labels() {
  local id=$1 add remove l
  add=$(comm -13 <(printf '%s\n' "$2" | sed '/^$/d' | sort -u) <(printf '%s\n' "$3" | sed '/^$/d' | sort -u))
  remove=$(comm -23 <(printf '%s\n' "$2" | sed '/^$/d' | sort -u) <(printf '%s\n' "$3" | sed '/^$/d' | sort -u))
  if [ -n "$add" ]; then
    peal_json l:labels "$add" \
      | peal_gh --method POST "repos/$PEAL_REPO/issues/$id/labels" --input - --jq 'length' >/dev/null || return 2
  fi
  while IFS= read -r l; do
    [ -z "$l" ] || peal_gh --method DELETE "repos/$PEAL_REPO/issues/$id/labels/$(peal_urlencode "$l")" >/dev/null || return 2
  done <<<"$remove"
}

# _peal_issues_current_labels ID -> the labels of issue ID the task text manages.
_peal_issues_current_labels() {
  local l
  peal_gh "repos/$PEAL_REPO/issues/$1" --jq '.labels[].name' | while IFS= read -r l; do
    _peal_issues_managed "$l" && printf '%s\n' "$l"
  done
  return "${PIPESTATUS[0]}"
}

# _peal_issues_rewrite VERB ID OLD NEW DIR -> the checks on the rewritten task text NEW
# of issue ID (OLD the one before), peal_edit_check's and task-check.awk's in revise
# mode, then peal_cycle_check's, and DIR/issue made from NEW. Status 2 with every problem
# reported, 1 for a cycle.
_peal_issues_rewrite() {
  local verb=$1 id=$2 old=$3 new=$4 dir=$5 status=0
  PEAL_FIELDS=$(_peal_issues_fields)
  peal_edit_check "$verb" "$old" "$new" "issue $id" || status=2
  _peal_issues_context "$dir" "$new" || status=2
  PEAL_CHECK_ID=$id PEAL_CHECK_OLDMS=$(peal_fm_get "$old" milestone 2>/dev/null) \
    peal_task_check "$new" revise "issue $id" "$dir/context" >/dev/null || status=2
  [ $status != 0 ] || peal_cycle_check_text "$verb" "$id" "$new" "$PEAL_RECORDS" || status=$?
  if [ $status = 0 ]; then
    mkdir -p "$dir/issue"
    _peal_issues_from_text "$new" "$id" "$dir/issue" || status=2
  fi
  return $status
}

# _peal_issues_apply ID ROW DIR NOTE -> issue ID, as ROW read it, rewritten from DIR/issue
# (title, body, milestone, the labels the text owns) and NOTE as a comment. An edit
# replaces text it does not own: a change since ROW is refused, not overwritten.
_peal_issues_apply() {
  local id=$1 row=$2 dir=$3 note=$4 now
  if ! now=$(_peal_issues_issue "$id") || [ "$now" != "$row" ]; then
    peal_err "issue $id changed meanwhile; read it again and run again"
    return 2
  fi
  _peal_issues_post "$dir/issue" "$id" \
    && _peal_issues_labels "$id" "$(_peal_issues_current_labels "$id")" "$(cat "$dir/issue/labels")" \
    && _peal_issues_comment "$id" "$note" || return 1
}

# peal_store_edit ID REASON [--dry-run] -> the unclaimed issue's text replaced by the one
# on stdin: its title, body, milestone and the labels its frontmatter owns, and REASON as
# a comment "Revised <date>: REASON"; --dry-run prints the change instead. Refused as for
# task files (a changed heading number, Raw section or part-of, an Outcome filled or its
# heading added or dropped, no change at all, whatever task-check.awk refuses), and when
# the issue changed since it was read.
peal_store_edit() {
  local id=$1 reason=$2 dry=${3-} tmp status=0 row note
  [ -n "$reason" ] || { peal_err "revise: give a reason"; return 2; }
  _peal_issues_unclaimed "$id" revise || return 2
  tmp=$(mktemp -d) || return 2
  if ! row=$(_peal_issues_issue "$id"); then
    rm -rf "$tmp"
    return 2
  fi
  if [ "$(_peal_field "$row" 2)" != open ]; then
    peal_err "revise: issue $id is closed"
    rm -rf "$tmp"
    return 2
  fi
  _peal_issues_text "$row" >"$tmp/old"
  cat >"$tmp/new"
  if cmp -s "$tmp/old" "$tmp/new"; then
    peal_err "revise: the text is the same as issue $id's: nothing to revise"
    status=2
  fi
  [ $status != 0 ] || _peal_issues_rewrite revise "$id" "$tmp/old" "$tmp/new" "$tmp" || status=$?
  note="Revised $(date -u +%Y-%m-%d): $reason"
  if [ $status = 0 ] && [ "$dry" = --dry-run ]; then
    (cd "$tmp" && diff -u old new)
    echo "comment: $note"
    echo "revise: a dry run; nothing changed"
  elif [ $status = 0 ]; then
    if _peal_issues_apply "$id" "$row" "$tmp" "$note"; then
      echo "revised $id $(_peal_field "$row" 7)"
    else
      status=$?
    fi
  fi
  rm -rf "$tmp"
  return $status
}

# peal_store_defer ID REASON TEXT [--dry-run] -> the claim of issue ID, checked out here,
# given back: the issue rewritten from the task text in the file TEXT as a revise would,
# and "Deferred <date> after a claim: REASON" as a comment. Refused: another branch, any
# commit on it beyond the remote's main (an issue's claim makes none, so a commit is
# work), its remote branch holding more, anything uncommitted, a closed issue, and the
# checks of a revise but "no change".
peal_store_defer() {
  local id=$1 reason=$2 text=$3 dry=${4-} base work tmp row status=0 note
  [ -n "$reason" ] || { peal_err "defer: give a reason"; return 2; }
  _peal_issues_settings || return 2
  if [ "$(peal_store_branch_task)" != "$id" ]; then
    peal_err "defer: not on issue $id's branch (issue/$id), but on $(git symbolic-ref -q --short HEAD || echo a detached HEAD)"
    return 2
  fi
  git fetch -q "$PEAL_REMOTE" 2>/dev/null
  base=refs/remotes/$PEAL_REMOTE/$PEAL_MAIN
  git rev-parse -q --verify "$base" >/dev/null || { peal_err "defer: no $PEAL_REMOTE/$PEAL_MAIN"; return 2; }
  work=$(git log --format='%h %s' HEAD --not "$base")
  if [ -n "$work" ]; then
    peal_err "defer: issue/$id holds work beyond $PEAL_REMOTE/$PEAL_MAIN:"
    printf '%s\n' "$work" | head -n 5 | sed 's/^/  /' >&2
    peal_err "work ends through its close, with a pull request; defer only gives back a claim nothing was built on"
    return 2
  fi
  if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/issue/$id" >/dev/null \
      && ! git merge-base --is-ancestor "refs/remotes/$PEAL_REMOTE/issue/$id" HEAD; then
    peal_err "defer: $PEAL_REMOTE/issue/$id holds commits this worktree does not have"
    return 2
  fi
  if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
    peal_err "defer: uncommitted changes, which would go with the claim:"
    git status --porcelain --untracked-files=all | cut -c4- | sed 's/^/  /' >&2
    return 2
  fi
  row=$(_peal_issues_issue "$id") || return 2
  if [ "$(_peal_field "$row" 2)" != open ]; then
    peal_err "defer: issue $id is closed"
    return 2
  fi
  tmp=$(mktemp -d) || return 2
  _peal_issues_text "$row" >"$tmp/old"
  cp "$text" "$tmp/new"
  _peal_issues_rewrite defer "$id" "$tmp/old" "$tmp/new" "$tmp" || status=$?
  note="Deferred $(date -u +%Y-%m-%d) after a claim: $reason"
  if [ $status = 0 ] && [ "$dry" = --dry-run ]; then
    (cd "$tmp" && diff -u old new)
    echo "comment: $note"
    echo "defer: a dry run; nothing changed"
  elif [ $status = 0 ]; then
    # An unchanged text changes nothing on the issue; the comment says why it came back.
    if cmp -s "$tmp/old" "$tmp/new"; then
      _peal_issues_comment "$id" "$note" || status=1
    else
      _peal_issues_apply "$id" "$row" "$tmp" "$note" || status=$?
    fi
    [ $status != 0 ] || echo "deferred $id $(_peal_field "$row" 7)"
  fi
  rm -rf "$tmp"
  return $status
}

peal_store_set_milestone() {
  local id=$1 m=${2-} state ms=null current
  _peal_issues_unclaimed "$id" set-milestone || return 2
  current=$(_peal_field "$PEAL_RECORD" 6)
  if [ "$current" = "$m" ]; then
    peal_err "set-milestone: issue $id's milestone is ${m:-none} already: nothing to change"
    return 2
  fi
  PEAL_MS_ROWS=$(_peal_issues_milestone_rows) || return 2
  if [ -n "$m" ]; then
    state=$(printf '%s\n' "$PEAL_MS_ROWS" | awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" \
      -f "$PEAL_ROOT/lib/issues-milestones.awk" | awk -F '\t' -v m="$m" '$1 == m { print $3 }')
    case $state in
      "") peal_err "set-milestone: milestone $m does not exist"; return 2 ;;
      done) peal_err "set-milestone: milestone $m is done"; return 2 ;;
    esac
    ms=$(_peal_issues_milestone_number "$m") || return 2
  fi
  peal_json r:milestone "$ms" | peal_gh --method PATCH "repos/$PEAL_REPO/issues/$id" --input - --jq '.number' >/dev/null || return 1
  echo "task $id: milestone ${m:-none}"
}

# A comment is a comment, whoever holds the issue.
peal_store_comment() {
  local id=$1
  if [ -z "${2-}" ]; then
    peal_err "comment: no text"
    return 2
  fi
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    peal_err "comment: '$id' is no issue number"
    return 2
  fi
  _peal_issues_settings || return 2
  _peal_issues_comment "$id" "$2" || return 1
  echo "task $id: noted"
}

# _peal_issues_retire ID REASON -> the unclaimed issue ID closed as not planned, the dated
# REASON its last comment. Refused while a task not done names it in depends or part-of.
_peal_issues_retire() {
  local id=$1 reason=$2 dependents
  [ -n "$reason" ] || { peal_err "retire: give a reason"; return 2; }
  _peal_issues_unclaimed "$id" retire || return 2
  dependents=$(printf '%s\n' "$PEAL_RECORDS" | awk -F '\t' -v id="$id" '
    $2 != "done" && $1 != id && (index("," $7 ",", "," id ",") || $8 == id) {
      print "  " $1 " " $4 (index("," $7 ",", "," id ",") ? " (depends)" : " (part-of)") }')
  if [ -n "$dependents" ]; then
    peal_err "retire: task $id is still named by:"
    printf '%s\n' "$dependents" >&2
    peal_err "re-point those (peal revise) before retiring $id"
    return 2
  fi
  _peal_issues_comment "$id" "Retired $(date -u +%Y-%m-%d) without being claimed: $reason" || return 1
  peal_json s:state closed s:state_reason not_planned \
    | peal_gh --method PATCH "repos/$PEAL_REPO/issues/$id" --input - --jq '.number' >/dev/null || return 1
  echo "retired $id $(_peal_field "$PEAL_RECORD" 15)"
}

# _peal_issues_finish_done ID -> on the issue's own branch, what closes it: the pull
# request's body says "Fixes #ID", and its merge closes the issue.
_peal_issues_finish_done() {
  local id=$1 own
  _peal_issues_settings || return 2
  own=$(peal_store_branch_task) || own=""
  if [ "$own" != "$id" ]; then
    peal_err "finish: not on issue $id's branch (issue/$id), but on $(git symbolic-ref -q --short HEAD || echo a detached HEAD)"
    return 2
  fi
  echo "finished $id: the pull request's body says \"Fixes #$id\"; its merge closes the issue"
}

# An issue has no Outcome section of its own: the close writes it in the worktree's git
# directory, and the pull request's body carries it.
peal_store_close_text() {
  local file
  file=$(git rev-parse --absolute-git-dir)/peal-outcome.md || return 2
  if [ ! -e "$file" ]; then
    printf '%s\n' "## Outcome" "" \
      "<!-- Written at close, replacing this comment: what was built, what was decided, what was" \
      "     found and left (each a new task), and what the next session needs to know. -->" >"$file" || return 2
  fi
  printf '%s\n' "$file"
}

peal_store_finish() {
  case ${2-} in
    done) [ $# -eq 2 ] || { peal_err "finish: ID done"; return 2; }; _peal_issues_finish_done "$1" ;;
    retired) [ $# -eq 3 ] || { peal_err "finish: ID retired REASON"; return 2; }; _peal_issues_retire "$1" "$3" ;;
    *) peal_err "finish: ID done, or ID retired REASON"; return 2 ;;
  esac
}

# _peal_issues_cache ID FILE -> issue ID's text written to FILE, for the session hooks;
# an empty FILE when it cannot be read, so a hook does not ask again on every call.
_peal_issues_cache() {
  if peal_store_read "$1" >"$2.$$" 2>/dev/null; then
    mv -f "$2.$$" "$2"
  else
    rm -f "$2.$$"
    [ -e "$2" ] || : >"$2"
  fi
}

# _peal_issues_label_claim ID -> the claim label on issue ID.
_peal_issues_label_claim() {
  peal_json l:labels "$PEAL_ISSUES_CLAIMED" \
    | peal_gh --method POST "repos/$PEAL_REPO/issues/$1/labels" --input - --jq 'length' >/dev/null
}

# peal_store_claim ID -> the issue claimed as Belfry claims one: the worktree
# {worktrees}/issue-ID on branch issue/ID (the local branch if there is one, else the
# remote's, else a new one from the remote's main) and the label "in progress". One line
# "claimed ID BRANCH PATH" or "resumed ID BRANCH PATH", PEAL_CLAIM_PATH the worktree. The
# issue's text is kept in the worktree's git directory for the session hooks. Status 2
# for anything refused or failed, taken back.
peal_store_claim() {
  local id=$1 dir branch wt err how=claimed gitdir
  _peal_issues_settings || return 2
  dir=$(peal_worktrees_dir) || return 2
  branch=issue/$id wt=$dir/issue-$id
  if [ -e "$wt" ]; then
    peal_err "claim: $wt is in the way; move it, or remove it with git worktree remove"
    return 2
  fi
  mkdir -p "$dir" || return 2
  err=$(mktemp) || return 2
  if git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    how=resumed
    set -- worktree add -q "$wt" "$branch"
  else
    git fetch -q "$PEAL_REMOTE" 2>/dev/null
    if git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$branch" >/dev/null; then
      set -- worktree add -q --track -b "$branch" "$wt" "$PEAL_REMOTE/$branch"
    elif git rev-parse -q --verify "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN" >/dev/null; then
      set -- worktree add -q --no-track -b "$branch" "$wt" "$PEAL_REMOTE/$PEAL_MAIN"
    else
      peal_err "claim: no $PEAL_REMOTE/$PEAL_MAIN to branch from"
      rm -f "$err"
      return 2
    fi
  fi
  if ! git "$@" 2>"$err"; then
    peal_err "claim: could not add the worktree $wt:"
    cat "$err" >&2
    rm -f "$err"
    return 2
  fi
  rm -f "$err"
  if ! _peal_issues_label_claim "$id"; then
    peal_err "claim: could not label issue $id '$PEAL_ISSUES_CLAIMED'; taken back"
    git worktree remove --force "$wt" >/dev/null 2>&1
    [ "$how" = resumed ] || git branch -q -D "$branch" >/dev/null 2>&1
    return 2
  fi
  gitdir=$(git -C "$wt" rev-parse --absolute-git-dir) && _peal_issues_cache "$id" "$gitdir/peal-task.md"
  PEAL_CLAIM_PATH=$(cd "$wt" && pwd -P)
  echo "$how $id $branch $PEAL_CLAIM_PATH"
}

# peal_store_release ID -> issue ID's claim on this machine ended as for task files (the
# tip kept as refs/reaped/issue-ID, the worktree and the local branch removed, the
# remote's branch too when it holds nothing more), and the label taken off an open issue.
peal_store_release() {
  local id=$1 branch=issue/$1 name=issue-$1 wt tip labels
  _peal_issues_settings || return 2
  if ! git rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    peal_err "release: no local branch of task $id"
    return 2
  fi
  tip=$(git rev-parse "refs/heads/$branch") || return 2
  if ! peal_reaped_keep "$name" "$tip"; then
    peal_err "release: could not keep the tip as refs/reaped/$name; nothing removed"
    return 2
  fi
  wt=$(peal_store_claim_worktrees | awk -F '\t' -v id="$id" '$1 == id { print $3; exit }')
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
  if labels=$(peal_gh "repos/$PEAL_REPO/issues/$id" --jq 'select(.state == "open") | .labels[].name'); then
    if printf '%s\n' "$labels" | grep -qxF "$PEAL_ISSUES_CLAIMED" \
        && ! peal_gh --method DELETE "repos/$PEAL_REPO/issues/$id/labels/$(peal_urlencode "$PEAL_ISSUES_CLAIMED")" >/dev/null; then
      peal_err "warning: could not take the label '$PEAL_ISSUES_CLAIMED' off issue $id"
    fi
  else
    peal_err "warning: could not read issue $id; its label '$PEAL_ISSUES_CLAIMED' may still be on"
  fi
  echo "released $id $branch, tip kept as refs/reaped/$name"
}

peal_store_branch_task() {
  local branch
  branch=$(git symbolic-ref -q --short HEAD) || return 1
  [[ "$branch" =~ ^issue/([0-9]+)$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# The branch is the claim: Belfry's sessions start in a worktree it made, before any
# label. The text is the copy the claim kept, fetched again when missing or asked to.
peal_store_session_task() {
  local id gitdir file
  id=$(peal_store_branch_task) || return 1
  gitdir=$(git rev-parse --absolute-git-dir) || return 1
  file=$gitdir/peal-task.md
  if [ ! -e "$file" ] || [ -n "${PEAL_TASK_REFRESH-}" ]; then
    _peal_issues_settings 2>/dev/null && _peal_issues_cache "$id" "$file"
  fi
  printf '%s\t%s\n' "$id" "$file"
}

peal_store_claim_worktrees() {
  git worktree list --porcelain | awk -v OFS='\t' '
    /^worktree / { path = substr($0, 10) }
    /^branch refs\/heads\/issue\/[0-9]+$/ { b = substr($0, 19); print substr(b, 7), b, path }'
}

peal_store_local_branch() {
  git rev-parse -q --verify "refs/heads/issue/$1" >/dev/null || return 1
  printf 'issue/%s\n' "$1"
}

# The issue itself: its title, body and the labels its frontmatter owns, and the copy the
# claim keeps fetched again.
peal_store_record() {
  local id=$1 what=$2 text=$3 tmp status=0
  _peal_issues_settings || return 2
  PEAL_FIELDS=$(_peal_issues_fields)
  PEAL_MS_ROWS=$(_peal_issues_milestone_rows) || return 2
  tmp=$(mktemp -d) || return 2
  if ! _peal_issues_from_text "$text" "$id" "$tmp"; then
    status=2
  elif ! _peal_issues_post "$tmp" "$id" \
      || ! _peal_issues_labels "$id" "$(_peal_issues_current_labels "$id")" "$(cat "$tmp/labels")"; then
    status=1
  else
    _peal_issues_cache "$id" "$(git rev-parse --absolute-git-dir)/peal-task.md"
    echo "recorded the $what of $id on issue $id"
  fi
  rm -rf "$tmp"
  return $status
}

# _peal_issues_ms_number ID -> PEAL_MS_NUM, the number of the milestone titled ID, and
# PEAL_MS_ROWS; status 2 and a message if there is none.
_peal_issues_ms_number() {
  PEAL_MS_ROWS=$(_peal_issues_milestone_rows) || return 2
  PEAL_MS_NUM=$(_peal_issues_milestone_number "$1") || { peal_err "no milestone $1"; return 2; }
}

# peal_store_milestone_text ID -> the milestone's description.
peal_store_milestone_text() {
  local num
  _peal_issues_settings || return 2
  _peal_issues_ms_number "$1" || return 2
  num=$PEAL_MS_NUM
  peal_gh "repos/$PEAL_REPO/milestones/$num" --jq '.description // ""'
}

# The milestone closed (done) or opened, its description's first line "Parked" or
# "Parked: REASON" for parked, taken out again for any other state, and REVIEW's text
# appended under "## Review, <date>". Which open milestone is current follows from the
# due dates, as ever (lib/issues-milestones.awk).
peal_store_milestone_state() {
  local id=$1 state=$2 reason=$3 review=$4 num old tmp gh_state=open status=0
  _peal_issues_settings || return 2
  _peal_issues_ms_number "$id" || return 2
  num=$PEAL_MS_NUM
  old=$(printf '%s\n' "$PEAL_MS_ROWS" | awk -F '\t' -f "$PEAL_ROOT/lib/issues-lib.awk" \
    -f "$PEAL_ROOT/lib/issues-milestones.awk" | awk -F '\t' -v id="$id" '$1 == id { print $3; exit }')
  if [ "$old" = "$state" ] || { [ "$old" = current ] && [ "$state" = open ]; }; then
    echo "milestone $id: $old already, nothing changed"
    return 0
  fi
  tmp=$(mktemp -d) || return 2
  peal_gh "repos/$PEAL_REPO/milestones/$num" --jq '.description // ""' >"$tmp/old" || { rm -rf "$tmp"; return 2; }
  # The parked line goes, and the blank lines around what is left.
  awk 'NR == 1 && tolower($0) ~ /^[ \t]*parked/ { next }
    /^[ \t\r]*$/ { if (n) blank++; next }
    { for (; blank > 0; blank--) print ""; print; n++ }' "$tmp/old" >"$tmp/rest"
  {
    if [ "$state" = parked ]; then
      printf 'Parked%s\n' "${reason:+: $reason}"
      [ ! -s "$tmp/rest" ] || echo
    fi
    cat "$tmp/rest"
    if [ -n "$review" ]; then
      if [ -s "$tmp/rest" ] || [ "$state" = parked ]; then echo; fi
      printf '## Review, %s\n\n' "$(date -u +%Y-%m-%d)"
      cat "$review"
    fi
  } >"$tmp/desc"
  [ "$state" != "done" ] || gh_state=closed
  peal_json s:state "$gh_state" f:description "$tmp/desc" \
    | peal_gh --method PATCH "repos/$PEAL_REPO/milestones/$num" --input - --jq '.number' >/dev/null || status=2
  rm -rf "$tmp"
  [ $status = 0 ] && echo "milestone $id: $state"
  return $status
}
