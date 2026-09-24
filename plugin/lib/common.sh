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
