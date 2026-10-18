#!/usr/bin/env bash
# Runs shellcheck over every shell script in the repository: *.sh files and any file
# whose first line names bash or sh; then tools/pins.sh (the workflow files' pins); then this branch's `peal check` over Peal's own tasks
# (a duplicate task id, an empty Outcome, a depends cycle). CI runs this; so can you:
#
#   tools/lint.sh
#
# The files looked at are git's: tracked, plus untracked ones that are not ignored; never
# a sandbox's placeholder mounts, nor anything that is not a readable regular file.
#
#   tools/lint.sh --list    prints the scripts found, one per line, and stops
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

scripts=()
while IFS= read -r -d '' file; do
  if [ ! -f "$file" ] || [ -L "$file" ] || [ ! -r "$file" ]; then continue; fi
  case $file in
    *.sh) scripts+=("$file") ;;
    *) head -n1 "$file" 2>/dev/null | grep -Eq '^#!.*[/ ](ba)?sh$' && scripts+=("$file") ;;
  esac
done < <(git ls-files -co --exclude-standard -z 2>/dev/null | sort -zu)
if [ ${#scripts[@]} -eq 0 ]; then
  echo "lint: no shell scripts found; the search is broken" >&2
  exit 2
fi
if [ "${1-}" = "--list" ]; then
  printf '%s\n' "${scripts[@]}"
  exit 0
fi
printf 'lint: shellcheck on %d scripts\n' "${#scripts[@]}"
status=0
shellcheck "${scripts[@]}" || status=1
echo 'lint: pins'
tools/pins.sh || status=1
echo 'lint: peal check'
PEAL_ROOT=$PWD/plugin plugin/bin/peal check || status=1
exit $status
