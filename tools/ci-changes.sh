#!/usr/bin/env bash
# Whether CI's harnesses must run for the change from BASE to HEAD: prints
# `harnesses=true` or `harnesses=false`, a line for $GITHUB_OUTPUT.
#
#   tools/ci-changes.sh BASE HEAD
#
# false only when every changed file is one no harness reads: a task file (tasks/),
# a milestone's text (docs/milestones/), the changelog (CHANGELOG.md, a release's
# entry), or plugin.json with nothing but its version changed (a release's bump).
# Anything else runs them, and so does any doubt: no BASE (a new branch's first push), a
# BASE git does not have, a diff that fails.
set -uo pipefail

base=${1:-} head=${2:-HEAD}
yes() { echo harnesses=true; exit 0; }

case $base in '' | *[!0]*) ;; *) yes ;; esac # empty, or 000…: nothing to compare with
[ -n "$base" ] || yes
git cat-file -e "$base^{commit}" 2>/dev/null || yes
# --no-renames: a file moved from code into tasks/ lists its old path too.
files=$(git diff --no-renames --name-only "$base" "$head") || yes

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case $f in
    tasks/* | docs/milestones/* | CHANGELOG.md) continue ;;
    plugin/.claude-plugin/plugin.json)
      # Only lines setting "version" may change.
      # As strict as peal_version (plugin/bin/peal) reads it: spaces only, not empty.
      changed=$(git diff --no-renames -U0 "$base" "$head" -- "$f" | grep -E '^[-+]' | grep -Ev '^(\+\+\+|---) ') || yes
      if printf '%s\n' "$changed" | grep -Evq '^[-+] *"version": *"[^"]+", *$'; then
        yes
      fi
      ;;
    *) yes ;;
  esac
done <<<"$files"
echo harnesses=false
