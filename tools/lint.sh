#!/usr/bin/env bash
# Runs shellcheck over every shell script in the repository: *.sh files and any file
# whose first line names bash or sh. CI runs this; so can you:
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
shellcheck "${scripts[@]}"
