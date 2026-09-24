#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for a milestone's end (lib/review.sh, peal_store_milestone_state and
# peal_store_milestone_text in both storages), on task files and on issues (lib/fake-gh),
# through the peal CLI:
#
#   bash plugin/lib/review.test.sh
#
# milestone-review: the milestone by default and by id, its review task, its open tasks,
# the next current one, the parked ones, its text and the project's steps, READY or OPEN.
# milestone-state: done, parked with a reason, open, the next current one, the review
# appended, nothing changed for the state it has, and the refusals; for task files one
# commit onto main that the pre-push gate lets through.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

peal() { at "$work" "$PEAL" "$@"; }
in_wt() { at "$wt" "$PEAL" "$@"; }
current() { peal board --no-pr 2>/dev/null | sed -n 's/.*"id":"\([^"]*\)","title":"[^"]*","state":"current".*/\1/p'; }

files() {
  local work wt out before
  work=$(repo)
  put "$work" backlog 0001 first-task "milestone: m1"
  put "$work" backlog 0002 review-of-m1 "milestone: m1" "depends: [milestone]"
  put "$work" backlog 0003 loose-idea

  out=$(peal milestone-review 2>&1)
  check "review: the current milestone by default" "0:Milestone m1, \"Milestone m1\", current (docs/milestones/m1.md).
Review task: 0002.
Tasks of m1 not done, its review task aside:
  0001 free Title of 0001
Next: m2 \"Milestone m2\" becomes current once m1 is done.
Parked milestones:
  m3 \"Milestone m3\"
Tasks without a milestone, not done: 1 (peal overview lists them)." "$?:$(sed -n 1,8p <<<"$out")"
  check "review: the text" "1" "$(grep -c '^# Milestone m1$' <<<"$out")"
  check "review: no steps" "1" "$(grep -c '^The project.s review steps: none (.peal/review.md does not exist).$' <<<"$out")"
  check "review: open" "OPEN 1" "$(tail -n 1 <<<"$out")"
  check "review: another milestone" "Current milestone: m1 \"Milestone m1\", staying current." \
    "$(peal milestone-review m2 2>&1 | sed -n 5p)"
  check_refused "review: done" "milestone-review: milestone m0 is done already" peal milestone-review m0
  check_refused "review: unknown" "milestone-review: no milestone m9" peal milestone-review m9
  check_refused "review: two ids" "milestone-review: ?ID]" peal milestone-review m1 m2

  # The review task's worktree: its milestone by default, READY once the rest is done.
  mkdir -p "$work/.peal"
  printf 'Play the build with the human.\n' >"$work/.peal/review.md"
  mkdir -p "$work/tasks/done"
  git -C "$work" mv tasks/backlog/0001-first-task.md tasks/done/0001-first-task.md
  publish "$work"
  at "$work" "$PEAL" hooks install >/dev/null
  peal claim 0002 >/dev/null 2>&1
  wt=$(dirname "$work")/work-wt/0002-review-of-m1
  out=$(in_wt milestone-review 2>&1)
  check "review: in the review task's worktree" "Review task: 0002 (this worktree's).
Tasks of m1 not done, its review task aside:
  none" "$(sed -n 2,4p <<<"$out")"
  check "review: the steps" "1" "$(grep -c '^Play the build with the human.$' <<<"$out")"
  check "review: ready" "READY" "$(tail -n 1 <<<"$out")"

  # The state: refusals first, nothing pushed.
  git -C "$work" fetch -q
  before=$(git -C "$work" rev-parse origin/main)
  check_refused "state: no state" "milestone-state: ID done|parked|open" peal milestone-state m1
  check_refused "state: current" "'current' is not one of: done parked open" peal milestone-state m2 current
  check_refused "state: a reason not parking" "a reason is for parking" peal milestone-state m1 "done" --reason x
  check_refused "state: empty review" "no review in -" peal milestone-state m1 "done" --review - </dev/null
  check_refused "state: unknown milestone" "no milestone m9" peal milestone-state m9 "done"
  check_refused "state: unknown argument" "unknown argument --now" peal milestone-state m1 "done" --now
  check "state: refusals push nothing" "$before" "$(git -C "$work" fetch -q; git -C "$work" rev-parse origin/main)"

  # Done from the review task's worktree: straight onto main, the next one current, the
  # review in the milestone's file.
  out=$(in_wt milestone-state m1 "done" --review - <<<"All acceptance criteria met." 2>&1)
  check "state: done" "0:milestone m1: done
milestone m2: current
current milestone: m2" "$?:$out"
  check "state: the subject" "docs(tasks): milestone m1 done, m2 current" \
    "$(git -C "$work" log -1 --format=%s origin/main)"
  check "state: the review" "---
state: done
order: 1
---

# Milestone m1

## Review, $today

All acceptance criteria met." "$(on_main "$work" docs/milestones/m1.md)"
  check "state: the board" "m2" "$(current)"
  check "state: the worktree untouched" "" "$(git -C "$wt" status --porcelain)"

  # Parked with a reason, the current one: none is left current.
  out=$(peal milestone-state m2 parked --reason "until #12, other/repo#43" 2>&1)
  check "state: parked" "0:milestone m2: parked
current milestone: none" "$?:$out"
  check "state: the reason" "reason: 'until #12, other/repo#43'" "$(on_main "$work" docs/milestones/m2.md | grep '^reason')"
  check "state: the reason on the board" '"reason":"until #12, other/repo#43"' \
    "$(peal board --no-pr | grep -o '"reason":"until #12[^"]*"')"
  check "state: the same again" "milestone m2: parked already, nothing changed" \
    "$(peal milestone-state m2 parked 2>&1 | sed -n 1p)"
  # Un-parked with none current: it becomes current, its reason gone.
  out=$(peal milestone-state m2 open 2>&1)
  check "state: open with none current" "0:milestone m2: current
current milestone: m2" "$?:$out"
  check "state: the reason gone" "" "$(on_main "$work" docs/milestones/m2.md | grep '^reason')"
  check "state: open on the current one" "milestone m2: current already, nothing changed" \
    "$(peal milestone-state m2 open 2>&1 | sed -n 1p)"
  # A done one opens again; another stays current.
  check "state: reopen" "milestone m1: open" "$(peal milestone-state m1 open 2>&1 | sed -n 1p)"
  check "state: one commit each, through the pre-push gate" "docs(tasks): milestone m1 open
docs(tasks): milestone m2 current
docs(tasks): milestone m2 parked
docs(tasks): milestone m1 done, m2 current" "$(git -C "$work" log -4 --format=%s origin/main)"
}

issues() {
  local work out
  issues_repo
  issue 5 "First task" --milestone m1
  issue 6 "Review of m1" --milestone m1 --body "Depends on milestone"
  issue 7 "Loose idea"

  out=$(peal milestone-review 2>&1)
  check "issues review" "0:Milestone m1, \"m1\", current (https://github.com/acme/widgets/milestone/2).
Review task: 6.
Tasks of m1 not done, its review task aside:
  5 free First task
Next: m2 \"m2\" becomes current once m1 is done.
Parked milestones:
  m3 \"m3\": until later
Tasks without a milestone, not done: 1 (peal overview lists them).

The milestone's text:

(empty)" "$?:$(sed -n 1,12p <<<"$out")"
  check "issues review: open" "OPEN 1" "$(tail -n 1 <<<"$out")"
  check "issues review: m2's text" "Second" "$(peal milestone-review m2 2>&1 | sed -n '/^The milestone.s text:$/{n;n;p;}')"

  # Parked with a reason: the description's first line; open takes it out again.
  out=$(peal milestone-state m2 parked --reason "until #12" 2>&1)
  check "issues state: parked" "0:milestone m2: parked
current milestone: m1" "$?:$out"
  check "issues state: the description" "Parked: until #12

Second" "$(gh_get '.[] | select(.number == 3) | .description' milestones)"
  check "issues state: the reason" '"reason":"until #12"' "$(peal milestones --json | grep '"m2"' | grep -o '"reason":"[^"]*"')"
  out=$(peal milestone-state m2 open 2>&1)
  check "issues state: open" "0:milestone m2: open
current milestone: m1" "$?:$out"
  check "issues state: the parked line gone" "Second" "$(gh_get '.[] | select(.number == 3) | .description' milestones)"
  peal milestone-state m2 parked >/dev/null 2>&1
  check "issues state: parked, no reason" "Parked

Second" "$(gh_get '.[] | select(.number == 3) | .description' milestones)"
  check "issues state: the same again" "milestone m2: parked already, nothing changed" "$(peal milestone-state m2 parked 2>&1 | sed -n 1p)"
  peal milestone-state m2 open >/dev/null 2>&1

  # Done: closed, the review appended; the next one due is current.
  gh_save issues 'map(if .number == 5 then .state = "closed" else . end)'
  check "issues review: ready" "READY" "$(peal milestone-review m1 2>&1 | tail -n 1)"
  out=$(peal milestone-state m1 "done" --review - <<<"All good." 2>&1)
  check "issues state: done" "0:milestone m1: done
current milestone: m2" "$?:$out"
  check "issues state: closed with its review" "closed|## Review, $today

All good." "$(gh_get '.[] | select(.number == 2) | .state + "|" + .description' milestones)"
  check "issues state: the board" "m2" "$(current)"
  check_refused "issues state: unknown" "no milestone m9" peal milestone-state m9 "done"
  check "issues state: reopen" "milestone m1: open" "$(peal milestone-state m1 open 2>&1 | sed -n 1p)"
  check "issues state: reopened" "open" "$(gh_get '.[] | select(.number == 2) | .state' milestones)"
}

cases() {
  files
  if command -v jq >/dev/null; then
    issues
  elif [ -n "${PEAL_REQUIRE_JQ-}" ]; then
    check "jq is installed (PEAL_REQUIRE_JQ)" "jq" ""
  fi
}

for_each_awk cases
finish
