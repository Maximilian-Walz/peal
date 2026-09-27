#!/usr/bin/env bash
# Runs every *.test.sh harness in the repository and fails if any fails. CI runs this;
# so can you:
#
#   tools/test-all.sh
#
# Given paths, runs only those harnesses instead of finding every one:
#
#   tools/test-all.sh plugin/lib/hostile.test.sh
#
# With no arguments, the harnesses are found, never listed, so a new one is covered the
# moment it exists. Each harness's elapsed time is printed after it runs.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

harnesses=("$@")
if [ ${#harnesses[@]} -eq 0 ]; then
  while IFS= read -r harness; do
    harnesses+=("$harness")
  done < <(find . -name '*.test.sh' -not -path './.git/*' | sort)
fi
if [ ${#harnesses[@]} -eq 0 ]; then
  echo "test-all: no *.test.sh found; the search is broken, not the repository empty" >&2
  exit 2
fi

failed=()
for harness in "${harnesses[@]}"; do
  echo "== $harness"
  start=$SECONDS
  bash "$harness" || failed+=("$harness")
  printf '   %ds\n' "$((SECONDS - start))"
done
echo
if [ ${#failed[@]} -gt 0 ]; then
  printf 'test-all: %d of %d harnesses failed:\n' "${#failed[@]}" "${#harnesses[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
printf 'test-all: all %d harnesses passed\n' "${#harnesses[@]}"
