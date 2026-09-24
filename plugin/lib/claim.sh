# shellcheck shell=bash
# Claims, above the storage: which tasks a pool offers and in what order, which may be
# claimed, and when a claim's worktree may go. The storage does the claiming and the
# releasing (peal_store_claim, peal_store_release); every rule is here, the same for each.
#
# A claim lives in a worktree of its own, {worktrees}/<branch without its prefix>, and
# leaves files in that worktree's git directory, where no commit or status sees them:
#   peal-turns, peal-nudged   the turn budget's count and whether it nudged (session.sh)
#   peal-heartbeat            touched on every tool call; a worktree touched in the last
#                             PEAL_IDLE_MINUTES is live and never reaped
# Released tips are kept as refs/reaped/<name> for PEAL_REAPED_DAYS, their times in the
# common git directory's peal-reaped/.

PEAL_IDLE_MINUTES=30
PEAL_REAPED_DAYS=30

# peal_worktrees_dir -> the directory claims are made in: the worktrees setting, {repo}
# the primary checkout's name, relative to that checkout.
peal_worktrees_dir() {
  local setting primary parent
  setting=$(peal_config_get worktrees) || return 2
  primary=$(git worktree list --porcelain | awk '!f && /^worktree / { print substr($0, 10); f = 1 }')
  if [ -z "$primary" ]; then
    peal_err "no primary checkout to put worktrees next to"
    return 2
  fi
  setting=${setting//\{repo\}/$(basename "$primary")}
  case $setting in /*) ;; *) setting=$primary/$setting ;; esac
  setting=${setting%/}
  if [ -d "$setting" ]; then
    (cd "$setting" && pwd -P)
  elif parent=$(cd "$(dirname "$setting")" 2>/dev/null && pwd -P); then
    printf '%s/%s\n' "$parent" "$(basename "$setting")"
  else
    printf '%s\n' "$setting"
  fi
}

# _peal_field RECORD N -> field N of a tab-separated record.
_peal_field() {
  printf '%s\n' "$1" | cut -f "$2"
}

# _peal_common_dir -> the git directory every worktree shares, absolute.
_peal_common_dir() {
  (cd "$(git rev-parse --git-common-dir)" && pwd -P)
}

# peal_reaped_keep NAME TIP -> TIP kept as refs/reaped/NAME, with the time it was kept.
peal_reaped_keep() {
  local common
  git update-ref "refs/reaped/$1" "$2" || return 1
  common=$(_peal_common_dir) || return 0
  mkdir -p "$common/peal-reaped" && date +%s >"$common/peal-reaped/$1"
  return 0
}

# peal_reaped_expire -> the kept tips older than PEAL_REAPED_DAYS deleted. A tip without
# its time is left alone.
peal_reaped_expire() {
  local common now ref name kept
  common=$(_peal_common_dir) || return 0
  now=$(date +%s)
  git for-each-ref --format='%(refname)' refs/reaped/ | while IFS= read -r ref; do
    name=${ref#refs/reaped/}
    kept=$(cat "$common/peal-reaped/$name" 2>/dev/null) || continue
    case $kept in "" | *[!0-9]*) continue ;; esac
    if [ $((now - kept)) -ge $((PEAL_REAPED_DAYS * 86400)) ]; then
      git update-ref -d "$ref" && rm -f "$common/peal-reaped/$name"
    fi
  done
}

# peal_pool_buckets POOL MILESTONES -> the pool's buckets in its order, one per line: a
# milestone id, or unassigned for the tasks without one. POOL is a comma list of
# milestone ids, current and unassigned; MILESTONES peal_ms_load's lines. A milestone
# that does not exist, is parked or is done is refused: it has nothing to offer.
peal_pool_buckets() {
  local token state out="" current tokens
  current=$(printf '%s\n' "$2" | awk -F '\t' '!f && $3 == "current" { print $1; f = 1 }')
  # Commas only: a milestone's id may hold spaces (an issue milestone's title).
  IFS=, read -r -a tokens <<<"$1"
  for token in ${tokens[@]+"${tokens[@]}"}; do
    case $token in
      unassigned) ;;
      current) token=$current ;;
      *)
        state=$(printf '%s\n' "$2" | awk -F '\t' -v m="$token" '!f && $1 == m { print $3; f = 1 }')
        case $state in
          "") peal_err "pool: milestone $token does not exist"; return 2 ;;
          parked | done) peal_err "pool: milestone $token is $state; its tasks are not offered"; return 2 ;;
        esac
        ;;
    esac
    [ -n "$token" ] || continue
    case ",$out," in *",$token,"*) continue ;; esac
    out=${out:+$out,}$token
  done
  [ -z "$out" ] || printf '%s\n' "$out" | tr ',' '\n'
}

# _peal_offer_order BUCKETS -> the list records on stdin that are free and in one of the
# BUCKETS (a comma list), best first: by bucket in the pool's order, then the free
# members of an open split, then by number. "bucket<TAB>id<TAB>title<TAB>split" each,
# split "(part of ORIGIN, D/T done)" or empty.
_peal_offer_order() {
  awk -F '\t' -v buckets="$1" '
    BEGIN { n = split(buckets, b, ","); for (i = 1; i <= n; i++) rank[b[i]] = i }
    $2 == "free" {
      k = $6 == "" ? "unassigned" : $6
      if (!(k in rank)) next
      sp = ""
      if (match($3, /split:[0-9]+ [0-9]+\/[0-9]+/)) {
        s = substr($3, RSTART + 6, RLENGTH - 6)
        sp = "(part of " substr(s, 1, index(s, " ") - 1) ", " substr(s, index(s, " ") + 1) " done)"
      }
      printf "%d\t%d\t%s\t%s\t%s\t%s\n", rank[k], (sp == "" ? 1 : 0), $1, k, $5, sp
    }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3 | cut -f3- \
    | awk -F '\t' -v OFS='\t' '{ print $2, $1, $3, $4 }'
}

# peal_offer POOL [--top N] -> "CANDIDATE <id> <bucket> <title>" for the best N (3) free
# tasks of POOL, then "MORE <bucket> <count>" for each bucket with free tasks left over.
# Nothing at all for an empty pool.
peal_offer() {
  local pool="" top=3 records milestones buckets
  while [ $# -gt 0 ]; do
    case $1 in
      --top)
        [[ "${2-}" =~ ^[1-9][0-9]*$ ]] || { peal_err "offer: --top takes a positive number"; return 2; }
        top=$2
        shift ;;
      -*) peal_err "offer: unknown option $1"; return 2 ;;
      *) [ -z "$pool" ] || { peal_err "offer: one pool, a comma list"; return 2; }; pool=$1 ;;
    esac
    shift
  done
  [ -n "$pool" ] || { peal_err "offer: POOL [--top N]"; return 2; }
  records=$(peal_store_list --fetch --no-pr) || return 2
  milestones=$(peal_store_milestones) || return 2
  buckets=$(peal_pool_buckets "$pool" "$milestones") || return 2
  [ -n "$buckets" ] && [ -n "$records" ] || return 0
  printf '%s\n' "$records" | _peal_offer_order "$(printf '%s' "$buckets" | tr '\n' ',')" \
    | awk -F '\t' -v top="$top" -v buckets="$(printf '%s' "$buckets" | tr '\n' ',')" '
      { total[$1]++
        if (++shown <= top) printf "CANDIDATE %s %s %s%s\n", $2, $1, $3, ($4 == "" ? "" : " " $4)
        else left[$1]++ }
      END { n = split(buckets, b, ","); for (i = 1; i <= n; i++) if (left[b[i]]) print "MORE", b[i], left[b[i]] }'
}

# peal_claim ID [--print-path] | --next [POOL] [--print-path] -> task ID claimed into a
# worktree of its own, or the best free task of POOL (current,unassigned) that no other
# claim beats to it. Refused: a task done, awaiting merge, blocked, claimed elsewhere, or
# of a milestone that is parked, done or unknown. A task claimed on this machine already
# prints its worktree again, and a parked claim is resumed. --print-path: the worktree's
# path as the last line. Status 1 when --next finds nothing to claim.
peal_claim() {
  local id="" next=0 pool="" print=0 candidates cand status
  while [ $# -gt 0 ]; do
    case $1 in
      --print-path) print=1 ;;
      --next)
        next=1
        if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then pool=$2; shift; fi ;;
      [0-9]*)
        [[ "$1" =~ ^[0-9]+$ ]] || { peal_err "claim: '$1' is no task id"; return 2; }
        [ -z "$id" ] || { peal_err "claim: one task"; return 2; }
        id=$1 ;;
      *) peal_err "claim: unknown argument $1"; return 2 ;;
    esac
    shift
  done
  if { [ $next = 1 ] && [ -n "$id" ]; } || { [ $next = 0 ] && [ -z "$id" ]; }; then
    peal_err "claim: ID [--print-path], or --next [POOL] [--print-path]"
    return 2
  fi
  if [ $next = 0 ]; then
    _peal_claim_one "$id" "$print"
    return
  fi
  candidates=$(peal_offer "${pool:-current,unassigned}" --top 9999) || return 2
  candidates=$(printf '%s\n' "$candidates" | awk '$1 == "CANDIDATE" { print $2 }')
  if [ -z "$candidates" ]; then
    peal_err "claim: no free task in ${pool:-current,unassigned}"
    return 1
  fi
  for cand in $candidates; do
    _peal_claim_one "$cand" "$print" fresh
    status=$?
    case $status in
      3 | 4) continue ;;
      *) return $status ;;
    esac
  done
  peal_err "claim: every free task in ${pool:-current,unassigned} went to another claim first"
  return 1
}

# _peal_claim_one ID PRINT [fresh] -> the claim of one task; with fresh (--next), a task
# that is no longer free is status 4 instead of refused, and only free tasks are claimed.
_peal_claim_one() {
  local id=$1 print=$2 fresh=${3-} records rec state detail ms mstate status
  records=$(peal_store_list --fetch --no-pr) || return 2
  rec=$(printf '%s\n' "$records" | awk -F '\t' -v id="$id" '$1 == id')
  if [ -z "$rec" ]; then
    peal_err "claim: no task $id"
    return 2
  fi
  state=$(_peal_field "$rec" 2)
  detail=$(_peal_field "$rec" 3)
  ms=$(_peal_field "$rec" 6)
  if [ -n "$fresh" ] && [ "$state" != free ]; then
    return 4
  fi
  case $state in
    done) peal_err "claim: task $id is done"; return 2 ;;
    awaiting-merge)
      peal_err "claim: task $id is finished and awaits the merge of its pull request ($detail); a fix is a new task"
      return 2 ;;
    blocked) peal_err "claim: task $id is blocked, $detail"; return 2 ;;
    claimed-live)
      case $detail in
        wt:*)
          echo "task $id is claimed here already: ${detail#wt:}"
          [ "$print" = 0 ] || printf '%s\n' "${detail#wt:}"
          return 0 ;;
      esac
      peal_err "claim: task $id is claimed elsewhere ($detail)"
      return 2 ;;
    free | parked) ;;
    *) peal_err "claim: task $id is $state"; return 2 ;;
  esac
  if [ -n "$ms" ]; then
    mstate=$(peal_store_milestones | awk -F '\t' -v m="$ms" '!f && $1 == m { print $3; f = 1 }')
    if [ -z "$mstate" ]; then
      peal_err "claim: task $id's milestone $ms does not exist"
      return 2
    fi
    if ! peal_ms_claimable "$mstate"; then
      peal_err "claim: task $id's milestone $ms is $mstate; a milestone review or the human moves the task out first"
      return 2
    fi
  fi
  PEAL_CLAIM_PATH=""
  peal_store_claim "$id"
  status=$?
  [ $status = 0 ] || return $status
  _peal_claim_started "$PEAL_CLAIM_PATH"
  _peal_claim_overlap "$id" "$records"
  [ "$print" = 0 ] || printf '%s\n' "$PEAL_CLAIM_PATH"
}

# _peal_claim_started WT -> the new claim's turn budget started from zero.
_peal_claim_started() {
  local gitdir
  gitdir=$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null) || return 0
  printf '0\n' >"$gitdir/peal-turns"
  rm -f "$gitdir/peal-nudged"
}

# _peal_scope_paths FILE -> the `backticked` words of FILE's Scope section that look like
# paths: holding a / or ending in an extension.
_peal_scope_paths() {
  # shellcheck disable=SC2016 # backticks, not an expansion
  peal_text_section Scope <"$1" | grep -o '`[^`]*`' | tr -d '`' | grep -E '/|\.[A-Za-z0-9]{1,6}$' | sort -u
}

# _peal_claim_overlap ID RECORDS -> a warning for each path the new claim's Scope names
# that another claim's branch changes already. Scope is prose: best effort, never refused.
_peal_claim_overlap() {
  local id=$1 file scope remote main oid ostate oref ref files p hit
  file=$(mktemp) || return 0
  peal_store_read "$id" >"$file" 2>/dev/null
  scope=$(_peal_scope_paths "$file")
  rm -f "$file"
  [ -n "$scope" ] || return 0
  remote=$(peal_config_get remote)
  main=refs/remotes/$remote/$(peal_config_get main)
  printf '%s\n' "$2" | awk -F '\t' -v id="$id" -v OFS='\t' \
    '$1 != id && $13 != "" && ($2 == "claimed-live" || $2 == "parked" || $2 == "awaiting-merge") { print $1, $2, $13 }' \
    | while IFS="$(printf '\t')" read -r oid ostate oref; do
        ref=refs/heads/$oref
        git rev-parse -q --verify "$ref" >/dev/null || ref=refs/remotes/$remote/$oref
        git rev-parse -q --verify "$ref" >/dev/null || continue
        files=$(git diff --name-only "$(git merge-base "$main" "$ref" 2>/dev/null)" "$ref" 2>/dev/null) || continue
        while IFS= read -r p; do
          hit=$(printf '%s\n' "$files" | awk -v p="$p" '
            f { next }
            p ~ /\/$/ { if (index($0, p) == 1) { print; f = 1 } next }
            p ~ /\// { if ($0 == p) { print; f = 1 } next }
            { n = split($0, parts, "/"); if (parts[n] == p) { print; f = 1 } }')
          [ -z "$hit" ] || peal_err "warning: Scope names $p, which task $oid ($ostate) changes already: $hit"
        done <<<"$scope"
      done
  return 0
}

# _peal_admin_dir PATH -> the git directory of the worktree at PATH, even when PATH itself
# is gone; status 1 if git knows no such worktree.
_peal_admin_dir() {
  local common d
  common=$(_peal_common_dir) || return 1
  for d in "$common"/worktrees/*/; do
    d=${d%/}
    [ -f "$d/gitdir" ] || continue
    if [ "$(cat "$d/gitdir")" = "$1/.git" ]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

# peal_release_verdict ID BRANCH PATH STATE -> why the claim of task ID (its local BRANCH,
# its worktree at PATH or none, the task's STATE) must stay, or "ok" if it may go:
#   own         PATH is the worktree asking
#   live        a session worked there in the last PEAL_IDLE_MINUTES
#   not-landed  the task is not done on the main branch
#   dirty       PATH holds uncommitted changes
#   unpushed    BRANCH has commits its remote branch does not
peal_release_verdict() {
  local id=$1 branch=$2 path=$3 state=$4 top admin up
  if [ -n "$path" ] && [ -d "$path" ]; then
    top=$(git rev-parse --show-toplevel 2>/dev/null) && top=$(cd "$top" && pwd -P)
    if [ "$top" = "$(cd "$path" && pwd -P)" ]; then echo own; return; fi
  fi
  if [ -n "$path" ] && admin=$(_peal_admin_dir "$path") && [ -f "$admin/peal-heartbeat" ] \
      && [ -n "$(find "$admin/peal-heartbeat" -mmin -"$PEAL_IDLE_MINUTES" 2>/dev/null)" ]; then
    echo live
    return
  fi
  if [ "$state" != "done" ]; then echo not-landed; return; fi
  if [ -n "$path" ] && [ -d "$path" ] && [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
    echo dirty
    return
  fi
  up=$(git rev-parse -q --verify "refs/heads/$branch@{upstream}" 2>/dev/null) \
    || up=$(git rev-parse -q --verify "refs/remotes/$(peal_config_get remote)/$branch" 2>/dev/null) || up=""
  if [ -n "$up" ] && [ "$(git rev-list --count "$up..refs/heads/$branch")" -gt 0 ]; then
    echo unpushed
    return
  fi
  echo ok
}

# _peal_verdict_words VERDICT ID -> the verdict as words.
_peal_verdict_words() {
  case $1 in
    own) echo "it is the worktree this runs in" ;;
    live) echo "a session worked there in the last $PEAL_IDLE_MINUTES minutes" ;;
    not-landed) echo "task $2 is not done on the main branch" ;;
    dirty) echo "its worktree holds uncommitted changes" ;;
    unpushed) echo "its branch holds commits not pushed" ;;
    *) echo "$1" ;;
  esac
}

# peal_release ID -> the claim of task ID on this machine released, its worktree and branch
# removed with the tip kept, once it has landed and nothing would be lost: refused with the
# reason otherwise (peal_release_verdict).
peal_release() {
  local id=${1-} records state branch path verdict
  if ! [[ "$id" =~ ^[0-9]+$ ]] || [ $# -ne 1 ]; then
    peal_err "release: ID"
    return 2
  fi
  records=$(peal_store_list --fetch --no-pr) || return 2
  state=$(printf '%s\n' "$records" | awk -F '\t' -v id="$id" '!f && $1 == id { print $2; f = 1 }')
  if ! branch=$(peal_store_local_branch "$id"); then
    peal_err "release: task $id has no branch here; nothing to release"
    return 2
  fi
  path=$(peal_store_claim_worktrees | awk -F '\t' -v b="$branch" '!f && $2 == b { print $3; f = 1 }')
  verdict=$(peal_release_verdict "$id" "$branch" "$path" "$state")
  if [ "$verdict" != ok ]; then
    peal_err "release: task $id stays: $(_peal_verdict_words "$verdict" "$id")"
    return 2
  fi
  peal_store_release "$id"
}

# peal_reap -> every claim worktree under the worktrees directory that may go
# (peal_release_verdict) released, a line "reaped ID BRANCH, tip kept as REF" each; a
# landed one that must stay gets "kept ID PATH: why". The others, still at work, pass
# silently. Kept tips past their time expire.
peal_reap() {
  local dir records id branch path state verdict out
  dir=$(peal_worktrees_dir) || return 0
  records=$(peal_store_list --no-pr 2>/dev/null) || return 0
  while IFS="$(printf '\t')" read -r id branch path; do
    [ -n "$id" ] || continue
    case $path in "$dir"/*) ;; *) continue ;; esac
    state=$(printf '%s\n' "$records" | awk -F '\t' -v id="$id" '!f && $1 == id { print $2; f = 1 }')
    verdict=$(peal_release_verdict "$id" "$branch" "$path" "$state")
    case $verdict in
      ok)
        if out=$(peal_store_release "$id" 2>&1); then
          printf '%s\n' "$out" | sed 's/^released /reaped /'
        else
          printf 'kept %s %s: %s\n' "$id" "$path" "$(printf '%s' "$out" | tail -n 1)"
        fi ;;
      dirty | unpushed) printf 'kept %s %s: landed, but %s\n' "$id" "$path" "$(_peal_verdict_words "$verdict" "$id")" ;;
    esac
  done < <(peal_store_claim_worktrees)
  peal_reaped_expire
}
