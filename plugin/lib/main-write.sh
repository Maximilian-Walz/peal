# shellcheck shell=bash
# Writes onto the main branch that never touch a worktree: a commit built on a temporary
# index from the fetched main, and pushed. The push is the lock: one that loses a race is
# built again on the new main. The task-file storage files and edits tasks this way, the
# decisions module publishes its index.
#
# A main branch that refuses direct pushes (a ruleset, branch protection) gets the same
# commit through a pull request instead: pushed to a branch of its own, opened, and merged
# once its checks pass, by GitHub's auto-merge or else by Peal. The setting main-writes
# says which way: push (never a pull request), pr (always one), auto (push, and on a
# refusal by the remote switch to pull requests, remembered for the clone in git config
# peal.mainWrites; `git config --unset peal.mainWrites` forgets it).

# The branches a write through a pull request is pushed to: this, then the commit's
# short sha.
PEAL_MW_PREFIX=peal/main-write-

# _peal_mw_route -> push, pr or auto: the setting main-writes, auto made pr when the clone
# remembers a refusal.
_peal_mw_route() {
  local setting
  setting=$(peal_config_get main-writes) || return 2
  case $setting in
    push | pr) printf '%s\n' "$setting" ;;
    auto)
      if [ "$(git config --get peal.mainWrites 2>/dev/null)" = pr ]; then
        echo pr
      else
        echo auto
      fi
      ;;
    *) peal_err "main-writes: '$setting' is none of push, pr, auto"; return 2 ;;
  esac
}

# _peal_mw_refused_by_rule ERRFILE -> status 0 when git's push output in ERRFILE shows the
# remote itself refusing the main branch ("[remote rejected] ... -> main (...)"): a rule
# or protection on the server. A local gate's refusal and a lost race say otherwise.
_peal_mw_refused_by_rule() {
  local line
  while IFS= read -r line; do
    case $line in
      *"[remote rejected] "*" -> $PEAL_MAIN ("*) return 0 ;;
    esac
  done <"$1"
  return 1
}

# _peal_mw_fetch_branches -> the remote's main-write branches fetched, the gone ones pruned.
_peal_mw_fetch_branches() {
  git fetch -q --prune "$PEAL_REMOTE" \
    "+refs/heads/$PEAL_MW_PREFIX*:refs/remotes/$PEAL_REMOTE/$PEAL_MW_PREFIX*" 2>/dev/null || true
}

# peal_push_main BUILD [COMMAND] -> BUILD BASE run on the remote's main and its result
# written there, again on a new main when the push loses a race (PEAL_PUSH_ATTEMPTS, 5).
# BUILD sets PEAL_TREE and PEAL_SUBJECT, or refuses with a status of its own (2, or 3 and
# 4 for its callers), passed through. COMMAND names the peal command writing, for a pull
# request's body. A push that fails for another reason is not retried: status 1; under
# main-writes auto a refusal by the remote switches to a pull request (_peal_mw_pr).
# PEAL_MW_TAKEN, when set, names a function REF... telling whether what the build wrote
# is taken at one of the REFs meanwhile (a filing's numbers); the pull request route then
# builds again. Afterwards PEAL_MW_PR, PEAL_MW_URL and PEAL_MW_STATE (merged, auto, open)
# describe the pull request, if one was made: peal_main_write_report.
peal_push_main() {
  local build=$1 command=${2-} attempt=1 max=${PEAL_PUSH_ATTEMPTS:-5} route base sha new err status replaces=""
  PEAL_MW_PR="" PEAL_MW_URL="" PEAL_MW_STATE=""
  route=$(_peal_mw_route) || return 2
  err=$(mktemp) || return 2
  [ "$route" != pr ] || _peal_mw_fetch_branches
  while :; do
    base=$(git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || {
      peal_err "$PEAL_REMOTE/$PEAL_MAIN is gone"; rm -f "$err"; return 2; }
    PEAL_TREE="" PEAL_SUBJECT=""
    "$build" "$base" || { status=$?; rm -f "$err"; return $status; }
    sha=$(git commit-tree "$PEAL_TREE" -p "$base" -m "$PEAL_SUBJECT") || { rm -f "$err"; return 2; }
    if [ "$route" = pr ]; then
      _peal_mw_pr "$sha" "$command" "$replaces"
      status=$?
      if [ $status != 5 ]; then
        rm -f "$err"
        return $status
      fi
      replaces=$PEAL_MW_PR
      PEAL_MW_PR="" PEAL_MW_URL="" PEAL_MW_STATE=""
      if [ $attempt -ge "$max" ]; then
        peal_err "gave up after $max pull requests, each replaced"
        rm -f "$err"
        return 1
      fi
      attempt=$((attempt + 1))
      git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null
      continue
    fi
    if git push -q "$PEAL_REMOTE" "$sha:refs/heads/$PEAL_MAIN" 2>"$err"; then
      rm -f "$err"
      return 0
    fi
    git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null
    new=$(git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || new=$base
    # A remote with several push URLs fails the push when one of them refuses, though
    # the commit may have landed: landed is landed.
    if git merge-base --is-ancestor "$sha" "$new" 2>/dev/null; then
      rm -f "$err"
      return 0
    fi
    if [ "$new" = "$base" ]; then
      if [ "$route" = auto ] && _peal_mw_refused_by_rule "$err"; then
        peal_err "$PEAL_REMOTE refuses direct pushes to $PEAL_MAIN; through a pull request instead (main-writes: auto)"
        route="pr"
        _peal_mw_fetch_branches
        continue
      fi
      peal_err "the push to $PEAL_REMOTE/$PEAL_MAIN failed, and not from a race:"
      cat "$err" >&2
      rm -f "$err"
      return 1
    fi
    if [ $attempt -ge "$max" ]; then
      peal_err "gave up after $max pushes to $PEAL_REMOTE/$PEAL_MAIN, each losing a race"
      rm -f "$err"
      return 1
    fi
    peal_err "the push lost a race ($attempt of $max); again on the new $PEAL_MAIN"
    attempt=$((attempt + 1))
  done
}

# _peal_mw_body COMMAND REPLACES -> a write's pull request body.
_peal_mw_body() {
  local what="Made by \`peal ${1:-write}\`"
  [[ "$PEAL_SUBJECT" =~ \[([0-9][0-9-]*)\]$ ]] && what="$what for task ${BASH_REMATCH[1]}"
  printf '%s. Peal merges it once the required checks pass (GitHub'"'"'s auto-merge, or Peal itself); nothing to review by hand.\n' "$what"
  [ -z "$2" ] || printf '\nReplaces #%s.\n' "$2"
}

# _peal_mw_pr SHA COMMAND REPLACES -> commit SHA (on the main fetched) written through a
# pull request: pushed to $PEAL_MW_PREFIX<short sha>, opened, and merged by auto-merge
# (squash), else by Peal once its checks pass (_peal_mw_merge_self). Status 0 when merged
# or auto-merge is on (PEAL_MAIN_WRITE_WAIT=merged waits for the merge then), 5 when it
# was closed to be built again (its number taken by an earlier one, or it conflicts), 3
# when it is still open after PEAL_MAIN_WRITE_BUDGET, 1 when it cannot open or its checks
# fail, 2 without the settings.
_peal_mw_pr() {
  local sha=$1 command=$2 replaces=$3 branch repo out node rivals refs ref mergeable e
  branch=$PEAL_MW_PREFIX$(git rev-parse --short "$sha")
  repo=$(peal_github_repo) || return 2
  e=$(mktemp) || return 2
  if ! git push -q -f "$PEAL_REMOTE" "$sha:refs/heads/$branch" 2>"$e"; then
    peal_err "the push of $branch to $PEAL_REMOTE failed:"
    cat "$e" >&2
    rm -f "$e"
    return 1
  fi
  git update-ref "refs/remotes/$PEAL_REMOTE/$branch" "$sha"
  _peal_mw_body "$command" "$replaces" >"$e"
  if ! out=$(peal_json s:title "$PEAL_SUBJECT" s:head "$branch" s:base "$PEAL_MAIN" f:body "$e" \
      | peal_gh --method POST "repos/$repo/pulls" --input - --jq '[(.number | tostring), .html_url, .node_id] | @tsv'); then
    rm -f "$e"
    peal_err "the pull request for $branch did not open (above); nothing was written"
    _peal_mw_drop "$repo" "" "$branch"
    return 1
  fi
  rm -f "$e"
  IFS="$(printf '\t')" read -r PEAL_MW_PR PEAL_MW_URL node <<<"$out"
  PEAL_MW_STATE=open
  [ "$(peal_config_get main-writes)" != auto ] || git config peal.mainWrites pr
  peal_err "opened pull request #$PEAL_MW_PR $PEAL_MW_URL${replaces:+ (replaces #$replaces)}"

  # Built on the same main, an earlier pull request may hold what this one does: the
  # lower number wins, this one is built again.
  if [ -n "${PEAL_MW_TAKEN-}" ]; then
    rivals=$(peal_gh "repos/$repo/pulls?state=open&per_page=100" --jq \
      ".[] | select(.number < $PEAL_MW_PR and (.head.ref | startswith(\"$PEAL_MW_PREFIX\"))) | .head.ref") || rivals=""
    refs="refs/remotes/$PEAL_REMOTE/$PEAL_MAIN"
    for ref in $rivals; do
      git fetch -q "$PEAL_REMOTE" "+refs/heads/$ref:refs/remotes/$PEAL_REMOTE/$ref" 2>/dev/null \
        && refs="$refs refs/remotes/$PEAL_REMOTE/$ref"
    done
    git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null
    # shellcheck disable=SC2086 # refs are words
    if "$PEAL_MW_TAKEN" $refs; then
      peal_err "#$PEAL_MW_PR's number is taken meanwhile, on $PEAL_MAIN or by an earlier pull request; closed, and built again"
      _peal_mw_drop "$repo" "$PEAL_MW_PR" "$branch"
      return 5
    fi
  fi
  mergeable=$(peal_gh "repos/$repo/pulls/$PEAL_MW_PR" --jq '.mergeable | tostring') || mergeable=null
  if [ "$mergeable" = false ]; then
    peal_err "#$PEAL_MW_PR conflicts with $PEAL_MAIN; closed, and built again on the new $PEAL_MAIN"
    _peal_mw_drop "$repo" "$PEAL_MW_PR" "$branch"
    return 5
  fi

  e=$(mktemp) || return 2
  # shellcheck disable=SC2016 # GraphQL's $variables
  if peal_gh graphql -f query='mutation($id: ID!) { enablePullRequestAutoMerge(input: {pullRequestId: $id, mergeMethod: SQUASH}) { clientMutationId } }' \
      -f id="$node" >/dev/null 2>"$e"; then
    rm -f "$e"
    PEAL_MW_STATE=auto
    [ "${PEAL_MAIN_WRITE_WAIT-}" != merged ] || _peal_mw_wait_merged "$repo" "$branch"
    return
  fi
  peal_err "auto-merge is not on for #$PEAL_MW_PR ($(sed 's/^peal: gh api graphql failed: //' "$e" | tr '\n' ' ' | sed 's/ $//')); Peal merges it once its checks pass"
  rm -f "$e"
  _peal_mw_merge_self "$repo" "$branch" "$sha"
}

# _peal_mw_drop REPO PR BRANCH -> pull request PR closed (none when empty), BRANCH deleted
# on the remote and here.
_peal_mw_drop() {
  local repo=$1 pr=$2 branch=$3
  if [ -n "$pr" ]; then
    peal_json s:state closed | peal_gh --method PATCH "repos/$repo/pulls/$pr" --input - --jq .number >/dev/null \
      || peal_err "#$pr did not close (above); close it by hand"
  fi
  git push -q "$PEAL_REMOTE" --delete "$branch" 2>/dev/null
  git update-ref -d "refs/remotes/$PEAL_REMOTE/$branch" 2>/dev/null
  PEAL_MW_STATE=""
  return 0
}

# _peal_mw_budget -> PEAL_MW_INTERVAL and PEAL_MW_BUDGET, whole seconds; status 2 else.
_peal_mw_budget() {
  PEAL_MW_INTERVAL=${PEAL_MAIN_WRITE_INTERVAL:-20} PEAL_MW_BUDGET=${PEAL_MAIN_WRITE_BUDGET:-540}
  case "$PEAL_MW_INTERVAL:$PEAL_MW_BUDGET" in
    *[!0-9:]* | :* | *:) peal_err "PEAL_MAIN_WRITE_INTERVAL and PEAL_MAIN_WRITE_BUDGET are whole seconds"; return 2 ;;
  esac
}

# _peal_mw_merged REPO BRANCH -> after the merge: the branch deleted, main fetched.
_peal_mw_merged() {
  PEAL_MW_STATE=merged
  peal_gh --method DELETE "repos/$1/git/refs/heads/$2" >/dev/null 2>&1 || git push -q "$PEAL_REMOTE" --delete "$2" 2>/dev/null
  git update-ref -d "refs/remotes/$PEAL_REMOTE/$2" 2>/dev/null
  git fetch -q "$PEAL_REMOTE" "$PEAL_MAIN" 2>/dev/null
  return 0
}

# _peal_mw_merge_self REPO BRANCH SHA -> PEAL_MW_PR squash-merged by Peal once the checks
# on SHA pass, polled every PEAL_MAIN_WRITE_INTERVAL seconds (20) within
# PEAL_MAIN_WRITE_BUDGET (540). Status 0 merged, 1 a check failing (left open), 3 the
# budget spent (left open).
_peal_mw_merge_self() {
  local repo=$1 branch=$2 sha=$3 start=$SECONDS line last=""
  _peal_mw_budget || return 2
  while :; do
    line=$(peal_pr_checks "$repo" "$sha" 2>/dev/null)
    case $line in
      READY*)
        if last=$(peal_json s:merge_method squash s:sha "$sha" \
            | peal_gh --method PUT "repos/$repo/pulls/$PEAL_MW_PR/merge" --input - --jq .sha 2>&1); then
          _peal_mw_merged "$repo" "$branch"
          return 0
        fi
        last=${last#peal: }
        ;;
      BLOCKED:checks-failing)
        peal_err "#$PEAL_MW_PR's checks fail: it stays open, unmerged, $PEAL_MW_URL"
        return 1
        ;;
    esac
    if [ $((SECONDS - start + PEAL_MW_INTERVAL)) -gt "$PEAL_MW_BUDGET" ]; then
      peal_err "#$PEAL_MW_PR is not merged after ${PEAL_MW_BUDGET}s (${line:-no verdict}${last:+; $last}): it stays open, $PEAL_MW_URL"
      return 3
    fi
    sleep "$PEAL_MW_INTERVAL"
  done
}

# _peal_mw_wait_merged REPO BRANCH -> PEAL_MW_PR, auto-merge on, waited for until merged,
# within the same budget. Status 0 merged, 1 closed unmerged, 3 still open.
_peal_mw_wait_merged() {
  local repo=$1 branch=$2 start=$SECONDS state
  _peal_mw_budget || return 2
  while :; do
    state=$(peal_gh "repos/$repo/pulls/$PEAL_MW_PR" --jq '[.state, (.merged | tostring)] | join(" ")' 2>/dev/null)
    case $state in
      *" true") _peal_mw_merged "$repo" "$branch"; return 0 ;;
      "closed "*) PEAL_MW_STATE=""; peal_err "#$PEAL_MW_PR was closed unmerged: $PEAL_MW_URL"; return 1 ;;
    esac
    if [ $((SECONDS - start + PEAL_MW_INTERVAL)) -gt "$PEAL_MW_BUDGET" ]; then
      PEAL_MW_STATE=open
      peal_err "#$PEAL_MW_PR is not merged after ${PEAL_MW_BUDGET}s: it stays open, auto-merge on, $PEAL_MW_URL"
      return 3
    fi
    sleep "$PEAL_MW_INTERVAL"
  done
}

# peal_main_write_written STATUS -> status 0 when a peal_push_main that returned STATUS
# wrote, or left its write open on a pull request.
peal_main_write_written() {
  [ "$1" = 0 ] || { [ "$1" = 3 ] && [ "$PEAL_MW_STATE" = open ]; }
}

# peal_main_write_report [NOTE] -> for a write that went through a pull request, a line
# saying which and where it stands, NOTE added while it is not merged; nothing for a push.
peal_main_write_report() {
  [ -n "${PEAL_MW_PR-}" ] || return 0
  case $PEAL_MW_STATE in
    merged) printf 'pull request #%s %s, merged\n' "$PEAL_MW_PR" "$PEAL_MW_URL" ;;
    auto) printf 'pull request #%s %s, merging once its checks pass%s\n' "$PEAL_MW_PR" "$PEAL_MW_URL" "${1:+; $1}" ;;
    open) printf 'pull request #%s %s, open, not merged%s\n' "$PEAL_MW_PR" "$PEAL_MW_URL" "${1:+; $1}" ;;
  esac
}

# peal_main_write_hint -> where writes go through pull requests, a hint that one may not
# have merged yet: for a read that did not find what a write made.
peal_main_write_hint() {
  [ "$(_peal_mw_route 2>/dev/null)" = pr ] || return 0
  peal_err "writes onto $PEAL_MAIN go through pull requests here: one from a $PEAL_MW_PREFIX* branch may not have merged yet"
}

# peal_write_tree BASE [add PATH FILE | remove PATH]... -> PEAL_TREE: BASE's tree with
# those changes.
peal_write_tree() {
  local base=$1 index blob status=0
  shift
  index=$(mktemp) || return 2
  rm -f "$index"
  GIT_INDEX_FILE=$index git read-tree "$base" || status=2
  while [ $status = 0 ] && [ $# -gt 0 ]; do
    case $1 in
      add)
        blob=$(git hash-object -w -- "$3") \
          && GIT_INDEX_FILE=$index git update-index --add --cacheinfo "100644,$blob,$2" || status=2
        shift 3 ;;
      remove)
        GIT_INDEX_FILE=$index git update-index --force-remove -- "$2" || status=2
        shift 2 ;;
    esac
  done
  [ $status = 0 ] && PEAL_TREE=$(GIT_INDEX_FILE=$index git write-tree) || status=2
  rm -f "$index"
  return $status
}
