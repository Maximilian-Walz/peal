#!/usr/bin/env bash
# Harness for tools/test-all.sh's total and budget warning:
#
#   bash tools/test-all.test.sh
#
# - it prints its total on success and on failure, and the exit status is the harnesses';
# - PEAL_TEST_BUDGET over the total warns on stderr, as a ::warning annotation under
#   GITHUB_ACTIONS=true, and never changes the exit status;
# - no budget, or one above the total, warns not at all;
# - a budget that is not a non-negative integer exits 2 before anything runs.
set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../plugin/lib/test-lib.sh
. "$REPO/plugin/lib/test-lib.sh"

dir=$(scratch_dir)
printf 'echo ok\n' >"$dir/pass.test.sh"
printf 'echo bad\nexit 1\n' >"$dir/fail.test.sh"
printf 'sleep 1\n' >"$dir/slow.test.sh"
unset PEAL_TEST_BUDGET GITHUB_ACTIONS

run() { bash "$REPO/tools/test-all.sh" "$@" >"$dir/out" 2>"$dir/err"; }

run "$dir/pass.test.sh"; status=$?
check "all pass: exit 0" 0 "$status"
check "all pass: total" "1" "$(grep -c '^test-all: all 1 harnesses passed in [0-9]*s$' "$dir/out")"
check "no budget: no warning" "" "$(cat "$dir/err")"

run "$dir/pass.test.sh" "$dir/fail.test.sh"; status=$?
check "one fails: exit 1" 1 "$status"
check "one fails: summary with total" "1" "$(grep -c '^test-all: 1 of 2 harnesses failed in [0-9]*s:$' "$dir/out")"
check "one fails: names it" "1" "$(grep -c "^  $dir/fail.test.sh$" "$dir/out")"

PEAL_TEST_BUDGET=0 run "$dir/slow.test.sh"; status=$?
check "over budget: exit 0" 0 "$status"
check "over budget: warning on stderr" "1" "$(grep -c '^test-all: warning: .*over the budget of 0s' "$dir/err")"
check "over budget: no annotation" "0" "$(grep -c '::warning' "$dir/out")"

PEAL_TEST_BUDGET=0 GITHUB_ACTIONS=true run "$dir/slow.test.sh"; status=$?
check "annotation: exit 0" 0 "$status"
check "annotation: ::warning line" "1" "$(grep -c '^::warning title=.*::.*over the budget of 0s' "$dir/out")"
check "annotation: stderr quiet" "" "$(cat "$dir/err")"

PEAL_TEST_BUDGET=0 run "$dir/fail.test.sh" ; status=$?
check "over budget and failing: exit 1" 1 "$status"

PEAL_TEST_BUDGET=600 run "$dir/pass.test.sh"; status=$?
check "under budget: exit 0" 0 "$status"
check "under budget: no warning" "" "$(cat "$dir/err")"

for bad in abc -1 1.5; do
  PEAL_TEST_BUDGET=$bad run "$dir/pass.test.sh"; status=$?
  check "budget '$bad': exit 2" 2 "$status"
  check "budget '$bad': says so" "1" "$(grep -c 'PEAL_TEST_BUDGET must be' "$dir/err")"
  check "budget '$bad': nothing ran" "0" "$(grep -c '^==' "$dir/out")"
done
finish
