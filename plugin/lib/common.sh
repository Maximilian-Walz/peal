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

# Values that name things (docs/design.md, "Hostile input"): an id, a slug, a branch, a
# path. Each is checked where it first enters, and one that fails is refused with
# peal_refuse; free text (titles, reasons, bodies) is never checked, only passed safely.

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
# in the work tree that way, not as work anyone did.
peal_status_porcelain() {
  local line path
  git status --porcelain "$@" | while IFS= read -r line; do
    case $line in
      '??'*)
        path=${line#???}
        [ -c "$path" ] && continue
        ;;
    esac
    printf '%s\n' "$line"
  done
}

# peal_git_try CMD ARGS... -> CMD ARGS... (a git fetch, push or ls-remote) run quietly:
# stdout kept (ls-remote's own), stderr captured. Its own status is returned; on failure
# PEAL_GIT_ERR holds the reason, one line, trimmed (empty when none was written); on
# success PEAL_GIT_ERR is "". bin/peal already sets GIT_TERMINAL_PROMPT=0 and, without a
# GIT_SSH_COMMAND of the caller's own, a batch-mode ssh with a connect timeout, so a
# remote that cannot authenticate fails this within seconds instead of hanging.
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
