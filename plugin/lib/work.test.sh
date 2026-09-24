#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq's $variables, not the shell's
# Harness for /peal:work's checks (lib/work.sh): peal work in and outside a task's
# worktree, peal brief and peal record, on each storage (task files, and issues on
# lib/fake-gh when jq is here), against throwaway repositories with a bare remote:
#
#   bash plugin/lib/work.test.sh
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"
# shellcheck source=issue-fixtures.sh
. "$PEAL_ROOT/lib/issue-fixtures.sh"

# The storage the cases run on: files or issues.
kind=files

# new_repo [CONFIG-LINE...] -> work, a new repository on the storage of kind, with those
# lines in its .peal/config.yml.
new_repo() {
  if [ $kind = files ]; then
    work=$(repo)
    mkdir "$work/.peal"
    printf '%s\n' "remote: origin" "$@" >"$work/.peal/config.yml"
  else
    ISSUES_CONFIG="" issues_repo
    printf '\n' >>"$work/.peal/config.yml"
    [ $# -eq 0 ] || printf '%s\n' "$@" >>"$work/.peal/config.yml"
  fi
  publish "$work"
}

# id N -> task N's id on this storage: 0001 as a file, 1 as an issue.
id() {
  if [ $kind = files ]; then printf '%04d\n' "$1"; else printf '%s\n' "$1"; fi
}

# task N SLUG [KEY=VALUE...] -> task N put on the storage: milestone, plan, size, model,
# depends (one id) as its frontmatter says them.
task() {
  local n=$1 slug=$2 kv lines=() args=() deps=""
  shift 2
  for kv in "$@"; do
    case $kv in
      depends=*) lines+=("depends: [$(id "${kv#*=}")]"); deps="Depends on #${kv#*=}"$'\n\n' ;;
      milestone=*) lines+=("milestone: ${kv#*=}"); args+=(--milestone "${kv#*=}") ;;
      *) lines+=("${kv%%=*}: ${kv#*=}"); args+=(--label "${kv%%=*}: ${kv#*=}") ;;
    esac
  done
  if [ $kind = files ]; then
    put "$work" backlog "$(id "$n")" "$slug" ${lines[@]+"${lines[@]}"}
  else
    issue "$n" "Title of $n" ${args[@]+"${args[@]}"} --body "${deps}Why."$'\n\n## Raw\n\nthe human said so\n\n## Notes\n'
  fi
}

# claim N -> task N claimed from work; its worktree's path.
claim() {
  at "$work" "$PEAL" claim "$(id "$1")" --print-path 2>/dev/null | tail -n 1
}

# with_plan TEXT -> the task text on stdin with a Plan section holding TEXT, before the
# rule above its Outcome, or at its end.
with_plan() {
  PEAL_PLAN=$1 awk '
    { line[++n] = $0 }
    END {
      at = n + 1
      for (i = 1; i <= n; i++) if (line[i] == "## Outcome") { at = i; break }
      if (at <= n) { j = at - 1; while (j > 0 && line[j] == "") j--; if (j > 0 && line[j] == "---") at = j }
      for (i = 1; i < at; i++) print line[i]
      print "## Plan"; print ""; print ENVIRON["PEAL_PLAN"]; print ""
      for (i = at; i <= n; i++) print line[i]
    }'
}

# with_field KEY VALUE -> the task text on stdin with KEY: VALUE added to its frontmatter.
with_field() {
  awk -v kv="$1: $2" '{ print } NR == 1 && $0 == "---" { print kv }'
}

outside() {
  local wt out
  new_repo
  task 1 first-task milestone=m1
  task 2 second-task
  task 3 later-task milestone=m2

  check "work: a bare pool offers current, then unassigned" "CANDIDATE $(id 1) m1 Title of $(id 1)
CANDIDATE $(id 2) unassigned Title of $(id 2)" "$(at "$work" "$PEAL" work)"
  check "work: a named pool" "CANDIDATE $(id 3) m2 Title of $(id 3)" "$(at "$work" "$PEAL" work m2)"
  check_refused "work: a parked pool" "milestone m3 is parked" at "$work" "$PEAL" work m3

  out=$(at "$work" "$PEAL" work "$(id 1)" 2>/dev/null)
  wt=$(printf '%s\n' "$out" | sed -n 's/^CLAIMED [0-9]* //p')
  check "work: an id claims it" "CLAIMED $(id 1) $wt" "$(printf '%s\n' "$out" | tail -n 1)"
  check "work: the claim's own lines first" "1" "$(printf '%s\n' "$out" | grep -c -v '^CLAIMED ')"
  check "work: the claim is made" "claimed-live" "$(at "$work" "$PEAL" list --no-pr "$(id 1)" | cut -d ' ' -f 2)"
  check "work: the worktree is there" "1" "$([ -d "$wt/.peal" ] && echo 1)"
  check "work: claimed here already, again its worktree" "CLAIMED $(id 1) $wt" \
    "$(at "$work" "$PEAL" work "$(id 1)" 2>/dev/null | tail -n 1)"
  task 4 blocked-task depends=2
  check_refused "work: a blocked task is refused" "is blocked" at "$work" "$PEAL" work "$(id 4)"
  task 5 human-task owner=human
  check_refused "work: a human task is refused" "task $(id 5) is a human task" at "$work" "$PEAL" work "$(id 5)"
  check "work: the human task stays free" "free" "$(at "$work" "$PEAL" list --no-pr "$(id 5)" | cut -d ' ' -f 2)"
  check "work: the human task is never offered" "" "$(at "$work" "$PEAL" work unassigned | grep "$(id 5)")"
  check "work: peal claim still claims it" "claimed-live" \
    "$(claim 5 >/dev/null; at "$work" "$PEAL" list --no-pr "$(id 5)" | cut -d ' ' -f 2)"
  check_refused "work: two arguments" "ID | POOL" at "$work" "$PEAL" work "$(id 1)" "$(id 2)"
  new_repo
  check "work: an empty pool says nothing" "0:" "$(at "$work" "$PEAL" work; printf '%s:' "$?")"
}

inside() {
  local one two three out file
  new_repo "models: {planner: haiku}"
  task 1 skipped-plan plan=skipped
  task 2 required-plan plan=required model=opus
  task 3 plain-task
  one=$(claim 1) two=$(claim 2) three=$(claim 3)

  out=$(at "$one" "$PEAL" work "$(id 1)")
  file=$(printf '%s\n' "$out" | sed -n 's/^TASK [0-9]* //p')
  check "work: in the worktree, no claim" "TASK $(id 1) $file
PLAN skipped
MODEL planner haiku
MODEL implementer sonnet
MODEL reviewer opus" "$out"
  check "work: TASK names the task's text" "Title of $(id 1)" "$(cd "$one" && peal_text_title "$(id 1)" <"$file")"
  check "work: bare, in the worktree" "TASK $(id 1) $file" "$(at "$one" "$PEAL" work | head -n 1)"
  check "work: no plan field is skipped" "PLAN skipped" "$(at "$three" "$PEAL" work | sed -n 2p)"
  check_refused "work: another task from a task's worktree" "this worktree holds task $(id 1)" \
    at "$one" "$PEAL" work "$(id 3)"
  check_refused "work: a pool from a task's worktree" "this worktree holds task $(id 1)" \
    at "$one" "$PEAL" work current
  check "work: plan required, the task's model" "PLAN required
MODEL implementer opus" "$(at "$two" "$PEAL" work | grep -e PLAN -e implementer)"
}

record() {
  local wt text out status
  new_repo "sizes: {S: 10, M: 20, L: 30}"
  task 1 planned-task plan=required milestone=m1
  task 2 other-task
  wt=$(claim 1)
  # After the fixtures' own commits on main, which the gates would refuse.
  at "$work" "$PEAL" hooks install >/dev/null
  text=$(at "$wt" "$PEAL" read "$(id 1)")

  check_refused "record: an empty Plan is no plan" "no Plan section" \
    at "$wt" "$PEAL" record "$(id 1)" plan < <(with_plan "<!-- to come -->" <<<"$text")
  check_refused "record: the same text" "nothing to record" at "$wt" "$PEAL" record "$(id 1)" notes <<<"$text"
  check_refused "record: Raw changed" "Raw section changed" \
    at "$wt" "$PEAL" record "$(id 1)" notes <<<"${text//the human said so/something else}"
  check_refused "record: milestone changed" "milestone changed" \
    at "$wt" "$PEAL" record "$(id 1)" plan < <(with_plan "Build it." <<<"$text" | sed 's/^milestone: m1/milestone: m2/')
  check_refused "record: another task" "holds task $(id 1), not $(id 2)" \
    at "$wt" "$PEAL" record "$(id 2)" notes <<<"$text"
  check_refused "record: outside a task's worktree" "holds no task" at "$work" "$PEAL" record "$(id 1)" notes <<<"$text"
  check_refused "record: WHAT" "ID plan|notes" at "$wt" "$PEAL" record "$(id 1)" outcome <<<"$text"
  check_refused "record: an undeclared field" "unknown field colour" \
    at "$wt" "$PEAL" record "$(id 1)" plan < <(with_plan "Build it." <<<"$text" | with_field colour red)
  check_refused "record: a size not in the tiers" "size XL" \
    at "$wt" "$PEAL" record "$(id 1)" plan < <(with_plan "Build it." <<<"$text" | with_field size XL)
  check "record: nothing recorded by a refusal" "PLAN required" "$(at "$wt" "$PEAL" work | sed -n 2p)"

  out=$(at "$wt" "$PEAL" record "$(id 1)" plan < <(with_plan "Build it with a loop." <<<"$text" \
    | with_field size S | with_field model opus) 2>&1)
  status=$?
  check "record: the plan recorded" "0" "$status"
  check "record: the plan is agreed" "PLAN agreed
MODEL implementer opus" "$(at "$wt" "$PEAL" work | grep -e PLAN -e implementer)"
  check "record: the plan in the task's text" "Build it with a loop." \
    "$(at "$wt" "$PEAL" read "$(id 1)" | peal_text_section Plan | grep Build)"
  check "record: the size in its frontmatter" "S" \
    "$(at "$wt" "$PEAL" read "$(id 1)" | awk '/^size:/ { print $2 }')"
  if [ $kind = files ]; then
    check "record: committed on the task's branch" "docs(tasks): record the plan of 0001 [0001]" \
      "$(git -C "$wt" log -1 --format=%s)"
    check "record: the tree clean" "" "$(git -C "$wt" status --porcelain)"
  else
    check "record: said so" "recorded the plan of 1 on issue 1" "$out"
    check "record: the labels" "in progress,model: opus,plan: required,size: S" "$(labels 1 | tr ',' '\n' | sort | paste -s -d, -)"
  fi
  # A task file has its Outcome heading from the start, an issue none.
  check_refused "record: an Outcome now" "Outcome" \
    at "$wt" "$PEAL" record "$(id 1)" notes < <(at "$wt" "$PEAL" read "$(id 1)" \
      | awk '/<!--/ { next } { print } /^## Outcome/ { print ""; print "Built."; o = 1 }
        END { if (!o) { print ""; print "## Outcome"; print ""; print "Built." } }')
}

brief() {
  local wt out
  new_repo "context: [docs/design.md, README.md]" "sizes: {S: 10, M: 20, L: 30}"
  printf 'Check the layering.\n' >"$work/.peal/reviewer.md"
  : >"$work/.peal/planner.md"
  publish "$work"
  task 1 briefed-task milestone=m1
  wt=$(claim 1)

  out=$(at "$wt" "$PEAL" brief planner)
  check "brief: the planner's" "Peal brief for the planner of task $(id 1).
Main branch: origin/main. This task's work: git log origin/main..HEAD.
Size tiers, tool calls per session: S 10, M 20, L 30.
Context documents, the project's own; read each that bears on the task:
  docs/design.md
  README.md" "$(printf '%s\n' "$out" | grep -v -e '^Task:' -e '^Current milestone:')"
  check "brief: the task" "Task: $(at "$wt" "$PEAL" work | sed -n 's/^TASK [0-9]* //p'). It is the whole scope: read it first." \
    "$(printf '%s\n' "$out" | grep '^Task:')"
  check "brief: the current milestone" "Current milestone: m1," \
    "$(printf '%s\n' "$out" | grep '^Current milestone:' | cut -d ' ' -f 1-3)"
  check "brief: the reviewer's rules appended" "
The project's rules for the reviewer (.peal/reviewer.md), on top of Peal's:

Check the layering." "$(at "$wt" "$PEAL" brief reviewer | sed -n '9,$p')"
  check "brief: the implementer gets no rules file" "8" "$(at "$wt" "$PEAL" brief implementer | wc -l | tr -d ' ')"
  check_refused "brief: an unknown role" "ROLE, one of" at "$wt" "$PEAL" brief closer
  check_refused "brief: no role" "ROLE, one of" at "$wt" "$PEAL" brief
  check_refused "brief: outside a task's worktree" "holds no task" at "$work" "$PEAL" brief planner

  new_repo
  task 1 bare-task
  wt=$(claim 1)
  check "brief: no context documents" "Context documents: none listed." \
    "$(at "$wt" "$PEAL" brief reviewer | tail -n 1)"
}

cases() {
  outside
  inside
  record
  brief
}

# run -> the cases on task files, then on issues.
run() {
  local saved=$awk_name
  kind=files
  cases
  if command -v jq >/dev/null; then
    kind=issues awk_name="$saved, issues"
    cases
    awk_name=$saved
  fi
}

if ! command -v jq >/dev/null; then
  echo "work.test.sh: no jq here, which the fake gh needs; the issues storage skipped" >&2
  [ -z "${PEAL_REQUIRE_JQ-}" ] || exit 1
fi
# shellcheck source=common.sh
. "$PEAL_ROOT/lib/common.sh"
# shellcheck source=task-text.sh
. "$PEAL_ROOT/lib/task-text.sh"
for_each_awk run
finish
