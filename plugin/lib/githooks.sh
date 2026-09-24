# shellcheck shell=bash
# Peal's git gates (docs/design.md, "Hooks"): what may reach the main branch, and what a
# commit must satisfy. `peal hooks install` writes templates/githook under every hook
# name into the git directory and points core.hooksPath there; that stub runs the gates
# below through `peal githook NAME`, then the project's own hook of the same name.

PEAL_GITHOOKS="applypatch-msg pre-applypatch post-applypatch pre-commit pre-merge-commit
prepare-commit-msg commit-msg post-commit pre-rebase post-checkout post-merge pre-push
post-rewrite pre-auto-gc post-index-change sendemail-validate"

# The commit subject grammar: <type>(<area>): <what> [NNNN].
PEAL_COMMIT_TYPES="feat fix test refactor docs chore wip"
PEAL_SUBJECT_RE='^(feat|fix|test|refactor|docs|chore|wip)(\(([a-z0-9][a-z0-9-]*)\))?: (.*[^ ])$'

# _peal_hooks_dir -> where the stubs live: peal/hooks in the git directory all worktrees
# share, as an absolute path.
_peal_hooks_dir() {
  local common
  common=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd) || {
    peal_err "not inside a git repository"
    return 2
  }
  printf '%s/peal/hooks\n' "$common"
}

# peal_hooks_install -> the stubs written, core.hooksPath pointed at them, a hooks path
# set before kept as peal.projectHooks for the stubs to chain to, and this Peal's root
# recorded for the stubs to find.
peal_hooks_install() {
  local dir prev name chain
  dir=$(_peal_hooks_dir) || return 2
  mkdir -p "$dir" || return 2
  for name in $PEAL_GITHOOKS; do
    if ! { cp "$PEAL_ROOT/templates/githook" "$dir/$name.$$" && chmod +x "$dir/$name.$$" \
        && mv -f "$dir/$name.$$" "$dir/$name"; }; then
      peal_err "could not write $dir/$name"
      return 2
    fi
  done
  prev=$(git config core.hooksPath)
  if [ -n "$prev" ] && [ "$prev" != "$dir" ]; then
    git config peal.projectHooks "$prev" || return 2
  fi
  git config core.hooksPath "$dir" || return 2
  printf '%s\n' "$PEAL_ROOT" >"${dir%/hooks}/../peal-root" || return 2
  chain=$(git config peal.projectHooks) || chain="${dir%/peal/hooks}/hooks"
  echo "installed Peal's git hooks in $dir (core.hooksPath); they chain to the hooks in $chain"
}

# peal_hooks_installed -> status 0 if core.hooksPath points at Peal's stubs.
peal_hooks_installed() {
  local dir
  dir=$(_peal_hooks_dir) || return 2
  [ "$(git config core.hooksPath)" = "$dir" ] && [ -x "$dir/commit-msg" ] && [ -x "$dir/pre-push" ]
}

# _peal_gate_refuse HOOK MESSAGE [LINE...] -> the refusal on stderr; PEAL_GATE_FAIL set.
_peal_gate_refuse() {
  local hook=$1
  printf '%s: %s\n' "$hook" "$2" >&2
  shift 2
  [ $# -eq 0 ] || printf '%s\n' "$@" | sed 's/^/  /' >&2
  PEAL_GATE_FAIL=1
}

# peal_githook NAME ARGS... -> the gate of hook NAME; status 1 when it refuses.
peal_githook() {
  local name=$1
  shift
  PEAL_GATE_FAIL=0
  if ! peal_config_load; then
    echo "$name: Peal's settings do not load (above); the $name is refused until they do" >&2
    return 1
  fi
  case $name in
    pre-push) _peal_pre_push ;;
    commit-msg)
      [ $# -ge 1 ] || { peal_err "githook commit-msg: the message file"; return 2; }
      _peal_commit_msg "$1"
      ;;
    *) peal_err "githook: no gate for $name"; return 2 ;;
  esac
}

# --- pre-push ----------------------------------------------------------------------------
# Lets through to the main branch only what the storage writes there directly, and merges
# of branches pushed before. Every commit the push adds to main's first-parent line is one
# of:
#   - a merge whose other parents are each on a remote-tracking branch already: a branch
#     that was pushed first, not content made up as a merge parent;
#   - a commit the storage made, told by its subject and checked by its diff's shape (the
#     subject alone is only a string the caller chose):
#       docs(tasks): file ...                  only added backlog task files
#       docs(tasks): revise|defer ID ...       exactly one modified backlog task file, ID's
#       docs(tasks): set milestone of ID ...
#       docs(tasks): note on ID ...
#       docs(tasks): retire ID ...             ID's backlog file moved to done/, unrenamed
# Rewriting main (not a fast-forward) and deleting it are refused. Git runs no pre-push
# for a merge made on the server (a pull request's), so this never stands in its way.
# Known limit: the main branch and the tasks directory are this worktree's settings.

_peal_pre_push() {
  local main tasks lsha rref rsha range sha parents
  main=$(peal_config_get main) || return 1
  tasks=$(peal_config_get tasks) || return 1
  tasks=${tasks%/}
  while IFS=' ' read -r _ lsha rref rsha; do
    [ "$rref" = "refs/heads/$main" ] || continue
    if [[ "$lsha" =~ ^0+$ ]]; then
      _peal_gate_refuse pre-push "the push deletes $main; never."
      continue
    fi
    if [[ "$rsha" =~ ^0+$ ]]; then
      range="$lsha --not --remotes"
    elif ! git merge-base --is-ancestor "$rsha" "$lsha" 2>/dev/null; then
      _peal_gate_refuse pre-push "the push to $main is not a fast-forward: $main is never rewritten."
      continue
    else
      range="$rsha..$lsha"
    fi
    # shellcheck disable=SC2086 # the range is several words
    for sha in $(git rev-list --first-parent $range); do
      parents=$(git show -s --format=%P "$sha" | wc -w)
      if [ "$parents" -gt 1 ]; then
        _peal_pre_push_merge "$sha" "$main"
      else
        _peal_pre_push_direct "$sha" "$main" "$tasks"
      fi
    done
  done
  [ "$PEAL_GATE_FAIL" = 0 ] || {
    echo "pre-push: nothing reaches $main but a merged pull request and Peal's own writes (peal create, revise, retire, ...)." >&2
    return 1
  }
}

# _peal_pre_push_merge SHA MAIN -> refused unless every parent after the first is on a
# remote-tracking branch.
_peal_pre_push_merge() {
  local sha=$1 main=$2 parent ref seen
  for parent in $(git show -s --format=%P "$sha" | cut -d' ' -f2-); do
    seen=0
    for ref in $(git for-each-ref --format='%(refname)' refs/remotes/); do
      if git merge-base --is-ancestor "$parent" "$ref" 2>/dev/null; then
        seen=1
        break
      fi
    done
    [ $seen = 1 ] || _peal_gate_refuse pre-push \
      "merge $(git rev-parse --short "$sha") brings $(git rev-parse --short "$parent") onto $main, which no pushed branch holds." \
      "A merge onto $main merges a branch that was pushed first."
  done
}

# _peal_pre_push_direct SHA MAIN TASKS -> refused unless SHA is one of the storage's
# writes, by subject and by the shape of its diff.
_peal_pre_push_direct() {
  local sha=$1 main=$2 tasks=$3 subject shape id diff short why
  subject=$(git show -s --format=%s "$sha")
  short=$(git rev-parse --short "$sha")
  case $subject in
    'docs(tasks): file '*) shape=add ;;
    'docs(tasks): revise '* | 'docs(tasks): defer '* | 'docs(tasks): set milestone of '* | 'docs(tasks): note on '*) shape=modify ;;
    'docs(tasks): retire '*) shape=retire ;;
    *)
      _peal_gate_refuse pre-push "$short reaches $main directly and is no merge: \"$subject\""
      return
      ;;
  esac
  id=""
  [[ "$subject" =~ \[([0-9][0-9][0-9][0-9])\]$ ]] && id=${BASH_REMATCH[1]}
  diff=$(git diff-tree -r --raw --no-commit-id --no-renames --root "$sha")
  if ! why=$(printf '%s\n' "$diff" | awk -v shape="$shape" -v tasks="$tasks" -v id="$id" '
      function bad(why) { print why; failed = 1; exit 1 }
      function task(p, dir,    f) {
        if (index(p, tasks "/" dir "/") != 1) return ""
        f = substr(p, length(tasks) + length(dir) + 3)
        return f ~ /^[0-9][0-9][0-9][0-9]-[^\/]+\.md$/ ? f : ""
      }
      $0 == "" { next }
      {
        split($0, f, "\t"); path = f[2]
        split(f[1], m, " "); omode = substr(m[1], 2); nmode = m[2]; st = m[5]
        n++
        if (shape == "add") {
          if (st != "A" || nmode != "100644" || task(path, "backlog") == "")
            bad("not an added backlog task file: " st " " nmode " " path)
        } else if (shape == "modify") {
          if (st != "M" || omode != "100644" || nmode != "100644" || task(path, "backlog") == "")
            bad("not a modified backlog task file: " st " " nmode " " path)
          if (substr(task(path, "backlog"), 1, 4) != id) bad("not the file of task " id ": " path)
        } else {
          if (st == "D" && task(path, "backlog") != "" && omode == "100644") gone = task(path, "backlog")
          else if (st == "A" && task(path, "done") != "" && nmode == "100644") came = task(path, "done")
          else bad("neither a deleted backlog nor an added done task file: " st " " nmode " " path)
        }
      }
      END {
        if (failed) exit 1
        if (n == 0) { print "the diff is empty"; exit 1 }
        if (shape == "modify" && n != 1) { print n " files changed, not one"; exit 1 }
        if (shape == "retire" && (n != 2 || gone == "" || gone != came)) { print "not one backlog task file moved to done/ as it is named"; exit 1 }
        if (shape == "retire" && substr(gone, 1, 4) != id) { print "not the file of task " id ": " gone; exit 1 }
      }'); then
    _peal_gate_refuse pre-push "$short reaches $main directly as \"$subject\", but its diff is not that shape:" "$why"
  fi
}

# --- commit-msg --------------------------------------------------------------------------
# The subject: <type>(<area>): <what> [NNNN], type one of PEAL_COMMIT_TYPES, the area one
# of commit.areas (required when there are any; `tasks` is always one), NNNN the task.
# Git's own subjects pass as they are (Revert, fixup!, squash!, amend!); a merge's is not
# checked, but its diff pays the checks. Two fast paths skip the checks:
#   wip: ... / wip(<area>): ...   honest work in progress, no task id needed;
#   <type>(tasks): ... [NNNN]     a task file's move or edit: the staged diff must lie in
#                                 the tasks directory and nowhere else.
# Otherwise each of checks.commit runs whose paths the staged diff touches: an item
# "PATH...: COMMAND" runs COMMAND when a staged path is PATH or under it (PATH may be a
# glob), an item without paths always runs.

# _peal_subject FILE -> the message's first line that is neither empty nor a comment.
_peal_subject() {
  awk '/^#/ || /^[ \t]*$/ { next } { print; exit }' "$1"
}

# _peal_staged -> every path the commit changes, both sides of a rename.
_peal_staged() {
  git diff --cached --name-only --no-renames
}

_peal_commit_msg() {
  local subject merge=0 area what areas tasks outside
  subject=$(_peal_subject "$1")
  case $subject in
    "Revert "* | "fixup! "* | "squash! "* | "amend! "*) return 0 ;;
    "Merge "*) merge=1 ;;
  esac
  if [ $merge = 0 ]; then
    if ! [[ "$subject" =~ $PEAL_SUBJECT_RE ]]; then
      _peal_gate_refuse commit-msg "the subject is not <type>(<area>): <what> [NNNN]: \"$subject\"" \
        "types: $PEAL_COMMIT_TYPES; wip: <what> for work in progress"
      return 1
    fi
    area=${BASH_REMATCH[3]} what=${BASH_REMATCH[4]}
    if [ "${subject%%[(:]*}" = wip ]; then
      echo "commit-msg: a wip commit; the checks are skipped. Say what is in flight in the task's Outcome."
      return 0
    fi
    areas=$(peal_config_get commit.areas) || return 1
    if [ -n "$areas" ] && [ -z "$area" ]; then
      _peal_gate_refuse commit-msg "the subject names no area: <type>(<area>): ..." \
        "areas: $(printf '%s\n' "$areas" tasks | tr '\n' ' ')"
      return 1
    fi
    if [ -n "$areas" ] && [ "$area" != tasks ] && ! printf '%s\n' "$areas" | grep -qxF -- "$area"; then
      _peal_gate_refuse commit-msg "the area $area is not one of commit.areas" \
        "areas: $(printf '%s\n' "$areas" tasks | tr '\n' ' ')"
      return 1
    fi
    if ! [[ "$what" =~ ^(.*[^ ])\ \[[0-9][0-9][0-9][0-9]\]$ ]]; then
      _peal_gate_refuse commit-msg "the subject does not end with its task id, as in \"feat(x): what [0042]\"" \
        "subject: $subject"
      return 1
    fi
    if [ "$area" = tasks ]; then
      tasks=$(peal_config_get tasks) || return 1
      tasks=${tasks%/}
      outside=$(_peal_staged | awk -v t="$tasks/" 'index($0, t) != 1')
      if [ -n "$outside" ]; then
        _peal_gate_refuse commit-msg "a ($area) commit touches only $tasks/; this one also:" "$outside"
        return 1
      fi
      echo "commit-msg: only task files; the checks are skipped."
      return 0
    fi
  fi
  _peal_commit_checks "$merge"
}

# _peal_check_split ITEM -> PEAL_CHECK_PATHS and PEAL_CHECK_CMD from "PATH...: COMMAND";
# no paths for an item that does not start with plain path words and ": ".
_peal_check_split() {
  local re='^([^- :;&|<>$"'\''=][^ :;&|<>$"'\''=]*( +[^- :;&|<>$"'\''=][^ :;&|<>$"'\''=]*)*): +(.+)$'
  if [[ "$1" =~ $re ]]; then
    PEAL_CHECK_PATHS=${BASH_REMATCH[1]} PEAL_CHECK_CMD=${BASH_REMATCH[3]}
  else
    PEAL_CHECK_PATHS="" PEAL_CHECK_CMD=$1
  fi
}

# _peal_check_applies PATHS STAGED -> status 0 if a staged path is one of PATHS or under
# it; always for no PATHS.
_peal_check_applies() {
  local pattern file
  [ -n "$1" ] || return 0
  for pattern in $1; do
    pattern=${pattern%/}
    while IFS= read -r file; do
      # shellcheck disable=SC2254 # the pattern is a glob on purpose
      case $file in $pattern | $pattern/*) return 0 ;; esac
    done <<<"$2"
  done
  return 1
}

# _peal_commit_checks MERGE -> each applicable check of checks.commit run from the top of
# the work tree, git's variables for this hook unset so a check's own git calls see its
# repository plainly; status 1 at the first that fails.
_peal_commit_checks() {
  local merge=$1 checks staged item top ran=0 remedy="Fix it, or commit as 'wip: ...'."
  [ "$merge" = 0 ] || remedy="Fix it and commit again, or give up the merge with git merge --abort."
  checks=$(peal_config_get checks.commit) || return 1
  [ -n "$checks" ] || return 0
  staged=$(_peal_staged)
  top=$(git rev-parse --show-toplevel) || return 1
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    _peal_check_split "$item"
    _peal_check_applies "$PEAL_CHECK_PATHS" "$staged" || continue
    ran=1
    echo "commit-msg: running $PEAL_CHECK_CMD"
    # shellcheck disable=SC2046 # the names of the variables to unset
    if ! (cd "$top" && unset $(compgen -v GIT_) && bash -c "$PEAL_CHECK_CMD") </dev/null; then
      _peal_gate_refuse commit-msg "$PEAL_CHECK_CMD failed; the commit is refused. $remedy"
      return 1
    fi
  done <<<"$checks"
  [ $ran = 1 ] && echo "commit-msg: the checks passed." || echo "commit-msg: no check applies to this diff."
}
