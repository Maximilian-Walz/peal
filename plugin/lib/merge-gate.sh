# shellcheck shell=bash
# peal merge-gate BASE HEAD: the check a pull request runs so that `merge: auto`, which
# the human writes only when agreeing a plan, cannot arrive through a pull request that
# merges by itself on its paths (a task-files-only one). It reads git objects only, never
# the work tree: BASE's settings for BASE, HEAD's for HEAD.
#
# Refused (status 1, each file named): a task file under backlog/ or doing/ that is new
# or changed from BASE and whose frontmatter does not parse, or that holds a merge key
# BASE did not already give a task of the same id outside done/, with the same value; a
# task that keeps an agreed merge but changes any byte (a move or rename keeps the blob);
# a file whose id another file in backlog/ or doing/ shares when any of them holds merge.
# Status 2 for a ref that is empty, all zeros, starts with "-", or is no commit, for
# settings that do not load, and for git failing: any doubt fails closed.

# _peal_mg_list REF TASKS -> "rel<TAB>blob" for each task file at REF under TASKS, rel
# its path below TASKS (backlog/0001-slug.md); only the names task-scan.awk reads (a
# kebab-case slug), which hold no tab or newline. Status 2 when git fails.
_peal_mg_list() {
  local ref=$1 tasks=$2 entry meta path rel tmp status=0
  tmp=$(mktemp) || { peal_err "merge-gate: no temporary file"; return 2; }
  git --literal-pathspecs ls-tree -r -z --full-tree "$ref" -- \
    "$tasks/backlog/" "$tasks/doing/" "$tasks/done/" >"$tmp" || status=2
  if [ $status = 0 ]; then
    while IFS= read -r -d '' entry; do
      meta=${entry%%$'\t'*}
      path=${entry#*$'\t'}
      [ "${meta#* blob }" != "$meta" ] || continue
      rel=${path#"$tasks/"}
      [ "$rel" != "$path" ] || continue
      [[ "$rel" =~ ^(backlog|doing|done)/[0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] || continue
      printf '%s\t%s\n' "$rel" "${meta##* }"
    done <"$tmp"
  else
    peal_err "merge-gate: cannot list the task files at $ref"
  fi
  rm -f "$tmp"
  return $status
}

# _peal_mg_shown TEXT -> TEXT printable, a backslash too (awk -v would read it as an
# escape): a tasks setting is the project's own text.
_peal_mg_shown() {
  # shellcheck disable=SC1003 # tr reads the escaped backslash itself
  printf '%s' "$1" | LC_ALL=C tr -c '[:print:]' '?' | LC_ALL=C tr '\\' '?'
}

# _peal_mg_merge BLOB NAME -> merge-gate.awk's verdict on the blob, read byte for byte as
# task-scan.awk reads the file: "bad", or "ok" and the merge records. Status 2 when git
# fails. NAME is printable already.
_peal_mg_merge() {
  git cat-file blob "$1" | awk -v name="$2" \
    -f "$PEAL_ROOT/lib/yaml-lib.awk" -f "$PEAL_ROOT/lib/merge-gate.awk" \
    || { peal_err "merge-gate: cannot read $2"; return 2; }
}

# _peal_mg_ref NAME REF -> REF's commit, or status 2 and why.
_peal_mg_ref() {
  local sha
  case $2 in
    -*) peal_refuse "merge-gate: $1" "$2"; return 2 ;;
    '') peal_err "merge-gate: $1 is empty: nothing to compare with"; return 2 ;;
  esac
  case $2 in
    *[!0]*) ;;
    *) peal_err "merge-gate: $1 is all zeros: nothing to compare with"; return 2 ;;
  esac
  sha=$(git rev-parse -q --verify "$2^{commit}" 2>/dev/null) || {
    peal_refuse "merge-gate: $1 (no commit)" "$2"
    return 2
  }
  printf '%s\n' "$sha"
}

peal_merge_gate() {
  local base head btasks htasks bkind blist hlist line rel blob id verdict value
  local bline bverdict match sameblob refused=0 bshown hshown dups dline dverdict anymerge
  [ $# -eq 2 ] || { peal_err "usage: peal merge-gate BASE HEAD"; return 2; }
  base=$(_peal_mg_ref BASE "$1") || return 2
  head=$(_peal_mg_ref HEAD "$2") || return 2

  peal_config_load_ref "$base" || return 2
  bkind=$(peal_config_get storage.kind) || return 2
  btasks=$(peal_config_get tasks) || return 2
  peal_config_load_ref "$head" || return 2
  if [ "$(peal_config_get storage.kind)" = issues ]; then
    echo "merge-gate: issues storage, nothing to check"
    return 0
  fi
  htasks=$(peal_config_get tasks) || return 2
  bshown=$(_peal_mg_shown "$btasks")
  hshown=$(_peal_mg_shown "$htasks")

  # BASE's task files; none when BASE kept its tasks as issues.
  blist=""
  if [ "$bkind" = files ]; then
    blist=$(_peal_mg_list "$base" "$btasks") || return 2
  fi
  hlist=$(_peal_mg_list "$head" "$htasks") || return 2

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    rel=${line%%$'\t'*}
    blob=${line#*$'\t'}
    case $rel in backlog/* | doing/*) ;; *) continue ;; esac
    # The same path with the same blob at BASE: nothing this pull request wrote.
    if printf '%s\n' "$blist" | grep -qxF -- "$line"; then continue; fi
    verdict=$(_peal_mg_merge "$blob" "$hshown/$rel") || return 2
    if [ "$verdict" = bad ]; then
      echo "merge-gate: refused: $hshown/$rel: its frontmatter does not parse"
      refused=1
      continue
    fi
    id=${rel#*/}
    id=${id%%-*}
    # Another file of this id in backlog/ or doing/ at HEAD, when any file of the id
    # holds merge: the gate matches an agreed merge by id, so a second file would borrow it.
    dups=$(printf '%s\n' "$hlist" | grep -E "^(backlog|doing)/$id-" || true)
    if [ "$(printf '%s\n' "$dups" | grep -c .)" -gt 1 ]; then
      anymerge=0
      [ "$verdict" = ok ] || anymerge=1
      while [ $anymerge = 0 ] && IFS= read -r dline; do
        dverdict=$(_peal_mg_merge "${dline#*$'\t'}" "$hshown/${dline%%$'\t'*}") || return 2
        [ "$dverdict" = ok ] || anymerge=1
      done <<<"$dups"
      if [ $anymerge = 1 ]; then
        echo "merge-gate: refused: $hshown/$rel: another task file holds id $id, which holds merge"
        refused=1
        continue
      fi
    fi
    [ "$verdict" != ok ] || continue
    value=${verdict#ok$'\n'}
    # A task of the same id outside done/ at BASE with the same merge value and the same
    # blob: moved or renamed, not edited and not given its merge here.
    sameblob=0
    match=0
    while IFS= read -r bline; do
      [ -n "$bline" ] || continue
      bverdict=$(_peal_mg_merge "${bline#*$'\t'}" "$bshown/${bline%%$'\t'*}") || return 2
      if [ "$bverdict" = "ok"$'\n'"$value" ]; then
        match=1
        [ "${bline#*$'\t'}" != "$blob" ] || sameblob=1
        [ $sameblob = 0 ] || break
      fi
    done <<<"$(printf '%s\n' "$blist" | grep -E "^(backlog|doing)/$id-")"
    if [ $match = 0 ]; then
      echo "merge-gate: refused: $hshown/$rel: sets merge, which only the human's agreement to a plan writes"
      refused=1
    elif [ $sameblob = 0 ]; then
      echo "merge-gate: refused: $hshown/$rel: changes a task whose merge the human agreed; drop merge with the change, or a human merges it"
      refused=1
    fi
  done <<<"$hlist"

  if [ $refused = 1 ]; then
    echo "merge-gate: a human merges this pull request (docs/security.md, \"Auto-merge tiers\")"
    return 1
  fi
  echo "merge-gate: no task file gains a merge key or changes under one"
  return 0
}
