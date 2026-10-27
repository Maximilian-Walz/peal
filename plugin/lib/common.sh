# shellcheck shell=bash
# Helpers every part of the peal CLI uses. Sourced by bin/peal, which sets PEAL_ROOT.

# peal_err MESSAGE... -> "peal: MESSAGE" on stderr.
peal_err() {
  printf 'peal: %s\n' "$*" >&2
}

# peal_project_root -> the top of the git work tree the caller is in, which holds .peal/.
peal_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || {
    peal_err "not inside a git repository"
    return 2
  }
}

# Values that name things (docs/design.md, "Task files"; docs/security.md): an id, a
# slug, a branch, a path. Each is checked where it first enters, and one that fails is
# refused with peal_refuse; free text (titles, reasons, bodies) is never checked, only
# passed safely.

# peal_valid_id ID -> status 0 for a task id of the configured storage: four digits for
# task files (0042), digits for issues (42).
peal_valid_id() {
  if [ "$(peal_config_get storage.kind 2>/dev/null)" = issues ]; then
    [[ "$1" =~ ^[0-9]+$ ]]
  else
    [[ "$1" =~ ^[0-9][0-9][0-9][0-9]$ ]]
  fi
}

# peal_valid_slug SLUG -> status 0 for kebab-case words of a-z and 0-9.
peal_valid_slug() {
  [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]
}

# peal_refuse WHAT VALUE -> "peal: refused: WHAT '<VALUE>'" on stderr (VALUE cut short and
# made printable) and status 2.
peal_refuse() {
  local shown
  shown=$(printf '%s' "$2" | head -c 80 | LC_ALL=C tr -c '[:print:]' '?')
  peal_err "refused: $1 '$shown'"
  return 2
}

# peal_status_porcelain ARGS... -> `git status --porcelain ARGS...`, with an untracked
# character device left out: a sandbox's /dev/null mounted over a protected path shows up
# in the work tree that way, not as work anyone did. An untracked symlink to a device is
# filtered too (it resolves through [ -c ] the same way). git's porcelain paths are
# root-relative regardless of the caller's directory, so they are resolved against the
# work tree's top before the test: called from any directory, not just the top, this
# still gives the right answer.
#
# Only the character device is filtered. Seen from outside that sandbox — a plain host
# process, a machine that never had the mount active, or the same worktree once the
# sandbox is gone — the same path is an ordinary empty regular file: [ -c ] says no, so it
# is not filtered and counts as work like any other untracked file. By decision (0087),
# this is left to git's own .gitignore or .git/info/exclude, not handled here: an
# empty-file heuristic would also swallow a real empty file kept on purpose (.gitkeep,
# __init__.py), and a known-path filter would not be generic.
peal_status_porcelain() {
  local top line path
  top=$(git rev-parse --show-toplevel) || return 1
  git status --porcelain "$@" | while IFS= read -r line; do
    case $line in
      '??'*)
        path=${line#???}
        [ -c "$top/$path" ] && continue
        ;;
    esac
    printf '%s\n' "$line"
  done
}

# peal_untracked_devices -> root-relative paths of untracked character devices, one per
# line: what peal_status_porcelain leaves out, for a caller that must exclude them from a
# `git add -A` rather than just ignore them in a status listing (git's add_to_index
# refuses a device outright, which would stage nothing at all). -z / NUL-separated so a
# quoted path is not misread; each null-terminated record with no rename arrow is one
# untracked path.
peal_untracked_devices() {
  local top rec path
  top=$(git rev-parse --show-toplevel) || return 1
  git status --porcelain -z --untracked-files=all | while IFS= read -r -d '' rec; do
    case $rec in
      '??'*)
        path=${rec#???}
        [ -c "$top/$path" ] && printf '%s\n' "$path"
        ;;
    esac
  done
}

# peal_ssh_batch_mode -> GIT_SSH_COMMAND exported as whatever ssh git already runs (its
# own GIT_SSH_COMMAND; else this repository's core.sshCommand; else GIT_SSH, a bare
# program path, quoted into a command; else plain ssh), " -o BatchMode=yes -o
# ConnectTimeout=10" appended: ssh keeps the first value it is given for an option, so
# any BatchMode or ConnectTimeout the setup already chose still wins, and a proxy or key
# it set through one of these still runs. Only when that command's program is ssh itself
# (the basename of its first word): plink, a wrapper script, is left exactly as it is,
# whatever it prompts its own business. Setting GIT_SSH_COMMAND outright, the way bin/peal
# once did, would have overridden core.sshCommand and GIT_SSH instead of layering onto
# them, and left a sandbox's own GIT_SSH_COMMAND (already set, without batch mode)
# unchanged, so this must run before Peal does anything over the network.
peal_ssh_batch_mode() {
  local cmd program bare=0

  if [ -n "${GIT_SSH_COMMAND-}" ]; then
    cmd=$GIT_SSH_COMMAND
  elif cmd=$(git config --get core.sshCommand 2>/dev/null) && [ -n "$cmd" ]; then
    :
  elif [ -n "${GIT_SSH-}" ]; then
    cmd=$GIT_SSH
    bare=1
  else
    cmd=ssh
  fi

  if [ "$bare" = 1 ]; then
    program=${cmd##*/}
    printf -v cmd '%q' "$cmd"
  else
    # shellcheck disable=SC2086 # a shell command line: word-split to find its program
    set -- $cmd
    program=${1##*/}
  fi
  [ "$program" = ssh ] || return 0

  export GIT_SSH_COMMAND="$cmd -o BatchMode=yes -o ConnectTimeout=10"
}

# peal_extract_tree REF PATH DEST -> REF's PATH copied under DEST; nothing if absent.
# Reads the committed blobs (git ls-tree -r -z, git cat-file blob), never git archive:
# an archive applies the archived tree's own .gitattributes (export-subst rewrites a
# file, export-ignore drops it), so a pull request could change what Peal reads from
# what a reviewer and the merge gate saw. Only regular blobs (100644, 100755) are
# copied; symlinks and gitlinks are skipped. Status 2 and one line saying why when git
# fails or a path has an empty, "." or ".." component.
peal_extract_tree() {
  local ref=$1 dir=$2 dest=$3 list entry meta path sha err status=0 part rest made=""
  git cat-file -e "$ref:$dir" 2>/dev/null || return 0
  list=$(mktemp) || { peal_err "could not read $dir at $ref: no temporary file"; return 2; }
  err=$(mktemp) || { rm -f "$list"; peal_err "could not read $dir at $ref: no temporary file"; return 2; }
  if ! git --literal-pathspecs ls-tree -r -z --full-tree "$ref" -- "$dir" >"$list" 2>"$err"; then
    status=2
    peal_err "could not read $dir at $ref: $(tr '\n' ' ' <"$err" | sed 's/  */ /g; s/ *$//')"
  else
    while IFS= read -r -d '' entry; do
      meta=${entry%%$'\t'*}
      path=${entry#*$'\t'}
      case $meta in
        100644\ blob\ * | 100755\ blob\ *) ;;
        *) continue ;;
      esac
      [ "${path#"$dir"/}" != "$path" ] || continue
      sha=${meta##* }
      rest=$path
      while :; do
        part=${rest%%/*}
        case $part in
          '' | . | ..)
            peal_err "could not read $dir at $ref: bad path component in $path"
            status=2
            break 2 ;;
        esac
        [ "$part" != "$rest" ] || break
        rest=${rest#*/}
      done
      if [ "${path%/*}" != "$made" ]; then
        mkdir -p "$dest/${path%/*}" 2>"$err" || { peal_err "could not read $dir at $ref: $(tr '\n' ' ' <"$err")"; status=2; break; }
        made=${path%/*}
      fi
      if ! git cat-file blob "$sha" >"$dest/$path" 2>"$err"; then
        peal_err "could not read $dir at $ref: $(tr '\n' ' ' <"$err" | sed 's/  */ /g; s/ *$//')"
        status=2
        break
      fi
    done <"$list"
  fi
  rm -f "$list" "$err"
  return $status
}

# peal_git_try CMD ARGS... -> CMD ARGS... (a git fetch, push or ls-remote) run quietly:
# stdout kept (ls-remote's own), stderr captured. Its own status is returned; on failure
# PEAL_GIT_ERR holds the reason, one line, trimmed (empty when none was written); on
# success PEAL_GIT_ERR is "". bin/peal already runs peal_ssh_batch_mode and sets
# GIT_TERMINAL_PROMPT=0, so a remote that cannot authenticate fails this within seconds
# instead of hanging.
peal_git_try() {
  local err status=0
  PEAL_GIT_ERR=""
  err=$(mktemp) || return 2
  "$@" 2>"$err" || status=$?
  # shellcheck disable=SC2034 # read by every caller, after it checks the status
  [ $status = 0 ] || PEAL_GIT_ERR=$(tr '\n' ' ' <"$err" | sed 's/  */ /g; s/ *$//')
  rm -f "$err"
  return $status
}

# peal_remote_ref BRANCH REMOTE -> where BRANCH is on REMOTE: its upstream when one is
# recorded, else the remote-tracking ref a push updates without writing config (a
# sandbox can lock the config); status 1 and nothing when neither exists.
peal_remote_ref() {
  if git rev-parse -q --verify "$1@{upstream}" >/dev/null; then
    echo "$1@{upstream}"
  elif git rev-parse -q --verify "refs/remotes/$2/$1" >/dev/null; then
    echo "refs/remotes/$2/$1"
  else
    return 1
  fi
}

# peal_valid_date DATE -> status 0 for a real calendar date, YYYY-MM-DD (next's declined
# dates, apply's milestone due).
peal_valid_date() {
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
