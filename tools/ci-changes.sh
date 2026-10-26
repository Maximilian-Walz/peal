#!/usr/bin/env bash
# Whether CI's harnesses must run for the change from BASE to HEAD: prints
# `harnesses=true` or `harnesses=false`, a line for $GITHUB_OUTPUT.
#
#   tools/ci-changes.sh BASE HEAD
#
# false only when every changed file is one no harness reads: a task file (tasks/),
# a milestone's text (docs/milestones/), the changelog (CHANGELOG.md, a release's
# entry), plugin.json with nothing but its version changed (a release's bump), or a
# plugin/templates/*.yml with nothing but Peal's fetch line changed in its SHA and/or
# `# vX.Y.Z` (a release's bump and pin; tools/pins.test.sh checks those lines in CI).
# Anything else runs them, and so does any doubt: no BASE (a new branch's first push), a
# BASE git does not have, a diff that fails.
set -uo pipefail

base=${1:-} head=${2:-HEAD}
yes() { echo harnesses=true; exit 0; }
fetch_url=https://github\\.com/Maximilian-Walz/peal

# The -/+ lines of one file's diff: everything before the first @@ is header, all after it
# is content (a content line may itself start with `++ ` or `-- `).
changed_lines() {
  git diff --no-renames -U0 "$base" "$head" -- "$1" | awk '/^@@/ {h=1; next} h && /^[-+]/'
}

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
      changed=$(changed_lines "$f") || yes
      if printf '%s\n' "$changed" | grep -Evq '^[-+] *"version": *"[^"]+", *$'; then
        yes
      fi
      ;;
    plugin/templates/*.yml)
      # One line out, one in, both Peal's fetch line, equal but for the SHA and the tag.
      # Hard-coded, not read from .peal/config.yml: a diff changing that runs everything.
      changed=$(changed_lines "$f") || yes
      [ "$(printf '%s\n' "$changed" | grep -c '^-')" = 1 ] || yes
      [ "$(printf '%s\n' "$changed" | grep -c '^+')" = 1 ] || yes
      old=$(printf '%s\n' "$changed" | grep '^-')
      new=$(printf '%s\n' "$changed" | grep '^+')
      norm() {
        printf '%s\n' "${1#?}" | sed -En "s|^(.*fetch -q --depth 1 ${fetch_url} )[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+\$|\1SHA # vN|p"
      }
      o=$(norm "$old") n=$(norm "$new")
      { [ -n "$o" ] && [ "$o" = "$n" ]; } || yes
      ;;
    *) yes ;;
  esac
done <<<"$files"
echo harnesses=false
