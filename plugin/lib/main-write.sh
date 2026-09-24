# shellcheck shell=bash
# Writes onto the main branch that never touch a worktree: a commit built on a temporary
# index from the fetched main, and pushed. The push is the lock: one that loses a race is
# built again on the new main. The task-file storage files and edits tasks this way, the
# decisions module publishes its index.

# peal_push_main BUILD -> BUILD BASE run on the remote's main and its result pushed
# there, again on a new main when the push loses a race (PEAL_PUSH_ATTEMPTS, 5). BUILD
# sets PEAL_TREE and PEAL_SUBJECT, or refuses with status 2. A push that fails for
# another reason is not retried: status 1.
peal_push_main() {
  local build=$1 attempt=1 max=${PEAL_PUSH_ATTEMPTS:-5} base sha new err status
  err=$(mktemp) || return 2
  while :; do
    base=$(git rev-parse --verify -q "refs/remotes/$PEAL_REMOTE/$PEAL_MAIN") || {
      peal_err "$PEAL_REMOTE/$PEAL_MAIN is gone"; rm -f "$err"; return 2; }
    PEAL_TREE="" PEAL_SUBJECT=""
    "$build" "$base" || { status=$?; rm -f "$err"; return $status; }
    sha=$(git commit-tree "$PEAL_TREE" -p "$base" -m "$PEAL_SUBJECT") || { rm -f "$err"; return 2; }
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
