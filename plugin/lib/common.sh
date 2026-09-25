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

# peal_valid_ref NAME -> status 0 for a branch name git accepts that reads as no option.
peal_valid_ref() {
  case $1 in "" | -*) return 1 ;; esac
  git check-ref-format "refs/heads/$1" 2>/dev/null
}

# peal_valid_relpath PATH -> status 0 for a path relative to the top that stays under it:
# no leading / or -, no .. component, no newline.
peal_valid_relpath() {
  case $1 in "" | /* | -* | *$'\n'*) return 1 ;; esac
  case /$1/ in */../*) return 1 ;; esac
}

# peal_refuse WHAT VALUE -> "peal: refused: WHAT '<VALUE>'" on stderr (VALUE cut short and
# made printable) and status 2.
peal_refuse() {
  local shown
  shown=$(printf '%s' "$2" | head -c 80 | LC_ALL=C tr -c '[:print:]' '?')
  peal_err "refused: $1 '$shown'"
  return 2
}
