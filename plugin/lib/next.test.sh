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
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

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
  # it in the catalogue's order (the stages of peal init, then review-task last), and
  # releases now also qualifies (no tag, >=5 done), filling the third ALSO line.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails]\n' >"$work/.peal/config.yml"
  publish "$work"
  for i in 0001 0002 0003 0004 0005 0006 0007 0008 0009 0010; do put "$work" "done" "$i" "task-$i"; done
  check "catalogue: milestones at the threshold, with the count in the evidence" \
    "0:SUGGEST milestones /peal:setup milestones 10 done, 0 open
ALSO belfry /peal:setup belfry 10 done
ALSO review-task /peal:setup milestones m1 current, no review task
ALSO releases /peal:release 10 done" "$(next "$work")"

  # belfry over review-task: guardrails and milestones both recorded (excluded); belfry
  # not recorded and past its threshold, ranked before review-task, the catalogue's last
  # of the original five. releases (no tag, >=5 done) and review-steps (the milestones
  # stage is recorded and m0, the fixture's own milestone, is done, and there is no
  # .peal/review.md yet) now also qualify, filling the ALSO lines.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails, milestones]\n' >"$work/.peal/config.yml"
  publish "$work"
  for i in 0001 0002 0003 0004 0005; do put "$work" "done" "$i" "task-$i"; done
  check "catalogue: belfry ranks over review-task" \
    "0:SUGGEST belfry /peal:setup belfry 5 done
ALSO review-task /peal:setup milestones m1 current, no review task
ALSO releases /peal:release 5 done
ALSO review-steps .peal/review.md m0 done" "$(next "$work")"

  # NONE: every stage recorded, m1's review task filed, and .peal/review.md already
  # there (m0, the fixture's own milestone, is otherwise always done, so review-steps
  # would fire); 0 done tasks keep decisions, drift, releases and reviewer silent too.
  work=$(next_repo)
  printf 'stages: [tasks, guardrails, milestones, belfry]\n' >"$work/.peal/config.yml"
  publish "$work"
  put "$work" backlog 0001 review-m1 "milestone: m1" "depends: [milestone]"
  : >"$work/.peal/review.md"
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
ALSO review-task /peal:setup milestones m1 current, no review task
ALSO releases /peal:release 10 done" "$(PEAL_TODAY=2026-03-31 next "$work")"
  check "decline: free again at day 90" \
    "0:SUGGEST milestones /peal:setup milestones 10 done, 0 open
ALSO belfry /peal:setup belfry 10 done
ALSO review-task /peal:setup milestones m1 current, no review task
ALSO releases /peal:release 10 done" "$(PEAL_TODAY=2026-04-01 next "$work")"
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

# feature_repo -> next_repo with every peal init stage recorded and m1's review task
# filed (id 0099, out of done_tasks' range), so none of the original five items qualify:
# a clean baseline for the features within the stages (decisions, drift, releases,
# reviewer, review-steps), 0 tasks done, m0 (the fixture's own milestone) already done,
# and no .peal/*.md of theirs yet.
feature_repo() {
  local work
  work=$(next_repo)
  printf 'stages: [tasks, guardrails, milestones, belfry]\n' >"$work/.peal/config.yml"
  publish "$work"
  put "$work" backlog 0099 review-m1 "milestone: m1" "depends: [milestone]"
  printf '%s\n' "$work"
}

# done_tasks WORK N -> N done tasks (0001..N) committed on WORK's main.
done_tasks() {
  local work=$1 n=$2 i
  for i in $(seq 1 "$n"); do put "$work" "done" "$(printf '%04d' "$i")" "task-$i"; done
}

# next_out DIR ARGS... -> `peal next ARGS...`'s own stdout and stderr, merged, without the
# exit-status prefix `next` adds (SUGGEST/ALSO are then each at the start of their line).
next_out() {
  local dir=$1
  shift
  (cd "$dir" && "$PEAL" next "$@" 2>&1)
}

# not_also WORK ITEM -> status 0 if ITEM names neither the SUGGEST nor an ALSO line of
# `peal next` in WORK.
not_also() {
  ! next_out "$1" | grep -q "^\(SUGGEST\|ALSO\) $2 "
}

features() {
  local work main

  # decisions: an ADR-like directory fires regardless of the threshold; without one, it
  # fires at 20 done, silent at 19; the module already on silences it either way. At 0
  # done, review-steps also qualifies (m0, the fixture's own milestone, is done).
  work=$(feature_repo)
  mkdir -p "$work/docs/adr"
  check "decisions: fires with docs/adr, at 0 done" \
    "0:SUGGEST decisions decisions: docs/adr docs/adr found
ALSO review-steps .peal/review.md m0 done" "$(next "$work")"

  work=$(feature_repo)
  done_tasks "$work" 19
  check "decisions: silent at 19 done, no ADR directory" "0" "$(not_also "$work" decisions; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 20
  check "decisions: fires at 20 done" "1" "$(next_out "$work" | grep -c '^SUGGEST decisions decisions: docs/decisions 20 done$')"

  work=$(feature_repo)
  done_tasks "$work" 20
  printf 'stages: [tasks, guardrails, milestones, belfry]\ndecisions: docs/decisions\n' >"$work/.peal/config.yml"
  check "decisions: silent with the module already on" "0" "$(not_also "$work" decisions; echo $?)"

  # drift: context: set, or other Markdown under docs/, and >=10 done; silent under the
  # threshold, with only the milestones' own Markdown, or once .peal/drift.md exists.
  work=$(feature_repo)
  done_tasks "$work" 10
  printf 'stages: [tasks, guardrails, milestones, belfry]\ncontext: [docs/design.md]\n' >"$work/.peal/config.yml"
  check "drift: fires at 10 done, context: set" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST drift /peal:drift 10 done, context set$')"

  work=$(feature_repo)
  done_tasks "$work" 10
  mkdir -p "$work/docs/extra"
  printf 'Notes.\n' >"$work/docs/extra/notes.md"
  check "drift: fires at 10 done, other docs Markdown" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST drift /peal:drift 10 done, 1 docs$')"

  work=$(feature_repo)
  done_tasks "$work" 9
  mkdir -p "$work/docs/extra"
  printf 'Notes.\n' >"$work/docs/extra/notes.md"
  check "drift: silent at 9 done" "0" "$(not_also "$work" drift; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 10
  check "drift: silent with only the milestones' own Markdown" "0" "$(not_also "$work" drift; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 10
  printf 'stages: [tasks, guardrails, milestones, belfry]\ncontext: [docs/design.md]\n' >"$work/.peal/config.yml"
  : >"$work/.peal/drift.md"
  check "drift: silent once .peal/drift.md exists" "0" "$(not_also "$work" drift; echo $?)"

  # releases: no local tag under release.tag-prefix reachable from local main, and >=5
  # done; a version file at the root suggests it in the evidence; a tag on main silences
  # it, respecting a custom tag-prefix (a "v" tag does not silence a "rel-" one).
  work=$(feature_repo)
  done_tasks "$work" 5
  printf '{}\n' >"$work/package.json"
  check "releases: fires at 5 done, no tag, names package.json" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST releases /peal:release 5 done, package.json$')"

  work=$(feature_repo)
  done_tasks "$work" 4
  check "releases: silent at 4 done" "0" "$(not_also "$work" releases; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 5
  main=$(at "$work" git rev-parse main)
  at "$work" git tag v0.1.0 "$main"
  check "releases: silent with a release tag on main" "0" "$(not_also "$work" releases; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 5
  printf 'stages: [tasks, guardrails, milestones, belfry]\nrelease:\n  tag-prefix: rel-\n' >"$work/.peal/config.yml"
  main=$(at "$work" git rev-parse main)
  at "$work" git tag v0.1.0 "$main"
  check "releases: respects a custom tag-prefix" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST releases /peal:release 5 done$')"

  # reviewer: no .peal/reviewer.md, and (context: empty with design-like docs) or (CI
  # files with checks.commit and checks.close both empty); silent with both set, or once
  # .peal/reviewer.md exists.
  work=$(feature_repo)
  mkdir -p "$work/docs"
  printf '# Design\n' >"$work/docs/design.md"
  check "reviewer: fires on docs/design.md, empty context" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST reviewer .peal/reviewer.md docs/design.md, no context$')"

  work=$(feature_repo)
  mkdir -p "$work/.github/workflows"
  printf 'name: CI\n' >"$work/.github/workflows/ci.yml"
  check "reviewer: fires on CI files, empty checks" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST reviewer .peal/reviewer.md .github/workflows/ci.yml, no checks$')"

  work=$(feature_repo)
  mkdir -p "$work/docs" "$work/.github/workflows"
  printf '# Design\n' >"$work/docs/design.md"
  printf 'name: CI\n' >"$work/.github/workflows/ci.yml"
  printf 'stages: [tasks, guardrails, milestones, belfry]\ncontext: [docs/design.md]\nchecks:\n  commit: ["true"]\n' \
    >"$work/.peal/config.yml"
  check "reviewer: silent when context and checks are both set" "0" "$(not_also "$work" reviewer; echo $?)"

  work=$(feature_repo)
  mkdir -p "$work/docs"
  printf '# Design\n' >"$work/docs/design.md"
  : >"$work/.peal/reviewer.md"
  check "reviewer: silent once .peal/reviewer.md exists" "0" "$(not_also "$work" reviewer; echo $?)"

  # review-steps: the milestones stage recorded, a milestone done (m0), and no
  # .peal/review.md; silent without the stage recorded, or once the file exists.
  work=$(feature_repo)
  check "review-steps: fires with a done milestone, no .peal/review.md" \
    "1" "$(next_out "$work" | grep -c '^SUGGEST review-steps .peal/review.md m0 done$')"

  work=$(next_repo)
  printf 'stages: [tasks, guardrails, belfry]\n' >"$work/.peal/config.yml"
  publish "$work"
  put "$work" backlog 0001 review-m1 "milestone: m1" "depends: [milestone]"
  check "review-steps: silent, the milestones stage is not recorded" "0" "$(not_also "$work" review-steps; echo $?)"

  work=$(feature_repo)
  : >"$work/.peal/review.md"
  check "review-steps: silent once .peal/review.md exists" "0" "$(not_also "$work" review-steps; echo $?)"

  # Declining each new item suppresses it, the same as the original five.
  work=$(feature_repo)
  mkdir -p "$work/docs/adr"
  at "$work" "$PEAL" next --decline decisions >/dev/null
  check "decisions: declined, no longer suggested" "0" "$(not_also "$work" decisions; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 10
  printf 'stages: [tasks, guardrails, milestones, belfry]\ncontext: [docs/design.md]\n' >"$work/.peal/config.yml"
  at "$work" "$PEAL" next --decline drift >/dev/null
  check "drift: declined, no longer suggested" "0" "$(not_also "$work" drift; echo $?)"

  work=$(feature_repo)
  done_tasks "$work" 5
  at "$work" "$PEAL" next --decline releases >/dev/null
  check "releases: declined, no longer suggested" "0" "$(not_also "$work" releases; echo $?)"

  work=$(feature_repo)
  mkdir -p "$work/docs"
  printf '# Design\n' >"$work/docs/design.md"
  at "$work" "$PEAL" next --decline reviewer >/dev/null
  check "reviewer: declined, no longer suggested" "0" "$(not_also "$work" reviewer; echo $?)"

  work=$(feature_repo)
  at "$work" "$PEAL" next --decline review-steps >/dev/null
  check "review-steps: declined, no longer suggested" "0" "$(not_also "$work" review-steps; echo $?)"

  # Order when every one of the five qualifies at once: the catalogue's fixed order,
  # decisions first, capped at three ALSO lines (review-steps drops off the end).
  work=$(feature_repo)
  mkdir -p "$work/docs/adr" "$work/.github/workflows"
  printf 'name: CI\n' >"$work/.github/workflows/ci.yml"
  printf 'stages: [tasks, guardrails, milestones, belfry]\ncontext: [docs/design.md]\n' >"$work/.peal/config.yml"
  done_tasks "$work" 10
  check "features: order when all five qualify, capped at three ALSO lines" \
    "0:SUGGEST decisions decisions: docs/adr docs/adr found
ALSO drift /peal:drift 10 done, context set
ALSO releases /peal:release 10 done
ALSO reviewer .peal/reviewer.md .github/workflows/ci.yml, no checks" "$(next "$work")"

  # NONE once every one of the five is set up (the module on, the three stubs) or, for
  # releases (nothing to turn on), simply under its threshold.
  work=$(feature_repo)
  printf 'stages: [tasks, guardrails, milestones, belfry]\ndecisions: docs/decisions\n' >"$work/.peal/config.yml"
  : >"$work/.peal/drift.md"
  : >"$work/.peal/reviewer.md"
  : >"$work/.peal/review.md"
  check "features: NONE once every one is set up" "0:NONE" "$(next "$work")"
}

# issues -> the catalogue through the issues storage (fake-gh), skipped without jq: closed
# issues count as done the same way, ranking belfry over the review task, releases and
# review-steps it also finds (m0, closed in the issues fixture too, counts as done).
issues() {
  command -v jq >/dev/null 2>&1 || return 0
  local i
  ISSUES_CONFIG=$'stages: [tasks, guardrails, milestones]\n' issues_repo
  for i in 1 2 3 4 5; do issue "$i" "closed work $i" --closed; done
  check "issues: belfry through the issues storage, review-task also (closed = done)" \
    "0:SUGGEST belfry /peal:setup belfry 5 done
ALSO review-task /peal:setup milestones m1 current, no review task
ALSO releases /peal:release 5 done
ALSO review-steps .peal/review.md m0 done" "$(next "$work")"
}

cases() {
  catalogue
  declined
  no_config
  features
  issues
}

for_each_awk cases
finish
