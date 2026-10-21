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
# moment it exists. Each harness's elapsed time is printed after it runs, and the total
# at the end. PEAL_TEST_BUDGET=<seconds> makes a total over it warn (stderr, or a
# ::warning annotation under GITHUB_ACTIONS=true); the exit status is never changed by it,
# so a shard that drifts slow shows without failing. Not a non-negative integer: exit 2.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

budget=${PEAL_TEST_BUDGET:-}
if [ -n "$budget" ] && ! [[ $budget =~ ^[0-9]+$ ]]; then
  echo "test-all: PEAL_TEST_BUDGET must be a non-negative integer of seconds, got '$budget'" >&2
  exit 2
fi

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
total_start=$SECONDS
for harness in "${harnesses[@]}"; do
  echo "== $harness"
  start=$SECONDS
  bash "$harness" || failed+=("$harness")
  printf '   %ds\n' "$((SECONDS - start))"
done
total=$((SECONDS - total_start))
echo
if [ -n "$budget" ] && [ "$total" -gt "$budget" ]; then
  msg="the harnesses took ${total}s, over the budget of ${budget}s; rebalance the shards (CONTRIBUTING.md)"
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::warning title=test-all over budget::$msg"
  else
    echo "test-all: warning: $msg" >&2
  fi
fi
if [ ${#failed[@]} -gt 0 ]; then
  printf 'test-all: %d of %d harnesses failed in %ds:\n' "${#failed[@]}" "${#harnesses[@]}" "$total"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
printf 'test-all: all %d harnesses passed in %ds\n' "${#harnesses[@]}" "$total"
