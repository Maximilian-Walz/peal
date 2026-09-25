#!/usr/bin/env bash
# Harness for the read model: `peal list`, `peal board` and `peal overview` over the task
# files (lib/store-files.sh, lib/task-scan.awk, lib/task-state.awk, lib/tasks.sh), against
# throwaway repositories with a bare remote:
#
#   bash plugin/lib/tasks.test.sh
#
# Every state, from refs and the remote's main only; the depends expansion of milestone,
# human and split origins; depends cycles in list, board and check; the board as JSON
# lines in the shapes of Belfry's contract, pull requests from gh included; the
# overview's groups; a task's priority in all three; its touches and merge on the board.
set -uo pipefail
# shellcheck source=test-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/test-lib.sh"
# shellcheck source=task-fixtures.sh
. "$PEAL_ROOT/lib/task-fixtures.sh"

list() { at "$work" "$PEAL" list --no-pr "$@"; }

# json_ok LINES -> "ok" if every line parses as a JSON object, else the first that does not.
json_ok() {
  if command -v jq >/dev/null; then
    printf '%s\n' "$1" | while IFS= read -r line; do
      printf '%s' "$line" | jq -e 'type == "object"' >/dev/null 2>&1 || { printf '%s\n' "$line"; exit 1; }
    done && echo ok
  elif ! command -v python3 >/dev/null; then
    echo "tasks.test.sh: neither jq nor python3 here; the board's JSON is not parsed" >&2
    echo ok
  else
    printf '%s\n' "$1" | python3 -c 'import json, sys
for line in sys.stdin:
    if not isinstance(json.loads(line), dict): print(line); sys.exit(1)
print("ok")'
  fi
}

states() {
  local work other out err
  work=$(repo)

  # No tasks at all: nothing, and fine.
  out=$(list 2>&1)
  check "empty: nothing" "0:" "$?:$out"

  put "$work" backlog 0001 free-task "milestone: m1"
  put "$work" "done" 0002 done-task
  put "$work" backlog 0003 blocked-task "depends: [0001]"
  put "$work" backlog 0004 live-task
  put "$work" backlog 0005 remote-task
  put "$work" backlog 0006 parked-task
  put "$work" backlog 0007 merging-task
  put "$work" "done" 0008 landed-task
  put "$work" backlog 0009 stale-branch
  put "$work" backlog 0010 unblocked-task "depends: [0002]"

  # claimed-live: a branch with a worktree.
  git -C "$work" worktree add -q -b task/0004-live-task "$work-0004" origin/main 2>/dev/null
  scratch+=("$work-0004")
  # claimed-live: a branch only the remote has.
  git -C "$work" push -q origin origin/main:refs/heads/task/0005-remote-task 2>/dev/null
  git -C "$work" fetch -q origin
  # parked: a local branch ahead of main, no worktree.
  git -C "$work" worktree add -q -b task/0006-parked-task "$work-0006" origin/main 2>/dev/null
  git -C "$work-0006" mv tasks/backlog/0006-parked-task.md tasks/backlog/0006-moved.md
  git -C "$work-0006" commit -q -m wip
  git -C "$work" worktree remove "$work-0006"
  # awaiting-merge: the branch's tip has the task under done/.
  git -C "$work" worktree add -q -b task/0007-merging-task "$work-0007" origin/main 2>/dev/null
  scratch+=("$work-0007")
  mkdir -p "$work-0007/tasks/done"
  git -C "$work-0007" mv tasks/backlog/0007-merging-task.md tasks/done/
  git -C "$work-0007" commit -q -m close
  # done outranks a branch still around.
  git -C "$work" branch -q task/0008-landed-task origin/main
  # a branch with no worktree and nothing ahead: unclaimed, with a warning.
  git -C "$work" branch -q task/0009-stale-branch origin/main

  out=$(list 2>/dev/null)
  check "every state" "0001 free free-task m1
0002 done done-task
0003 blocked blocked-task needs:0001
0004 claimed-live live-task wt:$work-0004
0005 claimed-live remote-task remote:origin
0006 parked parked-task 1 commit(s) ahead, last $today
0007 awaiting-merge merging-task pr:unknown wt:$work-0007 unpushed
0008 done landed-task
0009 free stale-branch -
0010 free unblocked-task -" "$out"
  check_fails "a stale branch warns" 0 "task/0009-stale-branch has no worktree and nothing ahead of main" \
    at "$work" "$PEAL" list --no-pr

  # Pushed, the awaiting-merge branch is no longer unpushed.
  git -C "$work-0007" push -q origin HEAD 2>/dev/null
  check "awaiting-merge, pushed" "0007 awaiting-merge merging-task pr:unknown wt:$work-0007" \
    "$(list 0007 2>/dev/null)"
  # Without its worktree too.
  git -C "$work" worktree remove "$work-0007"
  check "awaiting-merge, no worktree" "0007 awaiting-merge merging-task pr:unknown" "$(list 0007 2>/dev/null)"
  # Only on the remote.
  git -C "$work" branch -q -D task/0007-merging-task
  check "awaiting-merge, remote only" "0007 awaiting-merge merging-task pr:unknown" "$(list 0007 2>/dev/null)"

  # From another worktree, on another branch, with its own uncommitted and committed
  # changes: the same answer, since only refs and the remote's main count.
  other=$(list 2>/dev/null)
  mkdir -p "$work-0004/tasks/done"
  git -C "$work-0004" mv tasks/backlog/0003-blocked-task.md tasks/done/
  printf 'x\n' >"$work-0004/tasks/backlog/0099-local-only.md"
  check "any worktree, the same answer" "$other" "$(at "$work-0004" "$PEAL" list --no-pr 2>/dev/null)"
  git -C "$work" commit -q --allow-empty -m "local only"
  mkdir -p "$work/tasks/done"
  check "a local commit on main counts for nothing" "$other" "$(list 2>/dev/null)"

  # --state and ids filter.
  check "--state" "0001 free free-task m1
0009 free stale-branch -
0010 free unblocked-task -" "$(list --state free 2>/dev/null)"
  check "--state, several" "0002 done done-task
0004 claimed-live live-task wt:$work-0004
0005 claimed-live remote-task remote:origin
0008 done landed-task" "$(list --state done,claimed-live 2>/dev/null)"
  check "ids" "0003 blocked blocked-task needs:0001
0010 free unblocked-task -" "$(list 0010 0003 2>/dev/null)"
  check_refused "list: unknown argument" "list: unknown argument --nope" list --nope

  # --fetch sees what another clone pushed; without it, what is known here.
  git clone -q "$(dirname "$work")/remote.git" "$work-other" 2>/dev/null
  scratch+=("$work-other")
  put "$work-other" backlog 0011 from-elsewhere
  check "no fetch: not seen yet" "" "$(list 0011 2>/dev/null)"
  check "--fetch" "0011 free from-elsewhere -" "$(list --fetch 0011 2>/dev/null)"

  # No remote-tracking main: the local main, with a warning.
  work=$(repo)
  put "$work" backlog 0001 only-task
  git -C "$work" update-ref -d refs/remotes/origin/main
  err=$(list 2>&1 >/dev/null)
  check "no remote main: the local one" "0001 free only-task -" "$(list 2>/dev/null)"
  check "no remote main: warned" "peal: warning: no origin/main; reading the local main, which may be stale" "$err"
  git -C "$work" checkout -q --detach
  git -C "$work" branch -q -D main
  check_refused "no main at all" "neither origin/main nor main exists" list

  # The settings: another remote, main branch, tasks directory and branch prefix.
  work=$(repo)
  mkdir -p "$work/.peal" "$work/work/items/backlog"
  printf 'main: trunk\nremote: up\ntasks: work/items\nbranch-prefix: t-\n' >"$work/.peal/config.yml"
  git -C "$work" remote rename origin up
  ID=0001 text >"$work/work/items/backlog/0001-custom-place.md"
  ID=0002 text >"$work/work/items/backlog/0002-custom-claim.md"
  git -C "$work" add -A
  git -C "$work" commit -q -m custom
  git -C "$work" push -q up main:trunk 2>/dev/null
  git -C "$work" fetch -q up
  git -C "$work" worktree add -q -b t-0002-custom-claim "$work-t" up/trunk 2>/dev/null
  scratch+=("$work-t")
  check "settings" "0001 free custom-place -
0002 claimed-live custom-claim wt:$work-t" "$(list 2>/dev/null)"
}

expansion() {
  local work err
  work=$(repo)
  put "$work" backlog 0001 m-one-a "milestone: m1"
  put "$work" "done" 0002 m-one-done "milestone: m1"
  put "$work" backlog 0003 m-one-review "milestone: m1" "depends: [milestone]"
  put "$work" backlog 0004 m-two-review "milestone: m2" "depends: [milestone]"
  put "$work" backlog 0005 no-milestone-review "depends: [milestone]"
  put "$work" backlog 0006 waits-for-human "depends: [human, 0001]"
  put "$work" backlog 0007 waits-for-nothing "depends: [9999]"
  put "$work" backlog 0008 bad-depends "depends: [soon, 0002]"

  check "milestone, human, unknown" "0001 free m-one-a m1
0002 done m-one-done
0003 blocked m-one-review needs:0001
0004 free m-two-review m2
0005 free no-milestone-review -
0006 blocked waits-for-human needs:human,0001
0007 blocked waits-for-nothing needs:9999
0008 free bad-depends -" "$(list 2>/dev/null)"
  err=$(list 2>&1 >/dev/null)
  check "warnings" "peal: warning: tasks/backlog/0008-bad-depends.md: depends: 'soon' is no task id, milestone or human; ignored
peal: warning: task 0005 depends on its milestone but has none; ignored
peal: warning: task 0007 depends on 9999, which is no task" "$err"

  # Splits: 0010 split into 0011 and 0012, 0012 split again into 0013 and 0014.
  work=$(repo)
  put "$work" backlog 0010 origin-task
  put "$work" backlog 0011 piece-one "part-of: 0010"
  put "$work" backlog 0012 piece-two "part-of: 0010"
  put "$work" "done" 0013 piece-two-a "part-of: 0012"
  put "$work" backlog 0014 piece-two-b "part-of: 0012" "depends: [0012]"
  put "$work" backlog 0015 waits-for-split "depends: [0010]"
  put "$work" backlog 0016 waits-for-subsplit "depends: [0012]"
  put "$work" backlog 0017 piece-waits-sibling "part-of: 0010" "depends: [0010, 0011]"
  put "$work" backlog 0018 self-origin "part-of: 0018"
  put "$work" backlog 0019 lost-piece "part-of: 0999"
  check "splits" "0010 free origin-task - split:0010 1/6
0011 free piece-one - split:0010 1/6
0012 free piece-two - split:0012 1/3
0013 done piece-two-a
0014 blocked piece-two-b needs:0012
0015 blocked waits-for-split needs:0010,0011,0012,0014,0017
0016 blocked waits-for-subsplit needs:0012,0014
0017 blocked piece-waits-sibling needs:0010,0011
0018 free self-origin -
0019 free lost-piece -" "$(list 2>/dev/null)"
  err=$(list 2>&1 >/dev/null)
  check "splits: warnings" "peal: warning: task 0018's part-of names itself; ignored
peal: warning: task 0019's part-of 0999 names no task; ignored" "$err"

  # A part-of cycle ends.
  work=$(repo)
  put "$work" backlog 0001 cycle-a "part-of: 0002"
  put "$work" backlog 0002 cycle-b "part-of: 0001"
  put "$work" backlog 0003 waits-cycle "depends: [0001]"
  check "a part-of cycle" "0001 free cycle-a - split:0001 0/2
0002 free cycle-b - split:0002 0/2
0003 blocked waits-cycle needs:0001,0002" "$(list 2>/dev/null)"

  # A file whose frontmatter leaves the subset is listed without fields, with a warning;
  # a second file for the same number too.
  work=$(repo)
  put "$work" backlog 0001 bad-header "milestone: [m1" "depends: [0002]"
  put "$work" backlog 0002 twice-filed
  put "$work" "done" 0002 twice-done
  put "$work" backlog 0003 needs-title
  printf -- '---\nmilestone: m1\n---\nno heading here\n' >"$work/tasks/backlog/0003-needs-title.md"
  publish "$work"
  printf 'not a task\n' >"$work/tasks/backlog/README.md"
  printf 'template\n' >"$work/tasks/TEMPLATE.md"
  publish "$work"
  check "bad files" "0001 free bad-header -
0002 done twice-done
0003 free needs-title m1" "$(list 2>/dev/null)"
  err=$(list 2>&1 >/dev/null)
  check "bad files: warnings" "peal: tasks/backlog/0001-bad-header.md:2: expected , or ]
peal: warning: task 0002 has more than one file: tasks/backlog/0002-twice-filed.md and tasks/done/0002-twice-done.md; reading tasks/done/0002-twice-done.md" "$err"
}

# Depends cycles made by hand: blocked with the cycle in list and board, and each cycle
# once in check.
cycles() {
  local work out
  work=$(repo)
  put "$work" backlog 0001 cycle-a "depends: [0002]"
  put "$work" backlog 0002 cycle-b "depends: [0001]"
  put "$work" backlog 0003 waits-on-cycle "depends: [0001]"
  put "$work" backlog 0004 ring-a "depends: [0005, human]"
  put "$work" backlog 0005 ring-b "depends: [0006]"
  put "$work" backlog 0006 ring-c "depends: [0004]"
  put "$work" backlog 0007 review-a "milestone: m2" "depends: [milestone]"
  put "$work" backlog 0008 review-b "milestone: m2" "depends: [milestone]"
  put "$work" backlog 0009 own-milestone "milestone: m1" "depends: [milestone]"
  OUTCOME=Done. put "$work" "done" 0010 done-first "depends: [0011]"
  put "$work" backlog 0011 after-done "depends: [0010]"
  put "$work" backlog 0012 origin-task "depends: [0013]"
  put "$work" backlog 0013 piece-task "part-of: 0012" "depends: [0012]"
  check "cycles: list" "0001 blocked cycle-a needs:0002 cycle: 0001 → 0002 → 0001
0002 blocked cycle-b needs:0001 cycle: 0002 → 0001 → 0002
0003 blocked waits-on-cycle needs:0001
0004 blocked ring-a needs:0005,human cycle: 0004 → 0005 → 0006 → 0004
0005 blocked ring-b needs:0006 cycle: 0005 → 0006 → 0004 → 0005
0006 blocked ring-c needs:0004 cycle: 0006 → 0004 → 0005 → 0006
0007 blocked review-a needs:0008 cycle: 0007 → 0008 → 0007
0008 blocked review-b needs:0007 cycle: 0008 → 0007 → 0008
0009 free own-milestone m1
0010 done done-first
0011 free after-done -
0012 blocked origin-task needs:0013 cycle: 0012 → 0013 → 0012
0013 blocked piece-task needs:0012 cycle: 0013 → 0012 → 0013" "$(list 2>/dev/null)"
  out=$(at "$work" "$PEAL" board --no-pr 2>/dev/null)
  check "cycles: board" '{"id":"0004","state":"blocked","slug":"ring-a","title":"Title of 0004","depends":["0005","human"],"cycle":"0004 → 0005 → 0006 → 0004","path":"tasks/backlog/0004-ring-a.md"}
{"id":"0009","state":"free","slug":"own-milestone","title":"Title of 0009","milestone":"m1","depends":["milestone"],"path":"tasks/backlog/0009-own-milestone.md"}' \
    "$(printf '%s\n' "$out" | grep -E '"id":"000[49]"')"
  check "cycles: board is JSON" "ok" "$(json_ok "$out")"
  check_refused "cycles: check" "peal: depends cycle 0001 → 0002 → 0001
peal: depends cycle 0004 → 0005 → 0006 → 0004
peal: depends cycle 0007 → 0008 → 0007
peal: depends cycle 0012 → 0013 → 0012" at "$work" "$PEAL" check

  # A claimed task on a cycle keeps its claim's state; the others still show the cycle.
  git -C "$work" worktree add -q -b task/0002-cycle-b "$work-0002" origin/main 2>/dev/null
  scratch+=("$work-0002")
  check "cycles: a claim on one" "0001 blocked cycle-a needs:0002 cycle: 0001 → 0002 → 0001
0002 claimed-live cycle-b wt:$work-0002" "$(list 0001 0002 2>/dev/null)"

  # Broken, the cycle is gone from every view.
  git -C "$work" rm -q tasks/backlog/0002-cycle-b.md tasks/backlog/0005-ring-b.md \
    tasks/backlog/0008-review-b.md tasks/backlog/0013-piece-task.md
  publish "$work"
  check "cycles: broken" "0001 blocked cycle-a needs:0002" "$(list 0001 2>/dev/null)"
  check "cycles: check, none" ":0" "$(at "$work" "$PEAL" check 2>&1):$?"
}

board() {
  local work out bin
  work=$(repo)
  TITLE='Say "hi" \ bye' put "$work" backlog 0001 odd-title "milestone: m1" "plan: required" "size: M" \
    "depends: [human]" "needs: [display, gpu]"
  put "$work" backlog 0002 piece-task "part-of: 0001" "model: opus"
  put "$work" backlog 0003 merging-task
  git -C "$work" worktree add -q -b task/0003-merging-task "$work-0003" origin/main 2>/dev/null
  scratch+=("$work-0003")
  mkdir -p "$work-0003/tasks/done"
  git -C "$work-0003" mv tasks/backlog/0003-merging-task.md tasks/done/
  git -C "$work-0003" commit -q -m close
  git -C "$work-0003" push -q origin HEAD 2>/dev/null

  out=$(at "$work" "$PEAL" board --no-pr 2>/dev/null)
  check "board: every line is JSON" "ok" "$(json_ok "$out")"
  check "board" '{"id":"0001","state":"blocked","slug":"odd-title","title":"Say \"hi\" \\ bye","milestone":"m1","depends":["human"],"size":"M","plan":"required","needs":["display","gpu"],"path":"tasks/backlog/0001-odd-title.md"}
{"id":"0002","state":"free","slug":"piece-task","title":"Title of 0002","part_of":"0001","path":"tasks/backlog/0002-piece-task.md"}
{"id":"0003","state":"awaiting-merge","slug":"merging-task","title":"Title of 0003","path":"tasks/backlog/0003-merging-task.md"}
{"milestone":{"id":"m0","title":"Milestone m0","state":"done","order":0}}
{"milestone":{"id":"m1","title":"Milestone m1","state":"current","order":1}}
{"milestone":{"id":"m2","title":"Milestone m2","state":"open","order":2}}
{"milestone":{"id":"m3","title":"Milestone m3","state":"parked","order":3}}' "$out"

  # The pull request of a task awaiting merge, from gh.
  bin=$(scratch_dir)
  printf '#!/bin/sh\nprintf "task/0003-merging-task\\t21\\tfalse\\thttps://example.com/pull/21\\n"\nprintf "other\\t5\\ttrue\\thttps://example.com/pull/5\\n"\n' >"$bin/gh"
  chmod +x "$bin/gh"
  out=$(PATH="$bin:$PATH" at "$work" "$PEAL" board 2>&1 | sed -n 3p)
  check "board: pr from gh" '{"id":"0003","state":"awaiting-merge","slug":"merging-task","title":"Title of 0003","pr":"#21","path":"tasks/backlog/0003-merging-task.md"}' "$out"
  check "list: pr from gh" "0003 awaiting-merge merging-task pr:#21 https://example.com/pull/21 wt:$work-0003" \
    "$(PATH="$bin:$PATH" at "$work" "$PEAL" list 0003 2>&1)"
  printf '#!/bin/sh\nprintf "task/0003-merging-task\\t21\\ttrue\\thttps://example.com/pull/21\\n"\n' >"$bin/gh"
  check "list: a draft" "0003 awaiting-merge merging-task pr:#21 https://example.com/pull/21 draft wt:$work-0003" \
    "$(PATH="$bin:$PATH" at "$work" "$PEAL" list 0003 2>&1)"
  printf '#!/bin/sh\nexit 1\n' >"$bin/gh"
  check "list: gh failing" "peal: warning: gh pr list failed; pull requests of tasks awaiting merge are unknown
0003 awaiting-merge merging-task pr:unknown wt:$work-0003" "$(PATH="$bin:$PATH" at "$work" "$PEAL" list 0003 2>&1)"
  printf '#!/bin/sh\necho called >&2\nexit 1\n' >"$bin/gh"
  check "list: gh only for a task awaiting merge" "0001 blocked odd-title needs:human" \
    "$(PATH="$bin:$PATH" at "$work" "$PEAL" list --state blocked 2>&1 | grep -v '^0003')"

  # A fork's pull request, named like the task's branch, supplies no url: a stranger's
  # branch of the same name proves nothing about this task.
  printf '#!/bin/sh\nprintf "task/0003-merging-task\\t22\\tfalse\\thttps://example.com/pull/22\\ttrue\\n"\n' >"$bin/gh"
  check "list: a fork's pull request supplies no url" "0003 awaiting-merge merging-task pr:unknown wt:$work-0003" \
    "$(PATH="$bin:$PATH" at "$work" "$PEAL" list 0003 2>&1)"

  git -C "$work" worktree remove --force "$work-0003"
  git -C "$work" branch -q -D task/0003-merging-task
  git -C "$work" push -q origin --delete task/0003-merging-task 2>/dev/null
  git -C "$work" fetch -q --prune origin
  check "list: no gh call without a task awaiting merge" "" \
    "$(PATH="$bin:$PATH" at "$work" "$PEAL" list 2>&1 >/dev/null)"

  # No milestones: task lines only.
  work=$(repo)
  git -C "$work" rm -q -r docs/milestones
  publish "$work"
  put "$work" backlog 0001 lone-task
  check "board: no milestones" '{"id":"0001","state":"free","slug":"lone-task","title":"Title of 0001","path":"tasks/backlog/0001-lone-task.md"}' \
    "$(at "$work" "$PEAL" board --no-pr)"
}

overview() {
  local work
  work=$(repo)
  check "overview: nothing open" "No open tasks." "$(at "$work" "$PEAL" overview 2>&1)"
  put "$work" backlog 0001 current-task "milestone: m1"
  put "$work" "done" 0002 current-done "milestone: m1"
  put "$work" backlog 0003 unassigned-task
  put "$work" backlog 0004 open-task "milestone: m2" "depends: [0001]"
  put "$work" backlog 0005 parked-task "milestone: m3"
  put "$work" backlog 0006 left-behind "milestone: m0"
  put "$work" backlog 0007 typo-task "milestone: m9"
  put "$work" backlog 0008 piece-task "part-of: 0003"
  check "overview" "m1 Milestone m1 (current) — 1 open, 1 done
  0001  free           current-task

No milestone — 2 open, 0 done
  0003  free           unassigned-task  split:0003 0/2
  0008  free           piece-task  split:0003 0/2

m2 Milestone m2 (open) — 1 open, 0 done
  0004  blocked        open-task  needs:0001

m3 Milestone m3 (parked) — 1 open, 0 done
  0005  free           parked-task

m0 Milestone m0 (done) — 1 open, 0 done
  0006  free           left-behind

m9 (no such milestone) — 1 open, 0 done
  0007  free           typo-task" "$(at "$work" "$PEAL" overview 2>&1 | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
}

priority() {
  local work err
  work=$(repo)
  put "$work" backlog 0001 urgent-task "milestone: m1" "priority: urgent"
  put "$work" backlog 0002 high-task "priority: high"
  put "$work" backlog 0003 normal-task "priority: normal"
  put "$work" backlog 0004 low-task "priority: low"
  put "$work" backlog 0005 odd-task "priority: soon"
  put "$work" "done" 0006 done-task "priority: urgent"
  check "priority: board" '{"id":"0001","state":"free","slug":"urgent-task","title":"Title of 0001","milestone":"m1","priority":"urgent","path":"tasks/backlog/0001-urgent-task.md"}
{"id":"0002","state":"free","slug":"high-task","title":"Title of 0002","priority":"high","path":"tasks/backlog/0002-high-task.md"}
{"id":"0003","state":"free","slug":"normal-task","title":"Title of 0003","path":"tasks/backlog/0003-normal-task.md"}
{"id":"0004","state":"free","slug":"low-task","title":"Title of 0004","priority":"low","path":"tasks/backlog/0004-low-task.md"}
{"id":"0005","state":"free","slug":"odd-task","title":"Title of 0005","path":"tasks/backlog/0005-odd-task.md"}
{"id":"0006","state":"done","slug":"done-task","title":"Title of 0006","priority":"urgent","path":"tasks/done/0006-done-task.md"}' \
    "$(at "$work" "$PEAL" board --no-pr 2>/dev/null | grep -v '^{"milestone"')"
  err=$(list 2>&1 >/dev/null)
  check "priority: an unknown word is normal, with a warning" \
    "peal: warning: tasks/backlog/0005-odd-task.md: priority: 'soon' is not urgent, high, normal or low; read as normal" "$err"
  check "priority: list" "0001 free urgent-task m1 priority:urgent
0002 free high-task - priority:high
0003 free normal-task -
0004 free low-task - priority:low
0005 free odd-task -
0006 done done-task" "$(list 2>/dev/null)"
  check "priority: overview" "m1 Milestone m1 (current) — 1 open, 0 done
  0001! free           urgent-task

No milestone — 4 open, 1 done
  0002↑ free           high-task
  0003  free           normal-task
  0004  free           low-task
  0005  free           odd-task" "$(at "$work" "$PEAL" overview 2>/dev/null | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
}

# A human task's owner in the board, the list and the overview; a task depending on one
# waits for it like for any other.
owner() {
  local work err
  work=$(repo)
  put "$work" backlog 0001 human-task "milestone: m1" "owner: human"
  put "$work" backlog 0002 ai-task "owner: ai"
  put "$work" backlog 0003 waits-task "depends: [0001]"
  put "$work" backlog 0004 odd-task "owner: robot"
  put "$work" "done" 0005 done-task "owner: human"
  put "$work" backlog 0006 after-done "depends: [0005]"
  check "owner: board" '{"id":"0001","state":"free","slug":"human-task","title":"Title of 0001","milestone":"m1","owner":"human","path":"tasks/backlog/0001-human-task.md"}
{"id":"0002","state":"free","slug":"ai-task","title":"Title of 0002","path":"tasks/backlog/0002-ai-task.md"}
{"id":"0003","state":"blocked","slug":"waits-task","title":"Title of 0003","depends":["0001"],"path":"tasks/backlog/0003-waits-task.md"}
{"id":"0004","state":"free","slug":"odd-task","title":"Title of 0004","path":"tasks/backlog/0004-odd-task.md"}
{"id":"0005","state":"done","slug":"done-task","title":"Title of 0005","owner":"human","path":"tasks/done/0005-done-task.md"}
{"id":"0006","state":"free","slug":"after-done","title":"Title of 0006","depends":["0005"],"path":"tasks/backlog/0006-after-done.md"}' \
    "$(at "$work" "$PEAL" board --no-pr 2>/dev/null | grep -v '^{"milestone"')"
  err=$(list 2>&1 >/dev/null)
  check "owner: an unknown word is ai, with a warning" \
    "peal: warning: tasks/backlog/0004-odd-task.md: owner: 'robot' is not ai or human; read as ai" "$err"
  check "owner: list" "0001 free human-task m1 owner:human
0002 free ai-task -
0003 blocked waits-task needs:0001
0004 free odd-task -
0005 done done-task
0006 free after-done -" "$(list 2>/dev/null)"
  check "owner: overview" "m1 Milestone m1 (current) — 1 open, 0 done
  0001  free           human-task  owner:human

No milestone — 4 open, 1 done
  0002  free           ai-task
  0003  blocked        waits-task  needs:0001
  0004  free           odd-task
  0006  free           after-done" "$(at "$work" "$PEAL" overview 2>/dev/null | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
}

# touches: a list (a single path read as one), in the board only.
touches() {
  local work
  work=$(repo)
  put "$work" backlog 0001 two-paths "touches: [docs/api.md, 'ui/**/*.tscn']"
  put "$work" backlog 0002 one-path "touches: scripts/rank"
  put "$work" backlog 0003 no-paths "touches: []"
  check "touches: board" '{"id":"0001","state":"free","slug":"two-paths","title":"Title of 0001","touches":["docs/api.md","ui/**/*.tscn"],"path":"tasks/backlog/0001-two-paths.md"}
{"id":"0002","state":"free","slug":"one-path","title":"Title of 0002","touches":["scripts/rank"],"path":"tasks/backlog/0002-one-path.md"}
{"id":"0003","state":"free","slug":"no-paths","title":"Title of 0003","path":"tasks/backlog/0003-no-paths.md"}' \
    "$(at "$work" "$PEAL" board --no-pr 2>&1 | grep -v '^{"milestone"')"
  check "touches: not in the list" "0001 free two-paths -
0002 free one-path -
0003 free no-paths -" "$(list 2>&1)"
}

# merge: auto in the board only; any other word warned about and read as the default.
merge() {
  local work err
  work=$(repo)
  put "$work" backlog 0001 auto-merge "merge: auto"
  put "$work" backlog 0002 odd-merge "merge: always"
  put "$work" backlog 0003 default-merge
  check "merge: board" '{"id":"0001","state":"free","slug":"auto-merge","title":"Title of 0001","merge":"auto","path":"tasks/backlog/0001-auto-merge.md"}
{"id":"0002","state":"free","slug":"odd-merge","title":"Title of 0002","path":"tasks/backlog/0002-odd-merge.md"}
{"id":"0003","state":"free","slug":"default-merge","title":"Title of 0003","path":"tasks/backlog/0003-default-merge.md"}' \
    "$(at "$work" "$PEAL" board --no-pr 2>/dev/null | grep -v '^{"milestone"')"
  err=$(list 2>&1 >/dev/null)
  check "merge: an unknown word is the default, with a warning" \
    "peal: warning: tasks/backlog/0002-odd-merge.md: merge: 'always' is not auto; read as the project's default" "$err"
  check "merge: not in the list" "0001 free auto-merge -
0002 free odd-merge -
0003 free default-merge -" "$(list 2>/dev/null)"
}

cases() {
  states
  expansion
  cycles
  board
  overview
  priority
  owner
  touches
  merge
}

for_each_awk cases
finish
