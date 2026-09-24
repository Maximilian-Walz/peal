# shellcheck shell=bash
# peal commit: add, commit and report in one call, so a session spends one tool call on
# what is one step. It decides nothing about when to commit; the commit-msg gate still
# judges the commit.

# peal_commit SUBJECT [--body TEXT | --body-file FILE] [PATH...] -> PATHs (or everything,
# without any) staged and committed with SUBJECT, the commit reported. Refused: on the main
# branch or a detached HEAD, without Peal's git hooks installed (the commit would go
# ungated), a new backlog task file (those are filed onto main, never on a branch), and
# nothing to commit.
peal_commit() {
  local subject=${1-} body="" main branch tasks added top
  if [ -z "$subject" ]; then
    peal_err 'commit: "<type>(<area>): <what> [NNNN]" [--body TEXT | --body-file FILE] [PATH...]'
    return 2
  fi
  shift
  case ${1-} in
    --body)
      [ $# -ge 2 ] || { peal_err "commit: --body needs a text"; return 2; }
      body=$2
      shift 2
      ;;
    --body-file)
      [ $# -ge 2 ] || { peal_err "commit: --body-file needs a file"; return 2; }
      if [ ! -f "$2" ] || [ ! -r "$2" ]; then
        peal_err "commit: --body-file: no readable file $2"
        return 2
      fi
      body=$(cat "$2")
      [ -n "$body" ] || { peal_err "commit: --body-file: $2 is empty"; return 2; }
      shift 2
      ;;
  esac
  for added in "$@"; do
    case $added in
      --body | --body-file) peal_err "commit: $added goes right after the subject, once"; return 2 ;;
    esac
  done
  top=$(peal_project_root) || return 2
  cd "$top" || return 2
  main=$(peal_config_get main) || return 2
  tasks=$(peal_config_get tasks) || return 2
  tasks=${tasks%/}
  branch=$(git symbolic-ref -q --short HEAD) || {
    peal_err "commit: refused on a detached HEAD; commit on the task's branch"
    return 2
  }
  if [ "$branch" = "$main" ]; then
    peal_err "commit: refused on $main; commit on the task's branch"
    return 2
  fi
  if ! peal_hooks_installed; then
    peal_err "commit: Peal's git hooks are not installed here, so nothing would gate the commit; run: peal hooks install"
    return 2
  fi
  if [ $# -gt 0 ]; then
    git add -- "$@" || { peal_err "commit: git add failed"; return 2; }
  else
    git add -A || { peal_err "commit: git add failed"; return 2; }
  fi
  added=$(git diff --cached --name-only --no-renames --diff-filter=A -- "$tasks/backlog/")
  if [ -n "$added" ]; then
    printf '%s\n' "$added" | while IFS= read -r top; do git reset -q -- "$top"; done
    peal_err "commit: refused: a new backlog task file is filed onto $main (peal idea), never committed on a branch; unstaged:"
    printf '  %s\n' "$added" >&2
    return 2
  fi
  if git diff --cached --quiet; then
    peal_err "commit: nothing staged, nothing to commit"
    return 2
  fi
  set -- -q -m "$subject"
  [ -z "$body" ] || set -- "$@" -m "$body"
  if ! git commit "$@"; then
    peal_err "commit: the commit was refused (above); nothing was committed"
    return 1
  fi
  git log -1 --stat --format='committed %h %s'
}
