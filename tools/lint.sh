#!/usr/bin/env bash
# Runs shellcheck over every shell script in the repository: *.sh files and any file
# whose first line names bash or sh; then this branch's `peal check` over Peal's own tasks
# (a duplicate task id, an empty Outcome, a depends cycle). CI runs this; so can you:
#
#   tools/lint.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

scripts=()
while IFS= read -r file; do
  case $file in
    *.sh) scripts+=("$file") ;;
    *) head -n1 "$file" | grep -Eq '^#!.*[/ ](ba)?sh$' && scripts+=("$file") ;;
  esac
done < <(find . -type f -not -path './.git/*' | sort)
if [ ${#scripts[@]} -eq 0 ]; then
  echo "lint: no shell scripts found; the search is broken" >&2
  exit 2
fi
printf 'lint: shellcheck on %d scripts\n' "${#scripts[@]}"
status=0
shellcheck "${scripts[@]}" || status=1
echo 'lint: peal check'
PEAL_ROOT=$PWD/plugin plugin/bin/peal check || status=1
exit $status
