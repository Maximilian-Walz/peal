#!/usr/bin/env bash
# Harness for /peal:next's engine (lib/next.sh): the catalogue's ranking and the
# declined: bookkeeping, against throwaway repositories with a bare remote:
#
#   bash plugin/lib/next.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

# next DIR ARGS... -> `peal next ARGS...` run in DIR; status:output.
next() {
  local dir=$1 out
  shift
  out=$(cd "$dir" && "$PEAL" next "$@" 2>&1)
  printf '%s:%s' "$?" "$out"
}

# next_repo -> repo, with a committed .peal/config.yml recording only the tasks stage (a
# current milestone m1 already there, task-fixtures.sh's repo).
next_repo() {
  local work
  work=$(repo)
  mkdir "$work/.peal"
  printf 'stages: [tasks]\n' >"$work/.peal/config.yml"
  publish "$work"
  printf '%s\n' "$work"
}

no_config() {
  local work
  work=$(scratch_dir)
  git init -q -b main "$work"
  git -C "$work" commit -q --allow-empty -m root

  check "no config: only tasks, no ALSO, no error" "0:SUGGEST tasks /peal:setup" "$(next "$work")"
  check "no config: an item is offered regardless" "0:SUGGEST milestones" "$(next "$work" milestones | cut -d ' ' -f 1-2)"
  check_refused "no config: --decline refused" '*.peal/config.yml*' at "$work" "$PEAL" next --decline milestones
}

catalogue() {
  local work

  # guardrails: not recorded, and the fixture's own "root" commit on main has no [ID];
  # review-task also qualifies (m1 is current, no review task), ranked after it (last).
  work=$(next_repo)
  check "catalogue: guardrails from an untagged commit, review-task also" \
    "0:SUGGEST guardrails /peal:setup guardrails 0 done, 2 untagged
ALSO review-task /peal:setup milestones m1 current, no review task" "$(next "$work")"

  # State A: stages: [tasks] only, 12 done, no milestones. guardrails wins (12 done, and
  # the fixture's own untagged commits); milestones, belfry and review-task all also
  # qualify and fill the three ALSO lines, milestones' evidence carrying the count.
  work=$(next_repo)
  for i in 0001 0002 0003 0004 0005 0006 0007 0008 0009 0010 0011 0012; do put "$work" "done" "$i" "task-$i"; done
  check "catalogue: state A, guardrails wins, milestones also with its count" \
    "0:SUGGEST guardrails /peal:setup guardrails 12 done, 14 untagged
ALSO milestones /peal:setup milestones 12 done, 0 open
ALSO belfry /peal:setup belfry 12 done
ALSO review-task /peal:setup milestones m1 current, no review task" "$(next "$work")"

  # milestones: guardrails already recorded (excluded); 10 done tasks meet its threshold
  # (evidence carries the count); belfry and review-task both also qualify, ranked after
  # it in the catalogue's order (the stages of peal init, then review-task last).
  work=$(next_repo)
  printf 'stages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
  publish "$work"
  for i in 0001 0002 0003 0004 0005 0006 0007 0008 0009 0010; do put "$work" "done" "$i" "task-$i"; done
  check "catalogue: milestones at the threshold, with the count in the evidence" \
    "0:SUGGEST milestones /peal:setup milestones 10 done, 0 open
ALSO belfry /peal:setup belfry 10 done
ALSO review-task /peal:setup milestones m1 current, no review task" "$(next "$work")"

  # belfry over review-task: guardrails and milestones both recorded (excluded); belfry
  # not recorded and past its threshold, ranked before review-task, the catalogue's last.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails, milestones]\n' >"$work/.peal/config.yml"
  publish "$work"
  for i in 0001 0002 0003 0004 0005; do put "$work" "done" "$i" "task-$i"; done
  check "catalogue: belfry ranks over review-task" \
    "0:SUGGEST belfry /peal:setup belfry 5 done
ALSO review-task /peal:setup milestones m1 current, no review task" "$(next "$work")"

  # NONE: every stage recorded, and m1's review task filed.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails, milestones, belfry]\n' >"$work/.peal/config.yml"
  publish "$work"
  put "$work" backlog 0001 review-m1 "milestone: m1" "depends: [milestone]"
  check "catalogue: nothing left, NONE" "0:NONE" "$(next "$work")"

  # An item asked for by name is offered regardless of the catalogue.
  check "catalogue: an item asked for by name, though nothing qualifies" \
    "0:SUGGEST belfry /peal:setup belfry 0 done" "$(next "$work" belfry)"
  check_refused "catalogue: an unknown item refused" '*bogus*' at "$work" "$PEAL" next bogus
}

declined() {
  local work cfg

  work=$(next_repo)
  cfg="$work/.peal/config.yml"

  check "decline: writes today under the item" "0:declined milestones: 2026-01-01" \
    "$(PEAL_TODAY=2026-01-01 next "$work" --decline milestones)"
  check "decline: the block" "declined:
  milestones: [2026-01-01]" "$(awk '/^declined:/,/^$/' "$cfg" | sed '/^$/d')"
  check "decline: peal config still loads, the rest byte for byte" "tasks" \
    "$(at "$work" "$PEAL" config stages)"

  # A repeat refreshes the date, never a second entry.
  PEAL_TODAY=2026-02-01 next "$work" --decline milestones >/dev/null
  check "decline: a repeat refreshes the date" "declined:
  milestones: [2026-02-01]" "$(awk '/^declined:/,/^$/' "$cfg" | sed '/^$/d')"

  # A second item keeps the first.
  PEAL_TODAY=2026-02-01 next "$work" --decline belfry >/dev/null
  check "decline: a second item keeps the first, in the catalogue's order" "declined:
  milestones: [2026-02-01]
  belfry: [2026-02-01]" "$(awk '/^declined:/,/^$/' "$cfg" | sed '/^$/d')"

  check_refused "decline: an unknown item, no change" '*bogus*' at "$work" "$PEAL" next --decline bogus
  check "decline: unknown item made no change" "declined:
  milestones: [2026-02-01]
  belfry: [2026-02-01]" "$(awk '/^declined:/,/^$/' "$cfg" | sed '/^$/d')"

  # It blocks the suggestion while under 90 days, and lets it through again at day 90.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
  publish "$work"
  for i in 0001 0002 0003 0004 0005 0006 0007 0008 0009 0010; do put "$work" "done" "$i" "task-$i"; done
  PEAL_TODAY=2026-01-01 next "$work" --decline milestones >/dev/null
  check "decline: blocks it at day 89, belfry offered instead" \
    "0:SUGGEST belfry /peal:setup belfry 10 done
ALSO review-task /peal:setup milestones m1 current, no review task" "$(PEAL_TODAY=2026-03-31 next "$work")"
  check "decline: free again at day 90" \
    "0:SUGGEST milestones /peal:setup milestones 10 done, 0 open
ALSO belfry /peal:setup belfry 10 done
ALSO review-task /peal:setup milestones m1 current, no review task" "$(PEAL_TODAY=2026-04-01 next "$work")"
  check "decline: --all still shows it declined while blocked" "1" \
    "$(PEAL_TODAY=2026-03-31 next "$work" --all | grep -c '^DECLINED milestones 2026-01-01$')"
  check "decline: an item asked for by name ignores the decline" "0:SUGGEST milestones /peal:setup milestones 10 done, 0 open" \
    "$(PEAL_TODAY=2026-03-31 next "$work" milestones)"

  # An entry for something outside the catalogue warns and is ignored.
  work=$(next_repo)
  printf 'stages: [tasks]\ndeclined:\n  bogus: [2026-01-01]\n' >"$work/.peal/config.yml"
  publish "$work"
  out=$(cd "$work" && PEAL_TODAY=2026-01-01 "$PEAL" next 2>&1)
  check "decline: an unknown declined item does not stop the suggestion" "1" \
    "$(printf '%s\n' "$out" | grep -c '^SUGGEST guardrails')"
  check "decline: and warns" "1" "$(printf '%s\n' "$out" | grep -c 'declined.bogus is not a next item')"

  # A malformed date refuses, naming the item; the SUGGEST is not shown either.
  work=$(next_repo)
  printf 'stages: [tasks]\ndeclined:\n  guardrails: [not-a-date]\n' >"$work/.peal/config.yml"
  publish "$work"
  check_refused "decline: a malformed date refuses, naming the item" '*declined.guardrails*' \
    at "$work" "$PEAL" next

  work=$(next_repo)
  printf 'stages: [tasks]\ndeclined:\n  guardrails: [2026-02-30]\n' >"$work/.peal/config.yml"
  publish "$work"
  check_refused "decline: a date that is not a real calendar day refuses" '*declined.guardrails*' \
    at "$work" "$PEAL" next
}

cases() {
  catalogue
  declined
  no_config
}

for_each_awk cases
finish
