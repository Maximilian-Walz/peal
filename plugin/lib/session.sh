# shellcheck shell=bash
# Where Peal is installed, for callers outside Claude Code: the SessionStart hook records
# the running plugin's root in the repository's git directory, where the launcher
# (templates/launcher) looks before falling back to Claude Code's plugin cache.

PEAL_ROOT_RECORD=peal-root

# peal_record_root DIR -> writes PEAL_ROOT into the git directory shared by all of DIR's
# worktrees, if DIR is in a repository that uses Peal (has .peal/). Silent, and never
# fails a session: a missing record only makes the launcher search the cache.
peal_record_root() {
  local top common
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
  [ -d "$top/.peal" ] || return 0
  common=$(cd "$top" && cd "$(git rev-parse --git-common-dir)" && pwd) 2>/dev/null || return 0
  if printf '%s\n' "$PEAL_ROOT" >"$common/$PEAL_ROOT_RECORD.$$" 2>/dev/null; then
    mv -f "$common/$PEAL_ROOT_RECORD.$$" "$common/$PEAL_ROOT_RECORD" 2>/dev/null
  fi
  return 0
}
